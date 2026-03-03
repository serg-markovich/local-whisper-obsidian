from src.transcribe import build_note


def test_build_note_contains_transcript():
    note = build_note("voice.m4a", "Hello world", "en")
    assert "Hello world" in note


def test_build_note_frontmatter():
    note = build_note("voice.m4a", "Hello world", "en")
    assert "type: inbox" in note
    assert "language: en" in note
    assert "audio: \"[[voice.m4a]]\"" in note


def test_build_note_action_checkbox():
    note = build_note("voice.m4a", "text", "ru")
    assert "- [ ] Process by:" in note
