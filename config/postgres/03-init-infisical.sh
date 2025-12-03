#!/usr/bin/env bash
set -euo pipefail

# Create Infisical database if it does not exist, using env-provided Postgres credentials
# Uses POSTGRES_USER/POSTGRES_PASSWORD/POSTGRES_DB provided by the container env

DB_NAME="${INFISICAL_DB_NAME:-infisical_compat149}"
DB_OWNER="${INFISICAL_DB_USER:-infisical_service}"
DB_PASSWORD="${INFISICAL_DB_PASSWORD:-change-me-infisical}"
SUPERUSER="${POSTGRES_USER:-nodus}"

echo "[initdb] Ensuring role '$DB_OWNER' and database '$DB_NAME' exist (superuser: $SUPERUSER)"

psql_super() {
  psql -U "$SUPERUSER" -d postgres -v ON_ERROR_STOP=1 "$@"
}

role_exists=$(psql_super -tAc "SELECT 1 FROM pg_roles WHERE rolname='${DB_OWNER}'")
if [ -z "${role_exists}" ]; then
  echo "[initdb] Creating role '${DB_OWNER}'"
  psql_super -c "CREATE ROLE \"${DB_OWNER}\" LOGIN PASSWORD '${DB_PASSWORD}'"
else
  echo "[initdb] Role '${DB_OWNER}' exists; updating password"
  psql_super -c "ALTER ROLE \"${DB_OWNER}\" PASSWORD '${DB_PASSWORD}'"
fi

db_exists=$(psql_super -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'")
if [ -z "${db_exists}" ]; then
  echo "[initdb] Creating database '${DB_NAME}' owned by '${DB_OWNER}'"
  psql_super -c "CREATE DATABASE \"${DB_NAME}\" OWNER \"${DB_OWNER}\""
else
  echo "[initdb] Database '${DB_NAME}' already exists"
fi

psql_super -c "GRANT ALL PRIVILEGES ON DATABASE \"${DB_NAME}\" TO \"${DB_OWNER}\""

echo "[initdb] Infisical database ensured."


