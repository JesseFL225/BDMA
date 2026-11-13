# Step 15 — Linkage pilot of historical first disruption messages

Owner: Oliver. Development pilot, no new model training and no new final test.
See `output/PILOT_REPORT.md` for the measured results.

## Status and outcome (13 November 2026, completed)

All 12 downloads succeeded and were checked with SHA-256. The 7 unit tests, the
pipeline and the independent re-check (`report.py`) passed. Note: an earlier interim
run ran before the 2020 and 2023 files had arrived and therefore showed 0 links for
those years. That result was replaced; the current outputs are based on all twelve files.

| Pilot day | Clean disruptions | Uniquely linked (provisional) | Ambiguous | No candidate | Forecast time present |
|---|---:|---:|---:|---:|---:|
| 2017-11-10 | 7 | 7 | 0 | 0 | 2 |
| 2020-11-10 | 18 | 17 | 0 | 1 | 4 |
| 2023-11-10 | 17 | 16 | 1 | 0 | 16 |
| **Total** | **42** | **40 (95.2%)** | **1** | **1** | **22** |

What this does and does not show:

- **Technically feasible.** For these three days a first NS message with cause and
  impact can be found for almost every disruption. 38/40 have sequence number 1 and
  an initial phase. This is a linkage yield, not proven precision: no manual review
  has been done yet.
- **RDT start ≈ first public message.** The difference between the safe availability of
  the first message and `start_time` is a median of 1 second (min 0, max 35 s). The
  `start_time` in our dataset is therefore almost certainly the moment of the first NS
  publication, not the physical start of the incident. The report should say so: our
  current prediction moment is "at the first public message". Only 9/40 messages were
  strictly available at or before that second; a prediction moment "at receipt of the
  first message" solves this.
- **Cause sometimes changes.** In 5/40 the first cause differs from the final one. One
  case is pure wording ("storing in tunnel" → "storing in een tunnel"; our normalisation
  only removes a *leading* "een") and one is a synonym ("object" → "rommel op het spoor",
  i.e. "debris on the track"). Changed in substance: "eerdere verstoring" (earlier
  disruption) → "seinstoring" (signal failure), "onbekende oorzaak" (unknown cause) →
  "defecte trein" (defective train), "object op het spoor" (object on the track) →
  "aanrijding" (collision). This confirms the leakage concern around archived cause,
  but is too small to claim a percentage for the whole dataset.
- **Forecasts become more common over the years.** A forecast time is present in 2/7
  (2017), 4/17 (2020) and 16/16 (2023) first messages. Coverage depends strongly on the
  year; a forecast feature may only work for recent years. The meaning of the forecast
  codes (1, 2, 4, 6) has not yet been checked against the documentation.
- **The two misses were rejected on purpose.** 35090 (2020) has a candidate at 0 s, but
  only one shared station (AMF) while the rule requires two. 50491 (2023) has two valid
  NS dossiers (6026882 and 6026884, around the Rotterdam/The Hague tunnel). In both
  cases a manual match looks plausible, but the rules were fixed in advance and are
  **not** adjusted afterwards on these data. Any tie-breaker (e.g. identical station set
  or smallest time difference) must be fixed before a next round.

Advice: no new model based on this pilot. If the group wants to pursue enrichment,
first run a larger, pre-chosen, season-spread linkage sample with manual review. For the
current report the pilot is mainly useful as support for the limitation "archived
cause/route can change afterwards" and as a concrete recommendation for follow-up research.

## Question and pre-chosen sample

Can we find the first publicly recorded NS/NDOV message for a disruption, with the
original cause, impact and any recovery forecast?

We study 10 November in 2017, 2020 and 2023, plus the preceding UTC day as lookback per
year. The source already examined was 10 November 2023; the same calendar date in two
earlier years tests schema/linkage stability. This is not a random or seasonally
representative sample. The pilot includes all disruptions from the existing clean
selection that start on those local calendar days. 2024 and 2025 are not part of this
pilot. The earlier 2025 final test remains completed; an enriched model needs a new
evaluation plan.

Twelve small CSV.xz files: two types (PIL, VTBL), three dates each with a preceding day.
Source: the compiled archive by Adriaan van Natijne and Simon Pellegrom,
https://trein.fwrite.org/ . The collection uses CC BY 4.0; see the source for the terms
of the underlying message types. Publication index and description are in step 14. No
supplier contacted and no website block circumvented.

## Download and audit

`download.py` downloads sequentially, with a pause and a 5 MB limit per file. Existing
downloads are reused. Files are stored locally under `data/external/ndov_pilot/`
(Git-ignored); the manifest keeps source URL, file size and SHA-256. A failure is
recorded, not replaced by fabricated data. The source CSV and existing models remain
unchanged.

## Message processing

