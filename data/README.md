# Data

- `disruptions_2011_2025_raw.csv`: original source data from Rijden de Treinen; never modify (62,540 records).
- `disruptions_2011_2025_clean.csv`: strict selection of 44,248 disruptions, used by all models.

Rebuild the clean dataset from the repository root with:

```sh
Rscript "Data Cleaning/clean_disruptions.R"
```

See `../Data Cleaning/output/cleaning_report.md` for filters and limitations, and
`../docs/PROCESS.md` ("How the dataset changed") for dataset versions and differences
between years. Model steps read these files and never do their own cleaning.

Note: the column `long_disruption` (duration > 60 minutes) is a leftover of the
original binary plan. The modelling target is the 102-class target in `moddeling/01_target/`.
Columns ending in `_nl` contain the original Dutch source text.
