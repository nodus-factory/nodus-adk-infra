#!/usr/bin/env bash
set -euo pipefail

echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
echo '🚀 Initializing Backoffice Database'
echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'

DB_USER="${POSTGRES_USER:-nodus}"
DB_NAME="${POSTGRES_DB:-nodus_db}"
INIT_DATA_FILE="/docker-entrypoint-initdb.d/init-production-data.sql.seed"
TEMP_SQL_FILE="/tmp/init-production-data-$$.sql"

echo "Connecting to database: $DB_NAME"
echo "Using database user: $DB_USER"
echo "Substituting #db_user# placeholder with $DB_USER in seed file"

# Substitute #db_user# placeholder with the actual POSTGRES_USER
sed "s/#db_user#/$DB_USER/g" "$INIT_DATA_FILE" > "$TEMP_SQL_FILE"

echo "Applying init-production-data.sql seed"

psql -U "$DB_USER" -d "$DB_NAME" -f "$TEMP_SQL_FILE"

# Clean up temporary file
rm -f "$TEMP_SQL_FILE"

echo "✅ Backoffice database initialized successfully"

