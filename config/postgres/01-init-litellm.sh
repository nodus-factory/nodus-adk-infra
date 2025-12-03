#!/usr/bin/env bash
set -euo pipefail

echo '============================================================================'
echo 'LiteLLM Database Initialization'
echo '============================================================================'

DB_USER="${POSTGRES_USER:-nodus}"

# Create LiteLLM database
psql -U "$DB_USER" -d postgres <<EOF
CREATE DATABASE litellm_db;
GRANT ALL PRIVILEGES ON DATABASE litellm_db TO $DB_USER;
EOF

# Connect to litellm_db and setup extensions
psql -U "$DB_USER" -d litellm_db <<EOF
-- Enable required PostgreSQL extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Grant schema privileges
GRANT ALL ON SCHEMA public TO $DB_USER;
EOF

echo '✅ LiteLLM database initialized successfully'
echo "   - Database: litellm_db"
echo "   - Extensions: uuid-ossp"
echo "   - Owner: $DB_USER"

