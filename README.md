# local-whisper-obsidian

Local voice-to-Obsidian transcription pipeline. No cloud. No API keys. No subscriptions.

Records voice memos on mobile, syncs via Syncthing or iCloud, transcribes automatically
via [Faster Whisper](https://github.com/SYSTRAN/faster-whisper), and creates structured
Markdown notes directly in your Obsidian vault.

![CI](https://github.com/serg-markovich/local-whisper-obsidian/actions/workflows/ci.yml/badge.svg)
![Python](https://img.shields.io/badge/python-3.11-blue)
![License](https://img.shields.io/badge/license-MIT-green)

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
- macOS: `brew install fswatch` (required for watch mode)

## First run

On first use, the selected model is downloaded automatically (~75 MB for `tiny`, up to 3 GB for `large-v3`).
To free space after switching models:

```bash
rm -rf ~/.cache/huggingface/hub/models--Systran--faster-whisper-*
```

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
|---------------|---------|-----------------------------------------------------|
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

| Model      | Size   | Speed (CPU) | Accuracy | Recommended for                  |
|------------|--------|-------------|----------|----------------------------------|
| `tiny`     | 75 MB  | very fast   | low      | Quick tests                      |
| `base`     | 145 MB | fast        | medium   | Short notes, clear audio         |
| `small`    | 460 MB | moderate    | good     | Daily use (default)              |
| `medium`   | 1.5 GB | slow        | better   | Important recordings             |
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

## Installation (Docker / NAS)

For NAS setups (Unraid, Synology, QNAP) or any host where you prefer
not to install Python and system dependencies.

**Prerequisites:** Docker and Docker Compose installed on the host.
For autostart after reboot, ensure Docker daemon is enabled:

```bash
sudo systemctl enable docker
```

**Quick start:**

```bash
cp docker/.env.example docker/.env
nano docker/.env        # set VAULT_PATH, SCAN_PATHS, CURRENT_UID, CURRENT_GID
make docker-build
make docker-up
make docker-logs
```

**Configuration** via `docker/.env`:

| Variable      | Default  | Description                                          |
|---------------|----------|------------------------------------------------------|
| `VAULT_PATH`  | —        | Absolute path to your Obsidian vault on the host     |
| `MODEL`       | `small`  | Whisper model size (see Model selection table above) |
| `LANGUAGE`    | `auto`   | Language code or `auto`                              |
| `SCAN_PATHS`  | `/vault` | Colon-separated paths **inside** the container       |
| `CURRENT_UID` | `1000`   | Host user ID — run `id -u` to get your value         |
| `CURRENT_GID` | `1000`   | Host group ID — run `id -g` to get your value        |

> **Why CURRENT_UID/GID?** Without this, transcribed `.md` files are created
> as `root:root` inside the mounted volume. Setting these values ensures
> output files are owned by your host user.

> **Paths:** `SCAN_PATHS` uses container-side paths. If you mount
> `/home/user/vault:/vault`, set `SCAN_PATHS=/vault/0_inbox`.

> **Model cache:** Stored in Docker volume `whisper_models` — survives
> restarts, no re-download on `docker compose up`.

> **Changing models:** When switching models, old model files are not deleted
> automatically. To free disk space:
>
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

## My setup

- Model: `medium` — better accuracy for multilingual notes
- Sync: Syncthing (Android → Linux)
- Vault structure: `0_inbox` for new voice notes, `7_system/files` for Obsidian desktop recordings
- Native install (systemd) on laptop, Docker for NAS/homelab deployments

## License

MIT