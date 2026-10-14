# Lecture-note PDF build

Personal tooling to render the operating-systems lecture notes as A4 PDFs,
using `pandoc` with the Typst engine (no TeX distribution).

## Requirements
- `pandoc` 3.x and `typst` on PATH. On macOS: `brew install pandoc typst`.

## Usage
Run from the `operating-systems/` directory (or anywhere; the script cd's itself):

```
.pdfbuild/build.sh scheduling   # build one note -> scheduling.pdf
.pdfbuild/build.sh --all        # all 16 lecture notes + the review docs present
.pdfbuild/build.sh path/to/x.md  # any markdown file -> x.pdf here
```

The script caches the remote `assets.omscs.io` images under `.pdfbuild/img/`
(git-ignored, ~33 MB) on first run, refreshing `urls.txt` from the notes. This
pandoc build has no HTTP support, so images must be local; the script rewrites
image URLs to the cache in a temp copy before building.

## Notes
- Output is A4, serif body, images embedded and auto-sized, a "Contents" TOC
  (the `##` sections), quiz spoilers shown as small headings, and footer page numbers.
- The generated `<note>.pdf` files are personal study artifacts and are not
  committed to the notes repo.
- This directory lives only on a personal branch, not in upstream PRs.
