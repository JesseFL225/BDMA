# Werkplan predictive modelling — Mart en Oliver

Doel voor vandaag: één reproduceerbare vergelijking van baselines, multinomiale
logistic regression, random forest en gradient boosting op dezelfde validatierijen.
Werktaal code/rapport: Engels. Dit document is een werkvoorstel, geen modelresultaat.

## 1. Samen vastleggen voordat jullie splitsen (30 minuten)

| Onderwerp | Voorstel voor vandaag |
|---|---|
| Vraag | Bij aanvang voorspellen in welk duurinterval een storing eindigt |
| Dataset | `data/disruptions_2011_2025_clean.csv`, 44.248 rijen; geen eigen extra cleaning |
| Startpunt | Commit `a78d13c`, of een gezamenlijk gecontroleerde opvolger op main |
| Taal | R, passend bij het bestaande project |
| Targetbron | `duration_minutes`; niet opnieuw eindtijd minus begintijd berekenen |
| Tijdvakken | [0,10), [10,20), …, [1000,1010), [1010,+∞): 102 klassen |
| Split | Train 2011–2023, validatie 2024, test 2025, conform aangeleverde tekst |
| Seed | `set.seed(42)` |
| Modelselectie | Laagste multiclass log loss op validatie; bij vrijwel gelijke resultaten eenvoud en stabiliteit meewegen |
| Test | Pas openen voor modelevaluatie nadat modellen en instellingen definitief vaststaan |

**Targetbesluit bijgewerkt:** trek de 10-minutenklassen door totdat de restklasse
het dichtst bij de gemiddelde grootte van alle voorgaande klassen ligt. Op alleen
de training (2011–2023, 33.004 rijen) geeft dit een grens van **1010 minuten**.
De restklasse bevat **322 rijen (0,98%)**, tegenover gemiddeld **323,58** in de
overige 101 klassen. De eerdere restklasse ≥120 bevatte 9.274 rijen (28,1%).

Dit maakt niet alle klassen even groot: de mediaan van de gewone klassen is 34,
het minimum 4 en het maximum 4.715. Een kleine restklasse bewijst geen statistische
insignificantie. Verwacht moeilijke voorspellingen voor zeldzame lange tijdvakken.
Wijzig de klassen niet afzonderlijk per model of op basis van de testresultaten.

De keuze is reproduceerbaar met `moddeling/01_target/define_duration_classes.R`.
De vaste klassevolgorde staat in `moddeling/01_target/output/classes.csv`;
trainingsaantallen en alle kandidaatgrenzen staan in dezelfde map. De clean CSV
wordt niet gewijzigd. Mart en Oliver gebruiken exact deze gedeelde definitie.

Werk eerst de oude binaire target in Step 1, Step 3 en Step 5 bij. De binaire
3:1-foutkosten, één kansdrempel en binaire PR-AUC zijn niet rechtstreeks de
evaluatie van dit nieuwe probleem. Behoud `long_disruption` alleen als bestaande
datakolom; het is geen predictor van de nieuwe target.

## 2. Gedeeld contract — Mart beheert, Oliver reviewt

Mart maakt `moddeling/02_voorbereiding/prepare_data.R` en
`moddeling/07_evaluatie/evaluate.R`.
Beide modellenfolders importeren deze bestanden; niemand kopieert er een eigen
variant van. Publiceer een kleine eerste versie na maximaal een uur, voordat
Mart aan uitgebreide modeltuning begint.

`prepare_data()` levert train/validation/test, IDs, X, y, vaste class levels en
de getrainde preprocessing. Testdata hoeven vandaag nog geen voorspellingen te
krijgen. Eén rij blijft één storing, ook bij meerdere trajecten.

- Basiskenmerken: lokaal uur, weekdag, maand, weekend en spitsindicator.
- Uitgebreide kenmerken: aantal unieke traject-ID's, stationaantal, missingness,
  hubflags en multi-hot indicators voor de 20 meest voorkomende individuele
  trajecten in training. Ontbrekende stations betekenen onbekend, niet nul.
