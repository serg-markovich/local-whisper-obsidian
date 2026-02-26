#!/usr/bin/env python3
"""
local-whisper-obsidian: transcribe a single audio file to an Obsidian Markdown note.

Usage:
    python src/transcribe.py <audio_file> [--model small] [--language auto]

Repository:
    https://github.com/serg-markovich/local-whisper-obsidian
"""

import argparse
import logging
import os
import re
import sys
from datetime import datetime
from pathlib import Path

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    stream=sys.stdout,
)
logger = logging.getLogger("local-whisper-obsidian")

SUPPORTED_EXTENSIONS = {".m4a", ".mp3", ".wav", ".ogg", ".opus", ".webm", ".flac"}


class Transcriber:
    """Wraps WhisperModel with lazy loading — model is initialized once and reused."""

    def __init__(self, model_name: str = "small", device: str = "cpu"):
        self.model_name = model_name
        self.device = device
        self._model = None

    @property
    def model(self):
        if self._model is None:
            from faster_whisper import WhisperModel
            logger.info("Loading model: %s on %s", self.model_name, self.device)
            self._model = WhisperModel(
                self.model_name, device=self.device, compute_type="int8"
            )
        return self._model

    def transcribe(self, audio_path: str, language: str = "auto") -> tuple[str, str]:
        lang = None if language == "auto" else language
        segments, info = self.model.transcribe(audio_path, language=lang)
        text = " ".join(s.text.strip() for s in segments)
        return text, info.language


def format_transcript(text: str) -> str:
    """
    Basic transcript formatting:
    split into paragraphs of ~3 sentences for readability.
    """
    sentences = re.split(r'(?<=[.!?])\s+', text.strip())

    if not sentences:
        return text

    chunk_size = 3
    paragraphs = []
    for i in range(0, len(sentences), chunk_size):
        chunk = sentences[i:i + chunk_size]
        paragraphs.append(" ".join(chunk))

    return "\n\n".join(paragraphs)


def build_note(audio_path: str, text: str, language: str) -> str:
    filename = Path(audio_path).name
    now = datetime.now().strftime("%Y-%m-%d %H:%M")
    formatted = format_transcript(text)
    return f"""---
date: {now}
type: inbox
source: voice
status: unprocessed
language: {language}
audio: "[[{filename}]]"
tags:
  - review
---

# Voice note {now}

> [!note] Source
> [[{filename}]]

## Transcript

{formatted}

## Action

- [ ] Process by: 
"""


def process_file(audio_path: str, transcriber: Transcriber, language: str) -> bool:
    """
    Transcribe a single audio file and write a Markdown note alongside it.
    Returns True if transcription was created, False if skipped.
    Raises FileNotFoundError if the audio file does not exist.
    """
    path = Path(audio_path)

    if path.suffix.lower() not in SUPPORTED_EXTENSIONS:
        logger.debug("Skipping unsupported file type: %s", audio_path)
        return False

    if not path.exists():
        raise FileNotFoundError(f"File not found: {audio_path}")

    md_path = path.with_suffix(".md")
    if md_path.exists():
        logger.info("Already transcribed, skipping: %s", md_path)
        return False

    logger.info("Transcribing: %s", audio_path)
    text, detected_lang = transcriber.transcribe(audio_path, language)
    note = build_note(audio_path, text, detected_lang)

    with open(md_path, "w", encoding="utf-8") as f:
        f.write(note)

    logger.info("Done: %s (lang=%s)", md_path, detected_lang)
    return True


def main():
    parser = argparse.ArgumentParser(
        description="Transcribe an audio file to an Obsidian Markdown note"
    )
    parser.add_argument("audio", help="Path to audio file")
    parser.add_argument("--model", default=os.getenv("MODEL", "small"))
    parser.add_argument("--language", default=os.getenv("LANGUAGE", "auto"))
    args = parser.parse_args()

    transcriber = Transcriber(model_name=args.model)

    try:
        process_file(args.audio, transcriber, args.language)
    except FileNotFoundError as e:
        logger.error("%s", e)
        sys.exit(1)
    except Exception as e:
        logger.error("Transcription failed: %s", e)
        sys.exit(2)


if __name__ == "__main__":
    main()
