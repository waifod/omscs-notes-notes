#!/bin/zsh
# Build an operating-systems lecture note to an A4 PDF via pandoc + typst.
#
# Requirements: pandoc 3.x and typst on PATH (no TeX distribution needed).
#   macOS:  brew install pandoc typst
#
# Usage:
#   .pdfbuild/build.sh <note-name-without-extension>   # one note
#   .pdfbuild/build.sh --all                           # every lecture note
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
  local note="$1"
  local tmp="$BD/${note}.tmp.md"
  sed -E "s#https://assets\.omscs\.io/notes/#${IMG}/#g" "${note}.md" > "$tmp"
  # drop the first body H1 (title comes from YAML front matter) and fix list spacing
  perl -0pi -e 's/\n# [^\n]*\n/\n/ unless our $d++;' "$tmp"
  perl -0pi -e 's/(\*\*[^\n]*\*\*:)\n\*/$1\n\n*/g' "$tmp"
  pandoc "$tmp" -o "${note}.pdf" --pdf-engine=typst \
    -V papersize=a4 -V margin-x=2cm -V margin-y=2cm -V fontsize=10pt \
    --toc --toc-depth=1
  rm -f "$tmp"
  echo "built ${note}.pdf"
}

ensure_images
if [ "$1" = "--all" ]; then
  for n in "${LECTURES[@]}"; do build_one "$n"; done
else
  [ -n "$1" ] || { echo "usage: build.sh <note-name> | --all" >&2; exit 2; }
  build_one "$1"
fi
