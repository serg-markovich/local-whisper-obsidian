# Contributing

Contributions are welcome. Here is how to get started.

## Setup

\```bash
git clone https://github.com/serg-markovich/local-whisper-obsidian
cd local-whisper-obsidian
make install
\```

## Running tests

\```bash
make test
make lint
\```

## Submitting changes

1. Fork the repository
2. Create a branch: `git checkout -b fix/your-fix-name`
3. Make your changes
4. Run tests: `make test && make lint`
5. Commit: `git commit -m "fix: description of your change"`
6. Open a Pull Request against `main`

## Commit message format

Use conventional commits: `feat:`, `fix:`, `docs:`, `refactor:`
