# Overdracht modellering Part B — cijfers, beperkingen en afronding

Laatste update: 13 november 2026. Werkbranch: `Oliver`.
Voor: Mart en wie het verslag, de presentatie en de code-inlevering afrondt.

**Leesvolgorde**

1. [PROCESVERLOOP.md](PROCESVERLOOP.md): het verhaal, alle stappen en afslagen met hun reden.
2. Dit document: exacte cijfers, wat je wel en niet mag beweren, en hoe je afrondt.
3. [`moddeling/README.md`](../moddeling/README.md): stappenoverzicht en reproductie.

---

## 1. Opdracht en vraag

We voorspellen bij aanvang van een storing de kans op elk van 102 duurintervallen
([0,10), [10,20), …, [1000,1010), ≥1010 minuten). Eén rij is één storing, niet één
treinrit of één reizigersvertraging.

De originele opdracht (`Project.pdf`, Part B, p. 4–6) vraagt minimaal drie passende
voorspelmodellen, onderbouwde evaluatie, foutanalyse en modelkeuze. Er is geen
verplicht algoritme, geen verplichte binaire target en geen verplichte enkele databron.
Inlevering: verslag van maximaal 5 pagina's (excl. appendix/referenties), toegang
tot de exacte data, volledige analysecode, maximaal 10 slides. B5 telt voor 8 van de
25 punten. Meer complexiteit levert niet vanzelf een hoger cijfer op.

## 2. Data, splits en wat de modellen mogen zien

- Bestand: `data/disruptions_2011_2025_clean.csv`, 44.248 storingen
  (MD5 `6f22afc6b05fe5e65ed8bd583bc5ba68`). Gebouwd uit de ruwe data door
  `Data Cleaning/clean_disruptions.R`.
- Split: 33.004 training (2011–2023), 5.296 validatie (2024), 5.948 test (2025).
  De variant vanaf 2017 heeft minder trainingsrijen, maar dezelfde validatie- en test-ID's.
- Tuning: voorwaartse folds t/m 2021 → 2022 en t/m 2022 → 2023.
- **Tijd-only:** uur, weekdag, maand, weekend, spits.
- **Archived context:** daarnaast oorzaakgroep, aantallen trajecten/stations, hubs
  en top-20-trajecten.
- Preprocessing wordt alleen op training geleerd, opnieuw binnen iedere fold.
  Eindtijd, duur, statistische oorzaak en de target zijn nooit predictor.
- 2024 is herhaaldelijk gebruikt voor ontwikkeling. Noem 2024 dus **geen
  onafhankelijke test**. 2025 is één keer geopend, na het bevriezen van de modellen.

## 3. Resultaten op validatie (2024)

Log loss is de primaire maat (lager is beter).

| Model | Tijd-only | Archived context | Exact goed (context) |
|---|---:|---:|---:|
| Baseline (globaal / oorzaakgroep) | 3,2309 | 3,0716 | 11,78% |
| Multinomiale logistic regression | 3,2173 | 3,0820 | **12,76%** |
| Random forest | 3,2139 | **3,0591** | 12,31% |
| Multiclass XGBoost | 3,2195 | 3,0844 | 11,63% |
| Survival, 2011–2023 | 3,1935 | 3,0678 | 11,88% |
| Survival, 2017–2023 | **3,1905** | 3,0627 | 11,86% |

- Logistic wint op exact goed, forest op de primaire kansmaat.
- De extra winst van forest boven de oorzaakbaseline is beperkt. Beweer niet dat
  complexe ML een grote vooruitgang oplevert.
- Survival vanaf 2017 wint tijd-only duidelijk. Het contextverschil tussen survival
  en forest is klein en onzeker (dag-bootstrapinterval omvat nul).
- Regressie (stap 10): context-MAE 68,06 min tegen 78,77 voor de mediaan-baseline.
  Met historische kenmerken (stap 11) 68,95: geen winst.
- Context-survival: de centrale 80%-intervallen dekken 90,35%. Onder de 97,75% met
  een eindige bovengrens is de gemiddelde breedte 213,78 minuten. Dat is geen fout
  van 214 minuten per voorspelling en geen gegarandeerde dekking.

