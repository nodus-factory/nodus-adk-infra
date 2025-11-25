# Nodus ADK DEVSTACK - Setup Guide

Complete setup instructions for the Nodus ADK development environment.

## Prerequisites

### Required Software

1. **Docker Desktop** (or Docker Engine + Docker Compose)
   - macOS: https://docs.docker.com/desktop/install/mac-install/
   - Linux: https://docs.docker.com/engine/install/
   - Windows: https://docs.docker.com/desktop/install/windows-install/
   - Minimum version: Docker 20.10+, Compose 2.0+

2. **Git**
   - Should already be installed if you cloned the repos

3. **Text Editor / IDE**
   - VSCode, IntelliJ, or your preferred editor

### System Requirements

- **RAM**: 8GB minimum, 16GB recommended
- **Disk**: 10GB free space
- **CPU**: Multi-core recommended for running all services

### Ports

Ensure these ports are available:
- 5001 (Backoffice)
- 5002 (Llibreta)
- 5432 (PostgreSQL)
- 6333, 6334 (Qdrant)
- 6379 (Redis)
- 7443 (MCP Gateway)
- 8080 (ADK Runtime)
- 9000, 9001 (MinIO)

## Initial Setup

### 1. Clone Repositories

If not already done:

```bash
cd /Users/quirze/Factory
cd nodus-os-adk

# Verify all repos are present
ls -la
# Should see: adk-python, nodus-adk-runtime, nodus-adk-agents, 
#             nodus-adk-infra, nodus-backoffice, nodus-llibreta, nodus-mcp-gateway
```

### 2. Run Setup Script

```bash
cd nodus-adk-infra
./scripts/setup.sh
```

This will:
- Check Docker installation
- Create `.env` from template
- Pull base Docker images

### 3. Configure Environment

Edit `.env` file:

```bash
vim .env  # or use your preferred editor
```

Key configuration:
```env
# Use these defaults for local development
DATABASE_URL=postgresql://nodus:nodus_dev_password@postgres:5432/nodus
REDIS_URL=redis://redis:6379/0

# Optional: Google ADK credentials
GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
ADK_PROJECT_ID=your-gcp-project-id
```

### 4. Start Services

```bash
./dev up
```

First start will take 5-10 minutes as it builds all images.

### 5. Verify Installation

Check all services are running:

```bash
./dev status
```

Should show all services as "Up" or "healthy".

Test endpoints:
```bash
# Health checks
curl http://localhost:8080/health  # ADK Runtime
curl http://localhost:5001/health  # Backoffice (if available)
curl http://localhost:6333/health  # Qdrant
```

Access UIs:
- Llibreta: http://localhost:5002
- Backoffice: http://localhost:5001
- MinIO Console: http://localhost:9001 (minioadmin/minioadmin)

## Google Cloud Setup (Optional)

For real Google ADK model access:

### 1. Create GCP Project

```bash
gcloud projects create nodus-adk-dev
gcloud config set project nodus-adk-dev
```

### 2. Enable APIs

```bash
gcloud services enable aiplatform.googleapis.com
gcloud services enable compute.googleapis.com
```

### 3. Create Service Account

```bash
gcloud iam service-accounts create nodus-adk-dev \
    --display-name="Nodus ADK Development"

gcloud projects add-iam-policy-binding nodus-adk-dev \
    --member="serviceAccount:nodus-adk-dev@nodus-adk-dev.iam.gserviceaccount.com" \
    --role="roles/aiplatform.user"

gcloud iam service-accounts keys create ~/nodus-adk-credentials.json \
    --iam-account=nodus-adk-dev@nodus-adk-dev.iam.gserviceaccount.com
```

### 4. Configure Docker Compose

Update `docker-compose.yml` or create `docker-compose.override.yml`:

```yaml
services:
  adk-runtime:
    volumes:
      - ~/nodus-adk-credentials.json:/app/credentials/gcp.json:ro
    environment:
      - GOOGLE_APPLICATION_CREDENTIALS=/app/credentials/gcp.json
      - ADK_PROJECT_ID=nodus-adk-dev
```

## Troubleshooting

### Port Conflicts

If ports are in use:

```bash
# Find what's using the port
lsof -i :5001

# Kill the process or change the port in docker-compose.yml
```

### Docker Issues

```bash
# Reset Docker
./dev down -v
./dev clean

# Rebuild everything
./dev rebuild
./dev up
```

### Permission Issues

```bash
# macOS/Linux: Fix volume permissions
sudo chown -R $USER:$USER .
```

### Database Connection Issues

```bash
# Reset database
./dev down -v
./dev up postgres
./dev logs postgres

# Verify connection
./dev exec postgres psql -U nodus -d nodus -c "SELECT 1;"
```

### Services Crash on Start

```bash
# Check logs
./dev logs <service-name>

# Common issues:
# - Missing environment variables
# - Port conflicts
# - Insufficient memory (increase Docker memory limit)
```

## Next Steps

After successful setup:

1. Read [Development Guide](DEVELOPMENT.md)
2. Read [Architecture](ARCHITECTURE.md)
3. Start developing!

## Uninstall

To completely remove the DEVSTACK:

```bash
# Stop services and remove volumes
./dev down -v

# Remove Docker networks
docker network rm nodus-adk-internal nodus-adk-edge

# Remove images (optional)
docker images | grep nodus-adk | awk '{print $3}' | xargs docker rmi
```


