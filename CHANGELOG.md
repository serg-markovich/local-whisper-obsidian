# Changelog

## [v0.2.0] - 2026-03-03

### Fixed
- macOS: removed `flock` (Linux-only), added `fswatch` dependency check with install hint
- Apple Silicon: auto-detect `float16` compute type for M1/M2/M3

### Improved
- CLI: added help text for `--model` and `--language` arguments
- README: added macOS prerequisites, First run model download warning

### Tests
- Added edge case tests for `process_file()`: skip existing, unsupported format, file not found

## [v0.1.0] - 2026-03-03

### Added
- Local audio transcription via `faster-whisper`
- Obsidian-ready Markdown output with YAML frontmatter
- Docker support (`Dockerfile` + `docker-compose.yml`)
- Watch mode for Linux and macOS
- CI workflow via GitHub Actions (lint + tests)
- Unit tests with `pytest`
- Code linting with `ruff`
