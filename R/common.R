# R/common.R ------------------------------------------------------------------
# Shared helpers, sourced at the top of every page:
#
#   source("R/common.R")
#
# Everything factual (names, authorities, families, sites, collection records,
# references) lives in data/*.csv and references.bib. The functions here turn
# those into the repetitive parts of each page so the .qmd files only hold the
# writing (diagnosis, figure captions, notes).
# -----------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
})

knitr::opts_chunk$set(echo = FALSE, message = FALSE, warning = FALSE,
                      fig.align = "center", dev = "png", dpi = 200)

# ---- Locating the project ----------------------------------------------------

#' Walk up from the working directory until we find _quarto.yml, so the helpers
#' work whether a page is rendered from the project root or its own folder.
find_root <- function(path = getwd()) {
  path <- normalizePath(path)
  while (!file.exists(file.path(path, "_quarto.yml"))) {
    parent <- dirname(path)
    if (parent == path) stop("Could not find _quarto.yml above ", getwd())
    path <- parent
  }
  path
}
ROOT <- find_root()
root_path <- function(...) file.path(ROOT, ...)

# ---- Reading the data -------------------------------------------------------

read_chr_csv <- function(file) {
  readr::read_csv(root_path("data", file),
                  col_types = readr::cols(.default = readr::col_character()),
                  na = c("", "NA"), progress = FALSE)
}

load_species <- function() {
  read_chr_csv("species.csv") |>
    mutate(across(everything(), trimws),
           in_book = toupper(coalesce(in_book, "FALSE")) == "TRUE",
           display_name = coalesce(display_name, paste(genus, species)))
}

load_sites <- function() {
  read_chr_csv("sites.csv") |>
    mutate(lat = as.numeric(lat), lon = as.numeric(lon))
}

load_observations <- function() {
  read_chr_csv("observations.csv") |>
    mutate(date = as.Date(date),
           temp_c = suppressWarnings(as.numeric(temp_c)),
           salinity = suppressWarnings(as.numeric(salinity)),
           depth_m = suppressWarnings(as.numeric(depth_m)))
}

SPECIES <- load_species()
SITES <- load_sites()
OBS <- load_observations()

# ---- Small utilities ---------------------------------------------------------

is_html <- function() knitr::is_html_output()

#' Split a ";"-separated cell into a clean character vector.
split_field <- function(x) {
  if (is.null(x) || length(x) == 0 || is.na(x)) return(character())
  out <- trimws(strsplit(x, ";", fixed = TRUE)[[1]])
  out[nzchar(out)]
}

has <- function(x) length(x) > 0 && !is.na(x) && nzchar(x)

#' Cross-reference id used for a species chapter, e.g. "sec-acartia-tonsa".
sec_id <- function(slug) paste0("sec-", gsub("_", "-", slug))

#' Italicised species name in markdown.
italic_name <- function(sp) paste0("*", sp$display_name, "*")

#' Markdown reference to a species: a cross-reference if it has a chapter,
#' otherwise just the italicised name.
species_ref <- function(slug) {
  sp <- SPECIES[SPECIES$slug == slug, ]
  if (nrow(sp) == 0) return(paste0("*", gsub("_", " ", slug), "*"))
  if (sp$in_book) paste0("[", italic_name(sp), "](#", sec_id(slug), ")")
  else italic_name(sp)
}

#' Turn "key1; key2" into "@key1; @key2" (narrative citations).
cite_md <- function(keys) {
  keys <- split_field(keys)
  if (!length(keys)) return(NULL)
  paste0("@", keys, collapse = "; ")
}

#' Turn "Label <url>; Label2 <url2>" into markdown links.
links_md <- function(x) {
  items <- split_field(x)
  if (!length(items)) return(NULL)
  vapply(items, function(it) {
    m <- regmatches(it, regexec("^(.*?)\\s*<(.+)>$", it))[[1]]
    if (length(m) == 3) sprintf("[%s](%s)", m[2], m[3]) else sprintf("<%s>", it)
  }, character(1), USE.NAMES = FALSE)
}

worms_url <- function(aphia_id) {
  sprintf("https://www.marinespecies.org/aphia.php?p=taxdetails&id=%s", aphia_id)
}

# ---- Species pages -----------------------------------------------------------

#' Look up one species row by slug (the file name without .qmd).
species_info <- function(slug) {
  sp <- SPECIES[SPECIES$slug == slug, ]
  if (nrow(sp) != 1) {
    stop("Species '", slug, "' not found (or duplicated) in data/species.csv")
  }
  as.list(sp)
}

