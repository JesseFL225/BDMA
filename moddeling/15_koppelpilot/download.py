"""Small, fixed-date feasibility sample. Cache downloads and record provenance."""
from pathlib import Path
from datetime import date, timedelta
import urllib.request, hashlib, json, time
ROOT=Path(__file__).resolve().parents[2]
CACHE=ROOT/'data/external/ndov_pilot'
OUT=ROOT/'moddeling/15_koppelpilot/output'
DATES=['2017-11-10','2020-11-10','2023-11-10']

def run():
    CACHE.mkdir(parents=True,exist_ok=True); OUT.mkdir(parents=True,exist_ok=True)
    # Each pilot day plus the preceding UTC day as lookback, for both message types.
    targets=[(kind,str(date.fromisoformat(day)-timedelta(days=back))) for day in DATES for back in (1,0) for kind in ('InfoPlusPIL','InfoPlusVTBL')]
    manifest=[]
    for kind,day in targets:
        url=f'https://trein.fwrite.org/dedup/{day[:7]}/{kind}_{day}.csv.xz'
        path=CACHE/f'{kind}_{day}.csv.xz'
        item=dict(kind=kind,day=day,url=url,path=str(path.relative_to(ROOT)))
        try:
            if not path.exists():
                with urllib.request.urlopen(url,timeout=40) as response:
                    body=response.read(5_000_001)
                if len(body)>5_000_000: raise ValueError('File exceeds 5 MB pilot budget')
                path.write_bytes(body)
                time.sleep(1)
            body=path.read_bytes()
            item.update(status='ok',bytes=len(body),sha256=hashlib.sha256(body).hexdigest())
        except Exception as exc: item.update(status='failed',error=str(exc))
        manifest.append(item); print(kind,day,item['status'],item.get('bytes',''),flush=True)
        (OUT/'download_manifest.json').write_text(json.dumps(manifest,indent=2))

if __name__=='__main__':
    run()
