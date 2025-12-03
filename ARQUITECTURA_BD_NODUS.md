# 📊 Arquitectura de Bases de Dades - Nodus OS ADK

## 🎯 Estat Actual

Data: 26 Novembre 2025

### 🗄️ Bases de Dades PostgreSQL

Nodus OS utilitza **3 bases de dades separades** dins un únic contenidor PostgreSQL:

| Base de Dades | Propòsit | Servei Responsable | Taules Principals |
|---------------|----------|-------------------|-------------------|
| **`nodus`** | BD compartida per core + aplicacions | Backoffice, Llibreta, ADK Runtime | `users`, `tenants`, `roles`, `session`, `chat_messages`, `notebooks`, `conversation_messages` |
| **`langfuse_db`** | Observabilitat i traces | Langfuse | Taules internes de Langfuse |
| **`litellm_db`** | Proxy LLM i configuració | LiteLLM | Taules Prisma de LiteLLM |

---

## 🏗️ Arquitectura de Persistència

### ✅ Què funciona

1. **Bind Mounts** (`./data/postgres:/var/lib/postgresql/data`)
   - Les dades físiques es guarden al host
   - Compatible amb Time Machine (macOS)
   - Backups automàtics del sistema operatiu

2. **Backoffice com a "Guardià" del Core Schema**
   - Executa `ensureCoreSchema()` a CADA arrencada
   - Crea taules core amb `CREATE TABLE IF NOT EXISTS`
   - Insereix dades seed amb `ON CONFLICT DO NOTHING`
   - **✅ Idempotent**: Pot executar-se múltiples vegades sense problemes

3. **Llibreta amb Migracions Idempotents**
   - Executa `initializeDatabase()` a CADA arrencada
   - Usa DDL autocommit per garantir persistència
   - **✅ Idempotent**: Les migracions usen `IF NOT EXISTS`

4. **LiteLLM amb BD Separada**
   - Usa la seva pròpia BD `litellm_db`
   - Migracions Prisma automàtiques
   - **✅ No contamina** la BD `nodus`

---

## ⚠️ Problema Actual

### 🐛 Les taules desapareixen després de `docker compose down`/`up`

**Simptomes**:
- ✅ Durant la sessió: 60 taules (core + Llibreta + Backoffice + LiteLLM)
- ❌ Després de `down`/`up`: 44 taules (només LiteLLM)
- ❌ Taules perdudes: `users`, `tenants`, `roles`, `chat_messages`, `notebooks`, etc.

**Diagnòstic**:
1. **Els init scripts de Postgres (`/docker-entrypoint-initdb.d`) NOMÉS s'executen si `/var/lib/postgresql/data` està BUIT**
2. Després del primer `up`, el directori ja no està buit, així que els scripts no es tornen a executar
3. Backoffice i Llibreta **SÍ executen els seus init scripts** a cada arrencada
4. **PERÒ** les taules que creen NO persisteixen després del `down`

**Causa arrel**: 
- Postgres pot no estar fent `fsync` correctament abans del shutdown
- O hi ha algun problema amb els bind mounts i el sistema de fitxers de Docker

---

## 🔧 Solucions Proposades

### ✅ Opció 1: Usar Named Volumes (Recomanat per Staging/Prod)

```yaml
postgres:
  volumes:
    - postgres_data:/var/lib/postgresql/data  # Named volume
    - ./config/postgres:/docker-entrypoint-initdb.d

volumes:
  postgres_data:
    name: nodus-adk-postgres-data
```

**Avantatges**:
- ✅ Gestionat per Docker (més fiable)
- ✅ Millor rendiment
- ✅ Funciona igual a staging/prod (Hetzner)

**Desavantatges**:
- ❌ No compatible amb Time Machine automàtic
- ⚠️ Cal backups manuals o scripts

---

### ✅ Opció 2: Forçar CHECKPOINT abans del shutdown

Modificar `docker-compose.yml`:

```yaml
postgres:
  image: postgres:15-alpine
  stop_signal: SIGINT  # Graceful shutdown
  stop_grace_period: 60s  # Donar temps per fer CHECKPOINT
```

---

### ✅ Opció 3: Usar `docker compose stop`/`start` en lloc de `down`/`up`

```bash
# EVITAR (perd dades):
docker compose down && docker compose up

# PREFERIR (manté dades):
docker compose stop && docker compose start
```

**Motiu**: `stop` fa un shutdown graceful sense eliminar els contenidors.

---

## 🧩 Components i Responsabilitats

### 1. **Backoffice** - Guardià del Core Schema

**Responsabilitat**:
- Crear i mantenir el **core schema** (`users`, `tenants`, `roles`, `session`)
- Crear taules del Backoffice (`knowledge_*`, `settings`, `contacts`, etc.)

**Init Script**: `server/init-core-schema.ts`

```typescript
export async function ensureCoreSchema(): Promise<void> {
  // Executa CREATE TABLE IF NOT EXISTS per totes les taules core
  // Executa INSERT ... ON CONFLICT DO NOTHING per dades seed
}
```

**Crida**: `server/index.ts` - ABANS de registrar rutes

---

### 2. **Llibreta** - Aplicació Independent

**Responsabilitat**:
- Crear i mantenir les seves pròpies taules (`notebooks`, `chat_messages`, `text_cards`, etc.)
- Comparteix BD `nodus` però NO toca taules core

