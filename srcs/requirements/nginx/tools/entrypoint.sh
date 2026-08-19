#!/bin/bash
set -euo pipefail

: "${DOMAIN_NAME:?DOMAIN_NAME is required}"

CERT_DIR="/etc/nginx/ssl"
CERT_FILE="${CERT_DIR}/nginx.crt"
KEY_FILE="${CERT_DIR}/nginx.key"

mkdir -p "$CERT_DIR"

if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
    echo "Generating self-signed TLS certificate for ${DOMAIN_NAME}"

    openssl req -x509 -nodes -newkey rsa:2048 -sha256 -days 365 \
        -keyout "$KEY_FILE" \
        -out "$CERT_FILE" \
        -subj "/C=MA/O=42/OU=Inception/CN=${DOMAIN_NAME}" \
        -addext "subjectAltName=DNS:${DOMAIN_NAME}"

    chmod 600 "$KEY_FILE"
fi

nginx -t

exec nginx -g 'daemon off;'
