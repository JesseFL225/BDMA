"""Offline, conservative linkage audit. Does not train models or score 2025."""
from pathlib import Path
from datetime import datetime,timezone
from zoneinfo import ZoneInfo
from collections import defaultdict,Counter
import csv,lzma,xml.etree.ElementTree as ET,hashlib,json,re
from download import ROOT,CACHE,OUT,DATES
# Some planned-work XML payloads exceed Python's small default CSV field limit.
csv.field_size_limit(5_000_000)
UTC=timezone.utc
LOCAL=ZoneInfo('Europe/Amsterdam')

def stamp(value):
    if not value:return None
    t=datetime.fromisoformat(value.strip().replace('Z','+00:00'))
    if t.tzinfo is None:raise ValueError('Ambiguous timestamp without timezone')
    return t.astimezone(UTC)

def iso(t):return t.isoformat() if t else ''
def normalize_cause(value):
    return re.sub(r"^(?:door\s+)?(?:een\s+)?", "", " ".join(value.casefold().split())).strip(" .")
def text(node,path):
    e=node.find(path)
    return (e.text or '').strip() if e is not None else ''
def values(node,path):return sorted({(e.text or '').strip().upper() for e in node.findall(path) if (e.text or '').strip()})
def write_csv(path,rows,fields=None):
    fields=fields or (list(rows[0]) if rows else ['no_records'])
    with path.open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=fields);w.writeheader();w.writerows(rows)

def parse_message(row,path,line):
    if len(row)!=4:raise ValueError(f'Expected four fields, got {len(row)}')
    root=ET.fromstring(row[2])
    for e in root.iter():e.tag=e.tag.split('}')[-1]
    record=root.find('.//LandelijkePatroonInformatie')
    if record is None:
        return None,{'file':path.name,'line':line,'root_types':'|'.join(sorted({e.tag for e in root.iter()}))}
    received=stamp(row[0]); published=stamp(text(root,'.//ReisInformatieTijdstip'))
    released=stamp(text(record,'VrijgaveTijd'))
    available=max(t for t in (received,published,released) if t is not None)
    situation=record.find('Situatie')
    stations=values(record,'.//BaanvakBeperking//StationCode')
    # Only affected-route sections, never detour/advisory station lists.
    endpoints=values(record,'.//BaanvakBeperking/StationVan/StationCode')+values(record,'.//BaanvakBeperking/StationTot/StationCode')
    return dict(source_file=path.name,source_line=line,payload_sha256=hashlib.sha256(row[2].encode()).hexdigest(),
      dossier=text(record,'DossierNummer'),sequence=text(record,'DossierVolgNummer'),
      kind=text(record,'VerstoringSoort'),phase=text(record,'VerstoringFase'),change=text(record,'WijzigingTypeBericht'),
      received=iso(received),published=iso(published),released=iso(released),available=iso(available),
      registered=text(record,'RegistratieTijd'),incident_begin=text(record,'.//EVBeginTijd'),
      cause=text(record,'.//OorzaakKort'),impact=text(record,'VerstoringImpact'),
      impact_text=text(record,'.//ImpactOmschrijvingKort'),
      service_effects='|'.join(values(record,'.//GevolgenTreindienst/Niveau')),
      station_codes='|'.join(stations),endpoints='|'.join(sorted(set(endpoints))),
      location=' | '.join((e.text or '').strip() for e in record.findall('./PresentatieLocatie/Uitingen[@Taal="nl"]/Uiting')),
      forecast_code=text(record,'.//Prognose/TreindienstNormaalCode'),
      situation_clear=text(record,'.//Prognose/SituatieDuidelijk'),
      forecast_from=text(record,'.//Prognose/PrognoseVanTijd'),forecast_to=text(record,'.//Prognose/PrognoseTotTijd'),
      forecast_text=text(record,'.//Prognose/Omschrijving/Lang'),
      situation_text=' | '.join((e.text or '').strip() for e in record.findall('./PresentatieSituatie/Uitingen[@Taal="nl"]/Uiting'))),None

