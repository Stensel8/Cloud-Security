#!/usr/bin/env bash
# Export this course-portfolio repo (README.md + week-*/README.md + case/README.md)
# to a single PDF/A and a single ODT in the repo root, with images actually embedded,
# a table of contents, and (if setup/bibliography.bib has entries) an APA7-bronnenlijst.
#
# Usage: ./setup/export-portfolio.sh
# (bedoeld om vanuit elke courserepo's setup/-map te draaien, lokaal of in CI/CD;
# detecteert repo-root en -naam automatisch aan de hand van de locatie van dit script)
#
# Root cause this fixes: concatenating all READMEs into one temp .md file at
# repo-root level breaks any image reference that's relative to a subfolder
# (e.g. week-6/README.md referencing "images/foo.png"). This script rewrites
# every local image reference to an absolute path *before* concatenating, so
# it doesn't matter anymore where the combined file lives. It also rewrites
# <img> HTML tags to markdown images first, because pandoc's PDF/ODT writers
# silently drop raw HTML and would otherwise lose every such screenshot.
#
# Bronnenbeheer: setup/bibliography.bib (BibTeX) + setup/apa.csl (officiële CSL-stijl
# van citation-style-language/styles, CC-BY-SA) sturen pandoc's citeproc aan. Zet
# [@citekey]-verwijzingen in de README's en voeg de bijbehorende entry toe aan
# bibliography.bib; de "Bronnen"-sectie aan het eind wordt dan automatisch APA7-
# opgemaakt. Geen citaten in de tekst -> geen bronnenlijst, dat is geen fout.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
NAME="$(basename "$REPO")"
OUTDIR="${1:-$REPO}"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$OUTDIR"

# 1. Volgorde bepalen: root README, dan week-1, week-2, ... (natuurlijke sort), dan case/README.
mapfile -t WEEK_READMES < <(find "$REPO" -maxdepth 2 -regextype posix-extended \
  -regex '.*/(week|week[0-9]+-[0-9]+)[^/]*/README\.md' | sort -V)
CASE_README=""
[[ -f "$REPO/case/README.md" ]] && CASE_README="$REPO/case/README.md"

FILES=("$REPO/README.md" "${WEEK_READMES[@]}")
[[ -n "$CASE_README" ]] && FILES+=("$CASE_README")

echo "Volgorde van opname:"
printf '  %s\n' "${FILES[@]#"$REPO"/}"

# 2. Per bestand: image-paden absoluut maken, avif->png wegconverteren, concatenaten met pagebreak.
COMBINED="$WORK/combined.md"
: > "$COMBINED"

convert_avif_if_needed() {
  local img="$1"
  # IM7 (CachyOS e.a.) heeft "magick", het Ubuntu/Debian-pakket "imagemagick" is nog
  # IM6 en levert alleen "convert" — zonder deze fallback faalt dit stilletjes in CI.
  local im_cmd=""
  if command -v magick >/dev/null; then
    im_cmd="magick"
  elif command -v convert >/dev/null; then
    im_cmd="convert"
  fi
  if [[ "$img" == *.avif && -n "$im_cmd" ]]; then
    # In $WORK converteren, nooit naast het origineel: anders vervuilt elke run de
    # repo zelf met een los .png-bestand (gebeurde, zat in git status als untracked).
    local png="$WORK/avif-png/$(echo -n "$img" | md5sum | cut -c1-16).png"
    mkdir -p "$WORK/avif-png"
    if [[ ! -f "$png" ]]; then
      "$im_cmd" "$img" "$png" 2>/dev/null || return 1
    fi
    echo "$png"
  else
    echo "$img"
  fi
}

first=true
for f in "${FILES[@]}"; do
  [[ -f "$f" ]] || continue
  dir="$(dirname "$f")"
  tmp="$WORK/$(basename "$f").$(echo -n "$f" | md5sum | cut -c1-8).md"

  if [[ "$first" == false ]]; then
    printf '\n```{=typst}\n#pagebreak()\n```\n\n' >> "$COMBINED"
  fi
  first=false

  # 1) <img src="..." alt="..." width="..."> -> markdown ![alt](path){width=...px}
  #    (pandoc's HTML-passthrough drops raw <img> tags for non-HTML writers like
  #    typst/odt, which is the actual reason earlier PDF/ODT exports lost images).
  # 2) ![alt](path) -> ![alt](/abs/path), skipping http(s)/absolute links.
  python3 - "$f" "$dir" > "$tmp" <<'PYEOF'
import re, sys, os

src, basedir = sys.argv[1], sys.argv[2]
with open(src, encoding="utf-8") as fh:
    text = fh.read()

def html_img_to_md(m):
    attrs = m.group(1)
    def attr(name):
        am = re.search(rf'{name}="([^"]*)"', attrs)
        return am.group(1) if am else None
    path = attr("src") or ""
    alt = attr("alt") or ""
    width = attr("width")
    suffix = f'{{width={width}px}}' if width else ""
    return f"![{alt}]({path}){suffix}"

text = re.sub(r'<img\s+([^>]*?)/?>', html_img_to_md, text)

