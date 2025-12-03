# Estructura de Bases de Dades - Nodus OS ADK

## Resum Executiu

L'aplicació Nodus OS ADK utilitza múltiples bases de dades PostgreSQL per separar les responsabilitats de cada servei. Totes les bases de dades s'executen en una única instància PostgreSQL compartida.

## Bases de Dades Principals

### 1. `nodus_db` (Base de Dades Principal)
- **Propietari**: `nodus` (usuari PostgreSQL)
- **Mida actual**: ~10 MB
- **Propòsit**: Base de dades principal del Backoffice i sistema de gestió
- **Serveis que l'utilitzen**:
  - `backoffice` - Aplicació principal de gestió
  - `llibreta` - Autenticació (via `AUTH_DATABASE_URL`)
  - `adk-runtime` - Sessions i memòria de converses
- **Inicialització**: `00-init-backoffice.sh`
- **Dades inicials**: `init-production-data.sql.seed`
- **Migracions**: Drizzle ORM (directori `migrations/`)
- **Taules principals**:
  - `users`, `roles`, `tenants` - Gestió d'usuaris i permisos
  - `settings` - Configuració de l'aplicació (branding, email, etc.)
  - `menus`, `menu_roles` - Sistema de menús i permisos
  - `secret_handles` - Gestió de secrets
  - `tenant_egress_policies` - Polítiques de sortida per tenant
  - `adk_conversation_memory` - Memòria de converses (creada per `03-init-openmemory.sh`)
  - `recordings` - Gravacions processades (migració `20251126_create_recordings_table.sql`)

### 2. `litellm_db` (LiteLLM Proxy)
- **Propietari**: `nodus`
- **Mida actual**: ~8.4 MB
- **Propòsit**: Emmagatzematge de configuració de models i claus API per LiteLLM
- **Serveis que l'utilitzen**:
  - `litellm` - Gateway unificat per models d'IA
- **Inicialització**: `01-init-litellm.sh`
- **Extensions**: `uuid-ossp`
- **Taules**: Generades automàticament per Prisma (LiteLLM utilitza Prisma ORM)
  - `litellm_keys` - Claus API i configuració
  - `litellm_users` - Usuaris del proxy
  - `litellm_config` - Configuració de models
  - `litellm_spendlogs` - Logs de costos

### 3. `langfuse_db` (Langfuse Observability)
- **Propietari**: `nodus`
- **Mida actual**: ~11 MB
- **Propòsit**: Observabilitat i tracing de crides a models LLM
- **Serveis que l'utilitzen**:
  - `langfuse` - Plataforma d'observabilitat per LLM
- **Inicialització**: `02-init-langfuse.sh`
- **Extensions**: `uuid-ossp`, `pg_trgm` (per cerca de text)
- **Taules**: Generades automàticament per Langfuse
  - Traces, spans, generacions, scores, etc.

### 4. `infisical_compat149` (Infisical Secrets Manager)
- **Propietari**: `infisical_service` (usuari dedicat)
- **Mida actual**: ~16 MB
- **Propòsit**: Gestió centralitzada de secrets i credencials
- **Serveis que l'utilitzen**:
  - `infisical` - Gestor de secrets
- **Inicialització**: `03-init-infisical.sh`
- **Usuari dedicat**: `infisical_service` amb password `change-me-infisical`
- **Taules**: Generades automàticament per Infisical
  - Secrets, projectes, entorns, etc.

### 5. `openmemory` (OpenMemory - DEPRECATED)
- **Propietari**: `nodus`
- **Mida actual**: ~7.5 MB
- **Propòsit**: Sistema de memòria per a converses (DEPRECATED)
- **Estat**: ⚠️ **DEPRECATED** - Reemplaçat per Qdrant directe per CAPA 2
- **Inicialització**: `03-init-openmemory.sh`
- **Nota**: Mantingut per compatibilitat però no s'utilitza activament

## Configuració de Connexions

### Variables d'Entorn Principals

```bash
# Usuari i contrasenya PostgreSQL (compartit)
POSTGRES_USER=nodus
POSTGRES_PASSWORD=nodus_dev_password  # o nodus_password en producció

# Base de dades principal
POSTGRES_DB=nodus_db
```

### Connexions per Servei

#### Backoffice
```yaml
DATABASE_URL: postgresql://nodus:nodus_dev_password@postgres:5432/nodus_db
```

