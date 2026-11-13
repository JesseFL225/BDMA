# Stap 15 — Koppelpilot historische eerste storingsmeldingen

Eigenaar: Oliver. Ontwikkelpilot, geen nieuwe modeltraining of nieuwe eindtest.
Zie `output/PILOT_REPORT.md` voor de gemeten resultaten na uitvoering.

## Status en uitkomst (13 november 2026, afgerond)

Alle 12 downloads zijn gelukt en met SHA-256 gecontroleerd. De 7 unittests,
de pipeline en de onafhankelijke hercontrole (`report.py`) zijn geslaagd.
Let op: een eerdere tussentijdse run draaide vóórdat de 2020- en 2023-bestanden
binnen waren en gaf daardoor 0 koppelingen voor die jaren. Die uitkomst is
vervangen; de huidige outputs zijn gebaseerd op alle twaalf bestanden.

| Pilotdag | Clean storingen | Uniek voorlopig gekoppeld | Ambigu | Geen kandidaat | Prognosetijd aanwezig |
|---|---:|---:|---:|---:|---:|
| 2017-11-10 | 7 | 7 | 0 | 0 | 2 |
| 2020-11-10 | 18 | 17 | 0 | 1 | 4 |
| 2023-11-10 | 17 | 16 | 1 | 0 | 16 |
| **Totaal** | **42** | **40 (95,2%)** | **1** | **1** | **22** |

Wat dit wel en niet zegt:

- **Technisch haalbaar.** Voor deze drie dagen is bij bijna iedere storing een
  eerste NS-melding met oorzaak en impact terug te vinden. 38/40 hebben volgnummer 1
  én een initiële fase. Dit is een koppelopbrengst, geen bewezen precisie: er is
  nog geen handmatige controle gedaan.
- **RDT-start ≈ eerste publieke melding.** Het verschil tussen de veilige
  beschikbaarheid van het eerste bericht en `start_time` is mediaan 1 seconde
  (min 0, max 35 s). De `start_time` in onze dataset is dus vrijwel zeker het
  moment van de eerste NS-publicatie, niet het fysieke incidentbegin. Dat moet in
  het verslag zo worden benoemd: ons huidige voorspelmoment is "bij de eerste
  publieke melding". Slechts 9/40 berichten waren strikt op of vóór die seconde
  beschikbaar; een voorspelmoment "bij ontvangst eerste melding" lost dit op.