Bronnen: `moddeling/08_foutanalyse/output/`, `moddeling/13_survival/output/`
(`selection_and_uncertainty.md`, `all_model_comparison.csv`).

## 4. Vastgezette modelkeuze en eindtest (2025)

Gekozen op de laagste validatie-log-loss binnen ieder informatiescenario:

1. **Tijd-only:** survival vanaf 2017, diepte 2, 250 boostingrondes, learning rate 0,05.
   Vergeleken met globale frequenties uit dezelfde trainingsjaren.
2. **Archived context:** random forest, 200 bomen, minimale node size 100, mtry=sqrt,
   maximale diepte 12, 1% gemengde trainingsprior. Vergeleken met de oorzaakbaseline
   (2011–2023).

Geen hertraining op 2024. Hashes vooraf vastgelegd; voorspellingen opgeslagen
vóórdat de testlabels werden ingelezen. Details: `moddeling/09_modelkeuze_en_test/TEST_PROTOCOL.md`.

| Model | Log loss 2025 | Exact goed | RPS |
|---|---:|---:|---:|
| Tijd-only survival vanaf 2017 | **3,1620** | 10,93% | 0,05908 |
| Bijbehorende globale baseline | 3,2065 | 10,15% | 0,06422 |
| Context random forest | **3,0189** | 12,02% | 0,05048 |
| Bijbehorende oorzaakbaseline | 3,0273 | 11,79% | 0,05178 |

- Dag-bootstrap (model − baseline): survival −0,0663 tot −0,0246; forest −0,0151 tot −0,0012.
- Log loss was in 2025 lager dan in 2024, maar exacte accuracy en RPS verslechterden.
  Schrijf dus niet dat "alle prestaties beter werden". De jaren verschillen in samenstelling.
- Forest onderschat de klasse bij 83,84% van de modale voorspellingen.
- 80%-intervallen van forest dekken 90,97%; de 98,39% met een eindige bovengrens zijn
  gemiddeld 222,88 minuten breed.
- Brier voor "hersteld vóór 60/120 minuten" is bij forest iets slechter dan de
  oorzaakbaseline. Er is dus geen winst voor iedere beslissing.

Conclusie: een bescheiden winst in de totale kansvoorspelling, geen betrouwbaar
precieze eindtijd. De test is onafhankelijk gecontroleerd (`verify_saved_test.py`);
alle 5.948 test-ID's zijn behouden. **Niet meer tunen of selecteren op 2025.**

Exacte cijfers voor tabellen en figuren: `test_summary.csv`, `test_bootstrap.csv`,
`test_groups.csv`, `test_calibration.csv`, `test_thresholds.csv` in
`moddeling/09_modelkeuze_en_test/output/`.

## 5. Survival begrijpelijk uitleggen

Het model vraagt per toekomstig interval: als de storing tot hier duurt, hoe groot
is dan de kans dat zij in dit interval eindigt? Een storing die in het derde interval
eindigt, levert tijdens training twee "nog niet afgelopen"-rijen op, gevolgd door één
"afgelopen"-rij. Dat is een omzetting van dezelfde storing, geen extra data.

De conditionele kansen worden vermenigvuldigd tot een volledige duurverdeling. De
kans op herstel vóór 60 minuten is de som van de eerste zes klassen, dus **strikt
vóór** 60 (niet "tot en met"). XGBoost leert de intervalkansen met een binaire loss.
Dat is geen gewone binaire voorspelling "langer dan 60 minuten": het eindresultaat
blijft 102 kansen. De open eindklasse krijgt de resterende kans.

## 6. Koppelpilot eerste NS-meldingen (stap 15)

Drie vooraf gekozen dagen (10 november 2017, 2020 en 2023). Geen modeltraining, geen 2024/2025.

- 40 van de 42 storingen zijn eenduidig gekoppeld aan een eerste NS-melding. Er is
  1 ambigu geval en 1 zonder geldige kandidaat; beide zijn bewust geweigerd door
  vooraf vastgelegde regels.
