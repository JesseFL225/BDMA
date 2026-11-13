# Pilotresultaten — eerste NS/NDOV-meldingen

Uitgevoerd op 13 november 2026. Haalbaarheidsonderzoek, geen modelresultaat.

| Pilotdag | Clean storingen | Uniek voorlopig gekoppeld | Ambigu | Geen kandidaat | Initiële aanwijzingen | Prognosetijd aanwezig |
|---|---:|---:|---:|---:|---:|---:|
| 2017-11-10 | 7 | 7 | 0 | 0 | 7 | 2 |
| 2020-11-10 | 18 | 17 | 0 | 1 | 15 | 4 |
| 2023-11-10 | 17 | 16 | 1 | 0 | 16 | 16 |

Totaal: 40/42 voorlopig eenduidig gekoppeld (95.2%). Dit is de koppelopbrengst van drie gekozen dagen, geen bewezen matchprecisie of landelijke dekkingsschatting.
38/40 gekoppelde berichten hebben volgnummer 1 en een initiële fase. Een numerieke prognosetijd is aanwezig bij 22/40; de betekenis/code moet worden behouden.
Bij 5/40 verschilt de eerste oorzaak van de uiteindelijke oorzaak in de bestaande CSV. Vergelijking na normalisatie van hoofdletters, witruimte en inleidend ‘door’/‘een’; overige synoniemen zijn niet samengevoegd. De oorzaak werd niet gebruikt om de koppeling te kiezen.

## Tijd en beschikbaarheid

Mediaan verschil tussen veilige berichtbeschikbaarheid en RDT-start: 1.000 seconden; minimum 0.000, maximum 34.544.
9/40 eerste berichten waren volgens deze strikte klok uiterlijk op de exacte RDT-start beschikbaar.
Een positieve vertraging wordt niet verborgen. Voor vervolgonderzoek past voorspellen bij ontvangst van de eerste melding beter dan claims over het exacte fysieke incidentbegin. Dit verandert het operationele voorspelmoment en moet expliciet worden vastgelegd.

## Bronkwaliteit en interpretatie

12/12 downloads succesvol. Totaal 172,148 gecomprimeerde bytes. De bestanden staan lokaal en zijn via SHA-256 geverifieerd.
Prognosecodes in gekoppelde eerste berichten: {'2': 2, '6': 2, '1': 16, '4': 20}.
PIL is gebruikt voor koppeling; VTBL is alleen geïnventariseerd. Geen latere updates toegevoegd aan eerste berichten. Uiteindelijke locatie wordt wel voor koppeling gebruikt: een resterende retrospectieve selectiebeperking.
Eén dag lookback en volgnummer/fase helpen onvolledige beginhistorie te herkennen, maar bewijzen geen archiefvolledigheid. Unieke tijd-/locatiekandidaten zijn geen handmatig bevestigde ground truth.
Alle drie dagen zijn in november; uitkomsten mogen niet naar alle seizoenen/jaren worden geëxtrapoleerd. Oorzaak, eindtijd en modelscores zijn geen koppelcriteria.

## Conclusie en volgende stap

De pilot toont of oorspronkelijke operationele informatie technisch te ontsluiten is. Er is nog geen bewijs van hogere voorspelkwaliteit.
Breid eerst de koppelvalidatie uit naar een vooraf gekozen seizoensgespreide steekproef, controleer dubbelzinnige en niet-gekoppelde gevallen en bepaal het voorspelmoment. Stel daarna pas een verrijkte onderzoeksdataset samen.
Gebruik de eerste NS-herstelprognose als afzonderlijke baseline waar semantisch passend. Vergelijk modellen met en zonder prognose, op dezelfde rijen. Een ondergrens of onbekende prognose mag niet als exacte puntschatting worden gescoord.
De oorspronkelijke clean CSV, modellen en bevroren testbestanden zijn ongewijzigd. 2025 blijft een reeds bekeken eindtest; nieuwe training vereist een nieuw evaluatieplan.

## Controles

Zie checks.csv, independent_checks.csv en test_pilot.py. De hercontrole reconstrueert elke uitgegeven feature direct uit de oorspronkelijke XML-regel. Code en rapport zijn met AI-assistentie opgesteld.
