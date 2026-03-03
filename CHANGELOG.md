# Changelog

All notable changes to this project will be documented in this file.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [0.3.0] - 2026-03-03

### Fixed
- Docker volume files created as `root:root` on host — fixed via `CURRENT_UID/GID` in `docker/.env`
- Model cache moved from `/root/.cache` to `/cache/huggingface` — accessible by non-root user
- macOS watcher: replaced fixed `sleep` with `wait_for_stable` (polls file size until stable)
- macOS watcher: added deduplication for repeated fswatch events on same file
- macOS watcher: added Full Disk Access check with actionable error message

### Changed
- `Makefile`: all systemd commands branched by OS — macOS uses `nohup` + PID file
- `Makefile`: added guards on `docker-up` and `docker-build` for missing `.env`
- `Makefile`: added `docker-restart` target
- `docker/.env.example`: empty `CURRENT_UID/GID` to force explicit configuration

## [0.2.0] - 2026-03-02

### Added
- Docker support: `docker/Dockerfile`, `docker/docker-compose.yml`
- Model cache volume — no re-downloading on restart
- `make docker-build`, `make docker-up`, `make docker-down`, `make docker-logs`
- Docker entrypoint `bin/watch-docker.sh` — reads config from env vars

### Fixed
- macOS watcher: removed `flock` (Linux-only) — `fswatch` processes events sequentially
- macOS watcher: added explicit `fswatch` dependency check with install instructions
- Apple Silicon: auto-detect `float16` compute type for M1/M2/M3

## [0.1.0] - 2026-02-26

### Added
- Initial release
- Local voice transcription pipeline: inotifywait (Linux) / fswatch (macOS)
- Faster Whisper CPU transcription with configurable model size
- Markdown note output with YAML frontmatter and wikilink to source audio
- systemd user service with `KillMode=control-group`
- `Makefile` with install, start, stop, restart, status, logs targets
- CI: ruff lint + pytest on every push
- `close_write` event instead of `create` — prevents partial file transcription
- `flock` per-file locking on Linux — prevents parallel processing of same file
