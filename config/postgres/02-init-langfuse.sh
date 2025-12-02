#!/usr/bin/env bash
set -euo pipefail

echo '============================================================================'
echo 'Langfuse Database Initialization'
echo '============================================================================'

DB_USER="${POSTGRES_USER:-nodus}"

# Create Langfuse database
psql -U "$DB_USER" -d postgres <<EOF
CREATE DATABASE langfuse_db;
GRANT ALL PRIVILEGES ON DATABASE langfuse_db TO $DB_USER;
EOF

# Connect to langfuse_db and setup extensions
psql -U "$DB_USER" -d langfuse_db <<EOF
-- Enable required PostgreSQL extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Grant schema privileges
GRANT ALL ON SCHEMA public TO $DB_USER;
EOF

echo '✅ Langfuse database initialized successfully'
echo "   - Database: langfuse_db"
echo "   - Extensions: uuid-ossp, pg_trgm"
echo "   - Owner: $DB_USER"