- **Oorzaak verandert soms.** Bij 5/40 verschilt de eerste oorzaak van de
  uiteindelijke. Eén geval is puur formulering ("storing in tunnel" → "storing in
  een tunnel", ons normalisatieregeltje haalt alleen een *inleidend* "een" weg) en
  één is een synoniem ("object" → "rommel op het spoor"). Inhoudelijk veranderd:
  "eerdere verstoring" → "seinstoring", "onbekende oorzaak" → "defecte trein",
  "object op het spoor" → "aanrijding". Dit bevestigt de lekzorg rond archived cause,
  maar is te klein om een percentage voor de hele dataset te claimen.
- **Prognose groeit door de jaren.** Een prognosetijd staat in 2/7 (2017), 4/17
  (2020) en 16/16 (2023) eerste berichten. Dekking hangt dus sterk af van het jaar;
  een prognose-feature werkt mogelijk alleen voor recente jaren. De betekenis van de
  prognosecodes (1, 2, 4, 6) is nog niet tegen de documentatie gecontroleerd.
- **De twee missers zijn bewust geweigerd.** 35090 (2020) heeft een kandidaat op
  0 s, maar slechts één gedeeld station (AMF) terwijl de regel er twee vereist.
  50491 (2023) heeft twee geldige NS-dossiers (6026882 en 6026884, rond de tunnel
  Rotterdam/Den Haag). In beide gevallen lijkt handmatig een match aannemelijk,
  maar de regels zijn vooraf vastgelegd en worden **niet achteraf** op deze data
  aangepast. Een eventuele tie-breaker (bijv. exact gelijke stationset of kleinste
  tijdsverschil) moet vóór een volgende ronde worden vastgelegd.

Advies: geen nieuw model op basis van deze pilot. Als de groep de verrijking wil
doorzetten, eerst een grotere, vooraf gekozen seizoensgespreide koppelsteekproef
met handmatige review. Voor het huidige verslag is de pilot vooral nuttig als
onderbouwing van de beperking "archived cause/traject kunnen achteraf wijzigen" en
als concrete aanbeveling voor vervolgonderzoek.

## Vraag en vooraf gekozen steekproef

Kunnen we de eerste publiek vastgelegde NS/NDOV-melding bij een storing vinden,
met oorspronkelijke oorzaak, impact en eventueel herstelprognose?

We onderzoeken 10 november in 2017, 2020 en 2023, plus de voorgaande UTC-dag als
lookback per jaar. De al onderzochte voorbeeldbron is 10 november 2023; dezelfde
kalenderdatum in twee eerdere jaren onderzoekt schema-/koppelstabiliteit. Dit is
geen willekeurige of seizoensrepresentatieve steekproef. De pilot bevat alle
storingen uit de bestaande clean selectie die op die lokale kalenderdagen starten.
2024 en 2025 zijn geen onderdeel van deze koppelpilot. De vorige 2025-eindtest
blijft afgerond; een verrijkt model heeft een nieuw evaluatieplan nodig.

Twaalf kleine CSV.xz-bestanden: twee typen (PIL, VTBL), drie datums met ieder een
voorgaande dag. Bron: het samengestelde archief van Adriaan van Natijne en Simon
Pellegrom, https://trein.fwrite.org/ . De collectie gebruikt CC BY 4.0; zie de
bron voor de voorwaarden van de onderliggende berichttypen. Publicatie-index en
beschrijving staan in stap 14. Geen leverancier benaderd of websiteblokkade omzeild.

## Download en audit

`download.py` downloadt opeenvolgend, met een pauze en een limiet van 5 MB per
bestand. Bestaande downloads worden hergebruikt. Bestanden worden lokaal bewaard
onder `data/external/ndov_pilot/` (Git-ignored); de manifesten bewaren bron-URL,
bestandsgrootte en SHA-256. Een fout wordt geregistreerd, niet vervangen door
gefabriceerde data. De bron-CSV en bestaande modellen blijven ongewijzigd.

## Berichtverwerking

`pilot.py` verwerkt XML met een parser, niet met tekstpatronen. PIL bevat
`LandelijkePatroonInformatie`; we analyseren ongeplande storingen (`EV`). VTBL is
vrije service-informatie met een ander schema; we inventariseren de aanwezige
schema's maar koppelen die niet automatisch als dezelfde storing. De pilot
claimt dus geen volledige verwerking van alle NS-serviceberichten.

De vierde archiefkolom blijkt in de bekeken bestanden een bronverwijzing te
kunnen bevatten. We vertrouwen die niet blind als inhoudshash, maar berekenen
zelf SHA-256 over de XML.

Duplicaten met dezelfde XML-payload worden samengenomen, met de vroegste
waargenomen beschikbaarheid. Per NS-dossier gebruiken we uitsluitend het vroegste
beschikbare bericht in het opgehaalde venster. We vullen geen ontbrekende oorzaak
of prognose aan uit een latere update. Volgnummer 1, een initiële fase (1/1A/1B)
en geen verwijderbericht geven extra aanwijzing dat de startmelding aanwezig is.
Dat is een controle, geen garantie dat het archief alles heeft ontvangen.

Vier tijden blijven gescheiden:

- `incident_begin`: in het NS-bericht geregistreerd incidentbegin.
- `rdt_start`: start in onze bestaande dataset, vaak dicht bij de melding.
- `published`/`released`: product-/vrijgavetijd in het bronbericht.
- `received`: ontvangsttijd bij de archiefverzamelaar.

Voor veilige beschikbaarheid gebruiken we het maximum van producttijd,
vrijgavetijd en archiefontvangst. De parser vereist tijdzones en rekent in UTC.
Een kleine positieve vertraging wordt gerapporteerd, niet op nul gezet.

## Vooraf vastgelegde koppelregels

De bron heeft NS-dossiernummers; die zijn NIET hetzelfde als `rdt_id`.
Een kandidaat moet voldoen aan alle volgende regels:

1. Eerste producttijd maximaal 120 seconden vóór of na `rdt_start`.
2. Overlap in stationcodes uit de getroffen baanvak-/trajectsecties. Geen stations
   uit omreisadviezen meenemen. Hoofdletters en spaties worden genormaliseerd.
3. Minstens twee gemeenschappelijke stations, behalve als één van de sets slechts
   één station bevat. Overlap gedeeld door de kleinste setgrootte minstens 0,5.
4. Precies één kandidaat voor de RDT-storing én precies één RDT-storing voor het
   NS-dossier. Geen arbitraire keuze wanneer er meerdere kandidaten zijn.

Kandidaten binnen tien minuten worden daarnaast voor inspectie opgeslagen, ook
als ze niet voldoen. De grenzen zijn niet op duur, afloop of modelscores gekozen.
Bij de oorzaakvergelijking normaliseren we hoofdletters, witruimte en alleen de
inleidende woorden ‘door’ en ‘een’; tekstverschil en genormaliseerd verschil
blijven afzonderlijke auditvelden. Andere synoniemen worden niet samengevoegd.
Uiteindelijke oorzaak wordt alleen achteraf naast de eerste oorzaak gezet en
is geen koppelcriterium. Duur/eindtijd zijn geen koppelcriteria.

Unieke kandidaten heten **voorlopige koppelingen**, niet bewezen ground truth.
We koppelen mede met retrospectieve stationslijsten. Een latere locatieaanpassing
kan daardoor selectie of foute koppelingen veroorzaken. Een kleine audit kan geen
algemene precisieclaim rechtvaardigen. Kijk naar tijd en locatie in `candidate_audit.csv`.

## Kenmerken en moment van voorspellen

`first_message_features_REVIEW_ONLY.csv` bevat de eerste oorzaak, impactcode,
gevolgen, locatie en prognose inclusief betekenis/code en tijdstippen. Het is een
auditbestand, geen direct trainingsbestand. De kolom `cause_final_for_audit_only`
is uitdrukkelijk geen feature. Bronbestand en regelnummer maken controles mogelijk.

Beschikbaar op de exacte RDT-start wordt apart geteld. Een alternatief voorspelmoment
is ontvangst van de eerste publieke melding: max(RDT-start, beschikbaarheid).
Dat is een expliciete verandering van het operationele moment. Gebruik nooit de
koppeltolerantie van 120 seconden als impliciete toestemming voor toekomstige data.

Een prognosetijd is niet altijd een exacte puntschatting: de code/tekst kan een
ondergrens, een interval of onbekend uitdrukken. We bewaren dit onderscheid en
berekenen hier geen misleidende MAE over alle prognoses. Bovendien betreft de
bronprognose normaal herstel van de treindienst; dat moet nog worden afgestemd
op onze eindtijddefinitie. Een later model moet de eerste bruikbare NS-prognose
als eigen baseline vergelijken en met/zonder die invoer rapporteren.

## Reproductie

Vanuit de repositoryroot, alleen de eerste opdracht heeft netwerk nodig:

```sh
python3 -u moddeling/15_koppelpilot/download.py
python3 moddeling/15_koppelpilot/test_pilot.py
python3 moddeling/15_koppelpilot/pilot.py
python3 moddeling/15_koppelpilot/report.py
```

De synthetische tests controleren tijdzone-/tijdsgrenzen, onvoldoende overlap bij
een gedeeld knooppunt, meervoudige kandidaten en uitsluiting van adviesstations.
De pipeline controleert manifesthashes en alle eerder bevroren test-inputs/models.

## Outputs en overdracht

- `download_manifest.json`: alle aangevraagde bestanden, successen en fouten.
- `message_inventory.csv`: aantallen berichten en ontvangen tijdsbereik per bestand.
- `parse_errors.csv`, `non_pil_schemas.csv`: parserfouten en alternatieve schema's.
- `first_observed_dossiers.csv`: eerste waargenomen EV-bericht per brondossier.
- `candidate_audit.csv`: tijd-/locatiebewijs en alle nabije kandidaten.
- `linkage_results.csv`: alle geselecteerde clean storingen, inclusief niet-gekoppelde.
- `first_message_features_REVIEW_ONLY.csv`: voorlopige eerste-berichtkenmerken.
- `coverage_summary.csv`, `checks.csv`, `PILOT_REPORT.md`: conclusie en controles.

Bij goede uitkomst volgt eerst een grotere, seizoensgespreide koppelvalidatie met
handmatige review en expliciete featurebeschikbaarheid. Pas daarna een nieuw
modelonderzoek. Niet stilzwijgend koppelen aan of overschrijven van de clean CSV.
Geen commits, pushes of trainingsruns in deze pilot. Code met AI-assistentie.

## Technische bron

https://data.ndovloket.nl/docs/infoplus/VI/ndov-ri-cdm-common-vi-v1.0.3.xsd
beschrijft onder meer de gevolgen voor de treindienst en prognosevelden. Oudere
schemadocumentatie is ondersteunend; aangetroffen versies/waarden zijn leidend
voor de audit en moeten vóór verdere generalisatie per periode worden gecontroleerd.