- **Ons startmoment is de eerste publieke melding**: `start_time` ligt mediaan
  1 seconde van de eerste NS-publicatie (maximaal 35 s).
- Eerste oorzaak ≠ uiteindelijke oorzaak bij 5 van de 40, waarvan 3 inhoudelijk.
- Een NS-herstelprognose in het eerste bericht: 2/7 (2017), 4/17 (2020), 16/16 (2023).

Gebruik in het verslag: één à twee zinnen bij beperkingen of aanbevelingen, of in de
appendix. Het is geen modelresultaat en geen landelijk percentage. Details:
`moddeling/15_koppelpilot/README.md`. Bronnen voor verrijking: `moddeling/14_bronnenonderzoek/README.md`.

## 7. Beperkingen die in het verslag moeten blijven

- De cleaning sluit onder andere storingen boven 24 uur uit op basis van hun
  uiteindelijke duur. Bij aanvang kun je die populatie niet herkennen.
- Veel vroege records zijn uitgesloten wegens verschil tussen duurvelden. De
  2017-gevoeligheid onderzoekt dit deels, maar lost de selectie niet op.
- Opgeslagen oorzaken en getroffen trajecten kunnen achteraf zijn gewijzigd
  (bevestigd in de pilot). Contextresultaten zijn niet bewezen live inzetbaar.
- We voorspellen op het moment van de eerste publieke melding, niet bij het fysieke begin.
- Lage exacte accuracy en brede intervallen beperken bruikbare reizigersbeloften.
- Feature importance is een voorspellend verband, geen oorzakelijk bewijs.
- Eén klasse ernaast is niet hetzelfde als maximaal tien minuten fout. De open
  eindklasse heeft geen geldig middenpunt voor minuutfouten.
- 2024 is geen onafhankelijke test; alleen 2025 is dat.
- Alle resultaten gelden voor deze data en selectie, niet automatisch voor alle
  Nederlandse storingen of voor toekomstige registratiewijzigingen.

## 8. Zo rond je af

**Verslag** (max. 5 pagina's). Basis: `moddeling/09_modelkeuze_en_test/output/B5_FINAL_REPORT_TEXT.md`.
Dat is de enige actuele rapporttekst; oudere concepten zijn verwijderd.
Richtlijn: ~1½ pagina vraag/data/voorbereiding, ~2 pagina's modellen en evaluatie
(inclusief de eindtest), ~1½ pagina fouten, aanbevelingen en beperkingen. Gebruik één
hoofdvergelijking en één onzekerheids- of kalibratiefiguur. Volledige grids,
subgroepen en checks gaan naar de appendix. Toon alle modelfamilies uit de validatie,
niet alleen de twee geteste. Maak B1 en B3 consistent met de 10-minutenklassen.

**Presentatie** (max. 10 slides): 1 vraag en stakeholder; 2 data en selectie; 3 target en
tijdsplit; 4 baselines en modellen; 5 survival-intuïtie; 6 validatie en modelkeuze;
7 eindtest; 8 fouten en onzekerheid; 9 beperkingen; 10 aanbeveling.
Bruikbare figuren: `moddeling/08_foutanalyse/output/*.png` en
`moddeling/13_survival/output/probability_diagnostics.png`.

**Code.** Lever de repository in met de README in de hoofdmap als startpunt.
Modelcaches (`output/models/`) zijn lokaal en Git-ignored; de scripts bouwen ze
opnieuw op. Een ongewijzigde reproductie mag, maar een nieuwe modelkeuze op 2025 niet.
`final_test.R` weigert een tweede run zolang `TEST_OUTCOMES_OPENED.txt` bestaat;
verwijder dat bestand niet.

**Delen.** Alles staat lokaal op branch `Oliver` en is nog niet gecommit of gepusht.
Pas na een push en een PR naar `main` kan Mart erbij.

AI is gebruikt bij code, analyse en documentatie. Controleer de code, zorg dat de
groep de keuzes en resultaten zelf kan uitleggen, en vermeld het AI-gebruik.
