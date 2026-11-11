# Opschoning Nederlandse treinverstoringen

Bron: `data/disruptions_2011_2025_raw.csv` (MD5: `757d2c2aff9405c9ef9992b6b2476af0`).
Van **62540** raw-rijen naar **44248** geselecteerde storingen. **18292** rijen apart gezet.

## Stappen en aantallen

| Stap | Regel | Verwijderd in deze stap | Over |
|---|---|---:|---:|
| 1 | Exact dubbele rijen | 0 | 62540 |
| 2 | Ongeldige of conflicterende IDs | 0 | 62540 |
| 3 | Testberichten | 1 | 62539 |
| 4 | Informatie- en vervolgberichten | 49 | 62490 |
| 5 | Buitenlands traject of station | 5078 | 57412 |
| 6 | Traject niet betrouwbaar te classificeren | 999 | 56413 |
| 7 | Ontbrekende/ongeldige/ambigue tijd | 98 | 56315 |
| 8 | Ontbrekende, niet-eindige of niet-positieve duur | 692 | 55623 |
| 9 | Einde niet na begin | 0 | 55623 |
| 10 | Ongeldig of inconsistent bronjaar | 0 | 55623 |
| 11 | Opgegeven of berekende duur boven 24 uur | 344 | 55279 |
| 12 | Duurverschil groter dan 1 minuut | 11031 | 44248 |

Een rij kan meerdere regels raken. De tabel telt iedere rij eenmaal, bij de eerste regel. `excluded_disruptions.csv` bewaart de originele waarden, CSV-rijnummer, eerste reden, alle redenen en gevonden buitenlandse namen.

## Keuzes en beperkingen

- Dit is een strenge, reproduceerbare analyseselectie, geen bewijs dat alle uitgesloten records onjuist zijn. De raw-data blijft behouden; de clean-CSV in data/ wordt opnieuw opgebouwd.
- Maximumduur: 1440 minuten. Zowel de opgegeven als de berekende duur moet binnen de grens vallen. Langdurige brugschade, stakingen en weersproblemen kunnen echte incidenten zijn. Deze selectie voorspelt alleen binnen de geselecteerde duurpopulatie; bij aanvang weet je nog niet of een storing langer dan 24 uur duurt. Evalueer voor inzet ook op alle geldige duren.
- Een duurverschil groter dan 1 minuut leidt tot uitsluiting, niet tot een verzonnen correctie. Dit verwijdert vooral vroege jaren en verandert de populatie. Zie `yearly_retention.csv` en `threshold_sensitivity.csv`.
- Binnenlands betekent: alle gestandaardiseerde trajecteindpunten staan op de expliciete Nederlandse lijst, en geen buitenlandse naam is gevonden in de locatievelden. Een gemengd binnenlands/internationaal record gaat volledig eruit. Dit is een bewuste, conservatieve afbakening; het bewijst niet dat de feitelijke storing over de grens lag.
- Ontbrekende of onbekende gestandaardiseerde trajecten worden apart gezet: de vrije NS-tekst is niet betrouwbaar genoeg om automatisch binnenlandse eindpunten te garanderen. Onbekende toekomstige eindpunten worden nooit automatisch Nederlands.
- Testberichten worden expliciet herkend. Reisplannerproblemen, informatieberichten en toelichtingen worden apart gezet; die kunnen anders dubbel tellen naast een oorspronkelijke storing. De exacte patronen staan in het script. Niet-herkenbare testberichten zijn zonder verdere broninformatie niet gegarandeerd detecteerbaar.
- Ontbrekende station- en oorzaakgegevens blijven NA, met indicatoren. Er worden geen stations of oorzaken verzonnen. Alleen een ontbrekende cause_group krijgt unknown. Alle rijen met NA verwijderen zou onnodig historische data weggooien.
- Lokale brontijden worden geïnterpreteerd als Europe/Amsterdam. Niet-bestaande en dubbelzinnige zomertijd/wintertijdmomenten gaan ter controle apart. Outputtijdstippen staan in UTC; maand, weekdag (maandag=1) en uur blijven lokaal.
- Target: duration_minutes > 60. De oorspronkelijke statistische oorzaak blijft voor inspectie aanwezig, maar hoort niet in modelpredictoren. Ook eindtijd en alle duurvelden zijn geen predictoren. De laatste oorzaak kan eveneens informatie van na de start bevatten.
- Geen automatische verwijdering van echte storingsgroepen zoals werkzaamheden, stakingen of onbekende oorzaken. Geen IQR-filter: dat zou juist lange storingen uit de te voorspellen klasse verwijderen.

## Uitvoeren

```sh
Rscript "Data Cleaning/clean_disruptions.R"
```

Alleen base R nodig. Grenzen en lijsten staan bovenaan/in het script. Het script controleert totalen, IDs, filters, target en de opgeslagen CSV. Outputs en data/disruptions_2011_2025_clean.csv worden bij opnieuw uitvoeren vervangen; de raw-bron niet.

Brondefinities en beperkingen: https://www.rijdendetreinen.nl/open-data/treinstoringen
Bronvermelding dataset: Rijden de Treinen, CC BY 4.0. Opschoonscript opgesteld met AI-assistentie.
