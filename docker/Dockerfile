FROM python:3.11-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends inotify-tools \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src/ ./src/
COPY bin/watch-docker.sh ./bin/watch-docker.sh
RUN chmod +x /app/bin/watch-docker.sh

ENV MODEL=small \
    LANGUAGE=auto \
    SCAN_PATHS=/vault

ENTRYPOINT ["/app/bin/watch-docker.sh"]