- `cause_group` alleen in een expliciet gemarkeerd retrospectief experiment.
  De laatst opgeslagen oorzaak hoeft bij aanvang niet bekend te zijn. Ook de
  uiteindelijke stations/trajectlijst kan later zijn aangepast. Rapporteer daarom
  eerst een tijd-only model en daarna een archived-context model met dezelfde
  kenmerken voor alle algoritmen. Dat laatste is geen bewezen live inzetbaar model.
- Geen `rdt_id`, eindtijd, duur, calculated/difference minutes, long_disruption of
  statistical cause als predictors. ID en echte duur blijven apart voor evaluatie.
- Encoder, schaling, imputer, klasse-/trajectfrequenties uitsluitend op training
  fitten. Binnen tuningfolds opnieuw op het trainingsdeel fitten. Onbekende
  categorieën expliciet afhandelen; vaste kanskolomvolgorde bij alle modellen.
- Geen network-load/history-features vandaag: eerst de eenvoudige vergelijking
  werkend krijgen, daarna pas een gecontroleerde reconstructie van historische informatie.
- Bij tijdgrenzen mogen trainingslabels niet uit nog niet afgeronde storingen
  komen: verwijder zulke grensoverschrijdende rijen uit die trainingsfold.

Outputcontract per model: `rdt_id`, `split`, `model`, `feature_set`, `true_class`,
`predicted_class`, plus `p_0000_0010`, …, `p_1000_1010`, `p_1010_plus`.
Alle kansen zijn eindig, liggen tussen 0 en 1 en tellen per rij op tot 1.
Gebruik de 102 klassen in `classes.csv`-volgorde. Als een klasse ontbreekt in een
tuning-trainingsfold, spreek dan één beleid af voor die fold en alle modellen;
renummer niet stilzwijgend de klasse-ID's. De uiteindelijke training bevat alle klassen.
Sla daarnaast modelinstellingen, dataset-hash, seed en packageversies op.

Dataset SHA-256 bij voorbereiding:
`e5afb30aefc9e2ef3984a56b309acabe94f2d5adbc4e6a7c8f4a68cf03f5aabd`.

## 3. Mart — baselines, logistic regression en gedeelde evaluatie

Bestanden in `moddeling/02_voorbereiding/`, `03_baselines/`,
`04_logistic_regression/` en `07_evaluatie/`.

1. Implementeer en deel preprocessing, split en target met grenscontroles voor
   9, 10, 19, 20, 1009, 1010 en 1440 minuten. Controleer hetzelfde ID-set bij beide personen.
2. Maak een baseline met de trainingsfrequenties als constante kansverdeling.
   De voorspelde klasse is steeds de meest voorkomende trainingsklasse.
3. Maak voor het archived-context experiment een oorzaakgroepbaseline met
   trainingsfrequenties per klasse/groep. Gebruik smoothing; onbekende groepen
   krijgen de globale trainingsverdeling. Nooit validatielabels gebruiken.
4. Train multinomiale logistic regression, bijvoorbeeld `glmnet` via tidymodels.
   Gebruik een kleine regularisatiegrid. Gewone binaire logistic regression past
   niet bij deze target. Zet class weights niet automatisch aan.
5. Lever `evaluate_predictions()` voor alle modellen: log loss, accuracy, macro-F1,
   recall per klasse, confusion matrix en de hieronder gedefinieerde afstandsmaat.
6. Schrijf circa een halve pagina Engels over baselines, logistic regression en
   evaluatie. Lever één vergelijkingstabel en één confusion-matrixfiguur.

Klaar wanneer één commando alle Mart-resultaten reproduceert en Oliver zijn
voorspellingen door dezelfde evaluator kan sturen.

## 4. Oliver — random forest, boosting en foutanalyse

Bestanden in `moddeling/05_random_forest/`, `06_gradient_boosting/` en
`08_foutanalyse/`.

1. Terwijl Mart shared bouwt: maak modelscripts en kleine parametergrids die het
   afgesproken input/outputcontract gebruiken. Geen eigen cleaning schrijven.
2. Train een probability random forest, bijvoorbeeld `ranger`: varieer vooral
   `mtry` en minimale leaf size, met een vast aantal bomen als startpunt.
