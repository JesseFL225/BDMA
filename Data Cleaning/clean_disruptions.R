# Reproducible, conservative domestic-disruption selection (base R only).
# Run from the repository root: Rscript "Data Cleaning/clean_disruptions.R"
# Raw input is NEVER overwritten. The clean CSV in data/ is regenerated. All exclusions are logged.
# An exclusion is not necessarily an error: scope and uncertainty are separate.

MAX_DURATION_MINUTES <- 1440 # Analysis scope: at most 24 hours; not proof of error.
MAX_DIFFERENCE_MINUTES <- 1 # Allows rounding to whole minutes.
TIMEZONE <- "Europe/Amsterdam"
INPUT <- "data/disruptions_2011_2025_raw.csv"
OUTPUT <- "Data Cleaning/output"
CLEAN_OUTPUT <- "data/disruptions_2011_2025_clean.csv"

stopifnot(file.exists(INPUT))
dir.create(OUTPUT, recursive = TRUE, showWarnings = FALSE)
raw <- read.csv(INPUT, colClasses = "character", na.strings = c("", "NA"),
                check.names = FALSE, fileEncoding = "UTF-8")
expected <- c("rdt_id", "ns_lines", "rdt_lines", "rdt_lines_id",
 "rdt_station_names", "rdt_station_codes", "cause_nl", "cause_en",
 "statistical_cause_nl", "statistical_cause_en", "cause_group",
 "start_time", "end_time", "duration_minutes", "source_year")
stopifnot(identical(names(raw), expected), nrow(raw) > 0)
x <- raw
for (nm in names(x)) {
  x[[nm]] <- trimws(gsub("[[:space:]]+", " ", x[[nm]]))
  x[[nm]][!is.na(x[[nm]]) & tolower(x[[nm]]) %in% c("", "na", "nan", "null", "n/a")] <- NA
}
n <- nrow(x)
safe <- function(v) ifelse(is.na(v), "", v)
split_list <- function(v) lapply(safe(v), function(s) {
  if (!nzchar(s)) character() else trimws(strsplit(s, ",", fixed = TRUE)[[1]])
})

# Explicit endpoint allowlist: unknown future endpoints are quarantined, never
# silently assumed to be Dutch. Bad Nieuweschans and Oldenzaal ARE Dutch.
nl_endpoints <- c("'s-Hertogenbosch", "Alkmaar", "Almelo", "Almere Oostvaarders",
 "Alphen a/d Rijn", "Amersfoort", "Amsterdam Centraal", "Apeldoorn", "Arnhem Centraal",
 "Baarn", "Bad Nieuweschans", "Breda", "Breda (HSL)", "Delfzijl", "Den Haag Centraal",
 "Den Haag HS", "Den Helder", "Deventer", "Dordrecht", "Ede-Wageningen", "Eemshaven",
 "Eindhoven", "Emmen", "Enkhuizen", "Enschede", "Geldermalsen", "Gouda", "Groningen",
 "Haarlem", "Harlingen Haven", "Heerlen", "Hengelo", "Hilversum", "Hoek van Holland Strand",
 "Hoorn", "Kampen", "Kerkrade Centrum", "Leeuwarden", "Leiden Centraal", "Lelystad Centrum",
 "Maastricht", "Maastricht Randwyck", "Mariënberg", "Nijmegen", "Oldenzaal", "Rhenen",
 "Roermond", "Roosendaal", "Rotterdam Centraal", "Rotterdam Centraal (HSL)",
 "Schiphol Airport", "Schiphol Airport (HSL)", "Sittard", "Stavoren", "Tiel", "Tilburg",
 "Uitgeest", "Utrecht Centraal", "Utrecht Maliebaan", "Veendam", "Venlo", "Vlissingen",
 "Winterswijk", "Woerden", "Zaandam", "Zandvoort aan Zee", "Zutphen", "Zwolle")
