#!/usr/bin/env python3
"""Refresh repository-owned badge snapshots using authenticated GitHub metadata."""
import datetime, json, os, re, urllib.request
from pathlib import Path
from html import escape
ROOT=Path(__file__).resolve().parents[1]
REPO='leonardob8777-bit/Coconut'
def api(path):
 headers = {'User-Agent': 'Coconut-README-stats', 'Accept': 'application/vnd.github+json'}
 token = os.environ.get('GH_TOKEN') or os.environ.get('GITHUB_TOKEN')
 if token:
  headers['Authorization'] = f'Bearer {token}'
 request = urllib.request.Request('https://api.github.com/' + path, headers=headers)
 with urllib.request.urlopen(request, timeout=30) as response:
  return json.load(response)
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
(ROOT/'docs/brand/star.svg').write_text(f'''<svg xmlns="http://www.w3.org/2000/svg" width="132" height="48" viewBox="0 0 132 48" role="img" aria-label="Stars {stars}"><rect x=".5" y=".5" width="131" height="47" rx="11" fill="#f4f1ea" stroke="#c8beae"/><path d="m20 14 3 6 7 1-5 5 1 7-6-3-6 3 1-7-5-5 7-1Z" fill="none" stroke="#584b3e" stroke-width="1.5" stroke-linejoin="round"/><text x="38" y="30" font-family="Arial,sans-serif" font-size="16" font-weight="700" fill="#28251f">Stars {compact(stars)}</text></svg>\n''')
ipa=next((a for a in latest['assets'] if a['name'].endswith('-unsigned.ipa')), next(a for a in latest['assets'] if a['name'].endswith('.ipa')))
(ROOT/'docs/brand/download.svg').write_text(f'''<svg xmlns="http://www.w3.org/2000/svg" width="272" height="70" viewBox="0 0 272 70" role="img" aria-label="Download IPA, {ipa['size']/1000000:.2f} MB, {count} downloads"><rect x=".5" y=".5" width="271" height="69" rx="12" fill="#28251f" stroke="#ac9d88"/><g transform="translate(17 13)" fill="none" stroke="#fffaf0" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3v12m-5-5 5 5 5-5M4 17v4h16v-4"/></g><text x="52" y="32" font-family="Arial,sans-serif" font-size="20" font-weight="700" fill="#fffaf0">Download IPA</text><text x="136" y="55" text-anchor="middle" font-family="Arial,sans-serif" font-size="14" font-weight="600" fill="#fffaf0">{ipa['size']/1000000:.2f} MB · {count:,} downloads</text></svg>\n''')

# Refresh README labels and image URLs so cached buttons pick up this snapshot.
readme = ROOT / 'README.md'
text = readme.read_text()
now = datetime.datetime.now(datetime.timezone.utc)
cache_key = now.strftime('counts-%Y-%m-%dT%H%M%SZ')
for button in ('download', 'star'):
 text = re.sub(r'docs/brand/' + button + r'\.svg(?:\?[^"\s]*)?',
               f'docs/brand/{button}.svg?v={cache_key}', text)
text = re.sub(r'alt="Stars \d+"', f'alt="Stars {stars}"', text)
text = re.sub(r'Counts checked [^.]+\.',
              f"Counts checked {now.strftime('%B')} {now.day}, {now.year} (UTC).", text)
readme.write_text(text)