3. Train één multiclass boostingmodel, bijvoorbeeld XGBoost met kansoutput voor
   alle klassen. Beperk tuning tot boomdiepte, learning rate en aantal iteraties.
   Stem numerieke class IDs expliciet af op de gedeelde class levels.
4. Lever kansen en klassen in exact hetzelfde formaat als Mart. Vergelijk eerst
   de identieke tijd-only kenmerken, daarna identieke archived-context kenmerken.
5. Onderzoek op validatie welke klassen, maanden, oorzaakgroepen en trajecten
   vaak te kort/te lang worden voorspeld. Toon aantallen per groep, niet alleen percentages.
6. Maak permutation importance voor het beste validatiemodel. Benoem dat
   importance associaties beschrijft en geen oorzakelijk bewijs is.
7. Schrijf circa een halve pagina Engels over forest/boosting en fouten. Lever
   maximaal drie heldere figuren en een voorstel voor modelkeuze.

Klaar wanneer beide modellen via de gedeelde evaluator vergeleken zijn met
Marts baselines en hun outputs onafhankelijk opnieuw te genereren zijn.

## 5. Evaluatie en tuning

- **Primair: multiclass log loss** (lager beter): beoordeelt de volledige kansverdeling.
- **Aanvullend: accuracy en macro-F1**: exact tijdvak en prestaties over alle klassen.
  Toon support per klasse. Leg expliciet vast hoe afwezige klassen in een fold
  behandeld worden en gebruik bij alle modellen dezelfde convention.
- **Volgorde:** rapporteer naast exact goed het percentage maximaal één klasse
  ernaast. Dit is NIET hetzelfde als maximaal tien minuten fout. Bij de open
  eindklasse is klassenafstand geen vaste tijdsafstand; toon die klasse apart.
- Rapporteer onder- en overschatting van de klasse. Verzin geen minuutfout met
  1015 minuten als representant voor alle storingen ≥1010 minuten.
- Optioneel later: regressie op minuten, met MAE en daarna omzetting naar dezelfde
  tijdvakken. Vandaag eerst baseline plus drie vergelijkbare classifiers afronden.
- Tuning: vaste, kleine grids op forward folds binnen training, bijvoorbeeld
  trainen t/m 2021 → 2022 en trainen t/m 2022 → 2023. Geen random/shuffled folds.
  Daarna fitten op training t/m 2023; 2024 gebruiken voor de eindvergelijking.
- Selecteer en bevries de winnaar vóór test. Rapporteer daarna de vooraf gekozen
  modellen op 2025, zonder opnieuw instellingen te kiezen op basis van testresultaten.

Beperkingen in het eindverslag: de 24-uursselectie gebruikt de uiteindelijke duur,
dus prestaties gelden niet vanzelf voor alle nieuwe storingen. De strenge
duurcontrole heeft vroege jaren sterk uitgedund. Vergelijk, als er tijd is,
trainen op 2017–2023 met de hoofdvariant, op dezelfde 2024-validatierijen.

## 6. Branches en bestanden: zo voorkom je conflicten

- Oliver werkt op `Oliver` (bestaat lokaal en volgt inmiddels `origin/Oliver`).
- Mart maakt `mart-predictive-analysis` vanaf de afgesproken main-commit.
- Beiden pushen alleen hun eigen branch, vandaag niet rechtstreeks naar main.
- Mart beheert shared; Oliver verandert shared alleen na overleg en review.
- Mart pusht de shared-contractcommit eerst. Oliver haalt die binnen met
  `git fetch origin` en `git merge origin/mart-predictive-analysis` zodra die commit
  gereed is. Daarna bouwen ze verder in hun eigen bestanden.
- Alleen het pushen van een commit deelt bestanden; een lokale commit is niet
  automatisch zichtbaar op de andere computer.
- Dependencies: Mart beheert één setupbestand en eventueel renv-lockfile; Oliver
  geeft benodigde packages door. Vermijd gelijktijdige lockfilewijzigingen.
- Geen lokale `.RData`, caches, credentials of omvangrijke fitted models committen.
  Commit scripts, kleine voorspeltabellen/metrics, figuren en korte teksten.
