#!/bin/bash
# Quick install:
#   bash <(curl -fsSL https://raw.githubusercontent.com/serg-markovich/local-whisper-obsidian/main/install.sh)
set -e
git clone https://github.com/serg-markovich/local-whisper-obsidian.git \
    "$HOME/.local/share/local-whisper-obsidian-src"
cd "$HOME/.local/share/local-whisper-obsidian-src"
make install
echo "Setup is finished. Edit your config and start the service:"
echo "  nano ~/.config/local-whisper-obsidian/.env"
echo "  make start"
