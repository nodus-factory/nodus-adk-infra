#!/usr/bin/env bash
set -euo pipefail

echo '============================================================================'
echo 'OpenMemory Database'
echo '============================================================================'

DB_USER="${POSTGRES_USER:-nodus}"
DB_NAME="${POSTGRES_DB:-nodus_db}"

# Create database for OpenMemory (nodus-memory fork)
psql -U "$DB_USER" -d postgres <<EOF
CREATE DATABASE openmemory;
GRANT ALL PRIVILEGES ON DATABASE openmemory TO $DB_USER;
EOF

# Connect to openmemory database and prepare schema
psql -U "$DB_USER" -d openmemory <<EOF
-- Grant schema permissions (OpenMemory creates tables automatically)
GRANT ALL ON SCHEMA public TO $DB_USER;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $DB_USER;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO $DB_USER;

-- Set default privileges for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO $DB_USER;
EOF

# Switch back to main nodus database and create ADK conversation memory table
psql -U "$DB_USER" -d "$DB_NAME" <<EOF
-- ============================================================================
-- ADK Conversation Memory Table (for DatabaseMemoryService)
-- ============================================================================

-- Create table for short-term conversation memory
CREATE TABLE IF NOT EXISTS adk_conversation_memory (
    id SERIAL PRIMARY KEY,
    session_id VARCHAR(255) NOT NULL,
    user_id VARCHAR(255) NOT NULL,
    tenant_id VARCHAR(255) NOT NULL DEFAULT 'default',
    author VARCHAR(50),
    content TEXT NOT NULL,
    timestamp TIMESTAMP NOT NULL DEFAULT NOW(),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE(session_id, timestamp)
);

-- Indexes for fast queries
CREATE INDEX IF NOT EXISTS idx_conv_user_timestamp ON adk_conversation_memory(user_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_conv_session ON adk_conversation_memory(session_id);
CREATE INDEX IF NOT EXISTS idx_conv_tenant ON adk_conversation_memory(tenant_id);
CREATE INDEX IF NOT EXISTS idx_conv_created_at ON adk_conversation_memory(created_at DESC);

-- Grant permissions
GRANT ALL PRIVILEGES ON TABLE adk_conversation_memory TO $DB_USER;
GRANT USAGE, SELECT ON SEQUENCE adk_conversation_memory_id_seq TO $DB_USER;

-- Add comment for documentation
COMMENT ON TABLE adk_conversation_memory IS 'Short-term conversation memory for ADK PreloadMemoryTool. Stores last ~100 messages per user.';
EOF

echo "✅ OpenMemory database initialized successfully"


