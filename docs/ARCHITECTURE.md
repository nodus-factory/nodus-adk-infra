# Nodus ADK Architecture

System architecture and design decisions for Nodus OS ADK edition.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          USER LAYER                             │
│                                                                 │
│  ┌──────────────┐                                              │
│  │   Llibreta   │  Browser-based UI                            │
│  │   (React)    │  http://localhost:5002                       │
│  └──────┬───────┘                                              │
│         │                                                       │
└─────────┼───────────────────────────────────────────────────────┘
          │ HTTP/SSE
          │
┌─────────▼───────────────────────────────────────────────────────┐
│                      CONTROL PLANE                              │
│                                                                 │
│  ┌──────────────┐                                              │
│  │  Backoffice  │  Auth, Tenants, Secrets, Config              │
│  │   (Node.js)  │  http://localhost:5001                       │
│  └──────────────┘                                              │
│         │                                                       │
│         │ JWT, User Context                                    │
│         │                                                       │
└─────────┼───────────────────────────────────────────────────────┘
          │
┌─────────▼───────────────────────────────────────────────────────┐
│                       ADK RUNTIME                               │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              Google ADK Core                             │  │
│  │  ┌────────────────────────────────────────────────────┐  │  │
│  │  │          Root Agent (Personal Assistant)           │  │  │
│  │  │                                                    │  │  │
│  │  │  ┌──────┐ ┌──────┐ ┌─────┐ ┌─────┐ ┌─────┐      │  │  │
│  │  │  │Email │ │ Cal  │ │ CRM │ │ ERP │ │ RAG │ ...  │  │  │
│  │  │  │Agent │ │Agent │ │Agent│ │Agent│ │Agent│      │  │  │
│  │  │  └──────┘ └──────┘ └─────┘ └─────┘ └─────┘      │  │  │
│  │  │                                                    │  │  │
│  │  └────────────────────────────────────────────────────┘  │  │
│  │                                                          │  │
│  │  ┌─────────────────────────────────────────────────┐    │  │
│  │  │     Nodus ADK Runtime (FastAPI)                 │    │  │
│  │  │  - MCP Adapter                                  │    │  │
│  │  │  - Memory Adapter                               │    │  │
│  │  │  - Auth Middleware                              │    │  │
│  │  └─────────────────────────────────────────────────┘    │  │
│  └──────────────────────────────────────────────────────────┘  │
│         │                    │                    │             │
│         │ Tools              │ Memory             │ Auth        │
│         │                    │                    │             │
└─────────┼────────────────────┼────────────────────┼─────────────┘
          │                    │                    │
          │                    │                    │
┌─────────▼────────────────────▼────────────────────▼─────────────┐
│                     INTEGRATION LAYER                           │
│                                                                 │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐       │
│  │ MCP Gateway  │   │ Memory Layer │   │  Backoffice  │       │
│  │  (Node.js)   │   │  (Qdrant)    │   │   (Auth)     │       │
│  │              │   │              │   │              │       │
│  │ - Discovery  │   │ - Vectors    │   │ - JWT        │       │
│  │ - Governance │   │ - Search     │   │ - Tenants    │       │
│  │ - Egress     │   │ - Storage    │   │ - Secrets    │       │
│  └──────────────┘   └──────────────┘   └──────────────┘       │
│         │                                                       │
│         │ External Tools                                        │
│         ▼                                                       │
│  ┌──────────────┐                                              │
│  │ External     │  Email, Calendar, CRM, ERP                   │
│  │ Services     │  Google Workspace, etc.                      │
│  └──────────────┘                                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      DATA LAYER                                 │
│                                                                 │
│  ┌──────────┐  ┌────────┐  ┌────────┐  ┌────────┐            │
│  │PostgreSQL│  │ Redis  │  │ Qdrant │  │ MinIO  │            │
│  │          │  │        │  │        │  │        │            │
│  │ Relational  │ Cache  │  │Vectors │  │Objects │            │
│  └──────────┘  └────────┘  └────────┘  └────────┘            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

### User Layer

#### Llibreta (UI)
- User interface for interacting with assistant
- Session management
- HITL (Human-In-The-Loop) confirmations
- Attachments, context display
- Built with React + Vite

**Technology**: React, TypeScript, Vite, TanStack Query

### Control Plane

#### Backoffice
- **Authentication**: JWT issuance and validation
- **Multi-tenancy**: Tenant/user management
- **Secrets**: `secret://handle` resolution
- **Configuration**: System settings, feature flags
- **Scopes**: Permission management

**Technology**: Node.js, Express, PostgreSQL

### ADK Runtime

#### Google ADK Core
- **Agent Orchestration**: Root agent + domain agents
- **A2A Communication**: Agent-to-agent delegation
- **Planning**: Multi-step workflows
- **Context Management**: Session and conversation state
- **Model Interaction**: Gemini API calls

**Technology**: Python, Google ADK SDK

#### Nodus ADK Runtime (Integration Layer)
- **MCP Adapter**: Integrates ADK with MCP Gateway
- **Memory Adapter**: Integrates ADK with Qdrant
- **Auth Middleware**: JWT validation with Backoffice
- **API Server**: FastAPI endpoints for Llibreta

**Technology**: Python, FastAPI, HTTPx

#### Nodus ADK Agents
- **Root Agent**: Personal Assistant orchestrator
- **Domain Agents**: Email, Calendar, CRM, ERP, RAG, Memory
- **Packaged**: Installable Python package

