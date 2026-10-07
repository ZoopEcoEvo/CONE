# scripts/build.R ---------------------------------------------------------------
# Runs automatically before every `quarto render` (see pre-render in
# _quarto.yml). You can also run it by hand from the project root:
#
#   Rscript scripts/build.R
#
# It creates stub pages for new species, creates part pages for new orders,
# regenerates the chapter list in _quarto.yml, and checks the data for problems.
# -----------------------------------------------------------------------------

source(here::here("R", "build_tools.R"))
build_book()