foreign_endpoints <- c("Aachen Hbf", "Antwerpen-Centraal", "Basel SBB", "Berlin Ostbahnhof",
 "Bielefeld Hbf", "Brussel-Zuid/Midi", "Brussels Airport-Zaventem", "Dortmund Hbf",
 "Düsseldorf Hbf", "Frankfurt (M) Hbf", "Gronau (Westf.)", "Hamm (Westf.)", "Innsbruck Hbf",
 "Leer (Ostfriesland)", "Liège-Guillemins", "Münster (Westf.) Hbf", "Paris-Nord",
 "Wien Hbf", "Zürich HB")
route_lists <- split_list(x$rdt_lines)
endpoints <- lapply(route_lists, function(routes) unlist(strsplit(routes, " - ", fixed = TRUE)))
all_endpoints <- sort(unique(unlist(endpoints)))
endpoint_audit <- data.frame(endpoint = all_endpoints,
 classification = ifelse(all_endpoints %in% nl_endpoints, "NL",
                  ifelse(all_endpoints %in% foreign_endpoints, "foreign", "unresolved")))
foreign_pattern <- paste0("(?i)(?<![[:alpha:]])(", paste(c(
 "Aachen", "Antwerpen", "Antwerp", "Basel", "Berlin", "Berlijn", "Bielefeld",
 "Brussel", "Brussels", "Bruxelles", "Zaventem", "Dortmund", "Düsseldorf", "Dusseldorf",
 "Frankfurt", "Gronau", "Hamm", "Innsbruck", "Leer", "Liège", "Liege", "Luik",
 "Münster", "Munster", "Paris", "Parijs", "Wien", "Vienna", "Wenen", "Zürich", "Zurich",
 "London", "Londen", "St\\.? Pancras", "Ebbsfleet", "Ashford", "Calais", "Lille",
 "Köln", "Koln", "Keulen", "Hannover", "Bad Bentheim", "Emmerich", "Mönchengladbach",
 "Monchengladbach", "Kaldenkirchen", "Herzogenrath", "Hasselt", "Puurs", "Essen",
 "Duisburg", "Oberhausen", "Duitsland", "België", "Belgie", "Engeland", "Frankrijk",
 "Germany", "Belgium", "England", "France", "Oostenrijk", "Zwitserland"), collapse = "|"),
 ")(?![[:alpha:]])")
geo_text <- paste(safe(x$ns_lines), safe(x$rdt_lines), safe(x$rdt_station_names))
foreign <- vapply(endpoints, function(e) any(e %in% foreign_endpoints), logical(1)) |
           grepl(foreign_pattern, geo_text, perl = TRUE)
geo_evidence <- vapply(seq_len(n), function(i) {
  m <- regmatches(geo_text[i], gregexpr(foreign_pattern, geo_text[i], perl = TRUE))[[1]]
  paste(unique(c(intersect(endpoints[[i]], foreign_endpoints), m)), collapse = "; ")
}, character(1))
unresolved_route <- vapply(seq_len(n), function(i) {
  routes <- route_lists[[i]]
  !length(routes) || any(lengths(strsplit(routes, " - ", fixed = TRUE)) != 2) ||
    any(!endpoints[[i]] %in% c(nl_endpoints, foreign_endpoints)) ||
    is.na(x$rdt_lines_id[i]) || length(routes) != length(split_list(x$rdt_lines_id[i])[[1]])
}, logical(1))

# Explicit test and information-only patterns, not generic words like "werkzaamheden".
text <- apply(x[, c("ns_lines", "rdt_lines", "cause_nl", "cause_en",
                   "statistical_cause_nl", "statistical_cause_en")], 1, paste, collapse = " ")
test_message <- grepl("(?i)\\b(testbericht(en)?|testmelding(en)?|test message(s)?|dummy|proefbericht)\\b", text, perl = TRUE)
information_message <- grepl(paste(c("reisplanner", "reisinformatie", "vertrektijd",
 "meer info", "extra info", "aanvullende info", "extra uitleg", "toelichting",
 "app en site", "storingen-informatie", "tijdelijk geen actuele informatie"), collapse = "|"),
 safe(x$ns_lines), ignore.case = TRUE)

