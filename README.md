# local-whisper-obsidian

Local voice-to-Obsidian transcription pipeline. No cloud. No API keys. No subscriptions.

Record voice memos on your phone, sync them via Syncthing or iCloud, and let
[Faster Whisper](https://github.com/SYSTRAN/faster-whisper) transcribe them automatically into
structured Markdown notes inside your Obsidian vault. Everything runs locally on CPU.

![CI](https://github.com/serg-markovich/local-whisper-obsidian/actions/workflows/ci.yml/badge.svg)
![Python](https://img.shields.io/badge/python-3.11-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## Status

**`[PROTOTYPE]`** — the core pipeline, install flow, and Docker deployment work; macOS remains unverified and test coverage is narrow.

## Overview

The project solves the "voice → text → note" problem without cloud services, subscriptions, or API keys:

- watches vault directories (Linux: `inotifywait`, macOS: `fswatch`, Docker: `inotifywait`);
- transcribes new audio files locally with `faster-whisper`;
- creates a `.md` file next to the audio with YAML frontmatter, a relative wikilink to the source file, and a checklist;
- skips already processed files (a sibling `.md` exists) and empty transcriptions;
- scans the directories on startup and picks up files that accumulated while the service was offline.

## How it works

```
Voice memo (.m4a / .mp3 / .wav / .ogg / .opus / .webm / .flac)
        |
  inotifywait (Linux) / fswatch (macOS)   <-- watches SCAN_PATHS
        |
  flock / event deduplication
        |
  faster-whisper (CPU, fully local)
        |
  Markdown note with YAML frontmatter
        |
  Obsidian inbox
```

## Requirements

- Python 3.10+ (CI and Docker use 3.11)
- Ubuntu 22.04+ or macOS 13+
- Obsidian with mobile sync (Syncthing or iCloud)
- Linux: `inotify-tools` (installed by `make install`)
- macOS: `fswatch` (`brew install fswatch`; `make install` will try to install it)
- Docker option: Docker and Docker Compose

> **macOS note:** macOS support is maintained but not actively tested by the author
> (Linux-only setup). Bug reports and PRs from macOS users are welcome.

## First run

On first use, the selected model is downloaded automatically (~75 MB for `tiny`, up to 3 GB for `large-v3`). After that the app works offline.

To free space after switching models:

```bash
rm -rf ~/.cache/huggingface/hub/models--Systran--faster-whisper-*
```

## Quick Start

```bash
git clone https://github.com/serg-markovich/local-whisper-obsidian
cd local-whisper-obsidian
make install
nano ~/.config/local-whisper-obsidian/.env
make start
make logs
```

`make install` writes `WHISPER_SRC` pointing at this checkout automatically. Review the config and set the remaining paths:

```bash
WHISPER_SRC=/home/user/projects/local-whisper-obsidian/src
WHISPER_ENV=/home/user/.local/share/local-whisper-obsidian/venv
MODEL=small
LANGUAGE=auto
SCAN_PATHS=/home/user/vault/0_inbox:/home/user/vault/1_journal/assets
```

> **Config note:** `make install` adds `WHISPER_SRC` to the config. If you create the config manually, set it yourself; the watcher exits with a clear error when it is missing or does not contain `transcribe.py`.

## Configuration

All native-install settings live in `~/.config/local-whisper-obsidian/.env` (created by `make install`):

| Variable      | Default | Description                                        |
|---------------|---------|-----------------------------------------------------|
| `WHISPER_SRC` | —       | Path to the `src` directory of the cloned repository, e.g. `~/projects/local-whisper-obsidian/src` (required; `make install` sets it automatically) |
| `WHISPER_ENV` | auto    | Path to the Python venv (set by `make install`)     |
| `MODEL`       | `small` | Whisper model size (see the table below)            |
| `LANGUAGE`    | `auto`  | Language code (`en`, `de`, `uk`, `ru`) or `auto`    |
| `SCAN_PATHS`  | —       | Directories to watch, separated by `:`              |

Additionally, the watchers understand `WHISPER_CONFIG` — a path to an alternative env file.

### Model selection

| Model      | Size   | Speed (CPU) | Accuracy | Recommended for                  |
|------------|--------|-------------|----------|----------------------------------|
| `tiny`     | 75 MB  | very fast   | low      | Quick tests                      |
| `base`     | 145 MB | fast        | medium   | Short notes, clear audio         |
| `small`    | 460 MB | moderate    | good     | Daily use (default)              |
| `medium`   | 1.5 GB | slow        | better   | Important recordings             |
| `large-v3` | 3 GB   | very slow   | best     | GPU only, not recommended on CPU |

To change the model, edit the config and restart the service:

```bash
nano ~/.config/local-whisper-obsidian/.env
# set MODEL=medium
make restart
```

## Commands

```bash
make install    # install dependencies and register systemd service (Linux) / copy watcher (macOS)
make config     # create or update the user config and fill in WHISPER_SRC
make start      # start the watcher
make stop       # stop the watcher
make restart    # restart after config changes
make status     # service status
make logs       # live logs via journalctl (Linux) or tail (macOS)
make test       # run unit tests
make lint       # check code style with ruff
make clean      # remove test artifacts
```

Transcribe a single file without the watcher:

```bash
python src/transcribe.py path/to/voice.m4a --model small --language auto
```

CLI exit codes: `0` — success or skip, `1` — file not found, `2` — transcription error.

## Stack

`faster-whisper` · `systemd` · `inotify-tools` · `fswatch` · `Python 3.11` · `pytest` · `ruff` · Docker

## Installation (Docker / NAS)

For NAS setups (Unraid, Synology, QNAP) or any host where you prefer not to install Python and system dependencies. For UNRAID specifically, see [docs/unraid.md](docs/unraid.md) (community-tested status: unverified).

**Prerequisites:** Docker and Docker Compose. For autostart after reboot, enable the Docker daemon:

```bash
sudo systemctl enable docker
```

**Quick start:**

```bash
cp docker/.env.example docker/.env
nano docker/.env   # set VAULT_PATH, SCAN_PATHS, then run id -u && id -g for CURRENT_UID/GID
make docker-build
make docker-up
make docker-logs
```

**Configuration** via `docker/.env`:

| Variable      | Default  | Description                                          |
|---------------|----------|------------------------------------------------------|
| `VAULT_PATH`  | —        | Absolute path to your Obsidian vault on the host     |
| `MODEL`       | `small`  | Whisper model size (see the model table above)       |
| `LANGUAGE`    | `auto`   | Language code or `auto`                              |
| `SCAN_PATHS`  | `/vault` | **Container-side** paths, separated by `:`           |
| `CURRENT_UID` | —        | Host user ID — run `id -u`                           |
| `CURRENT_GID` | —        | Host group ID — run `id -g`                          |

> **Why CURRENT_UID/GID?** Without them, transcribed `.md` files are created as `root:root` inside the mounted volume. These values ensure the output files are owned by your host user.

> **Paths:** `SCAN_PATHS` uses container-side paths. If you mount `/home/user/vault:/vault`, set `SCAN_PATHS=/vault/0_inbox`.

> **Model cache:** stored in the Docker volume `whisper_models` — it survives restarts, so there is no re-download on `docker compose up`. Compose starts a one-shot `model-cache-init` container that chowns the volume to `CURRENT_UID:CURRENT_GID` before the watcher starts.

> **Changing models:** old model files are not deleted automatically. To free disk space:

>     docker volume rm local-whisper-obsidian_whisper_models

> **GPU:** CPU-only image. GPU acceleration is not supported.

**Docker commands:**

```bash
make docker-build      # build the image
make docker-up         # start in background
make docker-down       # stop
make docker-restart    # restart after config changes
make docker-logs       # live logs
```

## Status & Roadmap

### Working

- Single audio file → Markdown with YAML frontmatter and a relative wikilink.
- Idempotency: an existing `<stem>.md` means "already processed"; empty transcriptions are skipped.
- Linux watcher: `close_write`, per-file `flock`, startup scan, error handling that does not crash the loop.
- Native install: `make install` creates the config and sets `WHISPER_SRC` automatically; watchers fail with a clear error if the path is missing or invalid.
- Docker: image based on `python:3.11-slim` (pinned digest), Compose with a non-root user and a model-cache volume; CI builds the image.
- systemd user unit with `Restart=on-failure` and `KillMode=control-group`.
- CI: `ruff check src/`, `pytest tests/ -v`, Docker build. Release workflow on `v*` tags.
- macOS watcher implemented (fswatch, stable-size wait, deduplication, Full Disk Access check).

### Broken / Incomplete

- **Startup scan** uses `find -maxdepth 1`, while the watcher is recursive: subdirectory files may be missed after downtime.
- **macOS** is not tested by the author; `fswatch` filter behavior and a possible `wait_for_stable` loop when a file is deleted are unverified.
- **The model is reloaded for every file** (a separate `python` process per file) — slow for `medium`/`large-v3`.
- No tests for the watcher scripts, `main()`, or `Transcriber`; no shellcheck and no ruff configuration.

### Next Steps

1. Add an end-to-end Docker smoke test with a sample audio file (covers `model-cache-init` and transcription), and expose it as a `make` target.
2. Make the startup scan recursive, move the extension list to a single source, and add watcher integration tests + shellcheck.
3. Add `ruff.toml` (or `pyproject.toml`) and extend tests to `main()` and `Transcriber`.

## My setup

- Model: `medium` — better accuracy for multilingual notes
- Sync: Syncthing (Android → Linux)
- Vault structure: `0_inbox` for new voice notes, `7_system/files` for Obsidian desktop recordings
- Native install (systemd) on laptop, Docker for NAS/homelab deployments

## Eigenstack

This project is built around the [eigenstack](https://github.com/serg-markovich/eigenstack)
philosophy — privacy-first, local-first infrastructure where every service
runs on your own hardware, no cloud dependencies, no vendor lock-in.

**Related projects:**
- [eigenstack](https://github.com/serg-markovich/eigenstack) — architecture overview
- [whisper-ollama-enricher](https://github.com/serg-markovich/whisper-ollama-enricher) — stage 2: AI enrichment (titles, tags, summaries)
- [openwebui-systemd-stack](https://github.com/serg-markovich/openwebui-systemd-stack) — Ollama + Open WebUI on Linux

## Contributing

See `CONTRIBUTING.md`: conventional commits and `make test && make lint` before a PR.

## License

MIT