def resolve(m):
    alt, path, suffix = m.group(1), m.group(2), m.group(3) or ""
    if path.startswith(("http://", "https://", "/")):
        return m.group(0)
    abspath = os.path.normpath(os.path.join(basedir, path))
    return f"![{alt}]({abspath}){suffix}"

text = re.sub(r'!\[([^\]]*)\]\(([^)\s]+)\)(\{[^}]*\})?', resolve, text)
sys.stdout.write(text)
PYEOF

  # avif -> png conversie, want typst (PDF-pad) kan geen avif tonen.
  while IFS= read -r img; do
    [[ -z "$img" ]] && continue
    [[ "$img" == /* ]] || continue
    [[ -f "$img" ]] || continue
    case "$img" in
      *.avif)
        png="$(convert_avif_if_needed "$img" || true)"
        if [[ -n "$png" && -f "$png" ]]; then
          sed_safe_img=$(printf '%s' "$img" | sed 's/[.[\*^$/]/\\&/g')
          sed_safe_png=$(printf '%s' "$png" | sed 's/[.[\*^$/]/\\&/g')
          sed -i "s|$sed_safe_img|$sed_safe_png|g" "$tmp"
        fi
        ;;
    esac
  done < <(grep -oE '!\[[^]]*\]\([^)]+\)' "$tmp" | grep -oE '\(/[^)]+\)' | tr -d '()')

  cat "$tmp" >> "$COMBINED"
  echo >> "$COMBINED"
done

# 3. Bronnen: build_bibliography.py leest alle "Bronnen: [titel](url)"-regels uit de
#    READMEs (de single source of truth) en genereert setup/bibliography.bib. Geen
#    losse stap om te onthouden: dit draait vanzelf, bij elke export opnieuw.
BIB="$SCRIPT_DIR/bibliography.bib"
CSL="$SCRIPT_DIR/apa.csl"
python3 "$SCRIPT_DIR/build_bibliography.py" "$REPO"

CITEPROC_ARGS=()
YAML_HEADER=""
if [[ -f "$BIB" && -f "$CSL" ]] && grep -q '^@' "$BIB"; then
  # nocite: '@*' moet in een YAML-metadata-blok staan: pandoc's --metadata op de
  # command line laat deze speciale "neem de hele bibliografie op"-waarde stilletjes
  # zonder effect (geprobeerd en geverifieerd: de literatuurlijst bleef dan leeg).
  # Zo komt elke bron in bibliography.bib in de literatuurlijst, ook zonder
  # expliciete [@key]-verwijzing in de lopende tekst. Bestaande inline markdown-
  # links in de README's blijven intact (GitHub-weergave verandert niet).
  YAML_HEADER=$'---\nnocite: |\n  @*\n---\n\n'
  CITEPROC_ARGS=(--citeproc --csl "$CSL" --bibliography "$BIB" --metadata link-citations=true --metadata reference-section-title=Bronnen)
  echo "Bronnenlijst (APA7, via citeproc): aan (${BIB#"$REPO"/})"
else
  echo "Bronnenlijst: uit (geen setup/bibliography.bib met entries gevonden)"
fi

TITLE="# ${NAME} — Portfolio-export"
NOTE="*Dit document is automatisch gegenereerd vanuit de GitHub-repository via pandoc + typst (zie [\`setup/export-portfolio.sh\`](setup/export-portfolio.sh)), ter aanvulling op de losse bronbestanden. Zie: https://github.com/Stensel8/${NAME} voor de meest actuele versie.*"
printf '%s%s\n\n%s\n\n```{=typst}\n#pagebreak()\n```\n\n' "$YAML_HEADER" "$TITLE" "$NOTE" | cat - "$COMBINED" > "$WORK/final.md"

# 4. PDF/A via typst-engine (lichtgewicht, geen LaTeX nodig). PDF/A-2b: archiefwaardig,
#    lettertypen embedded, breed geaccepteerd (minder streng dan A-1b, geen transparantie-eis).
pandoc "$WORK/final.md" \
  --toc --toc-depth=2 --metadata lang=nl --metadata toc-title=Inhoudsopgave \
  "${CITEPROC_ARGS[@]}" \
  --pdf-engine=typst \
  --pdf-engine-opt=--pdf-standard=a-2b \
  --resource-path="$REPO:$WORK" \
  -o "$OUTDIR/${NAME}.pdf"
echo "PDF (PDF/A-2b) klaar: $OUTDIR/${NAME}.pdf"

# 5. ODT: native pandoc-writer, embedt afbeeldingen automatisch, en blijft bewerkbaar
#    (ook in WordCraft/Word/LibreOffice, inclusief de TOC- en bronnen-velden).
pandoc "$WORK/final.md" \
  --toc --toc-depth=2 --metadata lang=nl --metadata toc-title=Inhoudsopgave \
  "${CITEPROC_ARGS[@]}" \
  --resource-path="$REPO:$WORK" \
  -o "$OUTDIR/${NAME}.odt"
echo "ODT klaar: $OUTDIR/${NAME}.odt"
