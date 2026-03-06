from pathlib import Path
from unittest.mock import MagicMock

import pytest

from src.transcribe import Transcriber, build_note, process_file


def test_build_note_contains_transcript():
    note = build_note("voice.m4a", "Hello world", "en")
    assert "Hello world" in note


def test_build_note_frontmatter():
    note = build_note("voice.m4a", "Hello world", "en")
    assert "type: inbox" in note
    assert "language: en" in note
    assert 'audio: "[[voice.m4a]]"' in note


def test_build_note_action_checkbox():
    note = build_note("voice.m4a", "text", "ru")
    assert "- [ ] Process by:" in note


def test_process_file_creates_note(tmp_path):
    audio = tmp_path / "voice.m4a"
    audio.touch()
    transcriber = MagicMock(spec=Transcriber)
    transcriber.transcribe.return_value = ("Hello world", "en")
    result = process_file(str(audio), transcriber, "auto")
    assert result is True
    md_file = tmp_path / "voice.md"
    assert md_file.exists()
    assert "Hello world" in md_file.read_text()


def test_process_file_skips_existing_note(tmp_path):
    audio = tmp_path / "voice.m4a"
    audio.touch()
    (tmp_path / "voice.md").touch()
    transcriber = MagicMock(spec=Transcriber)
    result = process_file(str(audio), transcriber, "auto")
    assert result is False
    transcriber.transcribe.assert_not_called()


def test_process_file_unsupported_format(tmp_path):
    audio = tmp_path / "voice.txt"
    audio.touch()
    transcriber = MagicMock(spec=Transcriber)
    result = process_file(str(audio), transcriber, "auto")
    assert result is False


def test_process_file_not_found():
    transcriber = MagicMock(spec=Transcriber)
    with pytest.raises(FileNotFoundError):
        process_file("/nonexistent/voice.m4a", transcriber, "auto")

def test_process_file_skips_empty_transcription(tmp_path):
    from unittest.mock import MagicMock
    from src.transcribe import process_file, Transcriber

    audio = tmp_path / "voice.m4a"
    audio.touch()
    transcriber = MagicMock(spec=Transcriber)
    transcriber.transcribe.return_value = ("", "en")

    result = process_file(str(audio), transcriber, "auto")

    assert result is False
    assert not (tmp_path / "voice.md").exists()
