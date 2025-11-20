# Development Guide

Best practices and workflows for developing with Nodus ADK DEVSTACK.

## Daily Workflow

### Starting Your Day

```bash
cd nodus-os-adk/nodus-adk-infra

# Start the stack
./dev up

# Check everything is running
./dev status

# View logs
./dev logs
```

### During Development

All changes to source code are reflected immediately thanks to bind mounts and live reload:

- **Backoffice** (Node.js): Changes trigger nodemon restart
- **Llibreta** (Vite): Hot module replacement (HMR)
- **MCP Gateway** (Node.js/ts-node-dev): Auto-restart
- **ADK Runtime** (Python/uvicorn): Auto-reload

### End of Day

```bash
# Leave running for next day
./dev down

# Or keep running (uses ~2GB RAM idle)
```

## Working with Services

### Backoffice (Control Plane)

```bash
# View logs
./dev logs backoffice

# Shell into container
./dev shell backoffice

# Run migrations
./dev exec backoffice npm run migrate

# Run tests
./dev exec backoffice npm test
```

### Llibreta (UI)

```bash
# View logs
./dev logs llibreta

# Access at http://localhost:5002

# Run tests
./dev exec llibreta npm test

# Build for production
./dev exec llibreta npm run build
```

### ADK Runtime

```bash
# View logs
./dev logs adk-runtime

# Shell into container
./dev shell adk-runtime

# Run Python tests
./dev exec adk-runtime python -m pytest

# Install new dependency
./dev exec adk-runtime pip install <package>
# Then add to pyproject.toml and rebuild
```

### MCP Gateway

```bash
# View logs
./dev logs mcp-gateway

# Test MCP discovery
curl http://localhost:7443/mcp/discover

# Shell
./dev shell mcp-gateway
```

## Database Operations

### PostgreSQL

```bash
# Connect to database
./dev exec postgres psql -U nodus -d nodus

# Run migrations
./dev exec backoffice npm run migrate

# Dump database
./dev exec postgres pg_dump -U nodus nodus > backup.sql

# Restore database
cat backup.sql | ./dev exec -T postgres psql -U nodus nodus

# Reset database
./dev down -v
./dev up postgres
```

### Redis

```bash
# Redis CLI
./dev exec redis redis-cli

# Monitor commands
./dev exec redis redis-cli monitor

# Clear all data
./dev exec redis redis-cli FLUSHALL
```

### Qdrant

```bash
# Check collections
curl http://localhost:6333/collections

# View dashboard
open http://localhost:6333/dashboard
```

## Adding New Code

### Adding a New Agent

1. Edit `nodus-adk-agents/src/nodus_adk_agents/new_agent.py`
2. Changes are immediately available (bind mount)
3. Restart ADK Runtime: `./dev restart adk-runtime`

### Adding New Endpoint

1. Edit files in respective service
2. Changes auto-reload
3. Test immediately

### Adding New Dependency

**Python (ADK Runtime):**
```bash
# Add to pyproject.toml
vim ../nodus-adk-runtime/pyproject.toml

# Rebuild image
./dev rebuild adk-runtime
./dev restart adk-runtime
```

**Node.js (Backoffice/Llibreta/Gateway):**
```bash
# Add via exec
./dev exec backoffice npm install <package>

# Update package.json in your editor
# Rebuild for persistence
./dev rebuild backoffice
```

## Testing

### Unit Tests

```bash
# ADK Runtime
./dev exec adk-runtime python -m pytest

# Backoffice
./dev exec backoffice npm test

# Llibreta
./dev exec llibreta npm test
```

### Integration Tests

```bash
# Test full flow
curl -X POST http://localhost:8080/v1/assistant/sessions/test/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer test-token" \
  -d '{"message": {"text": "Hello"}}'
```

### Manual Testing

1. Open Llibreta: http://localhost:5002
2. Login (use test credentials)
3. Send message to assistant
4. Monitor logs: `./dev logs adk-runtime`

## Debugging

### Using Debugger

**Python (ADK Runtime):**

Add to docker-compose.override.yml:
```yaml
services:
  adk-runtime:
    ports:
      - "5678:5678"  # debugpy port
    command: python -m debugpy --listen 0.0.0.0:5678 --wait-for-client -m uvicorn ...
```

Then attach VSCode debugger.

**Node.js (Backoffice/Llibreta):**

Add to docker-compose.override.yml:
```yaml
services:
  backoffice:
    ports:
      - "9229:9229"  # Node inspector
    command: node --inspect=0.0.0.0:9229 server.js
```

### Print Debugging

Add logs and watch in real-time:
```bash
./dev logs -f adk-runtime | grep "DEBUG"
```

### Network Debugging

```bash
# Check service can reach another
./dev exec adk-runtime curl http://mcp-gateway:7443/health

# Check DNS
./dev exec adk-runtime nslookup postgres
```

## Performance

### Resource Usage

```bash
# Check Docker stats
docker stats

# Check service resource usage
./dev ps
```

### Optimizing Build Times

```bash
# Use BuildKit
export DOCKER_BUILDKIT=1

# Build with cache
./dev rebuild --build-arg BUILDKIT_INLINE_CACHE=1
```

## Common Tasks

### Resetting Everything

```bash
./dev down -v
./dev rebuild
./dev up
```

### Updating Dependencies

```bash
# Pull latest base images
docker compose pull

# Rebuild services
./dev rebuild
```

### Cleaning Up

```bash
# Remove stopped containers
docker container prune

# Remove unused images
docker image prune

# Remove unused volumes
docker volume prune

# Clean everything (DANGEROUS)
./dev clean
```

## Best Practices

1. **Commit often**: Changes in bind-mounted code are not in containers
2. **Check logs**: Always check logs when something doesn't work
3. **Use .gitignore**: Don't commit .env or local overrides
4. **Document changes**: Update READMEs when adding features
5. **Test locally**: Test in DEVSTACK before pushing

## Troubleshooting

### Service Won't Start

```bash
# Check logs
./dev logs <service>

# Rebuild
./dev rebuild <service>

# Check dependencies
./dev ps
```

### Changes Not Reflecting

```bash
# Check bind mount
./dev exec <service> ls -la /app

# Restart service
./dev restart <service>

# Rebuild if Dockerfile changed
./dev rebuild <service>
```

### Out of Memory

```bash
# Check usage
docker stats

# Increase Docker memory limit (Docker Desktop → Preferences → Resources)

# Or stop some services
./dev down postgres qdrant  # Keep only what you need
```

## Next Steps

- Read [Architecture](ARCHITECTURE.md) to understand system design
- Check individual repo READMEs for service-specific details
- Join team chat for questions

