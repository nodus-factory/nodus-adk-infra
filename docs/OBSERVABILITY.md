# 🔍 Observability Stack - Nodus OS ADK

Complete observability solution for Nodus OS ADK using **OpenTelemetry** + **Langfuse**.

## 📊 Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  Nodus ADK Applications                     │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  ADK Runtime (Python)                                │  │
│  │  - Agent invocations                                 │  │
│  │  - Tool calls (MCP, Knowledge Base, etc.)           │  │
│  │  - LLM requests (Gemini, OpenAI)                    │  │
│  └──────────────────────────────────────────────────────┘  │
│                          │                                  │
│                          │ Automatic Instrumentation        │
│                          ▼                                  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  OpenTelemetry SDK                                   │  │
│  │  - Captures spans, metrics, logs                     │  │
│  │  - Semantic conventions (Gen AI 1.37)                │  │
│  │  - Automatic context propagation                     │  │
│  └──────────────────────────────────────────────────────┘  │
│                          │                                  │
│                          │ OTLP/HTTP                        │
│                          ▼                                  │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    Langfuse Backend                         │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  OTLP Ingestion Endpoint                             │  │
│  │  http://langfuse:3000/api/public/ingestion           │  │
│  │  - Receives traces via OTLP                          │  │
│  │  - Converts to Langfuse format                       │  │
│  └──────────────────────────────────────────────────────┘  │
│                          │                                  │
│                          ▼                                  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  PostgreSQL (langfuse_db)                            │  │
│  │  - Traces, spans, generations                        │  │
│  │  - Prompt versions                                   │  │
│  │  - User sessions                                     │  │
│  └──────────────────────────────────────────────────────┘  │
│                          │                                  │
│                          ▼                                  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Langfuse Web UI                                     │  │
│  │  http://localhost:3000                               │  │
│  │  - Trace visualization                               │  │
│  │  - Cost tracking                                     │  │
│  │  - Prompt management                                 │  │
│  │  - Analytics & dashboards                            │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

### 1. Start the Stack

```bash
cd nodus-adk-infra
./dev up
```

This starts:
- ✅ PostgreSQL with `langfuse_db` database
- ✅ Langfuse UI on `http://localhost:3000`
- ✅ ADK Runtime with OpenTelemetry configured

### 2. Configure Langfuse (First Time Only)

1. **Access Langfuse UI:**
   ```bash
   open http://localhost:3000
   ```

2. **Create Admin Account:**
   - First user becomes admin automatically
   - Use strong password

3. **Create Project:**
   - Name: `nodus-adk`
   - Description: `Nodus OS ADK Runtime Observability`

4. **Generate API Keys:**
   - Go to: Settings → API Keys
   - Click "Create New Key"
   - Copy both keys:
     - `LANGFUSE_PUBLIC_KEY` (starts with `pk-lf-`)
     - `LANGFUSE_SECRET_KEY` (starts with `sk-lf-`)

5. **Update `.env`:**
   ```bash
   cd nodus-adk-infra
   nano .env  # or your editor
   ```
   
   Add the keys:
   ```bash
   LANGFUSE_PUBLIC_KEY=pk-lf-xxxxxxxxxxxxxxxxxxxxxxxx
   LANGFUSE_SECRET_KEY_API=sk-lf-xxxxxxxxxxxxxxxxxxxxxxxx
   ```

6. **Restart ADK Runtime:**
   ```bash
   ./dev restart adk-runtime
   ```

### 3. Verify Observability

Run the verification script:

```bash
cd nodus-adk-infra
./scripts/check_observability.sh
```

Expected output:
```
✅ Langfuse is running and healthy
✅ ADK Runtime is running
✅ OpenTelemetry is configured
✅ Langfuse credentials are set
✅ Traces are being sent to Langfuse
```

### 4. Test with a Query

Send a test message to the assistant:

```bash
curl -X POST http://localhost:8080/v1/assistant/sessions/test-123/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "message": "Hello, how are you?"
  }'
```

Then check Langfuse UI:
- Go to: http://localhost:3000/traces
- You should see a new trace with the agent invocation!

---

## 📋 What Gets Traced Automatically