# Detect ambiguous/nonexistent local times rather than silently picking a DST fold.
parse_time <- function(v) as.POSIXct(v, format = "%Y-%m-%d %H:%M:%S", tz = TIMEZONE)
start <- parse_time(x$start_time)
end <- parse_time(x$end_time)
bad_time <- function(v, t) {
  rendered <- format(t, "%Y-%m-%d %H:%M:%S", tz = TIMEZONE)
  ambiguous <- safe(format(t - 3600, "%Y-%m-%d %H:%M:%S", tz = TIMEZONE)) == safe(v) |
               safe(format(t + 3600, "%Y-%m-%d %H:%M:%S", tz = TIMEZONE)) == safe(v)
  is.na(v) | is.na(t) | safe(rendered) != safe(v) | ambiguous
}
duration <- suppressWarnings(as.numeric(x$duration_minutes))
elapsed <- as.numeric(difftime(end, start, units = "mins"))
difference <- duration - elapsed
year <- suppressWarnings(as.integer(x$source_year))
start_year <- as.integer(format(start, "%Y", tz = TIMEZONE))
id_bad <- is.na(x$rdt_id) | !grepl("^[1-9][0-9]*$", safe(x$rdt_id))
exact_duplicate <- duplicated(x)
# Conflicting duplicate IDs are all quarantined; exact duplicate copies keep first.
unique_records <- !exact_duplicate & !id_bad
conflict_ids <- names(which(table(x$rdt_id[unique_records]) > 1))

flags <- data.frame(
 exact_duplicate = exact_duplicate,
 invalid_or_conflicting_id = id_bad | x$rdt_id %in% conflict_ids,
 test_message = test_message,
 information_message = information_message,
 international_route = foreign,
 unresolved_route = unresolved_route,
 invalid_or_ambiguous_time = bad_time(x$start_time, start) | bad_time(x$end_time, end),
 invalid_duration = !is.finite(duration) | duration <= 0,
 end_not_after_start = is.finite(elapsed) & elapsed <= 0,
 invalid_source_year = is.na(year) | is.na(start_year) | year != start_year | year < 2011 | year > 2025,
 duration_over_limit = (is.finite(duration) & duration > MAX_DURATION_MINUTES) |
                       (is.finite(elapsed) & elapsed > MAX_DURATION_MINUTES),
 duration_mismatch = is.finite(difference) & abs(difference) > MAX_DIFFERENCE_MINUTES
)
flags[is.na(flags)] <- TRUE # Fail closed for unresolved validity checks.
labels <- c("Exact dubbele rijen", "Ongeldige of conflicterende IDs", "Testberichten",
 "Informatie- en vervolgberichten", "Buitenlands traject of station",
 "Traject niet betrouwbaar te classificeren", "Ontbrekende/ongeldige/ambigue tijd",
 "Ontbrekende, niet-eindige of niet-positieve duur", "Einde niet na begin",
 "Ongeldig of inconsistent bronjaar", "Opgegeven of berekende duur boven 24 uur",
 "Duurverschil groter dan 1 minuut")
active <- rep(TRUE, n)
first_reason <- rep(NA_character_, n)
audit <- data.frame()
for (j in seq_along(flags)) {
  remove <- active & flags[[j]]
  audit <- rbind(audit, data.frame(step = j, rule = names(flags)[j], description = labels[j],
    input_rows = sum(active), matching_all_raw = sum(flags[[j]]),
    removed_this_step = sum(remove), remaining_rows = sum(active) - sum(remove)))
  first_reason[remove] <- names(flags)[j]
  active[remove] <- FALSE
}
all_reasons <- apply(flags, 1, function(v) paste(names(flags)[v], collapse = ";"))

