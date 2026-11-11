# Run from project root: Rscript "Data Cleaning/test_clean_disruptions.R"
# Rebuilds outputs, then checks important geographic and clock edge cases.
source("Data Cleaning/clean_disruptions.R")

foreign_examples <- c("Amsterdam-London St Pancras", "Heerlen-Aachen Hbf",
 "Roosendaal-Antwerpen-C.", "Groningen-Leer (Ostfriesland)",
 "Maastricht-Liège-Guillemins", "Amsterdam-Parijs", "Arnhem-Köln Hbf",
 "Utrecht-Amsterdam; Amsterdam-Brussel", "Van en naar België")
domestic_examples <- c("Groningen-Bad Nieuweschans", "Hengelo-Oldenzaal",
 "Heerlen-Landgraaf", "Amsterdam-Haarlem", "Venlo-Roermond", "Zwijndrecht-Dordrecht")
stopifnot(all(grepl(foreign_pattern, foreign_examples, perl = TRUE)),
 !any(grepl(foreign_pattern, domestic_examples, perl = TRUE)),
 all(c("Bad Nieuweschans", "Oldenzaal", "Venlo") %in% nl_endpoints),
 !"London St Pancras" %in% nl_endpoints)

ambiguous <- "2024-10-27 02:30:00"
nonexistent <- "2024-03-31 02:30:00"
valid <- c("2024-03-31 01:30:00", "2024-03-31 03:30:00")
stopifnot(bad_time(ambiguous, parse_time(ambiguous)),
 bad_time(nonexistent, parse_time(nonexistent)),
 !any(bad_time(valid, parse_time(valid))),
 as.numeric(difftime(parse_time(valid[2]), parse_time(valid[1]), units = "mins")) == 60)

stopifnot("5672" %in% excluded$rdt_id, # Explicit test message.
 "5016" %in% excluded$rdt_id, # 64,927-minute event.
 "40522" %in% excluded$rdt_id, # Mixed German and Dutch routes.
 !any(c("5672", "5016", "40522") %in% clean$rdt_id),
 setequal(c(clean$rdt_id, excluded$rdt_id), raw$rdt_id),
 all(is.na(clean$rdt_station_codes[clean$stations_missing])),
 !any(endpoint_audit$classification == "unresolved"),
 all(vapply(endpoints[active], function(e) all(e %in% nl_endpoints), logical(1))))
cat("\nGeography, DST, known exclusions, missingness and row preservation checks passed.\n")