def candidates_for(row,messages,tolerance=120):
    start=stamp(row['start_time']);rs={s.strip().upper() for s in row['rdt_station_codes'].split(',') if s.strip() not in ('','NA')}
    out=[]
    for m in messages:
        # Publication time is the linkage clock; receive time is the strict feature-availability clock.
        mt=stamp(m['published']) or stamp(m['received'])
        delta=(mt-start).total_seconds()
        ss=set(filter(None,m['station_codes'].split('|')));common=rs&ss
        overlap=len(common)/min(len(rs),len(ss)) if rs and ss else 0
        required=min(2,len(rs),len(ss))
        eligible=bool(abs(delta)<=tolerance and common and len(common)>=required and overlap>=.5)
        if abs(delta)<=600:
            out.append(dict(rdt_id=row['rdt_id'],dossier=m['dossier'],publication_delta_seconds=round(delta,3),
              available_delta_seconds=round((stamp(m['available'])-start).total_seconds(),3),
              matched_station_codes='|'.join(sorted(common)),rdt_station_codes='|'.join(sorted(rs)),
              first_station_codes=m['station_codes'],station_overlap_coefficient=overlap,
              first_sequence=m['sequence'],first_phase=m['phase'],eligible=eligible,
              source_file=m['source_file'],source_line=m['source_line']))
    return out

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    frozen=json.loads(json.dumps(list(csv.DictReader(open(ROOT/'moddeling/09_modelkeuze_en_test/output/frozen_manifest.csv')))))
    for item in frozen:assert hashlib.md5((ROOT/item['path']).read_bytes()).hexdigest()==item['md5']
    manifest=json.loads((OUT/'download_manifest.json').read_text())
    if len(manifest)!=12:raise RuntimeError('Download inventory incomplete: finish the twelve-file pilot first')
    messages=[];inventory=[];errors=[];other=[]
    for item in manifest:
        if item['status']!='ok':continue
        path=ROOT/item['path'];assert hashlib.sha256(path.read_bytes()).hexdigest()==item['sha256']
        n=0;pil=0;dossiers=set();seen_time=[]
        with lzma.open(path,'rt',encoding='utf-8-sig',newline='') as f:
            for line,row in enumerate(csv.reader(f),1):
                n+=1
                try:
                    received=stamp(row[0]);seen_time.append(received)
                    m,nonpil=parse_message(row,path,line)
                    if m:
                        messages.append(m);pil+=1;dossiers.add(m['dossier'])
                    elif nonpil:other.append(nonpil)
                except (ET.ParseError,ValueError,IndexError) as exc:
                    errors.append(dict(file=path.name,line=line,error=str(exc)))
        inventory.append(dict(file=path.name,bytes=item['bytes'],rows=n,pil_rows=pil,dossiers=len(dossiers),
          min_received=iso(min(seen_time)) if seen_time else '',max_received=iso(max(seen_time)) if seen_time else ''))
    # Deduplicate exact payloads, retaining earliest observed availability. Grouping
    # uses source dossier, not a guessed equality between dossier and RDT IDs.
    unique={}
    for m in sorted(messages,key=lambda x:stamp(x['available'])):unique.setdefault(m['payload_sha256'],m)
    dossiers=defaultdict(list)
    for m in unique.values():
        if m['dossier'] and m['kind']=='EV':dossiers[m['dossier']].append(m)
    first=[]
    for dossier,rows in dossiers.items():
        m=min(rows,key=lambda x:(stamp(x['available']),x['payload_sha256'])).copy()
        m['observed_messages']=len(rows)
        m['initial_sequence_one']=m['sequence']=='1'
        m['initial_phase']=m['phase'] in ('1','1A','1B')
        m['is_initial_evidence']=m['initial_sequence_one'] and m['initial_phase'] and m['change']!='V'
        first.append(m)
    # Only selected development dates are retained. No duration/end/outcome fields
    # are used for matching, and no 2024/2025 rows enter the pilot.
    cohort=[]
    with (ROOT/'data/disruptions_2011_2025_clean.csv').open() as f:
        for r in csv.DictReader(f):
            if stamp(r['start_time']).astimezone(LOCAL).date().isoformat() in DATES:
                cohort.append({k:r[k] for k in ('rdt_id','start_time','rdt_station_codes','ns_lines','cause_nl')})
    candidates=[c for r in cohort for c in candidates_for(r,first)]
    eligible=[c for c in candidates if c['eligible']]
    byrdt=defaultdict(list);bydossier=defaultdict(list)
    for c in eligible:byrdt[c['rdt_id']].append(c);bydossier[c['dossier']].append(c)
    firstmap={m['dossier']:m for m in first}
    links=[];features=[]
    for r in cohort:
        cs=byrdt[r['rdt_id']]
        chosen=cs[0] if len(cs)==1 and len(bydossier[cs[0]['dossier']])==1 else None
        status='unique_provisional' if chosen else ('ambiguous' if cs else 'no_candidate')
        links.append(dict(**r,status=status,candidate_count=len(cs),dossier=chosen['dossier'] if chosen else '',
          **({k:chosen[k] for k in ('publication_delta_seconds','available_delta_seconds','station_overlap_coefficient')} if chosen else
             dict(publication_delta_seconds='',available_delta_seconds='',station_overlap_coefficient=''))))
        if chosen:
            m=firstmap[chosen['dossier']];start=stamp(r['start_time']);available=stamp(m['available'])
            ftime=stamp(m['forecast_from'])
            delay=(available-start).total_seconds()
            features.append(dict(rdt_id=r['rdt_id'],dossier=m['dossier'],rdt_start=r['start_time'],
              initial_evidence=m['is_initial_evidence'],first_sequence=m['sequence'],first_phase=m['phase'],
              feature_available=iso(available),available_at_exact_rdt_start=available<=start,
              publication_delta_seconds=chosen['publication_delta_seconds'],available_delta_seconds=delay,
              prediction_time_first_received=iso(max(start,available)),
              cause_first=m['cause'],cause_final_for_audit_only=r['cause_nl'],cause_text_different=m['cause'].casefold()!=r['cause_nl'].casefold(),
              cause_changed=normalize_cause(m['cause'])!=normalize_cause(r['cause_nl']),
              impact=m['impact'],impact_text=m['impact_text'],service_effects=m['service_effects'],
              first_station_codes=m['station_codes'],first_location=m['location'],
              forecast_code=m['forecast_code'],forecast_text=m['forecast_text'],forecast_from=m['forecast_from'],forecast_to=m['forecast_to'],
              forecast_minutes_from_receipt=(ftime-max(start,available)).total_seconds()/60 if ftime else '',
              incident_begin=m['incident_begin'],source_file=m['source_file'],source_line=m['source_line']))
    write_csv(OUT/'message_inventory.csv',inventory);write_csv(OUT/'parse_errors.csv',errors)
    write_csv(OUT/'non_pil_schemas.csv',[dict(schema=s,rows=n) for s,n in Counter(x['root_types'] for x in other).items()])
    write_csv(OUT/'first_observed_dossiers.csv',sorted(first,key=lambda x:x['available']))
    write_csv(OUT/'candidate_audit.csv',candidates);write_csv(OUT/'linkage_results.csv',links)
    write_csv(OUT/'first_message_features_REVIEW_ONLY.csv',features)
    summary=[]
    for day in DATES:
        ids={r['rdt_id'] for r in cohort if stamp(r['start_time']).astimezone(LOCAL).date().isoformat()==day}
        ls=[r for r in links if r['rdt_id'] in ids];fs=[r for r in features if r['rdt_id'] in ids]
        summary.append(dict(day=day,clean_disruptions=len(ls),unique_provisional=sum(r['status']=='unique_provisional' for r in ls),
          ambiguous=sum(r['status']=='ambiguous' for r in ls),no_candidate=sum(r['status']=='no_candidate' for r in ls),
          initial_evidence=sum(r['initial_evidence'] for r in fs),cause_available=sum(bool(r['cause_first']) for r in fs),
          impact_available=sum(bool(r['impact']) for r in fs),forecast_time_available=sum(bool(r['forecast_from']) for r in fs),
          exact_start_available=sum(r['available_at_exact_rdt_start'] for r in fs),cause_changed=sum(r['cause_changed'] for r in fs)))
    write_csv(OUT/'coverage_summary.csv',summary)
    for item in frozen:assert hashlib.md5((ROOT/item['path']).read_bytes()).hexdigest()==item['md5']
    write_csv(OUT/'checks.csv',[dict(check='Frozen test source/model/data hashes unchanged',passed=True),
      dict(check='Only prespecified 2017/2020/2023 pilot dates retained',passed=all(stamp(r['start_time']).year in (2017,2020,2023) for r in cohort)),
      dict(check='Accepted links one-to-one',passed=len({f['dossier'] for f in features})==len(features)),
      dict(check='Zero XML parse errors',passed=not errors)])
    print(json.dumps(summary,indent=2));print('Parse errors',len(errors),'messages',len(messages),'dossiers',len(first))

if __name__=='__main__':main()
