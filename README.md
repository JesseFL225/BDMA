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
| **Write the report or the deck** (what to say per section, with ready figures and tables) | [moddeling/16_report_inputs/REPORT_INPUTS.md](moddeling/16_report_inputs/REPORT_INPUTS.md) |
| Read the draft B5 wording | [moddeling/09_modelkeuze_en_test/output/B5_FINAL_REPORT_TEXT.md](moddeling/09_modelkeuze_en_test/output/B5_FINAL_REPORT_TEXT.md) |
| Reproduce a step or understand the code | [moddeling/README.md](moddeling/README.md) |
| Work on this project with an AI assistant (ChatGPT, Claude, Copilot…) | [AGENTS.md](AGENTS.md): rules, pitfalls, a map of every file, and which files to upload |

## Result in short (final test 2025, lower log loss is better)

| Information at prediction time | Chosen model | Log loss | Baseline | Exact class |
|---|---|---:|---:|---:|
| Time features only | Survival boosting (trained 2017–2023) | 3.1620 | 3.2065 | 10.93% |
| Archived context (cause, route) | Random forest (trained 2011–2023) | 3.0189 | 3.0273 | 12.02% |

Both models beat their baseline, but the gain is modest and a precise end time remains
unpredictable. The main finding: **knowing the cause matters far more than the algorithm**
(AUC for "ends within 60 min": 0.57 without cause, 0.78 with cause). The preferred model is
the random forest, provided the cause is available at the first message.

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
Rscript moddeling/run_all.R   # ~40 s: checks everything and rebuilds all report figures/tables
```

It verifies that the code, data and models used for the final test are unchanged,
re-runs every automated check, re-verifies the saved predictions and regenerates
`moddeling/16_report_inputs/output/`. It trains no models.

The full order and required packages are in [moddeling/README.md](moddeling/README.md).
Do not re-run the final test (`final_test.R`): 2025 has been used once and stays that way.

## Team and source

Jesse (data supply), Mart (exploration, target, shared preparation and evaluation,
baselines, logistic regression), Oliver (cleaning, tree models, error analysis,
experiments, survival, final test, source research).
Data: [Rijden de Treinen](https://www.rijdendetreinen.nl/open-data/treinstoringen), CC BY 4.0.
AI assistance was used for code, analysis and documentation.
