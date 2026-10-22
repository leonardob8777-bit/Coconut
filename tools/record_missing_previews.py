#!/usr/bin/env python3
"""Record actual clean Core Animation playback; retain native pixels and timing."""
import argparse,json,os,signal,subprocess,tempfile,time,zipfile
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--folder',type=Path,required=True);p.add_argument('--simulator',required=True);p.add_argument('--seconds',type=float,default=12);p.add_argument('--limit',type=int);a=p.parse_args();folder=a.folder.resolve();themes=json.loads((folder/'catalog.json').read_text())['themes'];bundle='dev.leonardobaptiste.coconut.cleanrender'
def sim(*args,**kw):return subprocess.run(['xcrun','simctl',*args],**kw)
count=0
for i,t in enumerate(themes):
 dst=folder/(t['id']+'-motion.mp4')
 if dst.exists():
  probe=subprocess.run(['ffprobe','-v','error','-show_entries','format=duration','-of','csv=p=0',str(dst)],capture_output=True,text=True)
  if probe.returncode==0 and float(probe.stdout.strip() or 0)>=a.seconds-0.5:continue
 with tempfile.TemporaryDirectory(prefix='coconut-record-') as tmp:
  with zipfile.ZipFile(folder/t['packageURL']) as archive:
   for entry in archive.infolist():
    if Path(entry.filename).is_absolute() or '..' in Path(entry.filename).parts:raise ValueError('Unsafe archive')
   archive.extractall(tmp)
  wallpaper=next(Path(tmp).rglob('*.wallpaper'))
  sim('terminate',a.simulator,bundle,capture_output=True)
  env=dict(os.environ,SIMCTL_CHILD_WALL_DIR=str(wallpaper),SIMCTL_CHILD_WALL_CLEAN='1',SIMCTL_CHILD_WALL_STATIC='1')
  sim('launch',a.simulator,bundle,env=env,check=True,capture_output=True)
  time.sleep(1.5)
  recording=subprocess.Popen(['xcrun','simctl','io',a.simulator,'recordVideo','--codec=h264','--mask=ignored','--force',str(dst)],stderr=subprocess.PIPE,text=True)
  try:
   while True:
    line=recording.stderr.readline()
    if 'Recording started' in line:break
    if not line and recording.poll() is not None:raise RuntimeError('Recorder failed: '+t['id'])
   time.sleep(a.seconds)
  finally:
   if recording.poll() is None:recording.send_signal(signal.SIGINT)
   recording.communicate(timeout=30)
   sim('terminate',a.simulator,bundle,capture_output=True)
  if recording.returncode!=0:raise RuntimeError('Recording failed: '+t['id'])
  print(f'{i+1}/{len(themes)} {t["id"]}: original animation recorded',flush=True)
 count+=1
 if a.limit and count>=a.limit:break
