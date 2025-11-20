#!/bin/bash
#
# Nodus OS ADK - Bootstrap Script
# Automatically clones all repositories and sets up the workspace
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

function info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

function warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

function error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

function title() {
    echo -e "\n${BLUE}━━━${NC} $1 ${BLUE}━━━${NC}\n"
}

# Check prerequisites
title "Checking Prerequisites"

if ! command -v git &> /dev/null; then
    error "Git is not installed. Please install Git first."
fi

if ! command -v docker &> /dev/null; then
    error "Docker is not installed. Please install Docker first."
fi

if ! command -v docker compose &> /dev/null; then
    error "Docker Compose is not installed. Please install Docker Compose first."
fi

info "✓ Git found: $(git --version)"
info "✓ Docker found: $(docker --version)"
info "✓ Docker Compose found: $(docker compose version)"

# Configuration
WORKSPACE_NAME="nodus-os-adk"
GITHUB_ORG="nodus-factory"

# Repository list
declare -A REPOS
REPOS[adk-python]="fork"
REPOS[nodus-adk-runtime]="new"
REPOS[nodus-adk-agents]="new"
REPOS[nodus-adk-infra]="new"
REPOS[nodus-backoffice]="existing"
REPOS[nodus-llibreta]="existing"
REPOS[nodus-mcp-gateway]="existing"

# Check if workspace already exists
if [ -d "$WORKSPACE_NAME" ]; then
    warn "Workspace '$WORKSPACE_NAME' already exists!"
    echo "Do you want to:"
    echo "  1) Delete and recreate (DANGEROUS)"
    echo "  2) Update existing repos"
    echo "  3) Exit"
    read -p "Choice (1/2/3): " choice
    
    case $choice in
        1)
            warn "Deleting existing workspace..."
            rm -rf "$WORKSPACE_NAME"
            ;;
        2)
            info "Will update existing repos"
            cd "$WORKSPACE_NAME"
            UPDATE_MODE=true
            ;;
        3)
            info "Exiting"
            exit 0
            ;;
        *)
            error "Invalid choice"
            ;;
    esac
else
    info "Creating workspace directory: $WORKSPACE_NAME"
    mkdir -p "$WORKSPACE_NAME"
    cd "$WORKSPACE_NAME"
fi

# Clone or update repositories
title "Cloning Repositories"

for repo in "${!REPOS[@]}"; do
    repo_type=${REPOS[$repo]}
    
    if [ -d "$repo" ] && [ "$UPDATE_MODE" = true ]; then
        info "Updating $repo..."
        cd "$repo"
        git fetch --all
        git pull
        cd ..
    elif [ -d "$repo" ]; then
        warn "Repository $repo already exists, skipping"
    else
        info "Cloning $repo ($repo_type)..."
        git clone "https://github.com/${GITHUB_ORG}/${repo}.git"
        
        # Special handling for ADK fork
        if [ "$repo" = "adk-python" ]; then
            cd "$repo"
            git remote add upstream https://github.com/google/adk-python.git
            git fetch upstream
            info "✓ Added upstream remote for adk-python fork"
            cd ..
        fi
    fi
done

info "✓ All repositories cloned/updated"

# Create root README if it doesn't exist
if [ ! -f "README.md" ]; then
    title "Creating Root Documentation"
    cat > README.md << 'EOF'
# Nodus OS - ADK Edition

Complete ADK-based development workspace for Nodus OS.

## Quick Start

```bash
cd nodus-adk-infra
./scripts/setup.sh
./dev up
```

See individual repository READMEs for details.

## Repositories

- **adk-python**: Google ADK fork
- **nodus-adk-runtime**: ADK runtime server
- **nodus-adk-agents**: Agent definitions
- **nodus-adk-infra**: DEVSTACK infrastructure
- **nodus-backoffice**: Control plane
- **nodus-llibreta**: UI
- **nodus-mcp-gateway**: MCP integration

## Documentation

- [Setup Guide](nodus-adk-infra/docs/SETUP.md)
- [Development Guide](nodus-adk-infra/docs/DEVELOPMENT.md)
- [Architecture](nodus-adk-infra/docs/ARCHITECTURE.md)
EOF
    info "✓ Root README created"
fi

# Run infrastructure setup
title "Setting Up DEVSTACK"

cd nodus-adk-infra

if [ ! -f ".env" ]; then
    info "Creating .env from template..."
    if [ -f ".env.example" ]; then
        cp .env.example .env
        warn "⚠ Please review and update .env with your configuration"
    else
        warn ".env.example not found, skipping .env creation"
    fi
fi

if [ -f "scripts/setup.sh" ]; then
    info "Running infrastructure setup..."
    ./scripts/setup.sh
else
    warn "Setup script not found, skipping"
fi

cd ..

# Final instructions
title "Setup Complete!"

cat << EOF
${GREEN}✓ Workspace ready at: $(pwd)${NC}

${BLUE}Next steps:${NC}

1. Review configuration:
   ${YELLOW}vim nodus-adk-infra/.env${NC}

2. Start DEVSTACK:
   ${YELLOW}cd nodus-adk-infra${NC}
   ${YELLOW}./dev up${NC}

3. Check status:
   ${YELLOW}./dev status${NC}

4. Access services:
   - Llibreta:     http://localhost:5002
   - Backoffice:   http://localhost:5001
   - ADK Runtime:  http://localhost:8080
   - MCP Gateway:  http://localhost:7443

${BLUE}Documentation:${NC}
   - Setup:        nodus-adk-infra/docs/SETUP.md
   - Development:  nodus-adk-infra/docs/DEVELOPMENT.md
   - Architecture: nodus-adk-infra/docs/ARCHITECTURE.md

${GREEN}Happy coding! 🚀${NC}
EOF