**Technology**: Python, Google ADK SDK

### Integration Layer

#### MCP Gateway
- **Discovery**: Dynamic tool catalog
- **Governance**: Risk assessment, scopes, rate limits
- **Egress Control**: Allowlist-based external access
- **Audit**: Comprehensive logging
- **Error Handling**: Standardized error responses

**Technology**: Node.js, TypeScript

#### Memory Layer
- **Vector Storage**: Qdrant for embeddings
- **Semantic Search**: Context retrieval
- **User Isolation**: Per-user collections
- **TTL Management**: Automatic expiration

**Technology**: Qdrant, Python client

### Data Layer

#### PostgreSQL
- **Schema**: Users, tenants, sessions, runs, configs
- **Transactional**: ACID guarantees
- **Migrations**: Version-controlled schema changes

#### Redis
- **Caching**: JWT tokens, rate limits
- **Queues**: Async job processing (if needed)
- **Sessions**: Temporary state storage

#### Qdrant
- **Vectors**: User memory embeddings
- **Collections**: Per-user isolation
- **Metadata**: Timestamps, PII flags, TTL

#### MinIO
- **Objects**: Attachments, documents
- **S3-compatible**: Standard API
- **Buckets**: Per-tenant isolation

## Data Flow

### User Message Flow

1. **User** types message in Llibreta
2. **Llibreta** sends `POST /v1/assistant/sessions/{id}/messages` to ADK Runtime
3. **ADK Runtime** validates JWT with Backoffice
4. **ADK Runtime** resolves user context (tenant_id, user_id, scopes)
5. **Root Agent** (PA) analyzes intent and plans
6. **Root Agent** delegates to **Domain Agent** (e.g., Email Agent)
7. **Domain Agent** calls MCP tools via **MCP Gateway**
8. **MCP Gateway** validates scopes, checks egress, calls external service
9. **External Service** (e.g., Gmail) processes request
10. **MCP Gateway** returns result to Domain Agent
11. **Domain Agent** processes result, updates memory via **Memory Adapter**
12. **Root Agent** composes final response
13. **ADK Runtime** returns response to Llibreta
14. **Llibreta** displays response to user

### HITL (Human-In-The-Loop) Flow

1. **Agent** wants to perform risky action (e.g., send email)
2. **Agent** returns HITL request instead of executing
3. **ADK Runtime** sends HITL event to Llibreta (via SSE/WebSocket)
4. **Llibreta** shows confirmation UI to user
5. **User** approves or rejects
6. **Llibreta** sends confirmation to ADK Runtime
7. **ADK Runtime** resumes agent execution
8. **Agent** executes approved action

## Security

### Authentication Flow

1. User logs in via Backoffice
2. Backoffice issues JWT with:
   - `sub`: user_id
   - `tenant_id`: tenant
   - `scopes`: permissions
   - `exp`: expiration
3. Llibreta includes JWT in requests
4. ADK Runtime validates JWT with Backoffice
5. ADK Runtime includes context in agent calls

### Authorization

- **Scopes**: Fine-grained permissions (e.g., `email:send`, `calendar:create`)
- **Tenant Isolation**: Data segregation by tenant_id
- **MCP Governance**: Tool-level access control

### Secrets Management

- Secrets stored in Backoffice
- Referenced as `secret://handle` in configs
- Never sent to agents or frontend
- Resolved at execution time by MCP Gateway

## Scalability

### Horizontal Scaling

- **ADK Runtime**: Stateless, can scale horizontally
- **MCP Gateway**: Stateless, can scale horizontally
- **Backoffice**: Mostly stateless, sessions in Redis
- **Llibreta**: Static assets, CDN-friendly

### Vertical Considerations

- **PostgreSQL**: Single instance (can use read replicas)
- **Qdrant**: Can cluster for large vector datasets
- **Redis**: Can use Redis Cluster

### Performance Optimizations

- **Caching**: JWT validation, MCP discovery
- **Connection Pooling**: Database connections
- **Lazy Loading**: Agents loaded on-demand
- **Streaming**: SSE for real-time updates

## Networks

### nodus-adk-internal
- Backend services only
- No external access
- Services: postgres, redis, qdrant, minio

### nodus-adk-edge
- Exposed services
- Accessible from host
- Services: backoffice, llibreta, adk-runtime, mcp-gateway

## Volumes

All data persisted in named volumes:
- `nodus-adk-postgres-data`: Database
- `nodus-adk-redis-data`: Cache
- `nodus-adk-qdrant-data`: Vectors
- `nodus-adk-minio-data`: Objects

## Development vs Production

### Development (DEVSTACK)
- Bind-mounted source code
- Live reload enabled
- Debug logging
- No TLS
- Exposed ports

### Production
- Immutable images
- Health checks
- Structured logging
- TLS everywhere
- Internal networking only

## Design Principles

1. **Separation of Concerns**: Each service has clear responsibility
2. **Fail Fast**: Early validation, clear errors
3. **Observability**: Structured logs, health checks, metrics
4. **Security by Default**: JWT everywhere, least privilege
5. **Backward Compatibility**: Version APIs, support migrations

## Related Documentation

- [Setup Guide](SETUP.md)
- [Development Guide](DEVELOPMENT.md)
- [ADK Runtime README](../../nodus-adk-runtime/README.md)
- [ADK Agents README](../../nodus-adk-agents/README.md)

