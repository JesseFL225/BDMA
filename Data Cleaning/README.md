# Data Cleaning

Run from the BDMA project root (base R only):

```sh
Rscript "Data Cleaning/clean_disruptions.R"
```

This reads `disruptions_2011_2025_raw.csv` and regenerates the root file
`disruptions_2011_2025_clean.csv`: 44,248 disruptions with the current input and settings.
The raw dataset is never overwritten.

The `output` folder contains the step-by-step Dutch report, filter counts,
excluded records with all reasons, endpoint classification, missingness,
retention by year and threshold sensitivity.

This strict selection excludes international or unresolved routes, test/information
messages, invalid records, durations above 24 hours and duration discrepancies
above one minute. These are explicit analysis choices, not proof that every
excluded event is erroneous. In particular, they substantially reduce pre-2017
coverage and exclude genuine long events. See `output/cleaning_report.md`.

Run validation, including rebuilding the outputs:

```sh
Rscript "Data Cleaning/test_clean_disruptions.R"
```

Dataset: Rijden de Treinen, CC BY 4.0.
Code prepared with AI assistance.