clean <- x[active, ]
clean$duration_minutes <- duration[active]
clean$source_year <- year[active]
clean$start_time <- format(start[active], "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
clean$end_time <- format(end[active], "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
clean$calculated_minutes <- elapsed[active]
clean$difference_minutes <- difference[active]
clean$start_year <- start_year[active]
clean$start_month <- as.integer(format(start[active], "%m", tz = TIMEZONE))
clean$start_weekday <- as.integer(format(start[active], "%u", tz = TIMEZONE))
clean$start_hour <- as.integer(format(start[active], "%H", tz = TIMEZONE))
clean$long_disruption <- as.integer(duration[active] > 60)
# Preserve missingness; these indicators are not a mandatory model feature set.
clean$stations_missing <- is.na(clean$rdt_station_codes)
clean$cause_missing <- is.na(clean$cause_nl)
clean$cause_group[is.na(clean$cause_group)] <- "unknown"
excluded <- cbind(raw[!active, ], source_csv_row = which(!active) + 1L,
 first_exclusion_reason = first_reason[!active], all_exclusion_reasons = all_reasons[!active],
 foreign_evidence = geo_evidence[!active], calculated_minutes = elapsed[!active],
 difference_minutes = difference[!active])
counts <- function(mask) as.integer(table(factor(year[mask], levels = 2011:2025)))
yearly <- data.frame(year = 2011:2025, raw_rows = counts(rep(TRUE, n)), clean_rows = counts(active))
yearly$removed_rows <- yearly$raw_rows - yearly$clean_rows
yearly$retained_pct <- round(100 * yearly$clean_rows / yearly$raw_rows, 2)
missingness <- data.frame(column = names(clean), missing = vapply(clean, function(v) sum(is.na(v)), integer(1)))
non_duration_rules <- setdiff(names(flags), c("duration_over_limit", "duration_mismatch"))
otherwise_eligible <- rowSums(flags[, non_duration_rules]) == 0
sensitivity <- expand.grid(max_duration_minutes = c(1440, 10080), max_difference_minutes = c(1, 5, 60))
sensitivity$retained_rows <- vapply(seq_len(nrow(sensitivity)), function(i) sum(
 otherwise_eligible & is.finite(difference) & abs(difference) <= sensitivity$max_difference_minutes[i] &
 duration <= sensitivity$max_duration_minutes[i] & elapsed <= sensitivity$max_duration_minutes[i], na.rm = TRUE), integer(1))

# Invariants verify the actual selection and preservation of input records.
stopifnot(nrow(clean) + nrow(excluded) == n, !anyDuplicated(clean$rdt_id),
 sum(audit$removed_this_step) == nrow(excluded), !any(rowSums(flags[active, ]) > 0),
 all(clean$duration_minutes > 0 & clean$duration_minutes <= MAX_DURATION_MINUTES),
 all(abs(clean$difference_minutes) <= MAX_DIFFERENCE_MINUTES),
 all(clean$long_disruption == as.integer(clean$duration_minutes > 60)))
write <- function(object, name) write.csv(object, file.path(OUTPUT, name), row.names = FALSE,
                                          na = "NA", fileEncoding = "UTF-8")
write.csv(clean, CLEAN_OUTPUT, row.names = FALSE, na = "NA", fileEncoding = "UTF-8")
write(excluded, "excluded_disruptions.csv")
write(audit, "filter_audit.csv")
write(yearly, "yearly_retention.csv")
write(missingness, "remaining_missingness.csv")
write(endpoint_audit, "endpoint_classification.csv")
write(sensitivity, "threshold_sensitivity.csv")
saved <- read.csv(CLEAN_OUTPUT, colClasses = "character")
stopifnot(nrow(saved) == nrow(clean), identical(saved$rdt_id, clean$rdt_id))
report <- c("# Opschoning Nederlandse treinverstoringen", "",
 sprintf("Bron: `%s` (MD5: `%s`).", INPUT, unname(tools::md5sum(INPUT))),
 sprintf("Van **%s** raw-rijen naar **%s** geselecteerde storingen. **%s** rijen apart gezet.", n, nrow(clean), nrow(excluded)), "",
 "## Stappen en aantallen", "",
 "| Stap | Regel | Verwijderd in deze stap | Over |", "|---|---|---:|---:|",
 vapply(seq_len(nrow(audit)), function(i) sprintf("| %s | %s | %s | %s |", i,
 audit$description[i], audit$removed_this_step[i], audit$remaining_rows[i]), character(1)), "",
 "Een rij kan meerdere regels raken. De tabel telt iedere rij eenmaal, bij de eerste regel. `excluded_disruptions.csv` bewaart de originele waarden, CSV-rijnummer, eerste reden, alle redenen en gevonden buitenlandse namen.", "",
 "## Keuzes en beperkingen", "",
 "- Dit is een strenge, reproduceerbare analyseselectie, geen bewijs dat alle uitgesloten records onjuist zijn. De raw-data blijft behouden; de clean-CSV in data/ wordt opnieuw opgebouwd.",
 sprintf("- Maximumduur: %s minuten. Zowel de opgegeven als de berekende duur moet binnen de grens vallen. Langdurige brugschade, stakingen en weersproblemen kunnen echte incidenten zijn. Deze selectie voorspelt alleen binnen de geselecteerde duurpopulatie; bij aanvang weet je nog niet of een storing langer dan 24 uur duurt. Evalueer voor inzet ook op alle geldige duren.", MAX_DURATION_MINUTES),
 sprintf("- Een duurverschil groter dan %s minuut leidt tot uitsluiting, niet tot een verzonnen correctie. Dit verwijdert vooral vroege jaren en verandert de populatie. Zie `yearly_retention.csv` en `threshold_sensitivity.csv`.", MAX_DIFFERENCE_MINUTES),
 "- Binnenlands betekent: alle gestandaardiseerde trajecteindpunten staan op de expliciete Nederlandse lijst, en geen buitenlandse naam is gevonden in de locatievelden. Een gemengd binnenlands/internationaal record gaat volledig eruit. Dit is een bewuste, conservatieve afbakening; het bewijst niet dat de feitelijke storing over de grens lag.",
 "- Ontbrekende of onbekende gestandaardiseerde trajecten worden apart gezet: de vrije NS-tekst is niet betrouwbaar genoeg om automatisch binnenlandse eindpunten te garanderen. Onbekende toekomstige eindpunten worden nooit automatisch Nederlands.",
 "- Testberichten worden expliciet herkend. Reisplannerproblemen, informatieberichten en toelichtingen worden apart gezet; die kunnen anders dubbel tellen naast een oorspronkelijke storing. De exacte patronen staan in het script. Niet-herkenbare testberichten zijn zonder verdere broninformatie niet gegarandeerd detecteerbaar.",
 "- Ontbrekende station- en oorzaakgegevens blijven NA, met indicatoren. Er worden geen stations of oorzaken verzonnen. Alleen een ontbrekende cause_group krijgt unknown. Alle rijen met NA verwijderen zou onnodig historische data weggooien.",
 "- Lokale brontijden worden geïnterpreteerd als Europe/Amsterdam. Niet-bestaande en dubbelzinnige zomertijd/wintertijdmomenten gaan ter controle apart. Outputtijdstippen staan in UTC; maand, weekdag (maandag=1) en uur blijven lokaal.",
 "- Target: duration_minutes > 60. De oorspronkelijke statistische oorzaak blijft voor inspectie aanwezig, maar hoort niet in modelpredictoren. Ook eindtijd en alle duurvelden zijn geen predictoren. De laatste oorzaak kan eveneens informatie van na de start bevatten.",
 "- Geen automatische verwijdering van echte storingsgroepen zoals werkzaamheden, stakingen of onbekende oorzaken. Geen IQR-filter: dat zou juist lange storingen uit de te voorspellen klasse verwijderen.", "",
 "## Uitvoeren", "", "```sh", "Rscript \"Data Cleaning/clean_disruptions.R\"", "```", "",
 "Alleen base R nodig. Grenzen en lijsten staan bovenaan/in het script. Het script controleert totalen, IDs, filters, target en de opgeslagen CSV. Outputs en data/disruptions_2011_2025_clean.csv worden bij opnieuw uitvoeren vervangen; de raw-bron niet.", "",
 "Brondefinities en beperkingen: https://www.rijdendetreinen.nl/open-data/treinstoringen",
 "Bronvermelding dataset: Rijden de Treinen, CC BY 4.0. Opschoonscript opgesteld met AI-assistentie.")
writeLines(report, file.path(OUTPUT, "cleaning_report.md"), useBytes = TRUE)
print(audit, row.names = FALSE)
cat("\nSaved", nrow(clean), "rows to", OUTPUT, "\n")
