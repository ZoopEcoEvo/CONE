# R/build_tools.R --------------------------------------------------------------
# Functions used by scripts/build.R and scripts/new_species.R. They:
#   * create a stub page for every species marked in_book = TRUE that has none
#   * create a part page for every order that has species in the book
#   * rewrite the generated chapter block in _quarto.yml
# -----------------------------------------------------------------------------

source(here::here("R", "common.R"))

# Orders appear as parts in this order; anything else follows alphabetically.
ORDER_LEVELS <- c("Calanoida", "Cyclopoida", "Harpacticoida",
                  "Siphonostomatoida", "Monstrilloida", "Misophrioida",
                  "Platycopioida", "Gelyelloida", "Mormonilloida")

ORDER_TITLES <- c(Calanoida = "Calanoid copepods",
                  Cyclopoida = "Cyclopoid copepods",
                  Harpacticoida = "Harpacticoid copepods",
                  Siphonostomatoida = "Siphonostomatoid copepods",
                  Monstrilloida = "Monstrilloid copepods")

fill_template <- function(template, values) {
  txt <- readLines(root_path(template), warn = FALSE, encoding = "UTF-8")
  for (k in names(values)) txt <- gsub(paste0("{{", k, "}}"), values[[k]], txt, fixed = TRUE)
  txt
}

#' Create species/<slug>.qmd from species/_template.qmd if it doesn't exist.
create_species_stub <- function(slug) {
  path <- root_path("species", paste0(slug, ".qmd"))
  if (file.exists(path)) return(invisible(FALSE))
  sp <- species_info(slug)
  txt <- fill_template("species/_template.qmd", list(
    NAME = sp$display_name, SLUG = slug, SEC_ID = sec_id(slug),
    SLUG_DASH = gsub("_", "-", slug)))
  writeLines(txt, path, useBytes = TRUE)
  dir.create(root_path("images", slug), showWarnings = FALSE, recursive = TRUE)
  message("  + created species/", slug, ".qmd")
  invisible(TRUE)
}

part_file <- function(order_name) file.path("parts", paste0(tolower(order_name), ".qmd"))

#' Create parts/<order>.qmd from parts/_template.qmd if it doesn't exist.
create_part_page <- function(order_name) {
  path <- root_path(part_file(order_name))
  if (file.exists(path)) return(invisible(FALSE))
  title <- if (order_name %in% names(ORDER_TITLES)) ORDER_TITLES[[order_name]] else order_name
  txt <- fill_template("parts/_template.qmd", list(
    TITLE = title, ORDER = order_name, ID = paste0("sec-part-", tolower(order_name))))
  writeLines(txt, path, useBytes = TRUE)
  message("  + created ", part_file(order_name))
  invisible(TRUE)
}

#' Species in the book, ordered order -> family -> genus -> species.
book_species <- function() {
  sp <- SPECIES[SPECIES$in_book, ]
  lv <- c(ORDER_LEVELS, sort(setdiff(unique(sp$order), ORDER_LEVELS)))
  sp[order(match(sp$order, lv), sp$family, sp$genus, sp$species), ]
}

comparison_files <- function() {
  f <- list.files(root_path("comparisons"), pattern = "\\.qmd$")
  file.path("comparisons", sort(f[!startsWith(f, "_")]))
}

#' The YAML lines for the generated part of the chapter list.
chapter_block <- function(indent = "    ") {
  sp <- book_species()
  out <- character()
  for (o in unique(sp$order)) {
    out <- c(out, paste0(indent, "- part: ", part_file(o)),
             paste0(indent, "  chapters:"),
             paste0(indent, "    - species/", sp$slug[sp$order == o], ".qmd"))
  }
  comps <- comparison_files()
  if (length(comps)) {
    out <- c(out, paste0(indent, "- part: parts/comparisons.qmd"),
             paste0(indent, "  chapters:"),
             paste0(indent, "    - ", comps))
  }
  out
}

BEGIN_MARK <- "# >>> BEGIN GENERATED CHAPTERS"
END_MARK   <- "# <<< END GENERATED CHAPTERS"

#' Replace the lines between the markers in _quarto.yml. Only writes the file
#' if something changed (so it doesn't trigger needless re-renders).
update_quarto_yml <- function() {
  path <- root_path("_quarto.yml")
  yml <- readLines(path, warn = FALSE, encoding = "UTF-8")
  b <- grep(BEGIN_MARK, yml, fixed = TRUE)
  e <- grep(END_MARK, yml, fixed = TRUE)
  if (length(b) != 1 || length(e) != 1 || e < b) {
    stop("_quarto.yml must contain one '", BEGIN_MARK, "' and one '", END_MARK, "' line")
  }
  indent <- sub("#.*$", "", yml[b])
  new <- c(yml[seq_len(b)], chapter_block(indent), yml[e:length(yml)])
  if (!identical(new, yml)) {
    writeLines(new, path, useBytes = TRUE)
    message("  ~ updated chapter list in _quarto.yml")
  }
  invisible(new)
}

#' Add a species to data/species.csv (or switch an existing row to in_book =
#' TRUE), then build its stub page.
add_species <- function(name, order = NA, family = NA, habitat = NA) {
  parts <- strsplit(trimws(name), "\\s+")[[1]]
  if (length(parts) != 2) stop("Give the name as 'Genus species'")
  slug <- tolower(paste(parts, collapse = "_"))
  path <- root_path("data", "species.csv")
  tab <- readr::read_csv(path, col_types = readr::cols(.default = "c"),
                         na = character(), progress = FALSE)
  if (slug %in% tab$slug) {
    tab$in_book[tab$slug == slug] <- "TRUE"
    if (!nzchar(tab$status[tab$slug == slug])) tab$status[tab$slug == slug] <- "stub"
    message("  ~ ", name, " already listed; set in_book = TRUE")
  } else {
    if (is.na(order)) stop("New species: please also give its order, e.g. Calanoida")
    row <- as.list(setNames(rep("", ncol(tab)), names(tab)))
    row[c("slug", "genus", "species", "order", "family", "habitat", "in_book", "status")] <-
      list(slug, parts[1], parts[2], order, ifelse(is.na(family), "", family),
           ifelse(is.na(habitat), "", habitat), "TRUE", "stub")
    tab <- rbind(tab, as.data.frame(row, check.names = FALSE))
    tab <- tab[order(tab$genus, tab$species), ]
    message("  + added ", name, " to data/species.csv")
  }
  readr::write_csv(tab, path, na = "")
  invisible(slug)
}

#' Everything scripts/build.R does.
build_book <- function() {
  # re-read data in case add_species() just changed it
  SPECIES <<- load_species(); SITES <<- load_sites(); OBS <<- load_observations()
  sp <- book_species()
  for (s in sp$slug) create_species_stub(s)
  for (o in unique(sp$order)) create_part_page(o)
  update_quarto_yml()
  source(root_path("R", "validate.R"))
  validate_book()
}
