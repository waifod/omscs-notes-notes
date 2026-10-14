#!/bin/zsh
# Build an operating-systems lecture note to an A4 PDF via pandoc + typst.
#
# Requirements: pandoc 3.x and typst on PATH (no TeX distribution needed).
#   macOS:  brew install pandoc typst
#
# Usage:
#   .pdfbuild/build.sh <note-name-without-extension>   # one note
#   .pdfbuild/build.sh <path/to/file.md>               # any markdown file (PDF lands here)
#   .pdfbuild/build.sh --all                           # every lecture note + review docs
#
# Images: lecture notes reference remote assets.omscs.io PNGs. This pandoc has
# no HTTP support, so images are cached locally under .pdfbuild/img and the URLs
# are rewritten in a temp copy. The cache is git-ignored; it is (re)built from
# .pdfbuild/urls.txt on demand, and urls.txt is refreshed from the notes here.
set -e
cd "$(dirname "$0")/.."            # operating-systems/
BD="$(pwd)/.pdfbuild"
IMG="$BD/img"

LECTURES=(
  introduction-to-operating-systems processes-and-process-management
  threads-and-concurrency threads-case-study-pthreads
  thread-design-considerations thread-performance-considerations
  scheduling memory-management inter-process-communication
  synchronization-constructs io-management virtualization
  remote-procedure-calls distributed-file-systems
  distributed-shared-memory datacenter-technologies
)
# review documents built by --all when present
OTHERS=(midterm-exam-review-questions midterm-sample-answers final-exam-review-questions)

ensure_images() {
  mkdir -p "$IMG"
  # refresh the URL list from the current lecture notes
  grep -hoE 'https://assets\.omscs\.io/notes/[^) ]+' "${LECTURES[@]/%/.md}" \
    | sort -u > "$BD/urls.txt"
  while read -r u; do
    fn="$IMG/$(basename "$u")"
    [ -f "$fn" ] || curl -fsSL "$u" -o "$fn"
  done < "$BD/urls.txt"
}

build_one() {
  # arg: a note name in operating-systems/, or a path to any markdown file
  local src="$1"; [ -f "$src" ] || src="$1.md"
  local note="$(basename "$src" .md)"
  local tmp="$BD/${note}.tmp.md"
  sed -E "s#https://assets\.omscs\.io/notes/#${IMG}/#g" "$src" > "$tmp"
  # drop the first body H1 (title comes from YAML front matter)
  perl -0pi -e 's/\n# [^\n]*\n/\n/ unless our $d++;' "$tmp"
  # quiz spoilers: typst has no <details>; render the <summary> text as a small
  # heading (kept with the answer that follows; below the TOC depth)
  perl -0pi -e 's{^[ \t]*<details>[ \t]*\n}{}mg; s{^[ \t]*</details>[ \t]*\n}{\n}mg;
    s{^[ \t]*<summary>(.*?)</summary>[ \t]*$}{ my $s=$1; $s =~ s#</?code>#`#g; "\n#### $s\n" }mge' "$tmp"
  # an image line directly after text would join that paragraph: separate it
  perl -0pi -e 's/^([^\n|>].*)\n(!\[)/$1\n\n$2/mg' "$tmp"
  # table cells: let long snake_case words wrap (escaped underscore + zero-width space)
  perl -CSD -pi -e 'if (/^\|/) { s/(?<=[A-Za-z0-9])_(?=[A-Za-z0-9])/\\_\x{200B}/g }' "$tmp"
  pandoc "$tmp" -o "${note}.pdf" --pdf-engine=typst \
    -f markdown+lists_without_preceding_blankline \
    -V papersize=a4 -V margin-x=2cm -V margin-y=2cm -V fontsize=10pt \
    -V header-includes='#show figure: set block(breakable: true)
#show table.cell: set par(justify: false)' \
    --toc --toc-depth=2
  rm -f "$tmp"
  echo "built ${note}.pdf"
}

ensure_images
if [ "$1" = "--all" ]; then
  for n in "${LECTURES[@]}" "${OTHERS[@]}"; do [ -f "$n.md" ] && build_one "$n"; done
else
  [ -n "$1" ] || { echo "usage: build.sh <note-name> | --all" >&2; exit 2; }
  build_one "$1"
fi
