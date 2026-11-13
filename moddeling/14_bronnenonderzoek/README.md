# Stap 14 — Publieke bronnen voor aanvullende voorspellers

Onderzocht op 13 november 2026. Eigenaar: Oliver. Status: bronnenonderzoek,
geen datakoppeling of nieuwe modeltraining. De bestaande finale test blijft behouden;
2025 is al gezien en wordt geen nieuwe onafhankelijke test voor een verrijkt model.

## Conclusie en prioriteit

Er zijn publieke bronnen voor historische storingsberichten en weer. Het meest
inhoudelijk interessante spoor is de **eerste storingsmelding met impact en
verwachte hersteltijd**. Het meest direct gedocumenteerde aanvullende meetbestand
is KNMI-uurweer. Beschikbaarheid betekent nog geen bewezen voorspelwinst.

| Bron | Gevonden beschikbaarheid | Koppeling | Belangrijkste onzekerheid |
|---|---|---|---|
| Rijden de Treinen storingspagina's | Tijdgestempelde berichten, impact en soms herstelschatting; voorbeelden uit 2015 en 2023 | ID in URL is dezelfde `rdt_id` | Geen geverifieerde bulkdownload van updates; volledigheid per jaar onbekend; directe requests gaven 403 |
| Fwrite samengesteld NDOV-archief | Downloadindex voor InfoPlusPIL, InfoPlusVTBL en andere berichttypen | Bronmelding-ID, tijd, stations/traject; brug naar RDT-ID nodig | Index en drie berichten uit één dagbestand gecontroleerd; koppeling/dekking nog niet |
| KNMI-uurgegevens | Historische meetbestanden per station, inclusief perioden 2011–2020 en 2021–2030 | Storingstijd + locatie naar weerstation | Latere kwaliteitscorrecties/publicatievertraging; niet elk station heeft elke variabele |
| Rijden de Treinen stations | Stationcode, coördinaten, type en gedateerde snapshots | `rdt_station_codes` → `code` | Historische veranderingen, ontbrekende codes en achteraf bijgewerkte storingslocatie |
| Rijden de Treinen treinarchief | CSV.gz met stops, vertragingen en uitval sinds 2019 | Station en tijdvenster; rit-ID is GEEN storing-ID | Eindtoestand per rit is geen reconstructie van bij aanvang bekende impact |
| NS API / NDOV live | Storings-/werkzaamhedeninformatie en actuele berichten | Operationele bron-ID's | Live beschikbaarheid bewijst geen compleet historisch archief |
| ProRail werkzaamhedenlijst | Openbare lijst grote geplande buitendienststellingen | Traject + geplande periode | Geen complete historisch geversioneerde CSV voor alle jaren bevestigd |

## 1. Oorspronkelijke meldingen en impact

Datasetdocumentatie maakt expliciet dat `cause_nl` in de jaarlijkse CSV de laatst
gebruikte oorzaak is. De individuele pagina kan eerdere meldingen bevatten.
Bijvoorbeeld ID 12345 toont een bericht op 28 oktober 2015 om 13:30 met impact
(minder treinen) en een prognose, gevolgd door latere updates. De site waarschuwt
bij dit oude archief dat er minder informatie beschikbaar is.

Een zoekresultaat voor ID 50489 (10 november 2023) toont een eerste melding om
18:38 met logistieke beperkingen, geen treinen en een prognose tot 19:45. De
paginatitel noemt juist een eerdere verstoring. Dit illustreert waarom de eerste
berichtinhoud nuttiger kan zijn dan de uiteindelijke oorzaak; het bewijst nog
niet dat alle records volledig zijn. ID 49166 bevat eveneens tijdgestempelde
meldingen en veranderende impact in 2023.

Bronnen:
- https://www.rijdendetreinen.nl/open-data/treinstoringen
- https://www.rijdendetreinen.nl/storingen/12345
- https://www.rijdendetreinen.nl/storingen/50489-10-november-2023-eerdere-verstoring-rotterdam-centraal
- https://www.rijdendetreinen.nl/storingen/49166-23-augustus-2023-stroomstoring-den-haag-rotterdam-leiden-rotterdam

