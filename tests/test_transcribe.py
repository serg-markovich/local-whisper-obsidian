"""Unit tests for local-whisper-obsidian transcription module."""
import sys
from pathlib import Path
from unittest.mock import MagicMock

sys.path.insert(0, str(Path(__file__).parent.parent / "src"))

from transcribe import build_note, process_file


def test_build_note_contains_transcript():
    note = build_note("/vault/rec.m4a", "Hello world", "en")
    assert "Hello world" in note
    assert "rec.m4a" in note
    assert "language: en" in note


def test_build_note_has_frontmatter():
    note = build_note("/vault/rec.m4a", "test", "de")
    assert note.startswith("---")
    assert "type: inbox" in note
    assert "source: voice" in note


def test_process_file_skips_unsupported():
    transcriber = MagicMock()
    result = process_file("/vault/image.png", transcriber, "auto")
    assert result is False
    transcriber.transcribe.assert_not_called()


def test_process_file_skips_existing_md(tmp_path):
    audio = tmp_path / "rec.m4a"
    md = tmp_path / "rec.md"
    audio.touch()
    md.write_text("existing")
    transcriber = MagicMock()
    result = process_file(str(audio), transcriber, "auto")
    assert result is False


def test_process_file_raises_if_missing():
    transcriber = MagicMock()
    try:
        process_file("/nonexistent/rec.m4a", transcriber, "auto")
        assert False, "Should have raised FileNotFoundError"
    except FileNotFoundError:
        pass


def test_process_file_creates_md(tmp_path):
    audio = tmp_path / "rec.m4a"
    audio.touch()
    transcriber = MagicMock()
    transcriber.transcribe.return_value = ("Hello world", "en")
    result = process_file(str(audio), transcriber, "auto")
    assert result is True
    md = tmp_path / "rec.md"
    assert md.exists()
    assert "Hello world" in md.read_text()
