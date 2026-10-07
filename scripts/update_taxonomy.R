# scripts/update_taxonomy.R ----------------------------------------------------
# Look every species up in the World Register of Marine Species (WoRMS) and
# fill in AphiaID, authority, family and accepted name in data/species.csv.
# Needs the worrms package and an internet connection:
#
#   install.packages("worrms")
#   Rscript scripts/update_taxonomy.R            # only fill empty cells
#   Rscript scripts/update_taxonomy.R --overwrite  # also replace existing values
#
# It never renames species or changes order/habitat on its own. Anything that
# needs a decision (unaccepted names, order/habitat mismatches, names WoRMS
# doesn't know) goes to data/taxonomy_report.csv for you to review.
# -----------------------------------------------------------------------------

overwrite <- "--overwrite" %in% commandArgs(trailingOnly = TRUE)
path <- here::here("data", "species.csv")
tab <- readr::read_csv(path, col_types = readr::cols(.default = "c"), na = character())

strip_subgenus <- function(x) gsub("\\s*\\([^)]*\\)", "", x)
fill <- function(old, new) if (overwrite || !nzchar(old)) new %||% old else old
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || is.na(a)) b else a

report <- list()
for (i in seq_len(nrow(tab))) {
  name <- paste(tab$genus[i], tab$species[i])
  message("Looking up ", name, " ...")
  rec <- tryCatch(worrms::wm_records_name(name, fuzzy = FALSE, marine_only = FALSE),
                  error = function(e) NULL)
  Sys.sleep(0.3)   # be polite to the WoRMS server
  if (is.null(rec) || nrow(rec) == 0) {
    report[[length(report) + 1]] <- data.frame(slug = tab$slug[i], issue = "not found in WoRMS", detail = "")
    next
  }
  # prefer an accepted record, then the first one
  r <- rec[order(!(rec$status %in% c("accepted", "alternative representation"))), ][1, ]

  tab$aphia_id[i]  <- fill(tab$aphia_id[i], as.character(r$AphiaID))
  tab$authority[i] <- fill(tab$authority[i], r$authority)
  tab$family[i]    <- fill(tab$family[i], r$family)

  valid <- strip_subgenus(r$valid_name %||% name)
  if (!identical(valid, name)) {
    tab$accepted_name[i] <- fill(tab$accepted_name[i], valid)
    report[[length(report) + 1]] <- data.frame(
      slug = tab$slug[i], issue = paste("WoRMS status:", r$status),
      detail = paste0("accepted as ", valid, " ", r$valid_authority %||% "",
                      " (AphiaID ", r$valid_AphiaID, ")"))
  }
  if (!is.na(r$order) && nzchar(tab$order[i]) && r$order != tab$order[i]) {
    report[[length(report) + 1]] <- data.frame(
      slug = tab$slug[i], issue = "order differs", detail = paste("WoRMS:", r$order))
  }
  envs <- c(marine = r$isMarine, brackish = r$isBrackish, freshwater = r$isFreshwater)
  envs <- names(envs)[!is.na(envs) & envs == 1]
  report[[length(report) + 1]] <- data.frame(
    slug = tab$slug[i], issue = "WoRMS environments", detail = paste(envs, collapse = "; "))
}

readr::write_csv(tab, path, na = "")
rep <- do.call(rbind, report)
readr::write_csv(rep, here::here("data", "taxonomy_report.csv"))
message("Updated data/species.csv. Review data/taxonomy_report.csv (",
        sum(rep$issue != "WoRMS environments"), " item(s) need a decision).")
