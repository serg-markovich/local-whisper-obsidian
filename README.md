# local-whisper-obsidian

Local voice-to-Obsidian transcription pipeline. No cloud. No API keys. No subscriptions.

Records voice memos on mobile, syncs via Syncthing or iCloud, transcribes automatically
via [Faster Whisper](https://github.com/SYSTRAN/faster-whisper), and creates structured
Markdown notes directly in your Obsidian vault.

![CI](https://github.com/serg-markovich/local-whisper-obsidian/actions/workflows/ci.yml/badge.svg)

## How it works

```
Voice memo (.m4a / .mp3 / .wav)
        |
  inotifywait (Linux) / fswatch (macOS)   <-- watches configured paths
        |
  faster-whisper (CPU, fully local)
        |
  Markdown note with YAML frontmatter
        |
  Obsidian inbox
```

## Requirements

- Python 3.10+
- Ubuntu 22.04+ or macOS 13+
- Obsidian with mobile sync (Syncthing or iCloud)

## Quick start

```bash
git clone https://github.com/serg-markovich/local-whisper-obsidian
cd local-whisper-obsidian
make install
nano ~/.config/local-whisper-obsidian/.env
make start
make logs
```

## Configuration

All settings live in `~/.config/local-whisper-obsidian/.env` (created by `make install`):

| Variable      | Default | Description                                        |
|---------------|---------|----------------------------------------------------|
| `WHISPER_SRC` | —       | Path to cloned repo, e.g. `~/projects/local-whisper-obsidian/src` |
| `WHISPER_ENV` | auto    | Path to Python venv (set by make install)          |
| `MODEL`       | `small` | Whisper model size (see table below)               |
| `LANGUAGE`    | `auto`  | Language code (`en`, `de`, `uk`, `ru`) or `auto`   |
| `SCAN_PATHS`  | —       | Colon-separated paths to watch                     |

Example:
```bash
WHISPER_SRC=/home/user/projects/local-whisper-obsidian/src
WHISPER_ENV=/home/user/.local/share/local-whisper-obsidian/venv
MODEL=small
LANGUAGE=auto
SCAN_PATHS=/home/user/vault/0_inbox:/home/user/vault/1_journal/assets
```

### Model selection

| Model      | Size   | Speed (CPU) | Accuracy | Recommended for               |
|------------|--------|-------------|----------|-------------------------------|
| `tiny`     | 75 MB  | very fast   | low      | Quick tests                   |
| `base`     | 145 MB | fast        | medium   | Short notes, clear audio      |
| `small`    | 460 MB | moderate    | good     | Daily use (default)           |
| `medium`   | 1.5 GB | slow        | better   | Important recordings          |
| `large-v3` | 3 GB   | very slow   | best     | GPU only, not recommended on CPU |

To change the model, edit your config and restart:

```bash
nano ~/.config/local-whisper-obsidian/.env
# set MODEL=medium
make restart
```

## Commands

```bash
make install    # install dependencies and register systemd service
make start      # start the watcher
make stop       # stop the watcher
make restart    # restart after config changes
make status     # service status
make logs       # live logs via journalctl
make test       # run unit tests
make lint       # check code style with ruff
make clean      # remove test artifacts
```

## Stack

`faster-whisper` · `systemd` · `inotify-tools` · `fswatch` · `Python 3.11` · `pytest` · `ruff`

## Author's setup

- Model: `medium` — better accuracy for multilingual notes (Ukrainian, Russian, German)
- Sync: Syncthing (Android → Linux)
- Vault structure: `0_inbox` for new voice notes, `7_system/files` for Obsidian mobile recordings

## License

MIT
