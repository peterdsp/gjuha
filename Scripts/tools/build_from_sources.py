#!/usr/bin/env python3
"""
Build a production content pack from OPEN sources.

Outputs:
- content/generated/vocabulary.csv
- content/generated/sentences.csv
- content/generated/templates.json
- content/generated/exercises.json

This script is intentionally conservative:
- Extracts Albanian sentences (lang= 'sqi') from Tatoeba detailed.
- Builds a frequency-ranked word list from those sentences.
- Leaves morphology (cases/conjugations) as TODO unless you add wiktextract step.

Recommended:
- Use 'wiktextract' (https://github.com/tatuylonen/wiktextract) to extract Albanian entries from the Wiktionary dump.
- Merge forms/conjugations into vocabulary items.
"""

import csv, re, json
from pathlib import Path
from collections import Counter

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "sources"
OUT = ROOT / "content" / "generated"
OUT.mkdir(parents=True, exist_ok=True)

# ---- 1) Read Tatoeba sentences_detailed (tsv inside tar.bz2) ----
import tarfile

sent_tar = SOURCES / "sentences_detailed.tar.bz2"
if not sent_tar.exists():
    raise SystemExit("Missing sources/sentences_detailed.tar.bz2. Run fetch_sources.sh first.")

def is_albanian_lang(code: str) -> bool:
    # Tatoeba uses ISO-639-3; Albanian is typically 'sqi'.
    return code.strip().lower() in {"sqi"}

sentences = []
with tarfile.open(sent_tar, "r:bz2") as tf:
    # file name is usually 'sentences_detailed.csv' (TSV), but may vary.
    member = next((m for m in tf.getmembers() if "sentences_detailed" in m.name), None)
    if member is None:
        raise SystemExit("Could not find sentences_detailed inside tar.")
    f = tf.extractfile(member)
    for line in f:
        row = line.decode("utf-8", errors="ignore").rstrip("\n").split("\t")
        if len(row) < 4:
            continue
        sid, lang, text = row[0], row[1], row[2]
        if is_albanian_lang(lang):
            sentences.append((sid, text))

# Save a manageable slice (you can increase later)
sentences = sentences[:50000]

# ---- 2) Tokenize + frequency list ----
token_re = re.compile(r"[\w'’çÇëË]+", re.UNICODE)
freq = Counter()

for _, s in sentences:
    tokens = [t.lower() for t in token_re.findall(s)]
    freq.update(tokens)

# top words
top = freq.most_common(6000)

with open(OUT / "word_frequency_top6000.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["rank","word","count"])
    for i,(word,count) in enumerate(top, start=1):
        w.writerow([i, word, count])

with open(OUT / "sentences_sqi_50k.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["id","sentence"])
    for sid, s in sentences:
        w.writerow([sid, s])

print("Generated: word_frequency_top6000.csv + sentences_sqi_50k.csv")
print("Next step: merge with Wiktionary extraction to add POS, gender, conjugations, declensions.")
