# Publishing the book with GitHub

This guide sets up a new GitHub repository, **ZoopEcoEvo/CONE** (the
Copepods of New England), for the book. After the one-time setup, every
push to `main` rebuilds the book (HTML and PDF) on GitHub's servers and
publishes it at:

**https://zoopecoevo.github.io/CONE/**

You never commit the rendered `_book/` folder (it's in `.gitignore`); GitHub
builds it for you. The build is defined in `.github/workflows/publish.yml`.
The repository and site addresses are already set in `_quarto.yml`
(`repo-url`, `site-url`).

Setup takes about 15 minutes.

---

## Before you start

- **Quarto, R and the R packages are installed locally**, and the book
  renders on your machine (open `CONE.Rproj` in RStudio → *Render Book*, or
  run `quarto render` in a terminal). Step 4 needs one local render.
- **The repository will be public.** GitHub Pages on a private repository
  needs a paid GitHub plan.
- **`ZoopEcoEvo` is an organisation.** Creating repositories and changing the
  Actions settings below may need an organisation owner.
- **Deleting the old `mass_copepods` repository** also takes down anything it
  published, and its links stop working. The new project starts with a
  fresh history.

---

## 1. Create the empty repository on GitHub

1. On github.com, click **+** (top right) → **New repository**.
2. *Owner*: **ZoopEcoEvo**. *Repository name*: **CONE**.
3. *Description* (optional): *The Copepods of New England, an
   identification guide built with Quarto and R*.
4. Choose **Public**.
5. **Leave everything under *Initialize this repository* unticked** (no
   README, .gitignore or licence). The project already has all three, and
   an empty repository makes the first push simple.
6. Click **Create repository**.

## 2. Allow the workflow to publish

In the new repository: **Settings → Actions → General**, scroll to *Workflow
permissions*, choose **Read and write permissions**, and click **Save**.

If the option is greyed out, an organisation owner must allow it first
(organisation **Settings → Actions → General**).

## 3. Push the project

Unzip `CONE.zip` wherever you keep projects. It contains a `CONE` folder.
Then, in a terminal:

```bash
cd path/to/CONE
git init -b main
git add -A
git commit -m "Initial commit: The Copepods of New England"
git remote add origin https://github.com/ZoopEcoEvo/CONE.git
git push -u origin main
```

*With the GitHub CLI (`gh`), the last two lines can instead be:*
`gh repo create ZoopEcoEvo/CONE --public --source=. --push`
*(which also creates the repository, replacing step 1).*

*In RStudio:* open `CONE.Rproj`, then **Tools → Version Control → Project
Setup → Version control system: Git** to initialise the repository. Commit
everything in the Git pane, then run the `git remote add` and `git push`
lines above in RStudio's Terminal tab.

This first push starts the workflow, and it will likely **fail** because
the `gh-pages` branch doesn't exist yet. Step 4 fixes that.

## 4. Publish once from your computer

From the `CONE` folder:

```bash
quarto publish gh-pages
```

Answer **Y** when asked. This command:

- creates a `gh-pages` branch that holds only the rendered site,
- renders the book and pushes it there,
- writes a small `_publish.yml` file into the project.

Commit that file:

```bash
git add _publish.yml
git commit -m "Add Quarto publish config"
git push
```

## 5. Turn on GitHub Pages

In the repository: **Settings → Pages** (left sidebar, under *Code and
automation*):

- *Source*: **Deploy from a branch**
- *Branch*: **gh-pages**, folder **/ (root)** → **Save**

## 6. Check it worked

1. Go to the **Actions** tab. The run from your last push should turn green
   after about 5–10 minutes. If the first run is red, open it and click
   **Re-run all jobs**, or use **Run workflow** on the left.
2. Visit https://zoopecoevo.github.io/CONE/. The PDF download button sits
   under the book title in the sidebar.
3. Optional: show the address on the repository's front page. Click the gear
   next to *About* on the main repository page and tick **Use your GitHub
   Pages website**.

---

## Day to day

```
edit .qmd / data/*.csv  →  render locally to check  →  commit  →  push
```

The site updates a few minutes after each push to `main`. The local render
isn't strictly needed, but it is faster for catching mistakes.

**Working with collaborators or students.** Have them work on a branch and
open a pull request. The workflow renders the book for every pull request
without publishing it, so a red ✗ on the pull request means something would
break the book (the build checks in `R/validate.R` also run there). Merge
once it's green.

**Pages with "Edit this page" / "Report an issue".** These links on every
page point to the GitHub repository. "Edit" opens the source file on GitHub
(handy for typo fixes), and "Report an issue" opens a GitHub issue, so
readers can send corrections.

---

## Optional extras

- **Citable versions (DOI).** Sign in to https://zenodo.org with GitHub,
  enable the repository under *GitHub* in your Zenodo account, then create a
  release on GitHub (Releases → *Draft a new release*, tag e.g. `v0.1`).
  Zenodo archives each release and gives it a DOI. Add the badge to the
  README and the citation to the preface.
- **Protect `main`.** Settings → Branches → *Add branch ruleset* → require the
  "Render and publish" check to pass before merging. This is useful once
  others contribute.
- **Custom domain.** Settings → Pages → *Custom domain*, if you want e.g.
  `copepods.yourlab.org`.

---

## Troubleshooting

| Symptom | Likely cause and fix |
|---|---|
| Action fails at *Render* with `there is no package called 'xyz'` | A new R package was used. Add `any::xyz` to the package list in `.github/workflows/publish.yml`. |
| Action fails with an `ERROR:` line from the build checks | The same check you'd see locally (missing image, unknown citation key, etc.). The log names the file. Fix it and push again. |
| Action fails at *Publish* with `Permission denied to github-actions[bot]` or `403` | Workflow permissions are read-only (step 2). |
| Action fails because the `gh-pages` branch is missing | Step 4 hasn't been done yet. |
| Site shows a 404 | Pages source isn't set to `gh-pages` (step 5), or the first deploy is still running. Wait a couple of minutes after a green run. |
| PDF fails in the action with a missing `.sty` file | Quarto normally installs missing LaTeX packages into TinyTeX automatically. If one is still missing, add a step before rendering: `run: tlmgr install <package>`. |
| Works locally but images are missing online | File name case: `Female.JPG` and `female.jpg` are the same file on a Mac but different files on GitHub's Linux machines. Match the case used in the `.qmd`. |
