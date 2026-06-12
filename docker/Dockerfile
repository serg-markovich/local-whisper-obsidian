FROM python:3.11-slim@sha256:f9fa7f851e38bfb19c9de3afbc4b86ae7176ea7aaf94535c31df5458d5849457

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
