#!/bin/bash
#
# Initial setup script for Nodus ADK DEVSTACK
#

set -e

echo "🚀 Setting up Nodus ADK DEVSTACK"
echo ""

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Please install Docker first."
    exit 1
fi

if ! command -v docker compose &> /dev/null; then
    echo "❌ Docker Compose not found. Please install Docker Compose first."
    exit 1
fi

echo "✅ Docker and Docker Compose found"

# Create .env if not exists
if [ ! -f ".env" ]; then
    echo "📝 Creating .env file from template..."
    cp .env.example .env
    echo "✅ .env created. Please review and update with your configuration."
else
    echo "✅ .env file already exists"
fi

# Pull base images
echo ""
echo "📦 Pulling base images..."
docker compose pull postgres redis qdrant minio

echo ""
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Review and update .env file"
echo "2. Run: ./dev up"
echo ""


