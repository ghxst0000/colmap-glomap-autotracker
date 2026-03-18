#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
SAMPLE_FILE="$SCRIPT_DIR/.env.sample"

if [[ -f "$ENV_FILE" ]]; then
    echo ".env already exists — nothing to do."
    echo "Edit it directly: $ENV_FILE"
    exit 0
fi

cp "$SAMPLE_FILE" "$ENV_FILE"
echo "✓ Created .env from .env.sample"
echo "  Edit $ENV_FILE to adjust settings before running the pipeline."
