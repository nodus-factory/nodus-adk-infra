#!/bin/bash
# ============================================================================
# Observability Stack Verification Script
# ============================================================================
# Checks that OpenTelemetry + Langfuse are properly configured and working.
#
# Usage:
#   ./scripts/check_observability.sh
#
# Exit codes:
#   0 - All checks passed
#   1 - One or more checks failed
# ============================================================================

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Emojis
CHECK_MARK="✅"
CROSS_MARK="❌"
WARNING="⚠️"
INFO="ℹ️"

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Nodus OS ADK - Observability Stack Verification     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Track overall status
ALL_CHECKS_PASSED=true

# ============================================================================
# Helper Functions
# ============================================================================

check_pass() {
    echo -e "${GREEN}${CHECK_MARK} $1${NC}"
}

check_fail() {
    echo -e "${RED}${CROSS_MARK} $1${NC}"
    ALL_CHECKS_PASSED=false
}

check_warn() {
    echo -e "${YELLOW}${WARNING} $1${NC}"
}

check_info() {
    echo -e "${BLUE}${INFO} $1${NC}"
}

# ============================================================================
# Check 1: Langfuse Service
# ============================================================================

echo -e "${BLUE}[1/7] Checking Langfuse service...${NC}"

if docker ps --format '{{.Names}}' | grep -q 'nodus-adk-langfuse'; then
    check_pass "Langfuse container is running"
    
    # Check health
    LANGFUSE_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/public/health 2>/dev/null || echo "000")
    
    if [ "$LANGFUSE_HEALTH" = "200" ]; then
        check_pass "Langfuse health check passed (HTTP 200)"
    else
        check_fail "Langfuse health check failed (HTTP $LANGFUSE_HEALTH)"
        check_info "Try: ./dev logs langfuse"
    fi
else
    check_fail "Langfuse container is not running"
    check_info "Start with: ./dev up langfuse"
fi

echo ""

# ============================================================================
# Check 2: Langfuse Database
# ============================================================================

echo -e "${BLUE}[2/7] Checking Langfuse database...${NC}"

DB_EXISTS=$(docker exec nodus-adk-postgres psql -U nodus -lqt 2>/dev/null | cut -d \| -f 1 | grep -w langfuse_db || echo "")

if [ -n "$DB_EXISTS" ]; then
    check_pass "langfuse_db database exists"
    
    # Check extensions
    EXTENSIONS=$(docker exec nodus-adk-postgres psql -U nodus -d langfuse_db -c "SELECT extname FROM pg_extension;" -t 2>/dev/null || echo "")
    
    if echo "$EXTENSIONS" | grep -q "uuid-ossp"; then
        check_pass "uuid-ossp extension installed"
    else
        check_warn "uuid-ossp extension not found (may cause issues)"
    fi
    
    if echo "$EXTENSIONS" | grep -q "pg_trgm"; then
        check_pass "pg_trgm extension installed"
    else
        check_warn "pg_trgm extension not found (may cause issues)"
    fi
else
    check_fail "langfuse_db database does not exist"
    check_info "Database should be created automatically on first startup"
    check_info "Try: ./dev restart postgres langfuse"
fi

echo ""

# ============================================================================
# Check 3: ADK Runtime Service
# ============================================================================

echo -e "${BLUE}[3/7] Checking ADK Runtime service...${NC}"

if docker ps --format '{{.Names}}' | grep -q 'nodus-adk-runtime'; then
    check_pass "ADK Runtime container is running"
    
    # Check health
    ADK_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health 2>/dev/null || echo "000")
    
    if [ "$ADK_HEALTH" = "200" ]; then
        check_pass "ADK Runtime health check passed (HTTP 200)"
    else
        check_warn "ADK Runtime health check failed (HTTP $ADK_HEALTH)"
        check_info "Service may still be starting up"
    fi
else
    check_fail "ADK Runtime container is not running"
    check_info "Start with: ./dev up adk-runtime"
fi

echo ""

# ============================================================================
# Check 4: OpenTelemetry Configuration
# ============================================================================

echo -e "${BLUE}[4/7] Checking OpenTelemetry configuration...${NC}"

if docker ps --format '{{.Names}}' | grep -q 'nodus-adk-runtime'; then
    # Check OTEL environment variables
    OTEL_ENDPOINT=$(docker exec nodus-adk-runtime env 2>/dev/null | grep OTEL_EXPORTER_OTLP_ENDPOINT || echo "")
    OTEL_SERVICE=$(docker exec nodus-adk-runtime env 2>/dev/null | grep OTEL_SERVICE_NAME || echo "")
    OTEL_SAMPLER=$(docker exec nodus-adk-runtime env 2>/dev/null | grep OTEL_TRACES_SAMPLER || echo "")
    
    if [ -n "$OTEL_ENDPOINT" ]; then
        check_pass "OTEL_EXPORTER_OTLP_ENDPOINT is set"
        echo "  $(echo $OTEL_ENDPOINT | sed 's/=/ = /')"
    else
        check_fail "OTEL_EXPORTER_OTLP_ENDPOINT is not set"
        check_info "Should be: http://langfuse:3000/api/public/ingestion"
    fi
    
    if [ -n "$OTEL_SERVICE" ]; then
        check_pass "OTEL_SERVICE_NAME is set"
    else
        check_warn "OTEL_SERVICE_NAME is not set (will use default)"
    fi
    
    if [ -n "$OTEL_SAMPLER" ]; then
        check_pass "OTEL_TRACES_SAMPLER is set"
        echo "  $(echo $OTEL_SAMPLER | sed 's/=/ = /')"
    else
        check_warn "OTEL_TRACES_SAMPLER not set (will use default)"
    fi
