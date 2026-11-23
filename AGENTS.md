# AGENTS.md

Rules and environment for AI assistants working in this repository.
Based on the state of `main` @ `621d3d7` (snapshot taken 2026-11-23).

## Tech Stack

- **Language:** Python 3.11 (CI and Docker); the README claims 3.10+, and the `str | None` syntax requires Python ≥ 3.10.
- **Transcription:** `faster-whisper==1.2.1` (CPU, CTranslate2 backend; GPU is not supported).
- **Glue:** Bash (`set -euo pipefail`), `inotify-tools` (Linux), `fswatch` (macOS), `systemd` user units, Docker + Docker Compose.
- **Package manager:** `pip` + `venv`; there is no `pyproject.toml`. Dependencies live in `requirements.txt` and `requirements-dev.txt`.
- **Tooling:** `pytest==8.3.5`, `ruff==0.9.10`; the `Makefile` is the main task runner. CI: GitHub Actions (`.github/workflows/ci.yml`, `release.yml`).
- **Versioning:** git tags (`v0.1.0`…`v0.4.0`) + `CHANGELOG.md`; there is no version in the code or package metadata.

## Commands

| Task | Command |
|---|---|
| Install (Linux/macOS, system-level) | `make install` |
| Create/update user config | `make config` |
| Dev dependencies | `python3 -m venv .venv && . .venv/bin/activate && pip install -r requirements-dev.txt` |
| Tests | `make test` or `pytest tests/ -v` (`pytest.ini`: `pythonpath = .`) |
| Lint | `make lint` or `ruff check src/` |
| Transcribe a single file | `python src/transcribe.py path/to/voice.m4a --model small --language auto` |
| Docker build | `make docker-build` (requires `docker/.env`) |
| Docker lifecycle | `make docker-up` / `make docker-down` / `make docker-restart` / `make docker-logs` |
| Clean artifacts | `make clean` |

- `make install` modifies the system: it creates a venv in `~/.local/share/local-whisper-obsidian/venv`, installs `inotify-tools` via `sudo apt-get`, copies the watcher to `~/.config/local-whisper-obsidian/`, and registers and enables a systemd user unit. Do not run it in a sandbox or CI without explicit intent.
- There is no dev server and no build step: this is a CLI plus a background watcher.
- On macOS the `Makefile` uses `nohup` + a PID file; systemd commands do not apply there.
- `make test` and `make lint` install `pytest`/`ruff` into the `WHISPER_ENV` venv, so they require a prior `make install`.

## Architecture & Boundaries

- `src/transcribe.py` — **all business logic**: lazy model loading (`Transcriber`), note generation (`build_note`), single-file processing (`process_file`), and the CLI (`main`). Add new transcription logic and note-format logic here.
- `bin/watch-linux.sh`, `bin/watch-macos.sh`, `bin/watch-docker.sh` — **filesystem event adapters**. They only load config, validate paths, run the startup scan, filter extensions, manage lock files, and invoke the CLI per file. Do not duplicate note logic here.
- `systemd/` — Linux packaging; `docker/` — Dockerfile and Compose; `docs/` — deployment guides such as UNRAID; `Makefile` — installation and lifecycle; `.github/workflows/` — CI and release.
- `tests/` — unit tests for pure functions and `process_file` with `MagicMock`; the real model is never loaded.
- Configuration is env-file based: `~/.config/local-whisper-obsidian/.env` (native) and `docker/.env` (Docker). Templates: `.env.example`, `docker/.env.example`.

## Coding Conventions & Guardrails

- **Python:** type hints on public functions, stdlib `logging` (output to stdout), f-strings, explicit `encoding="utf-8"` when writing files. Keep the heavy `faster_whisper` import lazy — importing the module and running tests must not pull in the model.
- **Shell:** `set -euo pipefail`, quote variables, exit early when config or valid paths are missing. Log a transcription failure and continue the loop; do not crash the watcher.
- **CLI exit codes:** `1` — file not found, `2` — transcription error. Do not change them without updating tests and documentation.
- **Note frontmatter** (`date`, `type`, `source`, `status`, `language`, `audio`, `tags`) is a public contract for Obsidian. When changing keys or format, update `build_note`, the tests, and the README together.
- **Idempotency:** the presence of `<stem>.md` next to the audio file is the only "already processed" signal. Do not change this behavior without tests.
- **The extension list is duplicated:** `SUPPORTED_EXTENSIONS` in `src/transcribe.py` plus regexes in the three watcher scripts. When adding a format, update every location.
- **Watcher env contract:** `WHISPER_SRC`, `WHISPER_ENV`, `MODEL`, `LANGUAGE`, `SCAN_PATHS`; optional `WHISPER_CONFIG`. `make install` writes `WHISPER_SRC` pointing at this checkout, and the watchers validate it at startup. Keep that behavior; a fresh install must not require manual env setup.
- **Do not commit:** `.env`, audio, models, generated `.md` files, caches. `.gitignore` covers the main cases but not all of them (see `CONTEXT.md`).
- **Before committing:** run `make test && make lint` (or `pytest tests/ -v && ruff check src/`). Commit messages follow conventional commits (`feat:`, `fix:`, `docs:`, `refactor:`), see `CONTRIBUTING.md`.
- **Do not add** `pyproject.toml`, a new framework, or a database without a separate decision: the project is intentionally minimal.
- macOS code is not tested by the author; mark changes as `[UNKNOWN / NEEDS CHECK]` and verify them on real macOS.
