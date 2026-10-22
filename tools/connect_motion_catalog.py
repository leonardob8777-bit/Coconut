#!/usr/bin/env python3
"""Connect verified public previews, changing no wallpaper package fields."""
import base64,hashlib,json,subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[1];folder=root/'build/motion-completion';repo='leonardob8777-bit/Coconut-Catalog';tag='motion-previews-2026-10-21'
uploaded=json.loads((folder/'uploaded-motion.json').read_text());expected=json.loads((folder/'catalog.json').read_text())['themes']
assert all(t['id'] in uploaded for t in expected),'Exports/uploads are incomplete'
def api(path):return json.loads(subprocess.check_output(['gh','api',path]))
release=api(f'repos/{repo}/releases/420007607');assets={v['name']:v for v in release['assets']}
for id,v in uploaded.items():
 asset=assets[id+'-motion.mp4'];assert asset['state']=='uploaded' and asset['size']==v['bytes'];assert asset['digest']=='sha256:'+v['sha256'],id
originals=json.loads((folder/'originals.json').read_text());originalRelease=api(f'repos/{repo}/releases/tags/gyroscope-2026-10-20');originalAssets={v['name']:v for v in originalRelease['assets']};links={id:v['url'] for id,v in uploaded.items()}
for id,path in originals.items():
 p=Path(path);a=originalAssets[p.name];assert a['digest']=='sha256:'+hashlib.sha256(p.read_bytes()).hexdigest(),id
 links[id]=a['browser_download_url']
subprocess.run(['gh','release','edit',tag,'--repo',repo,'--draft=false'],check=True)
remote=api(f'repos/{repo}/contents/catalog.json');document=json.loads(base64.b64decode(remote['content']))
for t in document['themes']:
 if t['id'] in links:t['previewVideoURL']=links[t['id']]
missing=[t['id'] for t in document['themes'] if not t.get('previewVideoURL')]
assert not missing,('Uncovered public themes',missing)
payload={'message':'Connect full-quality motion previews for every current wallpaper','sha':remote['sha'],'content':base64.b64encode((json.dumps(document,ensure_ascii=False,indent=2)+'\n').encode()).decode()}
payloadPath=folder/'catalog-update-request.json';payloadPath.write_text(json.dumps(payload))
subprocess.run(['gh','api','--method','PUT',f'repos/{repo}/contents/catalog.json','--input',str(payloadPath)],check=True,stdout=subprocess.DEVNULL)
readback=api(f'repos/{repo}/contents/catalog.json');verified=json.loads(base64.b64decode(readback['content']));assert verified==document
localPath=root/'App/BundledCatalog/catalog.json';local=json.loads(localPath.read_text())
for t in local['themes']:
 if t['id'] in links:t['previewVideoURL']=links[t['id']]
assert all(t.get('previewVideoURL') for t in local['themes'])
localPath.write_text(json.dumps(local,ensure_ascii=False,indent=2)+'\n')
(folder/'catalog-readback.json').write_text(json.dumps(verified,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'remoteThemes':len(document['themes']),'localThemes':len(local['themes']),'connectedNewPreviews':len(links),'allHaveVideo':True,'remoteSHA':readback['sha']},indent=2))
