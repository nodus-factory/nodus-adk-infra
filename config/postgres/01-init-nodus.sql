-- ============================================================================
-- Nodus ADK - PostgreSQL Initialization Script
-- ============================================================================
-- This script initializes the core tables for Backoffice and Llibreta
-- It runs automatically when the PostgreSQL container is first created
-- ============================================================================

\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo '🚀 Initializing Nodus ADK Database'
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'

-- Connect to nodus database
\c nodus;

-- ============================================================================
-- TENANTS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS tenants (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) UNIQUE NOT NULL,
    display_name VARCHAR(255),
    status VARCHAR(50) DEFAULT 'active',
    collection_prefix VARCHAR(100) DEFAULT 'knowledge',
    quota INTEGER DEFAULT 1000,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

\echo '✅ Created table: tenants'

-- Seed default tenant
INSERT INTO tenants (id, name, display_name, status, collection_prefix, quota)
VALUES (1, 'default', 'Default Tenant', 'active', 'knowledge', 1000)
ON CONFLICT (id) DO NOTHING;

\echo '✅ Inserted default tenant'

-- ============================================================================
-- ROLES TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    canwritedb BOOLEAN DEFAULT FALSE,
    can_select_collection BOOLEAN DEFAULT FALSE,
    can_apply BOOLEAN DEFAULT FALSE,
    can_save BOOLEAN DEFAULT FALSE,
    can_publish BOOLEAN DEFAULT FALSE
);

\echo '✅ Created table: roles'

-- Seed default roles
INSERT INTO roles (id, name, description, canwritedb, can_select_collection, can_apply, can_save, can_publish)
VALUES 
    (1, 'admin', 'Administrator with full access', TRUE, TRUE, TRUE, TRUE, TRUE),
    (2, 'developer', 'Developer with limited permissions', TRUE, TRUE, TRUE, TRUE, FALSE),
    (3, 'viewer', 'Read-only access', FALSE, FALSE, FALSE, FALSE, FALSE)
ON CONFLICT (id) DO NOTHING;

\echo '✅ Inserted default roles'

-- ============================================================================
-- USERS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    password TEXT NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    first_name VARCHAR(255) NOT NULL,
    last_name VARCHAR(255),
    role VARCHAR(50) DEFAULT 'developer',
    role_id INTEGER DEFAULT 2 REFERENCES roles(id),
    tenant_id INTEGER DEFAULT 1 REFERENCES tenants(id),
    active BOOLEAN DEFAULT TRUE,
    name TEXT,  -- Full name for backward compatibility with backoffice schema
    quota INTEGER DEFAULT 100,
    organization VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    last_login TIMESTAMP,
    reset_token TEXT,
    reset_token_expiry TIMESTAMP
);

\echo '✅ Created table: users'

-- Seed default users
-- Password for 'quirze' is 'holaquirze' (hashed)
-- Password for 'admin' is 'admin123' (hashed)
INSERT INTO users (id, username, password, email, first_name, last_name, name, role, role_id, tenant_id, active, quota)
VALUES 
    (12, 'quirze', '57aaf0d30f8070063a9c28519decf14b9f9dd6254e44d02e1cf8213b2ee483d6a2915d4842a1bbfbe345cc77b79ac3a6c998be69a6fd1e330dc91429e28c2a8a.cc973fbeb0436537606407ff6559f097', 'quirze@mynodus.com', 'Quirze', 'Salomó', 'Quirze Salomó', 'admin', 1, 1, TRUE, 1000),
    (1, 'admin', '93f66ceef0f855fb9735f020ff491a9ab668e7fc21bc8cf048f8070036689d4875e5807b008491986c75d8adb808716491524733206b1529376fbfbe22e443cc.2854b49d149c1e5037c0420024db6c05', 'admin@mynodus.com', 'Admin', 'User', 'Admin User', 'admin', 1, 1, TRUE, 1000)