#' Print the fact box at the top of a species page (use in an `output: asis`
#' chunk).
species_header <- function(sp) {
  line <- function(label, value) {
    if (is.null(value) || !length(value) || !has(value[1])) return(NULL)
    sprintf("**%s:** %s", label, paste(value, collapse = "; "))
  }

  links <- c(if (has(sp$aphia_id)) sprintf("[WoRMS](%s)", worms_url(sp$aphia_id)),
             links_md(sp$links))
  n_obs <- sum(OBS$slug == sp$slug)

  lines <- c(
    line("Authority", sp$authority),
    line("Classification", paste(sp$order, "›", sp$family)),
    line("Habitat", sp$habitat),
    if (has(sp$accepted_name))
      line("Currently accepted as", paste0("*", sp$accepted_name, "*")),
    line("Other names", sp$other_names),
    line("Original description", cite_md(sp$original_description)),
    line("Other useful sources", cite_md(sp$sources)),
    line("Regional record", cite_md(sp$record_source)),
    line("Links", links),
    sprintf("**Collection records in this book:** %d", n_obs)
  )

  status_note <- switch(
    coalesce(sp$status, ""),
    stub  = "This account is a placeholder; the description is still to be written.",
    draft = "This account is a working draft and may change.",
    NULL
  )

  cat("\n::: {.callout-note appearance=\"simple\" icon=\"false\"}\n")
  cat(paste(lines, collapse = " \\\n"), "\n")
  cat(":::\n\n")
  if (!is.null(status_note)) {
    cat("::: {.callout-warning appearance=\"minimal\"}\n", status_note, "\n:::\n\n")
  }
}

#' Observation records joined to site information.
species_observations <- function(slug) {
  OBS |>
    filter(.data$slug == !!slug) |>
    left_join(rename(SITES, site_notes = notes), by = "site_id") |>
    arrange(date)
}

#' Print a table of collection records (use in an `output: asis` chunk).
species_records <- function(sp) {
  obs <- species_observations(sp$slug)
  if (nrow(obs) == 0) {
    cat("*No collection records yet. Add rows to `data/observations.csv`.*\n\n")
    return(invisible(NULL))
  }
  tab <- obs |>
    transmute(Site = site_name, State = state,
              Coordinates = sprintf("%.4f, %.4f", lat, lon),
              Date = format(date, "%d %b %Y"),
              `Temp. (°C)` = temp_c, Salinity = salinity,
              `Depth (m)` = depth_m, Stages = life_stages, Notes = notes)
  # drop columns that are empty for every record
  tab <- tab[, vapply(tab, function(col) any(!is.na(col) & col != ""), logical(1)),
             drop = FALSE]
  print(knitr::kable(tab, format = "pipe", align = "l"))
  cat("\n\n")
}

#' Base map of New England for record maps.
new_england_map <- function() {
  states <- c("maine", "new hampshire", "vermont", "massachusetts",
              "rhode island", "connecticut", "new york")
  map_data <- ggplot2::map_data("state", region = states)
  ggplot() +
    geom_polygon(data = map_data, aes(long, lat, group = group),
                 fill = "grey94", colour = "grey60", linewidth = 0.25) +
    coord_quickmap(xlim = c(-73.8, -66.8), ylim = c(40.9, 47.5)) +
    theme_void(base_size = 10) +
    theme(legend.position = "bottom",
          panel.background = element_rect(fill = "#eaf2f8", colour = NA))
}

#' Map of the sites where a species was recorded (grey: other sampled sites).
#' Returns NULL (no figure) when there are no records.
species_map <- function(sp) {
  obs <- species_observations(sp$slug)
  if (nrow(obs) == 0) return(invisible(NULL))
  here <- distinct(obs, site_id, site_name, lon, lat)
  new_england_map() +
    geom_point(data = SITES, aes(lon, lat), colour = "grey55", size = 1.2) +
    geom_point(data = here, aes(lon, lat), shape = 21, size = 2.6,
               fill = "#c0392b", colour = "white", stroke = 0.6)
}

#' Records per month. Hidden until there are at least `min_records` records.
species_season <- function(sp, min_records = 3) {
  obs <- species_observations(sp$slug) |> filter(!is.na(date))
  if (nrow(obs) < min_records) return(invisible(NULL))
  obs |>
    mutate(month = factor(month.abb[as.integer(format(date, "%m"))],
                          levels = month.abb)) |>
    count(month, .drop = FALSE) |>
    ggplot(aes(month, n)) +
    geom_col(fill = "#2c6e8f", width = 0.7) +
    labs(x = NULL, y = "Records") +
    theme_minimal(base_size = 10) +
    theme(panel.grid.major.x = element_blank())
}

