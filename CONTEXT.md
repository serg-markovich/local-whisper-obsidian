# CONTEXT.md

Technical snapshot of the `local-whisper-obsidian` repository.
Audit date: 2026-11-23. State: branch `main`, commit `621d3d7`, `git describe` = `v0.4.0-4-g621d3d7`, working tree clean.

## Project Map

```
.
├── .github/workflows/          # ci.yml (ruff + pytest + docker build), release.yml (GitHub Release on v* tags)
├── bin/                        # watcher loops: watch-linux.sh (inotify), watch-macos.sh (fswatch), watch-docker.sh (inotify)
├── docker/                     # Dockerfile (python:3.11-slim pinned by digest), docker-compose.yml, .env.example
├── docs/                       # unraid.md — UNRAID Compose Manager setup guide
├── src/                        # transcribe.py — core: model, note, file processing, CLI
├── systemd/                    # local-whisper-obsidian.service — user unit, Restart=on-failure
├── tests/                      # test_transcribe.py — unit tests for build_note/process_file
├── Makefile                    # install, start/stop/restart/status/logs, test, lint, clean, docker-*
├── install.sh                  # bootstrap: git clone into ~/.local/share/... then make install
├── .env.example                # native config template (make install fills in WHISPER_SRC)
├── requirements.txt            # faster-whisper==1.2.1
├── requirements-dev.txt        # faster-whisper, pytest==8.3.5, ruff==0.9.10
├── pytest.ini                  # pythonpath = .
├── README.md / CHANGELOG.md / CONTRIBUTING.md
└── LICENSE                     # MIT
```

## Entrypoints & Data Flow

### Entrypoints

| Entrypoint | Purpose |
|---|---|
| `python src/transcribe.py <audio> [--model] [--language]` | Transcribe a single file manually or from a watcher |
| `bin/watch-linux.sh` | Linux: `inotifywait -m -e close_write -r`, startup scan, `flock` |
| `bin/watch-macos.sh` | macOS: `fswatch -0`, startup scan, file-size stabilization wait, 5-second deduplication |
| `bin/watch-docker.sh` | Docker entrypoint: `inotifywait`, startup scan, `flock`; config comes only from env |
| `systemd/local-whisper-obsidian.service` | `ExecStart=/bin/bash %h/.config/local-whisper-obsidian/watch.sh` |
| `docker/Dockerfile` | `ENTRYPOINT ["/app/bin/watch-docker.sh"]` |
| `install.sh` | One-command install: clone + `make install` |
| `make` targets | Install/lifecycle/Docker management |

### Data Flow

1. An audio file (`.m4a`, `.mp3`, `.wav`, `.ogg`, `.opus`, `.webm`, `.flac`) appears in one of the `SCAN_PATHS` directories — usually via Syncthing/iCloud or an Obsidian recording.
2. The watcher receives an event: Linux/Docker use `close_write` (protects against partially written files), macOS uses `fswatch` plus a stable-size check.
3. A Bash filter checks the extension with a regex. On Linux/Docker it takes a `flock` lock at `/tmp/whisper-<md5(path)>.lock`; macOS has no lock and processes events sequentially.
4. The watcher starts a **new process**: `python transcribe.py <file> --model ... --language ...`.
5. `process_file()`:
   - checks the extension (otherwise `False`);
   - checks that the file exists (otherwise `FileNotFoundError`);
   - if `<stem>.md` already exists, skips it (idempotency);
   - calls `Transcriber.transcribe()`; the model is loaded lazily on first use;
   - empty text → warning and skip;
   - `build_note()` produces Markdown with YAML frontmatter and a relative wikilink to the audio;
   - writes `<stem>.md` next to the audio file in UTF-8.
6. Logs go to stdout: systemd → journald (`make logs`), macOS → `~/.config/local-whisper-obsidian/whisper.log`, Docker → `docker compose logs`.

On startup all three watchers run a startup scan of the `SCAN_PATHS` directories and process any accumulated files; reprocessing is prevented by the presence of the `.md` file.

### Note Format

YAML frontmatter: `date`, `type: inbox`, `source: voice`, `status: unprocessed`, `language`, `audio` (relative wikilink), `tags: [review]`. Then a heading, a `## Transcript` section, and a `## Action` checklist.

## External Dependencies

### Runtime and System Dependencies

- Python 3.10+ (in practice CI/Docker use 3.11).
- `faster-whisper` / CTranslate2 — CPU inference.
- `inotify-tools` (`inotifywait`) on Linux and in Docker.
- `fswatch` on macOS (`brew install fswatch`).
- `systemd` (user units) — Linux only; Docker/Compose is the alternative.
- `flock`, `find`, `grep`, `md5sum` — standard Linux utilities.

### Network and External Services