ON CONFLICT (id) DO NOTHING;

\echo '✅ Inserted default users'

-- ============================================================================
-- OTHER ESSENTIAL TABLES
-- ============================================================================

-- Session table for authentication
CREATE TABLE IF NOT EXISTS session (
    sid VARCHAR PRIMARY KEY,
    sess JSON NOT NULL,
    expire TIMESTAMP(6) NOT NULL
);

CREATE INDEX IF NOT EXISTS "IDX_session_expire" ON session (expire);

\echo '✅ Created table: session'

-- Knowledge collections status
CREATE TABLE IF NOT EXISTS knowledge_collections_status (
    id SERIAL PRIMARY KEY,
    collection_name VARCHAR(255) UNIQUE NOT NULL,
    last_vectorization TIMESTAMP DEFAULT NOW() NOT NULL
);

\echo '✅ Created table: knowledge_collections_status'

-- Knowledge processed files
CREATE TABLE IF NOT EXISTS knowledge_processed_files (
    id SERIAL PRIMARY KEY,
    collection_name TEXT NOT NULL,
    file_name TEXT NOT NULL,
    file_hash TEXT NOT NULL,
    processed_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(collection_name, file_hash)
);

\echo '✅ Created table: knowledge_processed_files'

-- Queries (history)
CREATE TABLE IF NOT EXISTS queries (
    id SERIAL PRIMARY KEY,
    channel TEXT NOT NULL,
    sender TEXT NOT NULL,
    query TEXT NOT NULL,
    response TEXT,
    status TEXT NOT NULL,
    error_message TEXT,
    received_at TIMESTAMP DEFAULT NOW(),
    responded_at TIMESTAMP,
    processing_time INTEGER,
    vector_ids TEXT[],
    ai_model TEXT,
    conversation_id TEXT,
    previous_message_id INTEGER,
    openai_thread_id TEXT
);

\echo '✅ Created table: queries'

-- Settings
CREATE TABLE IF NOT EXISTS settings (
    id SERIAL PRIMARY KEY,
    category TEXT NOT NULL,
    key TEXT NOT NULL,
    value TEXT,
    last_updated TIMESTAMP DEFAULT NOW(),
    updated_by INTEGER REFERENCES users(id)
);

\echo '✅ Created table: settings'

-- Contacts (whitelist/blacklist)
CREATE TABLE IF NOT EXISTS contacts (
    id SERIAL PRIMARY KEY,
    type TEXT NOT NULL,
    value TEXT UNIQUE NOT NULL,
    name TEXT,
    list_type TEXT NOT NULL,
    reason TEXT,
    added_at TIMESTAMP DEFAULT NOW(),
    added_by INTEGER REFERENCES users(id)
);

\echo '✅ Created table: contacts'

-- Menus
CREATE TABLE IF NOT EXISTS menus (
    id SERIAL PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    path TEXT NOT NULL,
    icon TEXT,
    display_name TEXT NOT NULL,
    description TEXT,
    "order" INTEGER DEFAULT 0,
    parent_id INTEGER REFERENCES menus(id) ON DELETE SET NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW()
);

\echo '✅ Created table: menus'

-- Menu roles (permissions)
CREATE TABLE IF NOT EXISTS menu_roles (
    id SERIAL PRIMARY KEY,
    menu_id INTEGER REFERENCES menus(id) ON DELETE CASCADE,
    role_id INTEGER REFERENCES roles(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(menu_id, role_id)
);

\echo '✅ Created table: menu_roles'

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO nodus;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO nodus;

\echo '✅ Granted permissions to nodus user'

-- ============================================================================
-- COMPLETION
-- ============================================================================

\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo '✅ Nodus ADK Database Initialized Successfully'
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo ''
\echo 'Default credentials:'
\echo '  Username: quirze'
\echo '  Password: holaquirze'
\echo ''
\echo 'Or:'
\echo '  Username: admin'
\echo '  Password: admin123'
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'

