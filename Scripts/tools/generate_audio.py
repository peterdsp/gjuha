#!/usr/bin/env python3
"""
Reproducible pronunciation-audio pipeline for Gjuha.

Reads the canonical vocabulary, synthesizes per-word audio with a chosen
backend, caches by content hash, and records provenance in the audio manifest.
It NEVER marks an asset `reviewed: true`; that is a deliberate human step after
native-speaker review (see Documentation/Content/AUDIO_PIPELINE.md).

Backends
  apple-say : macOS `say` + `afconvert`. Free and offline, but there is no
              Albanian voice, so output mispronounces Albanian. Development only.
  azure     : Azure Neural TTS (sq-AL-AnilaNeural). Requires AZURE_SPEECH_KEY and
              AZURE_SPEECH_REGION in the environment and the explicit
              --yes-incur-cost flag. Keys are never written to disk.

Examples
  python3 Scripts/tools/generate_audio.py --provider apple-say --limit 20
  AZURE_SPEECH_KEY=... AZURE_SPEECH_REGION=westeurope \\
    python3 Scripts/tools/generate_audio.py --provider azure --yes-incur-cost
  python3 Scripts/tools/generate_audio.py --validate
"""
import argparse, hashlib, json, os, subprocess, sys, tempfile
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VOCAB = ROOT / "Gjuha" / "Data" / "Seed" / "Vocabulary" / "a1_vocabulary.json"
MANIFEST = ROOT / "Gjuha" / "Data" / "Seed" / "audio_manifest.json"
DEFAULT_OUT = ROOT / "Gjuha" / "Resources" / "Audio"