Thanks to ADK's built-in OpenTelemetry instrumentation, the following are **automatically traced**:

### ✅ Agent Invocations
- Agent name
- Description
- Session ID
- Invocation ID
- Execution time

### ✅ Tool Calls
- Tool name (e.g., `query_knowledge_base`, `mcp.call`)
- Arguments (sanitized if PII protection enabled)
- Response
- Execution time
- Success/failure status

### ✅ LLM Requests
- Model name (e.g., `gemini-2.0-flash-exp`)
- Prompt (optional, configurable)
- Response
- **Token usage** (input/output)
- Temperature, max_tokens, etc.
- Finish reason

### ✅ HTTP Calls
- Requests to MCP Gateway
- Requests to Backoffice
- External API calls

### ✅ Asyncio Tasks
- Concurrent operations
- Background tasks

---

## 🎛️ Configuration

### Environment Variables

All configuration is done via environment variables in `.env`:

```bash
# ============================================================================
# Langfuse Configuration
# ============================================================================

# Enable/disable observability
LANGFUSE_ENABLED=true

# Langfuse server URL (internal Docker network)
LANGFUSE_HOST=http://langfuse:3000

# API credentials (from Langfuse UI)
LANGFUSE_PUBLIC_KEY=pk-lf-xxxxxxxx
LANGFUSE_SECRET_KEY_API=sk-lf-xxxxxxxx

# ============================================================================
# OpenTelemetry Configuration
# ============================================================================

# OTLP endpoint (Langfuse ingestion)
OTEL_EXPORTER_OTLP_ENDPOINT=http://langfuse:3000/api/public/ingestion

# Service name (appears in traces)
OTEL_SERVICE_NAME=nodus-adk-runtime

# Sampling configuration
# Options: always_on, always_off, traceidratio, parentbased_always_on, 
#          parentbased_always_off, parentbased_traceidratio
OTEL_TRACES_SAMPLER=parentbased_traceidratio

# Sampling rate (0.0 to 1.0)
# 1.0 = 100% (trace everything) - good for development
# 0.1 = 10% (trace 10%) - good for production
OTEL_TRACES_SAMPLER_ARG=1.0

# ============================================================================
# ADK Telemetry Configuration
# ============================================================================

# Capture message content in spans (prompts, responses)
# Set to false in production if you have PII concerns
ADK_CAPTURE_MESSAGE_CONTENT_IN_SPANS=true
```

### Sampling Strategies

**Development:**
```bash
OTEL_TRACES_SAMPLER=parentbased_traceidratio
OTEL_TRACES_SAMPLER_ARG=1.0  # Trace everything
```

**Production (Low Traffic):**
```bash
OTEL_TRACES_SAMPLER=parentbased_traceidratio
OTEL_TRACES_SAMPLER_ARG=0.5  # Trace 50%
```

**Production (High Traffic):**
```bash
OTEL_TRACES_SAMPLER=parentbased_traceidratio
OTEL_TRACES_SAMPLER_ARG=0.1  # Trace 10%
```

**Custom (Trace only errors):**
Requires custom sampler implementation in `observability.py`.

---

## 🛠️ Advanced Usage

### Manual Instrumentation

For custom operations not automatically traced:

```python
from nodus_adk_runtime.observability import get_tracer, add_span_attributes

tracer = get_tracer(__name__)

# Manual span
with tracer.start_as_current_span("custom_operation") as span:
    # Add custom attributes
    span.set_attribute("tenant_id", "acme")
    span.set_attribute("user_id", "user-123")
    
    # Your code here
    result = do_something()
    
    span.set_attribute("result_count", len(result))
```

### Decorator for Functions

```python
from nodus_adk_runtime.observability import traced

@traced("process_knowledge_query", {"operation": "rag"})
async def process_knowledge_query(query: str, tenant_id: str):
    # Automatically traced with custom span name and attributes
    results = await search_knowledge_base(query)
    return results
```

### Add Context to Current Span

```python
from nodus_adk_runtime.observability import add_span_attributes

# Add metadata to the current span
add_span_attributes({
    "tenant_id": tenant_id,
    "user_id": user_id,
    "session_id": session_id,
    "mcp_tools_available": len(tools),
})
```

