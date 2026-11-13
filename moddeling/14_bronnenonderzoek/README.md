# Step 14 — Public sources for additional predictors

Researched on 13 November 2026. Owner: Oliver. Status: source research only, no data
linkage or new model training. The existing final test is kept; 2025 has already been
seen and cannot serve as a new independent test for an enriched model.

## Conclusion and priority

There are public sources for historical disruption messages and weather. The most
interesting lead in substance is the **first disruption message with impact and
expected recovery time**. The most directly documented additional measurement file is
KNMI hourly weather. Availability is not proof of predictive gain.

| Source | Availability found | Linkage | Main uncertainty |
|---|---|---|---|
| Rijden de Treinen disruption pages | Time-stamped messages, impact and sometimes a recovery estimate; examples from 2015 and 2023 | The ID in the URL is the same `rdt_id` | No verified bulk download of updates; completeness per year unknown; direct requests returned 403 |
| Fwrite compiled NDOV archive | Download index for InfoPlusPIL, InfoPlusVTBL and other message types | Source message ID, time, stations/route; a bridge to the RDT ID is needed | Index and three messages from one day file checked; linkage/coverage not yet |
| KNMI hourly data | Historical measurement files per station, including periods 2011–2020 and 2021–2030 | Disruption time + location to weather station | Later quality corrections/publication delay; not every station has every variable |
| Rijden de Treinen stations | Station code, coordinates, type and dated snapshots | `rdt_station_codes` → `code` | Historical changes, missing codes and a disruption location updated afterwards |
| Rijden de Treinen train archive | CSV.gz with stops, delays and cancellations since 2019 | Station and time window; journey ID is NOT a disruption ID | End state per journey is not a reconstruction of the impact known at onset |
| NS API / NDOV live | Disruption/engineering-work information and current messages | Operational source IDs | Live availability does not prove a complete historical archive |
| ProRail engineering-work list | Public list of large planned possessions | Route + planned period | No complete historically versioned CSV for all years confirmed |

## 1. Original messages and impact

The dataset documentation states explicitly that `cause_nl` in the yearly CSV is the
last cause used. The individual web page can contain earlier messages. For example,
ID 12345 shows a message on 28 October 2015 at 13:30 with impact (fewer trains) and a
forecast, followed by later updates. The site warns that less information is available
for this old archive.

A search result for ID 50489 (10 November 2023) shows a first message at 18:38 with
logistical restrictions, no trains and a forecast until 19:45. The page title instead
names an earlier disruption. This illustrates why the first message content can be
more useful than the final cause; it does not yet prove that all records are complete.
ID 49166 likewise contains time-stamped messages and changing impact in 2023.

Sources:
- https://www.rijdendetreinen.nl/open-data/treinstoringen
- https://www.rijdendetreinen.nl/storingen/12345
- https://www.rijdendetreinen.nl/storingen/50489-10-november-2023-eerdere-verstoring-rotterdam-centraal
- https://www.rijdendetreinen.nl/storingen/49166-23-augustus-2023-stroomstoring-den-haag-rotterdam-leiden-rotterdam

Access was checked via web search results and one opened old archive page. Some other
pages could not be opened by the web tool. Two direct HTTP requests to IDs 46000 and
51320 returned 403. No block was circumvented and no mass scrape was started. The
open-data CSV licence does not automatically confirm a bulk export right/licence for
all web page messages.

## 2. Raw historical messages as a download

https://trein.fwrite.org/ is a public, unofficial archive with a compiled, deduplicated
archive by Adriaan van Natijne and Simon Pellegrom. The documentation describes four
columns: time, station, message and hash, split per type and sorted chronologically.
The collection is CC BY 4.0; the source messages have their own terms. The archive does
not guarantee complete or correct content.

The main page has year indexes 2011–2026 and, among others, these relevant types:
- https://trein.fwrite.org/idx/dedup_InfoPlusPIL.html — structured national disruption messages.
- https://trein.fwrite.org/idx/dedup_InfoPlusVTBL.html — national free text.

The PIL index could be opened directly. The download links checked run from August
2016 to early October 2024, including day files for 2023. The main page also lists
other types/years: that is no proof of PIL files for all of 2025 or 2026. A 2026 date
in the HTML may be metadata and must not be counted as file coverage.

Concrete day file: https://trein.fwrite.org/dedup/2023-11/InfoPlusPIL_2023-11-10.csv.xz .

