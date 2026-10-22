#!/usr/bin/env python3
"""Refresh repository-owned badge snapshots using authenticated GitHub metadata."""
import datetime, json, subprocess
from pathlib import Path
from html import escape
ROOT=Path(__file__).resolve().parents[1]
REPO='leonardob8777-bit/Coconut-Catalog'
def api(path): return json.loads(subprocess.check_output(['gh','api',path]))
repo=api('repos/'+REPO)
releases=[]
page=1
while True:
 batch=api(f'repos/{REPO}/releases?per_page=100&page={page}')
 releases.extend(batch)
 if len(batch)<100: break
 page+=1
public=[r for r in releases if not r['draft']]
ipareleases=[r for r in public if any(a['name'].endswith('.ipa') for a in r['assets'])]
latest=max(ipareleases,key=lambda r:r['published_at'])
count=sum(a['download_count'] for r in public for a in r['assets'] if a['name'].endswith('.ipa'))
values=[('release','VERSION',latest['tag_name'].lstrip('v')),('downloads','IPA DOWNLOADS',str(count)),('stars','GITHUB STARS',str(repo['stargazers_count'])),('license','APP LICENSE','AGPL-3.0')]
for name,label,value in values:
 svg=f'''<svg xmlns="http://www.w3.org/2000/svg" width="220" height="76" viewBox="0 0 220 76" role="img" aria-label="{escape(label)}: {escape(value)}"><rect x=".5" y=".5" width="219" height="75" rx="18" fill="#f4f1ea" stroke="#e0dacf"/><text x="20" y="26" font-family="-apple-system,BlinkMacSystemFont,Segoe UI,Arial,sans-serif" font-size="10" font-weight="600" letter-spacing="1.5" fill="#786d61">{label}</text><text x="20" y="55" font-family="-apple-system,BlinkMacSystemFont,Segoe UI,Arial,sans-serif" font-size="23" font-weight="600" fill="#28251f">{escape(value)}</text><circle cx="196" cy="23" r="3" fill="#bba58a"/></svg>'''
 (ROOT/'docs/badges'/f'{name}.svg').write_text(svg+'\n')
snapshot={'checkedAtUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),'ipaDownloads':count,'stars':repo['stargazers_count'],'version':latest['tag_name'],'releaseURL':latest['html_url']}
(ROOT/'docs/badges/snapshot.json').write_text(json.dumps(snapshot,indent=2)+'\n')
print(json.dumps(snapshot))
