# CONE: The Copepods of New England

Repository: <https://github.com/ZoopEcoEvo/CONE>. Published book: <https://zoopecoevo.github.io/CONE/>

A Quarto book (HTML + PDF) built with R. Facts live in data files; the `.qmd`
pages hold the writing; R fills in the rest.

## Building

```r
# one-time setup
install.packages(c("quarto", "here", "dplyr", "readr", "ggplot2", "knitr",
                   "DT", "maps", "worrms"))
```

Then **Render Book** in RStudio, or `quarto render` in a terminal. Before each
render, `scripts/build.R` runs automatically: it creates stub pages for new
species, regenerates the chapter list in `_quarto.yml`, and checks the data
(missing images, unknown citation keys, observations for unknown species or
sites, malformed dates…). If a check fails, the render stops and says why.

The PDF uses XeLaTeX (`quarto install tinytex` if you have no LaTeX).

## Publishing

Pushing to `main` rebuilds the book on GitHub and publishes it to GitHub Pages
(`.github/workflows/publish.yml`). For the one-time setup, see
[GITHUB_SETUP.md](GITHUB_SETUP.md).

## Everyday tasks

| To… | Do this |
|---|---|
| **Start a species account** | `Rscript scripts/new_species.R "Temora longicornis"` (or set `in_book` to `TRUE` in `data/species.csv` and render). A stub appears in `species/` and in the right part of the book. |
| Add a species not yet listed | `Rscript scripts/new_species.R "Genus species" Order Family "habitat"` |
| Add a collection record | Add a row to `data/observations.csv` (and the site to `data/sites.csv` if new). Tables, maps and counts update everywhere. |
| Add a reference | Add it to `references.bib`; cite with `[@key]` in text, or put the key in `species.csv` (`original_description`, `sources`, `record_source`). |
| Add images | Save to `images/<slug>/`, e.g. `images/temora_longicornis/female_p5.jpg`, and reference them in the page's *Morphology* section. |
| Add a comparison | Copy `comparisons/_template.qmd` to `comparisons/<name>.qmd`. It joins the *Common comparisons* part automatically. |
| Update taxonomy | `Rscript scripts/update_taxonomy.R` fills AphiaIDs, authorities and families from WoRMS and writes `data/taxonomy_report.csv` listing names that need a decision. |
| Cross-reference | `@sec-genus-species` for a species chapter, `@fig-...` for a figure. |

## Layout

```
_quarto.yml          book config; the chapter block between the
                     ">>> BEGIN/<<< END GENERATED" markers is rewritten by scripts/build.R
index.qmd            preface
front/               how to use, collecting, morphology, keys, checklist
parts/               one intro page per order (+ comparisons); _template.qmd
species/             one page per species, named <genus_species>.qmd; _template.qmd
comparisons/         side-by-side guides; _template.qmd
appendices/          sampling sites, glossary
images/<slug>/       images for each species
data/                species.csv, sites.csv, observations.csv
R/                   common.R (page helpers), build_tools.R, validate.R
scripts/             build.R, new_species.R, update_taxonomy.R
.github/workflows/   publish.yml (render + publish on GitHub)
references.bib
```

Files starting with `_` are templates and are never rendered.

## Data dictionary

**`data/species.csv`**: one row per taxon known from the region.

| column | meaning |
|---|---|
| `slug` | `genus_species` in lower case; also the page file name |
| `genus`, `species` | the name as used in the book |
| `display_name` | optional; overrides the displayed name (e.g. *Epischura nordenskiöldi*) |
| `authority`, `aphia_id`, `accepted_name` | from WoRMS (`scripts/update_taxonomy.R`) |
| `order`, `family` | used to group and sort the book |
| `habitat` | `marine`, `brackish`, `freshwater`; separate several with `;` |
| `other_names` | synonyms or misidentifications in older literature |
| `original_description`, `sources`, `record_source` | citation keys from `references.bib`, separated by `;` |
| `links` | `Label <url>` items separated by `;` |
| `verified_id` | `TRUE` once you have confirmed the identification yourself |
| `in_book` | `TRUE` to give the species its own page |
| `status` | `stub`, `draft` or `complete`; stubs and drafts get a banner |
| `notes` | anything else (not shown in the book) |

**`data/sites.csv`**: `site_id` (short unique id), `site_name`, `lat`, `lon`
(decimal degrees), `state`, `waterbody` (lake, pond, river, estuary, coastal,
offshore…), `notes`.

**`data/observations.csv`**: one row per species per sampling event:
`slug`, `site_id`, `date` (YYYY-MM-DD), `temp_c`, `salinity`, `depth_m`,
`life_stages`, `collector`, `notes`.
