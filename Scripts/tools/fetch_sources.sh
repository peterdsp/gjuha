#!/usr/bin/env bash
set -euo pipefail

# This script downloads OPEN datasets to ./sources (big files).
# Run locally on your machine (not inside the app).
# You may need: curl, tar, bzip2, gzip.

mkdir -p sources

echo "1) Tatoeba: sentences + links (for Albanian filtering)"
echo "Download page: https://tatoeba.org/en/downloads"
# Examples (may change; check the page):
curl -L -o sources/sentences_detailed.tar.bz2 https://downloads.tatoeba.org/exports/sentences_detailed.tar.bz2
curl -L -o sources/links.tar.bz2 https://downloads.tatoeba.org/exports/links.tar.bz2

echo "2) Wiktionary dump (for Albanian lexicon + conjugations)"
echo "Index: https://dumps.wikimedia.org/enwiktionary/latest/"
curl -L -o sources/enwiktionary-latest-pages-articles.xml.bz2 https://dumps.wikimedia.org/enwiktionary/latest/enwiktionary-latest-pages-articles.xml.bz2

echo "3) Leipzig corpora word frequency lists (optional)"
echo "Download page: https://wortschatz.uni-leipzig.de/en/download/als"
# Pick ONE size first (30K/100K/etc) and uncomment:
# curl -L -o sources/als-al_web_2017_30K.tar.gz https://downloads.wortschatz-leipzig.de/corpora/als-al_web_2017_30K.tar.gz

echo "Done. Next: run tools/build_from_sources.py"
