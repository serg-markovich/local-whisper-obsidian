# UNRAID / Docker Compose setup

This guide describes how to run **local-whisper-obsidian** with Docker Compose on UNRAID.

> **Note:** This setup has been tested on Linux, not on UNRAID itself. If you use UNRAID and hit an issue, please open an issue with the relevant container logs.

## 1. Clone the repository

Clone the repository to a persistent location, for example:

```bash
git clone https://github.com/serg-markovich/local-whisper-obsidian.git /mnt/user/appdata/local-whisper-obsidian
```

The Compose file builds the image from the repository, so keep the full checkout available.

## 2. Create the environment file

Copy the example configuration:

```bash
cp docker/.env.example docker/.env
```

Edit `docker/.env` and set:

```env
VAULT_PATH=/mnt/user/appdata/obsidian-vault
MODEL=small
LANGUAGE=auto
SCAN_PATHS=/vault/0_inbox
CURRENT_UID=99
CURRENT_GID=100
```

- `VAULT_PATH` must point to an existing Obsidian vault directory on the UNRAID host.
- `SCAN_PATHS` uses paths **inside the container**. With the default mount, `/vault` corresponds to `VAULT_PATH` on the host.
- `CURRENT_UID` and `CURRENT_GID` prevent created Markdown files from being owned by `root`. On a typical UNRAID setup, `99:100` is commonly used, but verify the ownership of your vault share first.

## 3. Configure Compose Manager

In UNRAID Compose Manager, use:

- **Compose file:** `/mnt/user/appdata/local-whisper-obsidian/docker/docker-compose.yml`
- **ENV file:** `/mnt/user/appdata/local-whisper-obsidian/docker/.env`

The Compose file builds the image from the repository root:

```yaml
build:
  context: ..
  dockerfile: docker/Dockerfile
```

Therefore, both the Compose file and the `.env` file must remain inside the cloned repository.

## 4. Start the stack

Start the Compose stack from UNRAID. On first start, Docker will build the image and download the selected Whisper model into the `whisper_models` volume.

Check the container logs for model loading and transcription messages.

## 5. Verify transcription

Place a supported audio file into the configured inbox directory, for example:

```text
/mnt/user/appdata/obsidian-vault/0_inbox/voice-note.m4a
```

After processing, a Markdown note should appear next to the audio file:

```text
/mnt/user/appdata/obsidian-vault/0_inbox/voice-note.md
```

## Troubleshooting

- **Permission denied / root-owned files:** set `CURRENT_UID` and `CURRENT_GID` to the owner of the vault directory.
- **No files are processed:** ensure `SCAN_PATHS` points to a directory that exists inside the container.
- **Model download fails:** check available disk space and container logs; model files are stored in the `whisper_models` Docker volume.
- **Compose build fails:** make sure the full repository was cloned and that the Compose file path points to `docker/docker-compose.yml`.