The day file for 10 November 2023 was actually retrieved (34,120 bytes compressed). The
first three rows were parsed: four CSV columns, a UTC receive time and an XML message.
Fields found include `DossierNummer`, `DossierVolgNummer`, `RegistratieTijd`,
`VrijgaveTijd`, `OorzaakKort`, `GevolgenTreindienst`, `VerstoringImpact`, `StationCode`,
`VerstoringFase` and `Prognose`. This confirms a concrete usable structure, not yet that
every field is always filled or that the first three messages are initial messages.
The sample was inspected in memory; no bulk files or new dataset were saved.

That is no proof that every file or date is complete. Year indexes for all message
types together do not prove PIL coverage from 2011. This must be checked per type/date
before a training period is chosen.

The PPV schema describes planned and unplanned disruptions. The same source is
therefore also a candidate for historically known engineering work, but that coverage
has not been validated. The source ID need not match `rdt_id`.

Documentation:
- https://data.ndovloket.nl/docs/infoplus/VI/
- https://data.ndovloket.nl/docs/infoplus/VI/Publicatiedocument%20PPV%20Verstoringsinformatie%20NDOV_Push_v3.1%20def2.pdf
- https://data.ndovloket.nl/REALTIME.TXT — current feeds, no proof of historical coverage.
- https://groups.google.com/g/openov/c/x65ZfDpzGs4/m/rfFyj3G3AgAJ — original explanation of the archive.

## 3. KNMI weather and geographic linkage

Historical hourly values are publicly available as compact ZIP/ASCII files. The
interactive selection describes, among others, temperature, wind speed, gusts,
precipitation, visibility and indicators for fog, snow and thunder.

- https://www.knmi.nl/nederland-nu/klimatologie/uurgegevens
- https://daggegevens.knmi.nl/klimatologie/uurgegevens
- https://www.rijdendetreinen.nl/open-data/stations

Proposed linkage: station code to geographic location, then to a nearby weather
station; use only elapsed measurement windows. For a disruption at 10:35, the
precipitation total for 10:00–11:00 must not be used as known input. Daily totals
usually contain future information as well.

KNMI states that these archive data are checked afterwards and sometimes corrected or
supplemented. Release usually follows after one or a few days, sometimes up to two
weeks later. One hour before the disruption therefore does not automatically mean that
exactly this validated value was already published at that time. Without original
publication times this is a retrospective weather-context study, not a proven real-time
reconstruction. Work with an explicit availability assumption or an archive of
operational measurements. An arbitrary extra hour of delay does not solve later corrections.

## 4. Additional sources with limitations

Train journeys since 2019: https://www.rijdendetreinen.nl/open-data/treinarchief .
This allows studying train running before a disruption, but total cancellations or
maximum journey delay from after the disruption start must not be used as an onset
feature. The documented CSV is not a full message log with a publication time per update.

NS open API: https://apiportal.ns.nl/ . Access via registration and a subscription to the
relevant product. Public information covers timetables, engineering work and stations.
I could not confirm a complete historical export of all original messages on this portal.

ProRail: https://www.prorail.nl/verhalen/investeringen-spoor-nu-nodig/lijst-met-werkzaamheden .
This list describes large possessions longer than three days and notes that plans may
change. Do not treat it as a complete history of all engineering work and of what was
known about it at every earlier moment.

## 5. Recommended next step: feasibility pilot, no new model yet

1. Check a small selection of PIL/VTBL day files spread over the desired development
   years, with limited downloads and local caching.
2. Reconstruct the earliest available message per incident: receive/publication time,
   original cause, impact, affected locations and any recovery forecast.
3. Link conservatively to existing disruptions; measure coverage, ambiguous matches,
   missing initial messages and time differences. No match does not mean "no impact".
4. Define the prediction moment: actual start versus first public message. Information
   published later must not be backdated to the start.
5. Treat the first NS recovery forecast as its own baseline. Compare features without
   and with the forecast separately; otherwise the model may only look smart because it
   reuses an existing human forecast.
6. Only build an enriched research dataset if coverage is sufficient. Do not overwrite
   the existing clean CSV or the frozen test. Use the same rows in ablations.
7. KNMI is the practical alternative or a second, separate extension. A new independent
   final evaluation requires a period not yet used; 2026 availability and completeness
   must be established first.

This pilot was carried out in [step 15](../15_koppelpilot/README.md).

## Status and impact

Sources were found, but no new features or model gains were measured. No bulk data
downloaded, no accounts created, no suppliers contacted. Source research was carried
out with AI assistance.
