# Moddeling — stappenoverzicht en reproductie

(De mapnaam `moddeling` is historisch en bewust niet hernoemd; veel scripts verwijzen ernaar.)

Het verhaal achter deze stappen, met alle afslagen en hun reden, staat in
[docs/PROCESVERLOOP.md](../docs/PROCESVERLOOP.md). Cijfers en afrondingsinstructies
staan in [docs/OVERDRACHT_MODELLERING.md](../docs/OVERDRACHT_MODELLERING.md).

Status 13 november 2026: **alle stappen afgerond, eindtest op 2025 uitgevoerd.**
Waar een stap-README nog zegt dat 2025 "locked" of "dicht" is, beschrijft dat de
situatie tijdens die stap.

## Stappen in uitvoeringsvolgorde

De mapnummers zijn vooraf toegekend; de experimenten 10–13 zijn later toegevoegd
en vóór de eindtest (09) uitgevoerd.

| Volgorde | Map | Wat | Eigenaar | Uitkomst |
|---:|---|---|---|---|
| 1 | [01_target](01_target/README.md) | 102 klassen van 10 min, restklasse ≥ 1010 | Mart | Vaste target |
| 2 | [02_voorbereiding](02_voorbereiding/README.md) | Gedeelde split en preprocessing (`prepare_data()`) | Mart | Contract voor alle modellen |
| 3 | [07_evaluatie](07_evaluatie/README.md) | Gedeelde evaluator (`evaluate_predictions()`) | Mart | Contract voor alle modellen |
| 4 | [03_baselines](03_baselines/README.md) | Globale en oorzaakgroep-frequenties | Mart | Ondergrens |
| 5 | [04_logistic_regression](04_logistic_regression/README.md) | Multinomiale ridge regression | Mart | Hoogste exacte context-accuracy |
| 6 | [05_random_forest](05_random_forest/README.md) | Probability forest | Oliver | **Gekozen contextmodel** |
| 7 | [06_gradient_boosting](06_gradient_boosting/README.md) | Multiclass XGBoost | Oliver | Niet beter dan forest |
| 8 | [08_foutanalyse](08_foutanalyse/README.md) | Vergelijking, subgroepen, importance, figuren | Oliver | Forest wint validatie |
| 9 | [10_regressie_experiment](10_regressie_experiment/README.md) | Duur direct in minuten | Oliver | Niet overgenomen |
| 10 | [11_historische_kenmerken](11_historische_kenmerken/README.md) | Eerdere storingen als features | Oliver | Geen winst, niet overgenomen |
| 11 | [12_modelstrategie](12_modelstrategie/README.md) | Strategie: ordinaal voorstel | Oliver | Vervangen door survival |
| 12 | [13_survival](13_survival/README.md) | Discrete-time survival, 2017-gevoeligheid, onzekerheid | Oliver | **Gekozen tijd-only model** |
| 13 | [09_modelkeuze_en_test](09_modelkeuze_en_test/README.md) | Keuze bevriezen, eenmalige test 2025 | Oliver en Mart | **Eindresultaat** |
| 14 | [14_bronnenonderzoek](14_bronnenonderzoek/README.md) | Publieke bronnen voor extra features | Oliver | Alleen onderzoek |
| 15 | [15_koppelpilot](15_koppelpilot/README.md) | Eerste NS-meldingen koppelen (3 dagen) | Oliver | 40/42 gekoppeld; geen model |

Daarvoor: `../Data Cleaning/` (ruwe naar clean data) en `../descriptive data analysis/`
(verkenning van de ruwe data).

## Afspraken die voor alle stappen gelden

- Scripts starten vanuit de **hoofdmap** van de repository.
- Code staat per stap in de stapmap, resultaten in `output/` van die stap.
- Alleen `Data Cleaning/` schrijft naar `data/`. Modelscripts lezen alleen.
- Iedere modelstap gebruikt `prepare_data()` (02) en `evaluate_predictions()` (07).
  Niemand bouwt een eigen variant.
- Seed 42. Chronologische splits; tuning op de folds t/m 2021 → 2022 en t/m 2022 → 2023.
- Twee feature sets: `time_only` en `archived_context` (retrospectief, niet live bewezen).
- Duur, eindtijd en statistische oorzaak zijn nooit predictor.
- Fitted models komen in `output/models/` (Git-ignored); de scripts bouwen ze opnieuw op.

## Gedeeld contract gebruiken (voor nieuwe modelcode)

```r
source("moddeling/02_voorbereiding/prepare_data.R")
source("moddeling/07_evaluatie/evaluate.R")
prepared <- prepare_data(include_retrospective_cause = TRUE)  # FALSE = time-only
result <- evaluate_predictions(predictions,
  expected_ids = prepared$validation$ids,
  expected_true_class = prepared$validation$y)
```

Matrices staan in `prepared$train$X$time_only` en `$archived_context` (idem voor
validation). `class_levels` legt de volgorde van de 102 klassen vast. Zie de READMEs
van stap 02 en 07 voor de volledige API.

## Reproduceren

R 4.4–4.5. Base R volstaat voor de stappen 01, 02, 03 en 07. Verder nodig: `glmnet`
(stap 04, geverifieerd 4.1-10), `ranger` en `xgboost` (stappen 05, 06, 08, 10, 11, 13).
Python 3 (standaardbibliotheek) voor de verificatiescripts en stap 15.

```sh
# 0. Packages (optioneel; installeert ranger/xgboost in de Git-ignored .R-library/)
Rscript moddeling/05_random_forest/install_dependencies.R

# 1. Data (alleen nodig om de clean CSV opnieuw op te bouwen)
Rscript "Data Cleaning/clean_disruptions.R"

# 2. Gedeelde basis, baselines en logistic regression (Mart)
Rscript moddeling/02_voorbereiding/validate_preparation.R
Rscript moddeling/07_evaluatie/validate_evaluation.R
Rscript moddeling/03_baselines/run_baselines.R
Rscript moddeling/04_logistic_regression/run_logistic_regression.R

# 3. Bomen en foutanalyse (Oliver); gebruikt de outputs van stap 03/04
Rscript moddeling/run_oliver.R        # = stappen 05, 06 en 08 achter elkaar

# 4. Ontwikkelexperimenten
Rscript moddeling/10_regressie_experiment/run_regression.R
Rscript moddeling/11_historische_kenmerken/run_history_regression.R
Rscript moddeling/13_survival/run_survival.R
python3 moddeling/13_survival/verify_predictions.py

# 5. Eindtest: NIET opnieuw draaien. Alleen de opgeslagen resultaten controleren:
python3 moddeling/09_modelkeuze_en_test/verify_saved_test.py

# 6. Koppelpilot (eerste commando heeft internet nodig; 12 kleine bestanden)
python3 -u moddeling/15_koppelpilot/download.py
python3 moddeling/15_koppelpilot/test_pilot.py
python3 moddeling/15_koppelpilot/pilot.py
python3 moddeling/15_koppelpilot/report.py
```

Gebruik bij voorkeur een nieuwe R-sessie per stap. Het opnieuw trainen van de
bomen en het survivalmodel kan lang duren. `final_test.R` weigert te draaien zodra
`09_modelkeuze_en_test/output/TEST_OUTCOMES_OPENED.txt` bestaat; verwijder dat
bestand niet. Na een hertraining kunnen de hashes van modelbestanden verschillen,
ook als de voorspellingen gelijk zijn. Overschrijf de bevroren provenance in stap 09 niet.