Toegang gecontroleerd via webzoekresultaten en een geopende oude archiefpagina.
Enkele andere pagina's konden niet door de webtool worden geopend. Twee directe
HTTP-verzoeken naar ID 46000 en 51320 kregen 403. Geen blokkade omzeild en geen
massascrape gestart. De open-data-CSV-licentie is geen automatische bevestiging
van een bulk-exportrecht/licentie voor alle webpaginaberichten.

## 2. Ruwe historische berichten als download

https://trein.fwrite.org/ is een publiek onofficieel archief met een samengesteld,
gededupliceerd archief van Adriaan van Natijne en Simon Pellegrom. De documentatie
beschrijft vier kolommen: tijd, station, bericht en hash, gesplitst per type en
chronologisch gesorteerd. De collectie heeft CC BY 4.0; de bronberichten hebben
hun eigen voorwaarden. Het archief garandeert geen volledige of juiste inhoud.

De hoofdpagina bevat jaarindexen 2011–2026 en onder meer deze relevante typen:
- https://trein.fwrite.org/idx/dedup_InfoPlusPIL.html — gestructureerde landelijke verstoringsberichten.
- https://trein.fwrite.org/idx/dedup_InfoPlusVTBL.html — landelijke vrije tekst.

De PIL-index kon rechtstreeks worden geopend. De gecontroleerde downloadlinks lopen
van augustus 2016 tot begin oktober 2024; er staan dagbestanden voor 2023 tussen.
De totale hoofdpagina bevat ook andere typen/jaren: dat is geen bewijs van PIL-
bestanden voor heel 2025 of 2026. Een datum 2026 in de HTML kan metadata zijn en
mag niet als bestandsdekking worden geteld.

Concreet dagbestand: https://trein.fwrite.org/dedup/2023-11/InfoPlusPIL_2023-11-10.csv.xz .

Het dagbestand van 10 november 2023 is daadwerkelijk opgehaald (34.120 bytes
gecomprimeerd). De eerste drie rijen zijn geparseerd: vier CSV-kolommen, een
UTC-ontvangsttijd en een XML-bericht. Daarin zijn onder meer `DossierNummer`,
`DossierVolgNummer`, `RegistratieTijd`, `VrijgaveTijd`, `OorzaakKort`,
`GevolgenTreindienst`, `VerstoringImpact`, `StationCode`, `VerstoringFase` en
`Prognose` aangetroffen. Dit bevestigt concrete bruikbare structuur, nog niet dat
elk veld altijd gevuld is of dat de eerste drie berichten initiële meldingen zijn.
De sample is in geheugen bekeken; geen bulkbestanden of nieuwe dataset opgeslagen.

Dat is geen bewijs dat ieder bestand of iedere datum volledig is. Jaarindexen voor alle
berichttypen samen bewijzen geen PIL-dekking vanaf 2011. Dit moet per type/datum
worden gecontroleerd voordat een trainingsperiode wordt gekozen.

Het PPV-schema beschrijft geplande en ongeplande verstoringen. Daarmee is dezelfde
bron ook kandidaat voor historisch bekende werkzaamheden, maar die dekking is nog
niet inhoudelijk gevalideerd. Het bron-ID hoeft niet overeen te komen met `rdt_id`.

Documentatie:
- https://data.ndovloket.nl/docs/infoplus/VI/
- https://data.ndovloket.nl/docs/infoplus/VI/Publicatiedocument%20PPV%20Verstoringsinformatie%20NDOV_Push_v3.1%20def2.pdf
- https://data.ndovloket.nl/REALTIME.TXT — huidige feeds, geen bewijs van historische dekking.
- https://groups.google.com/g/openov/c/x65ZfDpzGs4/m/rfFyj3G3AgAJ — oorspronkelijke toelichting op het archief.

## 3. KNMI-weer en geografische koppeling

Historische uurwaarden zijn publiek als compacte ZIP/ASCII-bestanden beschikbaar.
De interactieve selectie beschrijft onder andere temperatuur, windsnelheid,
windstoten, neerslag, zicht en indicatoren voor mist, sneeuw en onweer.

