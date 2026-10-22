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

# Keep counts inside the actual action buttons, not in a separate text row.
def compact(number):
 return str(number) if number < 10000 else (f'{number/1000:.1f}'.rstrip('0').rstrip('.')+'k' if number < 1000000 else f'{number/1000000:.1f}'.rstrip('0').rstrip('.')+'m')
stars=repo['stargazers_count']
(ROOT/'docs/brand/star.svg').write_text(f'''<svg xmlns="http://www.w3.org/2000/svg" width="132" height="48" viewBox="0 0 132 48" role="img" aria-label="Star: {stars}"><rect x=".5" y=".5" width="131" height="47" rx="11" fill="#f4f1ea" stroke="#c8beae"/><path d="m20 14 3 6 7 1-5 5 1 7-6-3-6 3 1-7-5-5 7-1Z" fill="none" stroke="#584b3e" stroke-width="1.5" stroke-linejoin="round"/><text x="36" y="29" font-family="Arial,sans-serif" font-size="14" font-weight="600" fill="#28251f">Star</text><path d="M72 12v24" stroke="#d6cdbf"/><text x="102" y="29" text-anchor="middle" font-family="Arial,sans-serif" font-size="14" font-weight="700" fill="#28251f">{compact(stars)}</text></svg>\n''')
ipa=next(a for a in latest['assets'] if a['name'].endswith('.ipa'))
version=escape(latest['tag_name'])
(ROOT/'docs/brand/download.svg').write_text(f'''<svg xmlns="http://www.w3.org/2000/svg" width="272" height="62" viewBox="0 0 272 62" role="img" aria-label="Download IPA: {count} downloads"><rect x=".5" y=".5" width="271" height="61" rx="12" fill="#28251f" stroke="#ac9d88"/><g transform="translate(16 19)" fill="none" stroke="#fffaf0" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3v12m-5-5 5 5 5-5M4 17v4h16v-4"/></g><text x="50" y="28" font-family="Arial,sans-serif" font-size="17" font-weight="700" fill="#fffaf0">Download IPA</text><text x="50" y="47" font-family="Arial,sans-serif" font-size="12" fill="#d7cbbc">{version} · {ipa['size']/1000000:.2f} MB</text><path d="M191 13v36" stroke="#655a4d"/><text x="232" y="29" text-anchor="middle" font-family="Arial,sans-serif" font-size="19" font-weight="700" fill="#fffaf0">{compact(count)}</text><text x="232" y="45" text-anchor="middle" font-family="Arial,sans-serif" font-size="9" fill="#d7cbbc">downloads</text></svg>\n''')