---

## 🔍 Langfuse Features

### 1. Trace Visualization

**View trace tree:**
- Navigate to: http://localhost:3000/traces
- Click on any trace
- See hierarchical view of agent → tools → LLM calls

### 2. Cost Tracking

**Automatic cost calculation:**
- Token usage automatically captured
- Configure pricing in Langfuse settings
- View costs per:
  - User
  - Session
  - Agent
  - Time period

### 3. Prompt Management

**Version control for prompts:**
- Store prompts in Langfuse
- A/B test different versions
- Track performance by version
- Rollback to previous versions

### 4. Analytics

**Built-in dashboards:**
- Requests per minute
- Average latency
- Token usage trends
- Error rates
- Top users/sessions

### 5. Debugging

**Trace-level debugging:**
- Filter by user, session, or agent
- Search by error messages
- Compare traces side-by-side
- Export traces for analysis

---

## 🐛 Troubleshooting

### Langfuse Not Starting

```bash
# Check Langfuse logs
./dev logs langfuse

# Common issues:
# 1. PostgreSQL not ready → Wait for postgres health check
# 2. Database URL wrong → Check .env DATABASE_URL
# 3. Port 3000 in use → Stop conflicting service
```

### No Traces in Langfuse

```bash
# Verify OpenTelemetry is configured
./dev exec adk-runtime env | grep OTEL

# Check ADK Runtime logs
./dev logs adk-runtime | grep -i "telemetry\|observability"

# Expected output:
# ✅ OpenTelemetry + Langfuse initialized successfully
```

### "Authentication failed" in Logs

```bash
# Verify credentials are correct
./dev exec adk-runtime env | grep LANGFUSE

# Regenerate keys in Langfuse UI if needed
```

### Traces Not Showing Up

1. **Check sampling:** If `OTEL_TRACES_SAMPLER_ARG=0.1`, only 10% of traces are captured
2. **Check credentials:** Public/Secret keys must match Langfuse project
3. **Check endpoint:** Must be `http://langfuse:3000/api/public/ingestion`

---

## 📚 Resources

- **Langfuse Docs:** https://langfuse.com/docs
- **OpenTelemetry Docs:** https://opentelemetry.io/docs/
- **ADK Telemetry:** https://google.github.io/adk-docs/telemetry
- **Gen AI Semantic Conventions:** https://opentelemetry.io/docs/specs/semconv/gen-ai/

---

## 🔐 Security & Privacy

### PII Protection

Set this in production:

```bash
ADK_CAPTURE_MESSAGE_CONTENT_IN_SPANS=false
```

This prevents prompts and responses from being sent to Langfuse. Metadata and metrics are still captured.

### Access Control

Langfuse has built-in RBAC:
- **Admin:** Full access
- **Member:** View traces, no settings
- **Viewer:** Read-only

Configure in: Settings → Team

### Data Retention

Configure in Langfuse UI:
- Settings → Data Retention
- Set automatic deletion after N days
- Export before deletion if needed

---

## 🎯 Best Practices

1. **Use descriptive span names:** `process_user_query` not `handle`
2. **Add tenant/user context:** Always include in root span
3. **Sample wisely:** 100% in dev, 10-20% in production
4. **Monitor costs:** Check token usage weekly
5. **Tag important traces:** Use attributes for filtering
6. **Regular cleanups:** Delete old traces to save storage

---

## 📊 Metrics Dashboard

### Key Metrics to Monitor

- **Requests/min:** Track load
- **P95 latency:** Detect slow operations
- **Token usage:** Control costs
- **Error rate:** Detect issues early
- **Tool success rate:** Monitor reliability

### Creating Dashboards

1. Go to: Langfuse → Analytics
2. Create custom views
3. Export to Grafana (optional)

---

## 🚧 Roadmap

Future improvements:

- [ ] Custom error-aware sampling
- [ ] Prometheus metrics export
- [ ] Grafana dashboards
- [ ] Alerting on error rates
- [ ] Distributed tracing across services
- [ ] Log correlation with traces

---

**Need help?** Check the [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) or ask the team! 🚀


