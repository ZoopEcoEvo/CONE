# R/validate.R -----------------------------------------------------------------
# Consistency checks run before every build. Problems that would break the book
# (or silently drop content) are errors; everything else is a note.
# -----------------------------------------------------------------------------

bib_keys <- function(file = root_path("references.bib")) {
  bib <- readLines(file, warn = FALSE, encoding = "UTF-8")
  m <- regmatches(bib, regexpr("^\\s*@\\w+\\s*\\{\\s*([^,\\s]+)", bib, perl = TRUE))
  sub("^\\s*@\\w+\\s*\\{\\s*", "", m)
}

validate_book <- function(stop_on_error = TRUE) {
  errors <- character(); notes <- character()
  err  <- function(...) errors <<- c(errors, paste0(...))
  note <- function(...) notes  <<- c(notes, paste0(...))

  sp <- SPECIES; obs <- OBS; sites <- SITES
  keys <- bib_keys()

  # ---- species.csv ----
  need <- c("slug", "genus", "species", "order", "family", "habitat", "in_book")
  miss <- setdiff(need, names(sp))
  if (length(miss)) err("species.csv is missing column(s): ", paste(miss, collapse = ", "))

  dup <- unique(sp$slug[duplicated(sp$slug)])
  if (length(dup)) err("Duplicated slug(s) in species.csv: ", paste(dup, collapse = ", "))

  expect <- tolower(paste(sp$genus, sp$species, sep = "_"))
  bad <- sp$slug[sp$slug != expect]
  if (length(bad)) err("slug should be genus_species in lower case: ", paste(bad, collapse = ", "))

  inb <- sp[sp$in_book, ]
  nofam <- inb$slug[is.na(inb$order) | is.na(inb$family)]
  if (length(nofam)) err("Species in the book need an order and family: ", paste(nofam, collapse = ", "))

  for (col in intersect(c("original_description", "sources", "record_source"), names(sp))) {
    for (i in seq_len(nrow(sp))) {
      k <- split_field(sp[[col]][i])
      unknown <- setdiff(k, keys)
      if (length(unknown)) err("species.csv (", sp$slug[i], ", ", col, "): citation key(s) not in references.bib: ",
                               paste(unknown, collapse = ", "))
    }
  }

  noid <- sum(is.na(sp$aphia_id))
  if (noid) note(noid, " species have no WoRMS AphiaID yet (run scripts/update_taxonomy.R)")

  # ---- sites.csv / observations.csv ----
  dup <- unique(sites$site_id[duplicated(sites$site_id)])
  if (length(dup)) err("Duplicated site_id(s) in sites.csv: ", paste(dup, collapse = ", "))
  badc <- sites$site_id[is.na(sites$lat) | is.na(sites$lon) |
                        abs(sites$lat) > 90 | abs(sites$lon) > 180]
  if (length(badc)) err("Missing or impossible coordinates in sites.csv: ", paste(badc, collapse = ", "))

  unk <- setdiff(obs$slug, sp$slug)
  if (length(unk)) err("observations.csv uses slug(s) not in species.csv: ", paste(unk, collapse = ", "))
  unk <- setdiff(obs$site_id, sites$site_id)
  if (length(unk)) err("observations.csv uses site_id(s) not in sites.csv: ", paste(unk, collapse = ", "))
  raw_dates <- read_chr_csv("observations.csv")$date
  baddate <- which(!is.na(raw_dates) & is.na(obs$date))
  if (length(baddate)) err("observations.csv: dates must be YYYY-MM-DD (row(s) ",
                           paste(baddate + 1, collapse = ", "), ")")

  # ---- species pages ----
  pages <- list.files(root_path("species"), pattern = "\\.qmd$")
  pages <- pages[!startsWith(pages, "_")]
  orphan <- setdiff(sub("\\.qmd$", "", pages), inb$slug)
  if (length(orphan)) note("Page(s) not in the book because in_book is not TRUE: ",
                           paste0("species/", orphan, ".qmd", collapse = ", "))

  # ---- every .qmd: images and citations ----
  qmds <- list.files(ROOT, pattern = "\\.qmd$", recursive = TRUE)
  qmds <- qmds[!grepl("(^|/)(_book|_freeze|site_libs)/", qmds) & !grepl("(^|/)_", qmds)]
  for (f in qmds) {
    txt <- readLines(root_path(f), warn = FALSE, encoding = "UTF-8")
    body <- paste(txt, collapse = "\n")
    body <- gsub("(?s)<!--.*?-->", "", body, perl = TRUE)          # skip comments
    body <- gsub("(?s)```.*?```", "", body, perl = TRUE)            # skip code chunks

    imgs <- regmatches(body, gregexpr("!\\[[^]]*\\]\\(([^) ]+)", body, perl = TRUE))[[1]]
    imgs <- sub("^!\\[[^]]*\\]\\(", "", imgs)
    imgs <- imgs[!grepl("^https?://", imgs)]
    for (im in imgs) {
      p <- if (startsWith(im, "/")) root_path(sub("^/", "", im)) else file.path(dirname(root_path(f)), im)
      if (!file.exists(p)) err(f, ": image not found: ", im)
    }

    cites <- regmatches(body, gregexpr("(?<![\\w.])@([A-Za-z][\\w:-]*)", body, perl = TRUE))[[1]]
    cites <- sub("^@", "", cites)
    cites <- cites[!grepl("^(fig|sec|tbl|eq|lst|thm)-", cites)]
    unknown <- setdiff(unique(cites), keys)
    if (length(unknown)) err(f, ": citation key(s) not in references.bib: ", paste(unknown, collapse = ", "))
  }

  # ---- report ----
  n_stub <- sum(inb$status %in% "stub")
  message(sprintf("Checked %d species (%d with accounts, %d stubs), %d sites, %d records.",
                  nrow(sp), nrow(inb), n_stub, nrow(sites), nrow(obs)))
  for (n in notes) message("  note: ", n)
  if (length(errors)) {
    for (e in errors) message("  ERROR: ", e)
    if (stop_on_error) stop(length(errors), " problem(s) found; fix them and rebuild.", call. = FALSE)
  } else {
    message("  All checks passed.")
  }
  invisible(list(errors = errors, notes = notes))
}