- On first run the model is downloaded from Hugging Face Hub into `~/.cache/huggingface` (native) or the `/cache/huggingface` volume (Docker). After that the app works offline.
- There is no database, no third-party API, no cloud service, and no API key.

### Environment Variables

Native (`~/.config/local-whisper-obsidian/.env`):

| Variable | Required | Value / default | Notes |
|---|---|---|---|
| `WHISPER_SRC` | yes | Set by `make install` to `<checkout>/src` | Path to the `src` directory of the cloned repository; validated by the watcher |
| `WHISPER_ENV` | yes | `$HOME/.local/share/local-whisper-obsidian/venv` | Created by `make install` |
| `MODEL` | no | `small` | `tiny`, `base`, `small`, `medium`, `large-v3` |
| `LANGUAGE` | no | `auto` | Language code or `auto` |
| `SCAN_PATHS` | yes | — | Colon-separated directories |
| `WHISPER_CONFIG` | no | `$HOME/.config/local-whisper-obsidian/.env` | Overrides the env-file path |

Docker (`docker/.env`, read by Compose):

| Variable | Required | Notes |
|---|---|---|
| `VAULT_PATH` | yes | Host path to the vault, mounted at `/vault` |
| `SCAN_PATHS` | no | Colon-separated container paths; Compose default is `/vault` |
| `MODEL` | no | Default `small` |
| `LANGUAGE` | no | Default `auto` |
| `CURRENT_UID` / `CURRENT_GID` | yes (Makefile guard) | Runs the container as non-root |
| `HF_HOME` | set in Compose | `/cache/huggingface` |

Compose also runs a one-shot `model-cache-init` container (busybox, root) that chowns `/cache/huggingface` to `CURRENT_UID:CURRENT_GID` before the watcher starts.

## Tech Debt & Risks

### P1 — functional and operational

1. **The model is reloaded for every file.** `Transcriber` caches the model only within a process, while the watcher starts a separate `python` process per file. For `medium`/`large-v3` this adds noticeable latency and load. There is no daemon or queue.
2. **The startup scan is not recursive.** `find "$p" -maxdepth 1` versus the recursive `inotifywait -r`/`fswatch`: files in subdirectories that arrived during downtime are not processed until a new event occurs.
3. **The CHANGELOG lags behind `main`.** Most commits after `v0.4.0` (Docker digest pin, Docker CI job, wikilink fix, pipefail fix, UNRAID docs, Docker cache init, compute-type fix, lint fix) have no `CHANGELOG.md` entry; only the install fix is documented under Unreleased.
4. **macOS is not tested by the author.** The `fswatch` filters (`-e ".*" -i "..."`) and `wait_for_stable` need verification; if a file is deleted, `wait_for_stable` can loop forever (`stat` returns `-1`, so the exit condition is never reached). `[UNKNOWN / NEEDS CHECK]`.

### P2 — hygiene and maintainability

5. **No `pyproject.toml`, `ruff.toml`, type checking, or shellcheck.** `ruff check src/` runs with default rules; tests and shell scripts are not linted.
6. **Narrow test coverage.** `build_note` and `process_file` are covered; there are no tests for `Transcriber`, `main()`, the watcher scripts, the startup scan, or Docker integration. `tests/test_transcribe.py` has an unused `Path` import and duplicate local imports.
7. **`.gitignore` gaps:** no `.pytest_cache/`, `.ruff_cache/`, `.idea/`, `.vscode/`, `*.log`. `.dockerignore` contains `.env`, but whether it covers the nested `docker/.env` depends on Docker pattern semantics — `[UNKNOWN / NEEDS CHECK]`; the Dockerfile does not copy it.
8. **The extension list is duplicated** across Python and three shell scripts — a desynchronization risk.
9. **No automated dependency updates** (no Dependabot/Renovate). Versions are pinned and the base image is pinned by digest.
10. **No reprocess/force mode and no retry queue.** Failures are only logged; retrying is possible only after removing or lacking the `.md`. There are no failure notifications.
11. **`install.sh` is not idempotent** (a repeated `git clone` into the same path fails) and uses the `bash <(curl ...)` pattern — standard, but it requires trusting the source.
12. **Shell scripts are stored in git with mode `100644`.** Running `./bin/watch-linux.sh` directly will not work; `make install` and the Dockerfile run `chmod +x` on their copies. `install.sh` is also not executable.
13. **No version in metadata.** The version is defined only by tags and `CHANGELOG.md`; there is no `__version__`.
14. **`logging.basicConfig()` runs at import time** — using the module as a library overrides the host's logging configuration.

## Revival Effort Estimate

**Low.**

The project consists of one Python file and three Bash scripts with few dependencies; getting it running requires expanding the narrow test coverage and verifying macOS behavior. The full `pytest` + `ruff` cycle takes seconds and needs no GPU, so the repository can be brought back to a working state in one short pass.