**Init Script**: `server/init-database.ts`

```typescript
export async function initializeDatabase(): Promise<void> {
  // Executa migracions SQL amb DDL autocommit
  // 001_create_llibreta_tables.sql
  // 002_add_source_to_chat_messages.sql
  // 003_add_user_id_columns.sql
  // etc.
}
```

**Crida**: `server/index.ts` - ABANS de registrar rutes

---

### 3. **ADK Runtime** - Memory Adapter

**Responsabilitat**:
- Crear taula `conversation_messages` per històric de converses
- Usa Qdrant per vectors RAG

**Init Script**: `src/nodus_adk_runtime/adapters/memory_adapter.py`

```python
async def _ensure_schema(self):
    """Ensure database schema exists for conversation history."""
    await conn.execute("""
        CREATE TABLE IF NOT EXISTS conversation_messages (
            id SERIAL PRIMARY KEY,
            tenant_id VARCHAR(255),
            user_id VARCHAR(255),
            session_id VARCHAR(255),
            role VARCHAR(50),
            content TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    """)
```

**Crida**: A l'inicialitzar el `MemoryAdapter`

---

### 4. **LiteLLM** - Proxy LLM

**Responsabilitat**:
- Gestionar la seva pròpia BD `litellm_db`
- Migracions Prisma automàtiques

**Configuració**: `docker-compose.yml`

```yaml
environment:
  - DATABASE_URL=postgresql://nodus:nodus_dev_password@postgres:5432/litellm_db
```

---

### 5. **Langfuse** - Observabilitat

**Responsabilitat**:
- Gestionar la seva pròpia BD `langfuse_db`
- Traces, prompts, versioning

**Configuració**: `docker-compose.yml`

```yaml
environment:
  DATABASE_URL: postgresql://nodus:nodus_dev_password@postgres:5432/langfuse_db
```

---

## 🔐 Seguretat i Aïllament

### Multi-tenancy

| Nivell | Estratègia | Implementació |
|--------|-----------|---------------|
| **Backoffice** | Row-level (tenant_id) | Taules amb `tenant_id` + RLS |
| **Llibreta** | Row-level (user_id) | Taules amb `user_id` |
| **ADK Runtime** | Row-level (tenant_id + user_id) | `conversation_messages` amb ambdós |
| **Langfuse** | Project-level | Projects separats per tenant |
| **LiteLLM** | Key-level | API keys per tenant |

---

## 📦 OpenMemory (Independent)

**Ubicació**: Workspace `nodus-os` (separato de `nodus-os-adk`)

**Arquitectura**:
- ✅ **SQLite** per metadades (`/data/openmemory.sqlite`)
- ✅ **SQLite** per vectors
- ✅ **Named Volume** (`openmemory_data`)
- ✅ **Totalment independent** de PostgreSQL

**NO afecta** la BD `nodus`.

---

## 🎯 Recomanacions per Staging/Prod (Hetzner)

### ✅ Usar Named Volumes

```yaml
postgres:
  volumes:
    - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
    driver: local
```

### ✅ Backups Automàtics

```bash
# Cron job per backups diaris
0 2 * * * docker exec nodus-adk-postgres pg_dumpall -U nodus > /backups/nodus-$(date +\%Y\%m\%d).sql
```

### ✅ Monitorització

- Langfuse per traces LLM
- Prometheus/Grafana per mètriques Postgres
- Logs agregats amb Loki

---

## 📊 Resum d'Arquitectura

```
┌─────────────────────────────────────────────────────────┐
│           PostgreSQL (1 container)                       │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  📦 nodus (BD compartida)                               │
│  ├── Core Schema (users, tenants, roles, session)      │ ← Backoffice
│  ├── Backoffice Schema (knowledge_*, settings...)      │ ← Backoffice
│  ├── Llibreta Schema (notebooks, chat_messages...)     │ ← Llibreta
│  └── ADK Memory (conversation_messages)                │ ← ADK Runtime
│                                                          │
│  📦 langfuse_db                                         │ ← Langfuse
│                                                          │
│  📦 litellm_db                                          │ ← LiteLLM
│                                                          │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│           Qdrant (vector store)                          │
├─────────────────────────────────────────────────────────┤
│  • ADK Memory: adk_memory_{tenant_id}                  │
│  • ADK Memory: adk_memory_{tenant_id}_user_{user}      │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│           OpenMemory (servei independent)                │
├─────────────────────────────────────────────────────────┤
│  • SQLite: /data/openmemory.sqlite (metadades)         │
│  • SQLite: vectors (embeddings)                         │
│  • Named Volume: openmemory_data                        │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│           Redis (cache/sessions)                         │
└─────────────────────────────────────────────────────────┘
```

---

## 🚀 Next Steps

1. **Decidir estratègia de persistència**:
   - ✅ Bind mounts (dev local amb Time Machine)
   - ✅ Named volumes (staging/prod Hetzner)

2. **Implementar backups automàtics**:
   - Scripts de backup/restore
   - Verificació de restauració

3. **Monitorització**:
   - Alertes per pèrdua de dades
   - Mètriques de rendiment

4. **Documentació**:
   - Procediments de backup/restore
   - Runbooks per incidents

---

**Creat per**: AI Assistant  
**Data**: 26 Novembre 2025  
**Workspace**: `nodus-os-adk`  
**Versió**: 1.0