else
    check_fail "Cannot check - ADK Runtime is not running"
fi

echo ""

# ============================================================================
# Check 5: Langfuse Credentials
# ============================================================================

echo -e "${BLUE}[5/7] Checking Langfuse credentials...${NC}"

if docker ps --format '{{.Names}}' | grep -q 'nodus-adk-runtime'; then
    LANGFUSE_ENABLED=$(docker exec nodus-adk-runtime env 2>/dev/null | grep LANGFUSE_ENABLED || echo "")
    LANGFUSE_PUBLIC=$(docker exec nodus-adk-runtime env 2>/dev/null | grep LANGFUSE_PUBLIC_KEY || echo "")
    LANGFUSE_SECRET=$(docker exec nodus-adk-runtime env 2>/dev/null | grep LANGFUSE_SECRET_KEY || echo "")
    
    if echo "$LANGFUSE_ENABLED" | grep -q "true"; then
        check_pass "LANGFUSE_ENABLED=true"
    else
        check_warn "LANGFUSE_ENABLED is false or not set"
    fi
    
    if echo "$LANGFUSE_PUBLIC" | grep -q "pk-lf-"; then
        check_pass "LANGFUSE_PUBLIC_KEY is set"
        # Mask the key
        KEY_MASKED=$(echo "$LANGFUSE_PUBLIC" | sed 's/\(pk-lf-[a-zA-Z0-9]\{8\}\).*/\1.../')
        echo "  $KEY_MASKED"
    else
        check_fail "LANGFUSE_PUBLIC_KEY is not set or invalid"
        check_info "Generate keys in Langfuse UI: Settings → API Keys"
        check_info "Then add to .env and restart: ./dev restart adk-runtime"
    fi
    
    if echo "$LANGFUSE_SECRET" | grep -q "sk-lf-"; then
        check_pass "LANGFUSE_SECRET_KEY is set"
    else
        check_fail "LANGFUSE_SECRET_KEY is not set or invalid"
    fi
else
    check_fail "Cannot check - ADK Runtime is not running"
fi

echo ""

# ============================================================================
# Check 6: Telemetry Initialization
# ============================================================================

echo -e "${BLUE}[6/7] Checking telemetry initialization...${NC}"

if docker ps --format '{{.Names}}' | grep -q 'nodus-adk-runtime'; then
    # Check logs for telemetry initialization
    TELEMETRY_LOGS=$(docker logs nodus-adk-runtime 2>&1 | grep -i "telemetry\|observability" | tail -5 || echo "")
    
    if echo "$TELEMETRY_LOGS" | grep -q "initialized successfully"; then
        check_pass "Telemetry initialized successfully"
    elif echo "$TELEMETRY_LOGS" | grep -q "not configured"; then
        check_fail "Telemetry not configured"
        check_info "Check Langfuse credentials"
    elif echo "$TELEMETRY_LOGS" | grep -q "disabled"; then
        check_warn "Telemetry explicitly disabled"
    else
        check_warn "Cannot determine telemetry status from logs"
        check_info "Check logs manually: ./dev logs adk-runtime | grep -i telemetry"
    fi
    
    # Show relevant log lines
    if [ -n "$TELEMETRY_LOGS" ]; then
        echo ""
        echo "  Recent telemetry logs:"
        echo "$TELEMETRY_LOGS" | sed 's/^/    /'
    fi
else
    check_fail "Cannot check - ADK Runtime is not running"
fi

echo ""

# ============================================================================
# Check 7: End-to-End Test (Optional)
# ============================================================================

echo -e "${BLUE}[7/7] Running end-to-end test (optional)...${NC}"

if [ "$ALL_CHECKS_PASSED" = true ]; then
    check_info "All previous checks passed - attempting E2E test"
    
    # Try to access Langfuse traces endpoint
    TRACES_ACCESSIBLE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/traces 2>/dev/null || echo "000")
    
    if [ "$TRACES_ACCESSIBLE" = "200" ] || [ "$TRACES_ACCESSIBLE" = "302" ]; then
        check_pass "Langfuse UI is accessible"
        check_info "Visit: http://localhost:3000"
    else
        check_warn "Cannot access Langfuse UI (HTTP $TRACES_ACCESSIBLE)"
    fi
else
    check_warn "Skipping E2E test due to previous failures"
fi

echo ""

# ============================================================================
# Summary
# ============================================================================

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
if [ "$ALL_CHECKS_PASSED" = true ]; then
    echo -e "${GREEN}║  ${CHECK_MARK} ALL CHECKS PASSED - System is ready!              ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}Next steps:${NC}"
    echo "  1. Access Langfuse UI: http://localhost:3000"
    echo "  2. Send a test message to the assistant"
    echo "  3. Check traces in Langfuse: http://localhost:3000/traces"
    echo ""
    echo -e "${BLUE}Documentation: docs/OBSERVABILITY.md${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}║  ${CROSS_MARK} SOME CHECKS FAILED - See details above          ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Common fixes:${NC}"
    echo "  • Services not running: ./dev up"
    echo "  • Langfuse credentials missing: Check docs/OBSERVABILITY.md"
    echo "  • Database issues: ./dev restart postgres langfuse"
    echo "  • Configuration issues: Check .env file"
    echo ""
    echo -e "${BLUE}Need help? Check: docs/OBSERVABILITY.md${NC}"
    echo ""
    exit 1
fi


