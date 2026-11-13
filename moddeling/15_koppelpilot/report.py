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
rows=['# Pilotresultaten — eerste NS/NDOV-meldingen','',
'Uitgevoerd op 13 november 2026. Haalbaarheidsonderzoek, geen modelresultaat.','',
'| Pilotdag | Clean storingen | Uniek voorlopig gekoppeld | Ambigu | Geen kandidaat | Initiële aanwijzingen | Prognosetijd aanwezig |',
'|---|---:|---:|---:|---:|---:|---:|']
for c in coverage:
    rows.append('| '+' | '.join(c[k] for k in ['day','clean_disruptions','unique_provisional','ambiguous','no_candidate','initial_evidence','forecast_time_available'])+' |')
rows+=['',f'Totaal: {matched}/{total} voorlopig eenduidig gekoppeld ({100*matched/total:.1f}%). Dit is de koppelopbrengst van drie gekozen dagen, geen bewezen matchprecisie of landelijke dekkingsschatting.',
f'{initial}/{matched} gekoppelde berichten hebben volgnummer 1 en een initiële fase. Een numerieke prognosetijd is aanwezig bij {forecast}/{matched}; de betekenis/code moet worden behouden.',
f'Bij {changed}/{matched} verschilt de eerste oorzaak van de uiteindelijke oorzaak in de bestaande CSV. Vergelijking na normalisatie van hoofdletters, witruimte en inleidend ‘door’/‘een’; overige synoniemen zijn niet samengevoegd. De oorzaak werd niet gebruikt om de koppeling te kiezen.','',
'## Tijd en beschikbaarheid','',
f'Mediaan verschil tussen veilige berichtbeschikbaarheid en RDT-start: {statistics.median(delays):.3f} seconden; minimum {min(delays):.3f}, maximum {max(delays):.3f}.',
f'{sum(yes(f["available_at_exact_rdt_start"]) for f in features)}/{matched} eerste berichten waren volgens deze strikte klok uiterlijk op de exacte RDT-start beschikbaar.',
'Een positieve vertraging wordt niet verborgen. Voor vervolgonderzoek past voorspellen bij ontvangst van de eerste melding beter dan claims over het exacte fysieke incidentbegin. Dit verandert het operationele voorspelmoment en moet expliciet worden vastgelegd.','',
'## Bronkwaliteit en interpretatie','',
f'{sum(i["status"]=="ok" for i in manifest)}/12 downloads succesvol. Totaal {sum(i.get("bytes",0) for i in manifest):,} gecomprimeerde bytes. De bestanden staan lokaal en zijn via SHA-256 geverifieerd.',
f'Prognosecodes in gekoppelde eerste berichten: {dict(Counter(f["forecast_code"] or "missing" for f in features))}.',
'PIL is gebruikt voor koppeling; VTBL is alleen geïnventariseerd. Geen latere updates toegevoegd aan eerste berichten. Uiteindelijke locatie wordt wel voor koppeling gebruikt: een resterende retrospectieve selectiebeperking.',
'Eén dag lookback en volgnummer/fase helpen onvolledige beginhistorie te herkennen, maar bewijzen geen archiefvolledigheid. Unieke tijd-/locatiekandidaten zijn geen handmatig bevestigde ground truth.',
'Alle drie dagen zijn in november; uitkomsten mogen niet naar alle seizoenen/jaren worden geëxtrapoleerd. Oorzaak, eindtijd en modelscores zijn geen koppelcriteria.','',
'## Conclusie en volgende stap','',
'De pilot toont of oorspronkelijke operationele informatie technisch te ontsluiten is. Er is nog geen bewijs van hogere voorspelkwaliteit.',
'Breid eerst de koppelvalidatie uit naar een vooraf gekozen seizoensgespreide steekproef, controleer dubbelzinnige en niet-gekoppelde gevallen en bepaal het voorspelmoment. Stel daarna pas een verrijkte onderzoeksdataset samen.',
'Gebruik de eerste NS-herstelprognose als afzonderlijke baseline waar semantisch passend. Vergelijk modellen met en zonder prognose, op dezelfde rijen. Een ondergrens of onbekende prognose mag niet als exacte puntschatting worden gescoord.',
'De oorspronkelijke clean CSV, modellen en bevroren testbestanden zijn ongewijzigd. 2025 blijft een reeds bekeken eindtest; nieuwe training vereist een nieuw evaluatieplan.','',
'## Controles','',
'Zie checks.csv, independent_checks.csv en test_pilot.py. De hercontrole reconstrueert elke uitgegeven feature direct uit de oorspronkelijke XML-regel. Code en rapport zijn met AI-assistentie opgesteld.']
(OUT/'PILOT_REPORT.md').write_text('\n'.join(rows)+'\n')
print('\n'.join(rows[:15]));print('Independent raw-message verification passed.')
