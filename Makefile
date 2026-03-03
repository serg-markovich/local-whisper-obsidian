.PHONY: install start stop restart status logs test lint clean docker-build docker-up docker-down docker-logs docker-restart


CONFIG_DIR  := $(HOME)/.config/local-whisper-obsidian
SYSTEMD_DIR := $(HOME)/.config/systemd/user
VENV_DIR    := $(HOME)/.local/share/local-whisper-obsidian/venv
OS          := $(shell uname -s)


install:
	@echo "Installing local-whisper-obsidian..."
	mkdir -p $(CONFIG_DIR) $(SYSTEMD_DIR)
	python3 -m venv $(VENV_DIR)
	$(VENV_DIR)/bin/pip install -q --upgrade pip
	$(VENV_DIR)/bin/pip install -q -r requirements.txt
ifeq ($(OS),Linux)
	sudo apt-get install -q -y inotify-tools
	cp bin/watch-linux.sh $(CONFIG_DIR)/watch.sh
else ifeq ($(OS),Darwin)
	@which fswatch > /dev/null || brew install fswatch
	cp bin/watch-macos.sh $(CONFIG_DIR)/watch.sh
endif
	chmod +x $(CONFIG_DIR)/watch.sh
	@[ -f $(CONFIG_DIR)/.env ] \
		|| (cp .env.example $(CONFIG_DIR)/.env \
			&& echo "Config created. Edit before starting: nano $(CONFIG_DIR)/.env")
	cp systemd/local-whisper-obsidian.service $(SYSTEMD_DIR)/
	systemctl --user daemon-reload
	systemctl --user enable local-whisper-obsidian
	@echo "Done. Edit config, then: make start"


start:
	systemctl --user start local-whisper-obsidian


stop:
	systemctl --user stop local-whisper-obsidian


restart:
	systemctl --user restart local-whisper-obsidian


status:
	systemctl --user status local-whisper-obsidian


logs:
	journalctl --user -u local-whisper-obsidian -f


test:
	$(VENV_DIR)/bin/pip install -q pytest
	$(VENV_DIR)/bin/pytest tests/ -v


lint:
	$(VENV_DIR)/bin/pip install -q ruff
	$(VENV_DIR)/bin/ruff check src/


clean:
	rm -f tests/*.md
	find . -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true


docker-build:
	@test -f docker/.env || { echo "Error: docker/.env not found. Run: cp docker/.env.example docker/.env"; exit 1; }
	docker compose -f docker/docker-compose.yml --env-file docker/.env build


docker-up:
	@test -f docker/.env || { echo "Error: docker/.env not found. Run: cp docker/.env.example docker/.env"; exit 1; }
	docker compose -f docker/docker-compose.yml --env-file docker/.env up -d


docker-down:
	docker compose -f docker/docker-compose.yml --env-file docker/.env down


docker-restart:
	docker compose -f docker/docker-compose.yml --env-file docker/.env restart


docker-logs:
	docker compose -f docker/docker-compose.yml logs -f
