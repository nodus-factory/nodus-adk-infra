#!/usr/bin/env bash
set -euo pipefail

echo "==> Applying SQL migrations from /docker-entrypoint-initdb.d/migrations"

DB_USER="${POSTGRES_USER:-nodus}"
DB_NAME="${POSTGRES_DB:-nodus_db}"
MIGR_DIR="/docker-entrypoint-initdb.d/migrations"

if [ ! -d "$MIGR_DIR" ]; then
  echo "No migrations directory found at $MIGR_DIR (skipping)."
  exit 0
fi

# Create Drizzle schema and migrations tracking table if they don't exist
# This ensures compatibility with Drizzle's migration tracking system
psql -U "$DB_USER" -d "$DB_NAME" <<EOF
CREATE SCHEMA IF NOT EXISTS drizzle;
CREATE TABLE IF NOT EXISTS drizzle.__drizzle_migrations (
  id SERIAL PRIMARY KEY,
  hash text NOT NULL UNIQUE,
  created_at bigint
);
EOF

# Execute migrations in alphabetical order
# Note: Migrations should be idempotent (use IF NOT EXISTS, ON CONFLICT, etc.)
# Drizzle will detect and register these migrations when backoffice starts
echo "==> Executing migrations in alphabetical order..."

# Exclude backup files and meta directory
for f in $(ls -1 "$MIGR_DIR"/*.sql 2>/dev/null | grep -v ".bak$" | sort); do
  echo "==> Applying $(basename $f)"
  psql -U "$DB_USER" -d "$DB_NAME" -f "$f" || {
    echo "ERROR: Migration $(basename $f) failed"
    exit 1
  }
done

echo "==> Migrations completed"
echo "Note: Drizzle will register these migrations when backoffice starts"
