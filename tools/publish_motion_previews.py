#!/usr/bin/env python3
"""Validate completed native motion exports and upload to a draft release."""
import argparse,hashlib,json,subprocess,time,concurrent.futures
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--folder',type=Path,required=True);p.add_argument('--tag',required=True);a=p.parse_args();root=a.folder.resolve();themes=json.loads((root/'catalog.json').read_text())['themes'];resultFile=root/'uploaded-motion.json';results=json.loads(resultFile.read_text()) if resultFile.exists() else {};repo='leonardob8777-bit/Coconut-Catalog'
assets=json.loads(subprocess.check_output(['gh','api',f'repos/{repo}/releases/420007607']))['assets']
existing={v['name']:v for v in assets}
def upload(t):
 id=t['id'];path=root/(id+'-motion.mp4')
 if not path.exists():return None
 probe=subprocess.run(['ffprobe','-v','error','-show_entries','stream=width,height:format=duration','-of','json',str(path)],capture_output=True)
 if probe.returncode:return None
 d=json.loads(probe.stdout);duration=float(d['format']['duration'])
 if duration<11.5:return None
 frames=[]
 for second in [1,5,10]:
  frames.append(subprocess.check_output(['ffmpeg','-v','error','-ss',str(second),'-i',str(path),'-frames:v','1','-vf','scale=64:128,format=gray','-f','rawvideo','-']))
 delta=max(sum(abs(x-y) for x,y in zip(frames[0],f))/len(f) for f in frames[1:])
 if delta<0.1:raise RuntimeError('Preview has no measurable motion: '+id)
 if d['streams'][0]['width']<1170:raise RuntimeError('Unexpected resolution: '+id)
 sha=hashlib.sha256(path.read_bytes()).hexdigest()
 if path.name in existing:
  asset=existing[path.name]
  if asset.get('state') != 'uploaded' or asset['size'] != path.stat().st_size:
   asset=json.loads(subprocess.check_output(['gh','api',f'repos/{repo}/releases/assets/{asset["id"]}']))
   if asset.get('state') != 'uploaded':
    # A previous completed gh process can leave a failed upload placeholder.
    subprocess.run(['gh','api','--method','DELETE',f'repos/{repo}/releases/assets/{asset["id"]}'],check=True,stdout=subprocess.DEVNULL)
    existing.pop(path.name,None)
    subprocess.run(['gh','release','upload',a.tag,'--repo',repo,str(path)],check=True)
    asset={'size':path.stat().st_size}
  assert asset['size']==path.stat().st_size
 else:
  subprocess.run(['gh','release','upload',a.tag,'--repo',repo,str(path)],check=True)
 return id,{'sha256':sha,'bytes':path.stat().st_size,'duration':duration,'width':d['streams'][0]['width'],'height':d['streams'][0]['height'],'motionDifference':delta,'url':f'https://github.com/{repo}/releases/download/{a.tag}/{path.name}'}
with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
 pending={};queued=set()
 while len(results)<len(themes):
  for t in themes:
   if t['id'] not in results and t['id'] not in queued and (root/(t['id']+'-motion.mp4')).exists():
    pending[pool.submit(upload,t)]=t['id'];queued.add(t['id'])
  for future in list(pending):
   if not future.done():continue
   id=pending.pop(future);queued.remove(id);value=future.result()
   if value:
    results[value[0]]=value[1];resultFile.write_text(json.dumps(results,indent=2));print(f'{len(results)}/{len(themes)} verified and uploaded: {id}',flush=True)
  if len(results)<len(themes):time.sleep(5)
print('ALL_UPLOADS_VERIFIED',flush=True)
