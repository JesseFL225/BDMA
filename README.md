# Predicting the duration of train disruptions (BDMA, Part B)

At the start of a train disruption we predict a probability distribution over 102
ten-minute intervals (the last one: ≥ 1010 minutes). Data: Rijden de Treinen,
2011–2025, 44,248 selected domestic disruptions.

**Status (13 November 2026):** modelling completed and final test on 2025 done.
The report, presentation and code submission still need to be finished.

## Start here

| If you want to… | Read |
|---|---|
| Understand what we did, which decisions we took and why | [docs/PROCESS.md](docs/PROCESS.md) |
| Get exact numbers, limitations and how to finish the report/slides | [docs/HANDOVER.md](docs/HANDOVER.md) |
| Read the draft B5 report text | [moddeling/09_modelkeuze_en_test/output/B5_FINAL_REPORT_TEXT.md](moddeling/09_modelkeuze_en_test/output/B5_FINAL_REPORT_TEXT.md) |
| Reproduce a step or understand the code | [moddeling/README.md](moddeling/README.md) |
| Work on this project with an AI assistant (ChatGPT, Claude, Copilot…) | [AGENTS.md](AGENTS.md): rules, pitfalls, a map of every file, and which files to upload |

## Result in short (final test 2025, lower log loss is better)

| Information at prediction time | Chosen model | Log loss | Baseline | Exact class |
|---|---|---:|---:|---:|
| Time features only | Survival boosting (trained 2017–2023) | 3.1620 | 3.2065 | 10.93% |
| Archived context (cause, route) | Random forest (trained 2011–2023) | 3.0189 | 3.0273 | 12.02% |

Both models beat their baseline, but the gain is modest and a precise end time remains
unpredictable. See the handover for uncertainty and limitations.

## Folders

```
data/                       raw and clean dataset (only Data Cleaning writes here)
Data Cleaning/              raw → clean data, with a report per filter
descriptive data analysis/  exploration of the raw data
moddeling/                  all modelling steps 01–15, each with README, code and output/
docs/                       process story and handover
```

Some folder names are Dutch (e.g. `moddeling` = modelling, `foutanalyse` = error
analysis). They were kept because scripts refer to them; see the glossary in AGENTS.md.

## Quick start

From this folder, with R 4.4 or newer:

```sh
Rscript "Data Cleaning/clean_disruptions.R"                     # rebuild the clean data
Rscript moddeling/02_voorbereiding/validate_preparation.R        # check the shared basis
python3 moddeling/09_modelkeuze_en_test/verify_saved_test.py     # verify the final test
```

The full order and required packages are in [moddeling/README.md](moddeling/README.md).
Do not re-run the final test (`final_test.R`): 2025 has been used once and stays that way.

## Team and source

Jesse (data supply), Mart (exploration, target, shared preparation and evaluation,
baselines, logistic regression), Oliver (cleaning, tree models, error analysis,
experiments, survival, final test, source research).
Data: [Rijden de Treinen](https://www.rijdendetreinen.nl/open-data/treinstoringen), CC BY 4.0.
AI assistance was used for code, analysis and documentation.
