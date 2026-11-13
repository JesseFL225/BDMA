"""Reconcile saved pilot outputs with original cached messages and document scope."""
import csv,json,lzma,statistics
from collections import Counter
from pathlib import Path
from pilot import ROOT,OUT,stamp,parse_message

def read(name):
    with (OUT/name).open() as f:return list(csv.DictReader(f))
def yes(s):return s=='True'
manifest=json.loads((OUT/'download_manifest.json').read_text())
assert len(manifest)==12
coverage=read('coverage_summary.csv');links=read('linkage_results.csv');features=read('first_message_features_REVIEW_ONLY.csv')
first={m['dossier']:m for m in read('first_observed_dossiers.csv')}
assert len({r['rdt_id'] for r in links})==len(links)
assert len(features)==sum(r['status']=='unique_provisional' for r in links)
assert len({r['dossier'] for r in features})==len(features)
assert sum(int(r['clean_disruptions']) for r in coverage)==len(links)
# Independent reconstruction from the source row ensures that no field was
# silently filled from a later update while formatting the extracted features.
for f in features:
    path=ROOT/'data/external/ndov_pilot'/f['source_file']
    with lzma.open(path,'rt',encoding='utf-8-sig',newline='') as handle:
        row=next(r for i,r in enumerate(csv.reader(handle),1) if i==int(f['source_line']))
    m,_=parse_message(row,path,int(f['source_line']))
    assert m['dossier']==f['dossier']
    for target,source in [('cause_first','cause'),('impact','impact'),('forecast_from','forecast_from'),('forecast_to','forecast_to'),('feature_available','available')]:
        assert f[target]==m[source],(f['rdt_id'],target)
    assert first[f['dossier']]['payload_sha256']==m['payload_sha256']
    assert stamp(f['prediction_time_first_received'])>=stamp(f['feature_available'])
    assert yes(f['available_at_exact_rdt_start'])==(stamp(f['feature_available'])<=stamp(f['rdt_start']))
    assert yes(f['initial_evidence'])==yes(first[f['dossier']]['is_initial_evidence'])
with (OUT/'independent_checks.csv').open('w',newline='') as handle:
    w=csv.writer(handle);w.writerow(['check','passed'])
    for label in ['Every feature row reproduces its original first XML message','One-to-one provisional links','Coverage denominators reconcile','No backdating of first-receipt prediction time']:w.writerow([label,True])
total=len(links);matched=len(features);initial=sum(yes(f['initial_evidence']) for f in features)
forecast=sum(bool(f['forecast_from']) for f in features)
delays=[float(f['available_delta_seconds']) for f in features]
changed=sum(yes(f['cause_changed']) for f in features)
rows=['# Pilot results — first NS/NDOV messages','',
'Run on 13 November 2026. Feasibility study, not a model result.','',
'| Pilot day | Clean disruptions | Uniquely linked (provisional) | Ambiguous | No candidate | Initial-message evidence | Forecast time present |',
'|---|---:|---:|---:|---:|---:|---:|']
for c in coverage:
    rows.append('| '+' | '.join(c[k] for k in ['day','clean_disruptions','unique_provisional','ambiguous','no_candidate','initial_evidence','forecast_time_available'])+' |')
rows+=['',f'Total: {matched}/{total} provisionally linked one-to-one ({100*matched/total:.1f}%). This is the linkage yield on three chosen days, not a proven match precision or a national coverage estimate.',
f'{initial}/{matched} linked messages have sequence number 1 and an initial phase. A numeric forecast time is present in {forecast}/{matched}; its meaning/code must be kept.',
f'In {changed}/{matched} the first cause differs from the final cause in the existing CSV. Compared after normalising case, whitespace and a leading ‘door’/‘een’; other synonyms are not merged. The cause was not used to choose the link.','',
'## Time and availability','',
f'Median difference between safe message availability and the RDT start: {statistics.median(delays):.3f} seconds; minimum {min(delays):.3f}, maximum {max(delays):.3f}.',
f'{sum(yes(f["available_at_exact_rdt_start"]) for f in features)}/{matched} first messages were available at or before the exact RDT start on this strict clock.',
'A positive delay is not hidden. For follow-up work, predicting at receipt of the first message fits better than claims about the exact physical incident start. This changes the operational prediction moment and must be recorded explicitly.','',
'## Source quality and interpretation','',
f'{sum(i["status"]=="ok" for i in manifest)}/12 downloads succeeded. Total {sum(i.get("bytes",0) for i in manifest):,} compressed bytes. Files are stored locally and verified with SHA-256.',
f'Forecast codes in linked first messages: {dict(Counter(f["forecast_code"] or "missing" for f in features))}.',
'PIL was used for linkage; VTBL was only inventoried. No later updates were added to first messages. The final location is still used for linkage: a remaining retrospective selection limitation.',
'A one-day lookback and sequence/phase help detect incomplete start histories, but do not prove archive completeness. Unique time/location candidates are not manually confirmed ground truth.',
'All three days are in November; results must not be extrapolated to all seasons/years. Cause, end time and model scores are not linkage criteria.','',
'## Conclusion and next step','',
'The pilot shows whether original operational information can be retrieved technically. There is no evidence yet of better predictive quality.',
'First extend the linkage validation to a pre-chosen, season-spread sample, review ambiguous and unlinked cases, and fix the prediction moment. Only then build an enriched research dataset.',
'Use the first NS recovery forecast as a separate baseline where semantically appropriate. Compare models with and without the forecast on the same rows. A lower bound or unknown forecast must not be scored as an exact point estimate.',
'The original clean CSV, models and frozen test files are unchanged. 2025 remains an already-viewed final test; new training requires a new evaluation plan.','',
'## Checks','',
'See checks.csv, independent_checks.csv and test_pilot.py. The re-check rebuilds every exported feature directly from the original XML line. Code and report were prepared with AI assistance.']
(OUT/'PILOT_REPORT.md').write_text('\n'.join(rows)+'\n')
print('\n'.join(rows[:15]));print('Independent raw-message verification passed.')
