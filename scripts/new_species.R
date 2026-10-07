# scripts/new_species.R --------------------------------------------------------
# Add a species account to the book. From the project root:
#
#   Rscript scripts/new_species.R "Temora longicornis"
#       (species already in data/species.csv: switches in_book to TRUE)
#
#   Rscript scripts/new_species.R "Eurytemora carolleeae" Calanoida Temoridae "marine; brackish"
#       (new species: give order, and optionally family and habitat)
#
# Then open species/<genus_species>.qmd and start writing. Or from the R
# console: source("R/build_tools.R"); add_species("Temora longicornis"); build_book()
# -----------------------------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) stop('Usage: Rscript scripts/new_species.R "Genus species" [order] [family] [habitat]')
source(here::here("R", "build_tools.R"))
add_species(args[1], order = args[2], family = args[3], habitat = args[4])
build_book()
