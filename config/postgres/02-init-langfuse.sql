-- ============================================================================
-- Langfuse Database Initialization
-- ============================================================================
-- This script creates the Langfuse database and required extensions
-- for the Langfuse observability platform.
--
-- Executed automatically by PostgreSQL on first container startup.
-- ============================================================================

-- Create Langfuse database
CREATE DATABASE langfuse_db;

-- Grant privileges to nodus user
GRANT ALL PRIVILEGES ON DATABASE langfuse_db TO nodus;

-- Connect to langfuse_db and setup extensions
\c langfuse_db;

-- Enable required PostgreSQL extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Grant schema privileges
GRANT ALL ON SCHEMA public TO nodus;

-- Print confirmation
\echo '✅ Langfuse database initialized successfully'
\echo '   - Database: langfuse_db'
\echo '   - Extensions: uuid-ossp, pg_trgm'
\echo '   - Owner: nodus'