- https://www.knmi.nl/nederland-nu/klimatologie/uurgegevens
- https://daggegevens.knmi.nl/klimatologie/uurgegevens
- https://www.rijdendetreinen.nl/open-data/stations

Voorgestelde koppeling: stationcode naar geografische locatie, vervolgens naar
nabijgelegen weerstation; gebruik alleen verstreken meetvensters. Bij een storing
om 10:35 mag de neerslagsom van 10:00–11:00 niet als bekende invoer worden gebruikt.
Dagtotalen bevatten doorgaans eveneens toekomstige informatie.

Het KNMI vermeldt dat deze archiefgegevens achteraf worden gecontroleerd en soms
gecorrigeerd/aangevuld. Vrijgave volgt meestal na één of enkele dagen, soms tot twee
weken later. Een uur vóór de storing betekent daarom niet automatisch dat precies
deze gevalideerde waarde toen al gepubliceerd was. Zonder originele publicatietijden
is dit een retrospectieve weerscontextstudie, geen bewezen realtime reconstructie.
Werk met een expliciete beschikbaarheidsaanname of een archief van operationele
metingen. Een willekeurige extra uur vertraging lost latere correcties niet op.

## 4. Aanvullende bronnen met beperkingen

Treinritten sinds 2019: https://www.rijdendetreinen.nl/open-data/treinarchief .
Hiermee is voorafgaande treinenloop mogelijk te onderzoeken, maar totale uitval
of maximale ritvertraging van ná het storingsbegin mag niet als startkenmerk dienen.
De gedocumenteerde CSV is geen volledig berichtenlog met publicatietijd per update.

NS open API: https://apiportal.ns.nl/ . Toegang via registratie en abonnement op
het betreffende product. Publieke informatie omvat dienstregeling, werkzaamheden
én stations. Een complete historische export van alle oorspronkelijke meldingen
heb ik op dit portaal niet kunnen bevestigen.

ProRail: https://www.prorail.nl/verhalen/investeringen-spoor-nu-nodig/lijst-met-werkzaamheden .
Deze lijst beschrijft grote buitendienststellingen langer dan drie dagen en vermeldt
dat planningen kunnen wijzigen. Niet behandelen als volledige historie van alle
werkzaamheden en wat daarvan op elk vroeger moment bekend was.

## 5. Aanbevolen volgende stap: haalbaarheidspilot, nog geen nieuw model

1. Controleer een kleine selectie PIL/VTBL-dagbestanden verspreid over de gewenste
   ontwikkeljaren, met beperkte downloads en lokale caching.
2. Reconstrueer de vroegste beschikbare melding per incident: ontvangst-/publicatietijd,
   oorspronkelijke oorzaak, impact, getroffen locaties en eventueel herstelprognose.
3. Koppel conservatief aan bestaande storingen; meet dekking, dubbelzinnige matches,
   ontbrekende initiële berichten en tijdsverschillen. Geen match is niet ‘geen impact’.
4. Definieer het voorspelmoment: feitelijk begin versus eerste publieke melding.
   Later gepubliceerde informatie mag niet terug worden gedateerd naar het begin.
5. Behandel de eerste NS-herstelprognose als eigen baseline. Vergelijk kenmerken
   zonder prognose en met prognose apart; anders lijkt het model mogelijk slim
   doordat het een al bestaande menselijke voorspelling hergebruikt.
6. Alleen bij voldoende dekking een verrijkte onderzoeksdataset bouwen. Bestaande
   clean CSV en bevroren test niet overschrijven. Gebruik gelijke rijen bij ablaties.
7. KNMI is het praktische alternatief of een tweede afzonderlijke uitbreiding.
   Nieuwe onafhankelijke eindtoetsing vereist een nog niet gebruikte periode;
   2026-beschikbaarheid en volledigheid moeten eerst worden vastgesteld.

## Status en impact

Er zijn bronnen gevonden, maar nog geen nieuwe kenmerken of modelwinsten gemeten.
Geen bulkdata gedownload, geen accounts aangemaakt, geen leveranciers benaderd,
geen commits/pushes uitgevoerd. Bronnenonderzoek is met AI-assistentie uitgevoerd.