#### Llibreta
```yaml
# Base de dades pròpia (notebooks, cards, chat)
DATABASE_URL: postgresql://nodus:nodus_dev_password@postgres:5432/nodus_db

# Base de dades d'autenticació (users, roles)
AUTH_DATABASE_URL: postgresql://nodus:nodus_dev_password@postgres:5432/nodus_db
```

#### ADK Runtime
```yaml
DATABASE_URL: postgresql://nodus:nodus_dev_password@postgres:5432/nodus_db
```

#### LiteLLM
```yaml
DATABASE_URL: postgresql://nodus:nodus_dev_password@postgres:5432/litellm_db
```

#### Langfuse
```yaml
DATABASE_URL: postgresql://nodus:nodus_dev_password@postgres:5432/langfuse_db
```

#### Infisical
```yaml
DATABASE_URL: postgresql://infisical_service:change-me-infisical@postgres:5432/infisical_compat149
```

## Scripts d'Inicialització

Els scripts d'inicialització s'executen automàticament quan PostgreSQL s'inicia per primera vegada (directori `/docker-entrypoint-initdb.d/`):

1. **`00-init-backoffice.sh`** - Crea `nodus_db` i aplica dades inicials
2. **`01-init-litellm.sh`** - Crea `litellm_db` amb extensions
3. **`02-init-langfuse.sh`** - Crea `langfuse_db` amb extensions
4. **`02-migrations.sh`** - Aplica migracions SQL de Drizzle
5. **`03-init-infisical.sh`** - Crea usuari i base de dades per Infisical
6. **`03-init-openmemory.sh`** - Crea `openmemory` i taula `adk_conversation_memory`

## Ordre d'Execució

Els scripts s'executen en ordre alfabètic:
1. `00-init-backoffice.sh` (crea `nodus_db`)
2. `01-init-litellm.sh` (crea `litellm_db`)
3. `02-init-langfuse.sh` (crea `langfuse_db`)
4. `02-migrations.sh` (aplica migracions a `nodus_db`)
5. `03-init-infisical.sh` (crea `infisical_compat149`)
6. `03-init-openmemory.sh` (crea `openmemory`)

## Persistència

Totes les bases de dades es persisteixen en:
```
./data/postgres/
```

Aquest directori està muntat com a volum Docker i conté tots els fitxers de PostgreSQL.

## Seguretat

- **Usuari principal**: `nodus` - Accés a totes les bases de dades excepte Infisical
- **Usuari Infisical**: `infisical_service` - Accés només a `infisical_compat149`
- **Contrasenyes**: Configurades via variables d'entorn (`.env`)

## Notes Importants

1. **Llibreta i Backoffice comparteixen `nodus_db`**: Llibreta utilitza `nodus_db` tant per les seves dades pròpies (notebooks, cards) com per autenticació.

2. **OpenMemory està DEPRECATED**: El sistema de memòria ha estat migrat a Qdrant directe per CAPA 2, però la base de dades es manté per compatibilitat.

3. **Migracions Drizzle**: Les migracions SQL es troben a `nodus-backoffice/migrations/` i s'apliquen automàticament via `02-migrations.sh`.

4. **Extensions PostgreSQL**: 
   - `uuid-ossp`: Generació d'UUIDs (utilitzat per múltiples bases de dades)
   - `pg_trgm`: Cerca de text (només Langfuse)

5. **Prisma (LiteLLM)**: LiteLLM utilitza Prisma ORM i crea les seves taules automàticament en iniciar-se.

6. **Langfuse**: Crea les seves taules automàticament en la primera execució.

## Resum de Mides Actuals

| Base de Dades | Mida | Propòsit |
|--------------|------|----------|
| `nodus_db` | ~10 MB | Backoffice principal |
| `litellm_db` | ~8.4 MB | Configuració LiteLLM |
| `langfuse_db` | ~11 MB | Observabilitat |
| `infisical_compat149` | ~16 MB | Gestió de secrets |
| `openmemory` | ~7.5 MB | Memòria (DEPRECATED) |

**Total**: ~52.9 MB

## Manteniment

- **Backups**: Es recomana fer backups regulars del directori `./data/postgres/`
- **Migracions**: Les migracions de Drizzle s'apliquen automàticament però es poden executar manualment
- **Neteja**: La base de dades `openmemory` es pot eliminar si no es necessita compatibilitat amb versions antigues

