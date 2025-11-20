# Nodus ADK Infrastructure

Complete development stack (DEVSTACK) for Nodus OS ADK edition.

## Overview

This repository provides a complete local development environment for the entire Nodus ADK stack using Docker Compose:

- **Infrastructure**: PostgreSQL, Redis, Qdrant, MinIO
- **Nodus OS**: Backoffice, Llibreta, MCP Gateway
- **ADK**: Runtime server and agents

All services run with **live reload** and **bind-mounted source code** for instant feedback during development.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    NODUS ADK DEVSTACK                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────┐  ┌───────────┐  ┌─────────────┐            │
│  │Llibreta  │  │Backoffice │  │MCP Gateway  │            │
│  │(UI)      │  │(Control)  │  │(Tools)      │            │
│  │:5002     │  │:5001      │  │:7443        │            │
│  └────┬─────┘  └─────┬─────┘  └──────┬──────┘            │
│       │              │                │                    │
│       └──────────────┼────────────────┘                    │
│                      │                                     │
│              ┌───────▼────────┐                            │
│              │  ADK Runtime   │                            │
│              │  (Google ADK)  │                            │
│              │  :8080         │                            │
│              └───────┬────────┘                            │
│                      │                                     │
│       ┌──────────────┼──────────────┐                     │
│       │              │              │                     │
│  ┌────▼───┐    ┌────▼────┐    ┌───▼────┐                │
│  │Postgres│    │ Qdrant  │    │ Redis  │                │
│  │:5432   │    │ :6333   │    │ :6379  │                │
│  └────────┘    └─────────┘    └────────┘                │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

## Quick Start

### Prerequisites

- Docker Desktop or Docker Engine + Docker Compose
- Git
- 8GB+ RAM recommended
- Ports: 5001, 5002, 5432, 6333, 6379, 7443, 8080, 9000, 9001

### Setup

```bash
# Clone this repo (should already be in nodus-os-adk)
cd nodus-os-adk/nodus-adk-infra

# Run setup script
./scripts/setup.sh

# Review and update .env
vim .env

# Start the stack
./dev up
```

That's it! All services will start with live reload enabled.

## Service URLs

Once running, access services at:

| Service | URL | Description |
|---------|-----|-------------|
| Llibreta | http://localhost:5002 | User interface |
| Backoffice | http://localhost:5001 | Control plane / Admin |
| ADK Runtime | http://localhost:8080 | ADK API server |
| MCP Gateway | http://localhost:7443 | MCP tool gateway |
| Qdrant | http://localhost:6333 | Vector database |
| MinIO Console | http://localhost:9001 | S3 storage UI |
| PostgreSQL | localhost:5432 | Database (nodus/nodus_dev_password) |
| Redis | localhost:6379 | Cache/Queue |

## Dev Script Usage

The `./dev` script is your main interface to the DEVSTACK:

```bash
# Start all services
./dev up

# Start specific service
./dev up adk-runtime

# View logs
./dev logs
./dev logs llibreta

# Check status
./dev status

# Restart service
./dev restart mcp-gateway

# Shell into service
./dev shell backoffice

# Execute command in service
./dev exec adk-runtime python -m pytest

# Rebuild service
./dev rebuild adk-runtime

# Stop all services
./dev down

# Stop and remove volumes
./dev down -v

# Clean everything (DANGEROUS)
./dev clean
```

## Development Workflow

### Making Changes

All source code is bind-mounted, so changes are reflected immediately:

1. **Backoffice, Llibreta, MCP Gateway**: Edit code → Auto-reload (HMR/nodemon)
2. **ADK Runtime**: Edit Python code → Uvicorn reloads automatically
3. **ADK Agents**: Edit agents → Restart `adk-runtime` service

### Debugging

```bash
# View logs with follow
./dev logs -f adk-runtime

# Shell into container for debugging
./dev shell adk-runtime

# Check database
./dev exec postgres psql -U nodus -d nodus

# Check Redis
./dev exec redis redis-cli
```

### Running Tests

```bash
# In ADK runtime
./dev exec adk-runtime python -m pytest

# In backoffice
./dev exec backoffice npm test
```

## Configuration

### Environment Variables

All configuration via `.env` file (copy from `.env.example`).

Key variables:
- `DATABASE_URL`: PostgreSQL connection
- `REDIS_URL`: Redis connection
- `ADK_MODEL`: Google ADK model to use
- `GOOGLE_APPLICATION_CREDENTIALS`: Path to GCP credentials
- `LOG_LEVEL`: Logging verbosity

### Google ADK Configuration

To use Google ADK with real models:

1. Set up GCP project and enable Vertex AI
2. Download service account JSON
3. Mount credentials in docker-compose or set `GOOGLE_APPLICATION_CREDENTIALS`
4. Update `ADK_MODEL` in `.env`

### Custom Docker Compose

Create `docker-compose.override.yml` for local customizations:

```yaml
services:
  adk-runtime:
    environment:
      - CUSTOM_VAR=value
    ports:
      - "8081:8080"
```

## Troubleshooting

### Services won't start

```bash
# Check Docker is running
docker ps

# Check port conflicts
./dev down
lsof -i :5001  # Check which process uses the port

# Clean and restart
./dev clean
./dev up
```

### Database issues

```bash
# Reset database
./dev down -v
./dev up
```

### Rebuild from scratch

```bash
./dev down -v
./dev rebuild
./dev up
```

## Documentation

- [Setup Guide](docs/SETUP.md) - Detailed setup instructions
- [Development Guide](docs/DEVELOPMENT.md) - Development workflows
- [Architecture](docs/ARCHITECTURE.md) - System architecture details

## Repository Structure

```
nodus-adk-infra/
├── docker-compose.yml       # Main compose configuration
├── .env.example             # Environment template
├── dev                      # Main dev script
├── scripts/
│   └── setup.sh             # Initial setup script
├── config/
│   ├── postgres/            # PostgreSQL init scripts
│   ├── qdrant/              # Qdrant configuration
│   └── redis/               # Redis configuration
└── docs/
    ├── SETUP.md             # Setup guide
    ├── DEVELOPMENT.md       # Development guide
    └── ARCHITECTURE.md      # Architecture docs
```

## Networks

Two Docker networks:
- `nodus-adk-internal`: Backend services (database, cache, etc.)
- `nodus-adk-edge`: Exposed services (UI, APIs)

## Volumes

Persistent data stored in named volumes:
- `nodus-adk-postgres-data`: PostgreSQL data
- `nodus-adk-redis-data`: Redis data
- `nodus-adk-qdrant-data`: Qdrant vectors
- `nodus-adk-minio-data`: MinIO objects

## Related Repositories

- [nodus-adk-runtime](../nodus-adk-runtime) - ADK runtime server
- [nodus-adk-agents](../nodus-adk-agents) - Agent definitions
- [nodus-backoffice](../nodus-backoffice) - Control plane
- [nodus-llibreta](../nodus-llibreta) - User interface
- [nodus-mcp-gateway](../nodus-mcp-gateway) - MCP integration
- [adk-python](../adk-python) - Google ADK fork

## License

Copyright © 2024 Nodus Factory

## Support

For issues or questions, see individual repository READMEs or contact the development team.

