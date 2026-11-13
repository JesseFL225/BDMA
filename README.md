# Voorspellen van de duur van treinstoringen (BDMA, Part B)

Bij het begin van een treinstoring voorspellen we een kansverdeling over 102
tijdvakken van 10 minuten (laatste: ≥ 1010 minuten). Data: Rijden de Treinen,
2011–2025, 44.248 geselecteerde binnenlandse storingen.

**Status (13 november 2026):** modellering afgerond en eindtest op 2025 uitgevoerd.
Verslag, presentatie en code-inlevering moeten nog worden afgerond.

## Begin hier

| Wil je… | Lees |
|---|---|
| Begrijpen wat we gedaan hebben, welke afslagen we namen en waarom | [docs/PROCESVERLOOP.md](docs/PROCESVERLOOP.md) |
| Exacte cijfers, beperkingen en hoe je het verslag/de slides afrondt | [docs/OVERDRACHT_MODELLERING.md](docs/OVERDRACHT_MODELLERING.md) |
| De conceptrapporttekst voor B5 (Engels) | [moddeling/09_modelkeuze_en_test/output/B5_FINAL_REPORT_TEXT.md](moddeling/09_modelkeuze_en_test/output/B5_FINAL_REPORT_TEXT.md) |
| Een stap reproduceren of de code begrijpen | [moddeling/README.md](moddeling/README.md) |

## Resultaat in het kort (eindtest 2025, lagere log loss is beter)

| Informatie bij voorspelling | Gekozen model | Log loss | Baseline | Exact goed |
|---|---|---:|---:|---:|
| Alleen tijdkenmerken | Survival-boosting (getraind 2017–2023) | 3,1620 | 3,2065 | 10,93% |
| Opgeslagen context (oorzaak, traject) | Random forest (getraind 2011–2023) | 3,0189 | 3,0273 | 12,02% |

Beide modellen verslaan hun baseline, maar de winst is bescheiden en een precieze
eindtijd blijft onvoorspelbaar. Zie de overdracht voor onzekerheid en beperkingen.

## Mappen

```
data/                       ruwe en clean dataset (alleen Data Cleaning schrijft hierin)
Data Cleaning/              ruwe → clean data, met rapport per filter
descriptive data analysis/  verkenning van de ruwe data
moddeling/                  alle modelstappen 01–15, elk met README, code en output/
docs/                       procesverloop en overdracht
```

## Snel starten

Vanuit deze map, met R 4.4 of nieuwer:

```sh
Rscript "Data Cleaning/clean_disruptions.R"                     # clean data opnieuw opbouwen
Rscript moddeling/02_voorbereiding/validate_preparation.R        # gedeelde basis controleren
python3 moddeling/09_modelkeuze_en_test/verify_saved_test.py     # eindtest controleren
```

De volledige volgorde en benodigde packages staan in [moddeling/README.md](moddeling/README.md).
Draai de eindtest (`final_test.R`) niet opnieuw: 2025 is één keer gebruikt en blijft dat.

## Team en bron

Jesse (data-aanlevering), Mart (verkenning, target, gedeelde voorbereiding en evaluatie,
baselines, logistic regression), Oliver (cleaning, bomenmodellen, foutanalyse,
experimenten, survival, eindtest, bronnenonderzoek).
Data: [Rijden de Treinen](https://www.rijdendetreinen.nl/open-data/treinstoringen), CC BY 4.0.
AI-assistentie is gebruikt bij code, analyse en documentatie.
