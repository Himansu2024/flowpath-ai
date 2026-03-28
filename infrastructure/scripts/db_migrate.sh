#!/usr/bin/env bash
# infrastructure/scripts/db_migrate.sh
# Run all PostgreSQL migrations in order
set -euo pipefail

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-flowpath_db}"
DB_USER="${DB_USER:-flowpath_user}"
MIGRATIONS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../database/migrations" && pwd)"

echo "Running FlowPath migrations on $DB_HOST/$DB_NAME..."

for f in "$MIGRATIONS_DIR"/*.sql; do
  echo "  → $(basename $f)"
  PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" \
    -U "$DB_USER" -d "$DB_NAME" -f "$f" --on-error-stop 2>&1
done

echo "✅ All migrations complete"