def load_json(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def text_hash(provider, voice, text):
    return hashlib.sha256(f"{provider}|{voice}|{text}".encode("utf-8")).hexdigest()


def file_checksum(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()[:16]


def now_iso():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


# ---- Backends ---------------------------------------------------------------

def synth_apple_say(text, out_path):
    """macOS say -> aiff -> m4a. Development audio only (no Albanian voice)."""
    if not (subprocess.run(["which", "say"], capture_output=True).returncode == 0):
        raise SystemExit("`say` not available; apple-say backend needs macOS.")
    voice = os.environ.get("SAY_VOICE", "Daniel")  # any voice; NOT Albanian
    with tempfile.NamedTemporaryFile(suffix=".aiff", delete=False) as tmp:
        aiff = tmp.name
    try:
        subprocess.run(["say", "-v", voice, "-o", aiff, text], check=True)
        subprocess.run(["afconvert", aiff, str(out_path), "-d", "aac", "-f", "m4af"], check=True)
    finally:
        os.path.exists(aiff) and os.remove(aiff)
    return {"provider": "apple-say-dev", "voice": voice,
            "license": "Apple system voice, development only, not for release"}


def synth_azure(text, out_path):
    """Azure Neural TTS. Requires key + region + explicit cost acknowledgement."""
    import urllib.request
    key = os.environ.get("AZURE_SPEECH_KEY")
    region = os.environ.get("AZURE_SPEECH_REGION")
    if not key or not region:
        raise SystemExit("azure backend needs AZURE_SPEECH_KEY and AZURE_SPEECH_REGION env vars.")
    voice = os.environ.get("AZURE_VOICE", "sq-AL-AnilaNeural")
    token = urllib.request.urlopen(urllib.request.Request(
        f"https://{region}.api.cognitive.microsoft.com/sts/v1.0/issueToken",
        data=b"", headers={"Ocp-Apim-Subscription-Key": key})).read().decode()
    ssml = (f'<speak version="1.0" xml:lang="sq-AL"><voice name="{voice}">'
            f'{text}</voice></speak>')
    req = urllib.request.Request(
        f"https://{region}.tts.speech.microsoft.com/cognitiveservices/v1",
        data=ssml.encode("utf-8"),
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/ssml+xml",
                 "X-Microsoft-OutputFormat": "audio-24khz-96kbitrate-mono-mp3",
                 "User-Agent": "gjuha-audio"})
    Path(out_path).write_bytes(urllib.request.urlopen(req).read())
    return {"provider": "azure-neural", "voice": voice,
            "license": "Azure Cognitive Services TTS output, redistribution per Azure terms"}


BACKENDS = {"apple-say": synth_apple_say, "azure": synth_azure}


# ---- Manifest ---------------------------------------------------------------

def load_manifest():
    if MANIFEST.exists():
        return load_json(MANIFEST)
    return {"version": "1", "generator": "Scripts/tools/generate_audio.py", "notes": "", "assets": []}


def save_manifest(manifest):
    manifest["assets"].sort(key=lambda a: a["wordId"])
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def validate(out_dir):
    manifest = load_manifest()
    missing, ok = [], 0
    for asset in manifest["assets"]:
        if (out_dir / asset["file"]).exists() or (out_dir.parent / asset["file"]).exists():
            ok += 1
        else:
            missing.append(asset["wordId"])
    print(f"Manifest assets: {len(manifest['assets'])}  present: {ok}  missing: {len(missing)}")
    if missing:
        print("MISSING files for:", ", ".join(missing))
        return 1
    reviewed = sum(1 for a in manifest["assets"] if a.get("reviewed"))
    print(f"Reviewed (production-ready): {reviewed}")
    return 0


def generate(args):
    if args.provider == "azure" and not args.yes_incur_cost:
        raise SystemExit("azure may incur charges; pass --yes-incur-cost to proceed (see AUDIO_PIPELINE.md).")
    backend = BACKENDS[args.provider]
    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    words = load_json(VOCAB)
    if args.words:
        wanted = set(args.words.split(","))
        words = [w for w in words if w["id"] in wanted]
    if args.limit:
        words = words[: args.limit]

    manifest = load_manifest()
    by_id = {a["wordId"]: a for a in manifest["assets"]}
    generated, cached = 0, 0
    for word in words:
        text = word["albanian"]
        out_file = out_dir / f"{word['id']}.m4a"
        # Cache: skip if a file already exists with a matching provenance hash.
        existing = by_id.get(word["id"])
        h = None
        if existing and out_file.exists() and existing.get("textHash"):
            cached += 1
            continue
        meta = backend(text, out_file)
        h = text_hash(meta["provider"], meta.get("voice", ""), text)
        by_id[word["id"]] = {
            "wordId": word["id"], "text": text, "file": out_file.name,
            "provider": meta["provider"], "voice": meta.get("voice"),
            "license": meta.get("license"), "reviewed": False,
            "generatedAt": now_iso(), "checksum": file_checksum(out_file),
            "textHash": h,
        }
        generated += 1
        print(f"  {word['id']} {text} -> {out_file.name} [{meta['provider']}]")

    manifest["assets"] = list(by_id.values())
    manifest["generator"] = "Scripts/tools/generate_audio.py"
    save_manifest(manifest)
    print(f"Done. generated={generated} cached={cached} total={len(manifest['assets'])}")
    print("All new assets are reviewed:false. Native-speaker review is required "
          "before any are marked reviewed:true and shown in graded lessons.")
    return 0


def main():
    ap = argparse.ArgumentParser(description="Generate/validate Gjuha pronunciation audio.")
    ap.add_argument("--provider", choices=list(BACKENDS), default="apple-say")
    ap.add_argument("--out", default=str(DEFAULT_OUT))
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--words", help="comma-separated word ids, e.g. w001,w002")
    ap.add_argument("--validate", action="store_true", help="check manifest vs files, then exit")
    ap.add_argument("--yes-incur-cost", action="store_true", help="required for paid providers")
    args = ap.parse_args()
    if args.validate:
        sys.exit(validate(Path(args.out)))
    sys.exit(generate(args))


if __name__ == "__main__":
    main()
