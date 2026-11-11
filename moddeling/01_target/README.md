# 01_target

Eigenaar: Mart, review Oliver

## Doel

Definieer de 10-minutenklassen uitsluitend op trainingsdata.

## Status

Targetdefinitie uitgevoerd; nog geen modellen getraind.

## Input

Beschrijf gebruikte bestanden, dataset-/commitversie en benodigde eerdere stappen. De datasets staan in ../../data/.

## Wat is uitgevoerd?

De klassegrens is gekozen door de restklasse te vergelijken met het gemiddelde aantal trainingsrijen per voorgaand 10-minutenvak. Zie define_duration_classes.R en output/.

## Resultaten en output

33.004 trainingsrijen; 101 gewone tijdvakken plus een restklasse. Restklasse: 322; gemiddelde gewone klasse: 323,58; minimum: 4.

## Impact op het project

102 klassen; restklasse vanaf 1010 minuten met 322 trainingsrijen. Zeldzame klassen vragen extra aandacht.

## Controles en beperkingen

De grens is uitsluitend gekozen op 2011–2023. Klassegrenzen en rijtotalen zijn gecontroleerd. De klassen zijn onderling niet even groot.

## Volgende stap en overdracht

Noteer wat de volgende stap gebruikt, wie verdergaat en welke besluiten nog openstaan.

## Wijzigingslog

- Structuur aangemaakt; geen modelprestaties geclaimd.