# ---- Part pages, checklist, comparisons -------------------------------------

#' Bullet list of all species in an order (from data/species.csv), grouped by
#' habitat. Species with an account link to it.
part_species_list <- function(order_name) {
  sp <- SPECIES |>
    filter(order == order_name) |>
    arrange(habitat, family, genus, species)
  if (nrow(sp) == 0) {
    cat("*No species of this order are listed yet.*\n")
    return(invisible(NULL))
  }
  for (h in unique(sp$habitat)) {
    cat("\n### ", tools::toTitleCase(coalesce(h, "Habitat not recorded")),
        " {.unnumbered .unlisted}\n\n", sep = "")
    sub <- sp[sp$habitat %in% h, ]
    for (i in seq_len(nrow(sub))) {
      cat("- ", species_ref(sub$slug[i]), " (", sub$family[i], ")",
          if (!sub$in_book[i]) " — no account yet", "\n", sep = "")
    }
  }
  cat("\n")
}

#' Full species checklist: searchable table in HTML, plain table in PDF.
checklist_table <- function(link_prefix = "../species/") {
  tab <- SPECIES |>
    arrange(order, family, genus, species) |>
    left_join(count(OBS, slug, name = "records"), by = "slug") |>
    mutate(records = coalesce(records, 0L))

  if (is_html()) {
    tab <- tab |>
      transmute(
        Species = ifelse(in_book,
                         sprintf('<a href="%s%s.html"><em>%s</em></a>',
                                 link_prefix, slug, display_name),
                         sprintf("<em>%s</em>", display_name)),
        Authority = authority, Order = order, Family = family,
        Habitat = habitat, Records = records,
        Account = ifelse(in_book, coalesce(status, "yes"), "—"))
    DT::datatable(tab, escape = FALSE, rownames = FALSE,
                  options = list(pageLength = 25, scrollX = TRUE),
                  class = "compact stripe")
  } else {
    out <- character()
    for (o in unique(tab$order)) {
      sub <- tab[tab$order == o, ] |>
        transmute(Species = vapply(slug, species_ref, character(1)),
                  Authority = coalesce(authority, ""), Family = family,
                  Habitat = habitat)
      out <- c(out, paste0("\n### ", o, " {.unnumbered .unlisted}\n"),
               knitr::kable(sub, format = "pipe", row.names = FALSE), "")
    }
    knitr::asis_output(paste(out, collapse = "\n"))
  }
}

#' Side-by-side fact table for a comparison page (use in an `output: asis`
#' chunk), e.g. compare_species(c("acartia_tonsa", "acartia_hudsonica")).
compare_species <- function(slugs) {
  sp <- SPECIES[match(slugs, SPECIES$slug), ]
  if (anyNA(sp$slug)) stop("Unknown slug(s): ", paste(slugs[is.na(sp$slug)], collapse = ", "))
  n_obs <- vapply(slugs, function(s) sum(OBS$slug == s), integer(1))
  rows <- list(
    "Species"   = vapply(slugs, species_ref, character(1)),
    "Authority" = coalesce(sp$authority, ""),
    "Family"    = sp$family,
    "Habitat"   = sp$habitat,
    "Records"   = as.character(n_obs)
  )
  tab <- as.data.frame(do.call(rbind, rows), stringsAsFactors = FALSE)
  names(tab) <- paste0("Species ", seq_along(slugs))
  tab <- cbind(` ` = names(rows), tab)
  print(knitr::kable(tab[-1, ], format = "pipe", row.names = FALSE,
                     col.names = c(" ", rows$Species)))
  cat("\n\n")
}

#' Map of every sampled site (for the appendix).
sites_map <- function() {
  n <- count(OBS, site_id, name = "records")
  s <- left_join(SITES, n, by = "site_id") |> mutate(records = coalesce(records, 0L))
  new_england_map() +
    geom_point(data = s, aes(lon, lat, size = records), shape = 21,
               fill = "#2c6e8f", colour = "white", stroke = 0.5) +
    scale_size_area(max_size = 5, name = "Records")
}

sites_table <- function() {
  n <- count(OBS, site_id, name = "Records")
  s <- left_join(SITES, n, by = "site_id") |>
    mutate(Records = coalesce(Records, 0L)) |>
    arrange(state, site_name) |>
    transmute(Site = site_name, State = state, Waterbody = waterbody,
              Latitude = round(lat, 4), Longitude = round(lon, 4), Records)
  print(knitr::kable(s, format = "pipe"))
  cat("\n\n")
}
