#!/usr/bin/env bash
set -euo pipefail

service="${1:?service is required}"

case "${service}" in
    api) ;;
    *)
        echo "unsupported service: ${service}" >&2
        exit 1
        ;;
esac

image="google-finance-api:latest"
if ! docker image inspect "${image}" >/dev/null 2>&1; then
    docker compose -f docker-compose.prod.yml build "${service}"
fi

docker rm -f googlefinance-api || true
docker compose -f docker-compose.prod.yml up -d --no-build "${service}"
docker compose -f docker-compose.prod.yml ps
