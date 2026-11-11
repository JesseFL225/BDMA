# Data

- disruptions_2011_2025_raw.csv: oorspronkelijke brondata; niet wijzigen.
- disruptions_2011_2025_clean.csv: strenge selectie met 44.248 storingen.

Reproduceer de clean dataset vanuit de BDMA-hoofdmap met:

```sh
Rscript "Data Cleaning/clean_disruptions.R"
```

Zie ../Data Cleaning/output/cleaning_report.md voor filters en beperkingen. Modelstappen lezen deze bestanden en voeren geen eigen cleaning uit.