`pilot.py` processes XML with a parser, not with text patterns. PIL contains
`LandelijkePatroonInformatie` (national pattern information); we analyse unplanned
disruptions (`EV`). VTBL is free service information with a different schema; we
inventory the schemas present but do not link them automatically as the same
disruption. The pilot therefore does not claim to process all NS service messages.

The fourth archive column turned out to possibly contain a source reference in the
inspected files. We do not blindly trust it as a content hash, but compute our own
SHA-256 over the XML.

Duplicates with the same XML payload are merged, keeping the earliest observed
availability. Per NS dossier we use only the earliest available message in the
retrieved window. We do not fill a missing cause or forecast from a later update.
Sequence number 1, an initial phase (1/1A/1B) and no deletion message are extra
evidence that the start message is present. That is a check, not a guarantee that the
archive received everything.

Four times are kept separate:

- `incident_begin`: incident start recorded in the NS message.
- `rdt_start`: start in our existing dataset, often close to the message.
- `published`/`released`: product/release time in the source message.
- `received`: receive time at the archive collector.

For safe availability we use the maximum of product time, release time and archive
receipt. The parser requires time zones and computes in UTC. A small positive delay is
reported, not set to zero.

## Linkage rules fixed in advance

The source has NS dossier numbers; these are NOT the same as `rdt_id`. A candidate
must satisfy all of the following rules:

1. First product time at most 120 seconds before or after `rdt_start`.
2. Overlap in station codes from the affected route sections. Stations from detour
   advice are not included. Case and spaces are normalised.
3. At least two shared stations, unless one of the sets contains only one station.
   Overlap divided by the smaller set size at least 0.5.
4. Exactly one candidate for the RDT disruption and exactly one RDT disruption for the
   NS dossier. No arbitrary choice when there are several candidates.

Candidates within ten minutes are also stored for inspection, even if they do not
qualify. The limits were not chosen on duration, outcome or model scores. For the cause
comparison we normalise case, whitespace and only the leading words "door" and "een";
text difference and normalised difference remain separate audit fields. Other synonyms
are not merged. The final cause is only placed next to the first cause afterwards and is
not a linkage criterion. Duration/end time are not linkage criteria.

Unique candidates are called **provisional links**, not proven ground truth. Linkage
partly uses retrospective station lists. A later location change can therefore cause
selection or wrong links. A small audit cannot justify a general precision claim. Look
at time and location in `candidate_audit.csv`.

## Features and prediction moment

`first_message_features_REVIEW_ONLY.csv` contains the first cause, impact code, effects,
location and forecast including meaning/code and timestamps. It is an audit file, not a
direct training file. The column `cause_final_for_audit_only` is explicitly not a
feature. Source file and line number make checks possible.

Availability at the exact RDT start is counted separately. An alternative prediction
moment is receipt of the first public message: max(RDT start, availability). That is an
explicit change of the operational moment. Never use the 120-second linkage tolerance as
implicit permission for future data.

A forecast time is not always an exact point estimate: the code/text can express a lower
bound, an interval or unknown. We keep this distinction and do not compute a misleading
MAE over all forecasts. Moreover, the source forecast concerns normal recovery of the
train service; that still needs to be aligned with our end-time definition. A later model
must compare the first usable NS forecast as its own baseline and report with/without
that input.

## Reproduction

From the repository root; only the first command needs network access:

```sh
python3 -u moddeling/15_koppelpilot/download.py
python3 moddeling/15_koppelpilot/test_pilot.py
python3 moddeling/15_koppelpilot/pilot.py
python3 moddeling/15_koppelpilot/report.py
```

The synthetic tests check time-zone/time limits, insufficient overlap at a shared hub,
multiple candidates and exclusion of advice stations. The pipeline checks manifest
hashes and all previously frozen test inputs/models.

## Outputs

- `download_manifest.json`: all requested files, successes and failures.
- `message_inventory.csv`: message counts and received time range per file.
- `parse_errors.csv`, `non_pil_schemas.csv`: parser errors and alternative schemas.
- `first_observed_dossiers.csv`: first observed EV message per source dossier.
- `candidate_audit.csv`: time/location evidence and all nearby candidates.
- `linkage_results.csv`: all selected clean disruptions, including unlinked ones.
- `first_message_features_REVIEW_ONLY.csv`: provisional first-message features.
- `coverage_summary.csv`, `checks.csv`, `independent_checks.csv`, `PILOT_REPORT.md`: conclusion and checks.

With a good outcome, a larger, season-spread linkage validation with manual review and
explicit feature availability comes first. Only then a new modelling study. Do not
silently link to or overwrite the clean CSV. Code prepared with AI assistance.

## Technical source

https://data.ndovloket.nl/docs/infoplus/VI/ndov-ri-cdm-common-vi-v1.0.3.xsd describes,
among others, the effects on train service and the forecast fields. Older schema
documentation is supporting; the versions/values actually found are leading for the
audit and must be checked per period before further generalisation.