- Aan het einde opent ieder een PR naar main; de ander reviewt. Mart eerst mergen
  vanwege shared, Oliver daarna main in zijn branch mergen en opnieuw controleren.
- Maak pas daarna één `moddeling/run_all.R` (Mart eigenaar) en een
  eventueel gezamenlijk notebook dat de scripts aanroept; geen dubbele modellogica.

## 7. Tijdschema vanaf jullie startmoment

| Tijd | Mart | Oliver |
|---|---|---|
| 0:00–0:30 | Samen target, feature sets, split en outputs vastleggen | Samen |
| 0:30–1:30 | Shared contract, checks, baseline; shared commit pushen | Forest/boosting-scripts voorbereiden tegen het contract |
| 1:30–3:00 | Logistic regression en kleine tuninggrid | Shared binnenhalen; forest en boosting draaien |
| 3:00–3:30 | Samen validation-output en leakage controleren | Samen |
| 3:30–4:30 | Evaluatietabel en methodetekst | Foutanalyse, importance en figuren |
| 4:30–5:00 | Samen winnaar vastleggen; test alleen indien alles klaar is | Samen |
| 5:00–6:00 | Oliver reviewen, run_all, PR afronden | Mart reviewen, presentatiestructuur, PR afronden |

Minimum aan het einde: vier vergelijkbare modelgroepen, gedeelde validatietabel,
confusion matrix, fouten per klasse, korte Engelse B5-tekst en reproduceerbare code.
Bij tijdgebrek schrap uitgebreide tuning en regressie; gebruik testdata niet om
snel een overtuigender resultaat te zoeken.

Presentatie tot 10 slides: vraag; data/target; cleaning/beperkingen; split/features;
baselines/logistic; forest/boosting; vergelijking; foutanalyse; interpretatie;
aanbeveling. Vul pas na de runs prestaties en conclusies in.

## Referenties

- Aangeleverde projecttekst; daarin staat nog de binaire target. Dit is geen
  onafhankelijk gecontroleerde originele rubric van de docent.
- Multinomiale logistic regression: https://parsnip.tidymodels.org/reference/multinom_reg.html
- Multiclass log loss: https://yardstick.tidymodels.org/reference/mn_log_loss.html
- Macro-F1: https://yardstick.tidymodels.org/reference/f_meas.html

Plan opgesteld met AI-assistentie. Het oorspronkelijke plan is naar main gepusht;
de uitgebreidere targetdefinitie is lokaal berekend. Er zijn hiervoor geen modellen
getraind of berichten aan Mart verzonden.

## Verplichte documentatie per stap

De map heet bewust `moddeling/`. Elke genummerde stap heeft een eigen
`README.md`. Werk deze bij in dezelfde commit als de code/resultaten van die stap.
Beschrijf doel, eigenaar, status, inputs en versies, wat daadwerkelijk is uitgevoerd,
instellingen en motivatie, resultaten en outputbestanden, impact op het project,
controles/beperkingen en de overdracht naar de volgende stap. Houd geplande acties
en uitgevoerde acties uit elkaar; vermeld bij modelresultaten of het training,
validatie of test betreft.

| Stap | Eigenaar |
|---|---|
| `00_afspraken/` | Mart en Oliver |
| `01_target/` | Mart, review Oliver |
| `02_voorbereiding/` | Mart, review Oliver |
| `03_baselines/` | Mart |
| `04_logistic_regression/` | Mart |
| `05_random_forest/` | Oliver |
| `06_gradient_boosting/` | Oliver |
| `07_evaluatie/` | Mart, review Oliver |
| `08_foutanalyse/` | Oliver, review Mart |
| `09_modelkeuze_en_test/` | Mart en Oliver |

Sla code in de betreffende stapmap op en resultaten in een `output/`-submap.
Voer scripts uit vanuit de BDMA-hoofdmap. Alleen cleaning mag de gedeelde clean
CSV opnieuw opbouwen. Modelscripts lezen uit `data/` en schrijven daar niet naar.
De bestaande `Data Cleaning/` en `descriptive data analysis/` blijven behouden.
