-- ============================================================================
-- OpenMemory Database
-- ============================================================================

-- Create database for OpenMemory (nodus-memory fork)
CREATE DATABASE openmemory;

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE openmemory TO nodus;

-- Connect to openmemory database and prepare schema
\c openmemory;

-- Grant schema permissions (OpenMemory creates tables automatically)
GRANT ALL ON SCHEMA public TO nodus;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO nodus;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO nodus;

-- Set default privileges for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO nodus;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO nodus;

-- ============================================================================
-- ADK Conversation Memory Table (for DatabaseMemoryService)
-- ============================================================================

-- Switch back to main nodus database
\c nodus;

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
GRANT ALL PRIVILEGES ON TABLE adk_conversation_memory TO nodus;
GRANT USAGE, SELECT ON SEQUENCE adk_conversation_memory_id_seq TO nodus;

-- Add comment for documentation
COMMENT ON TABLE adk_conversation_memory IS 'Short-term conversation memory for ADK PreloadMemoryTool. Stores last ~100 messages per user.';

