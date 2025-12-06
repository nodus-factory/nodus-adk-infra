# Dynamic Output Schemas - Sistema Flexible d'Outputs Estructurats

## 📋 Resum Executiu

Sistema per gestionar **outputs estructurats dinàmics** per diferents clients/tenants sense reconstruir el runtime. Permet definir schemas personalitzats en JSON i aplicar-los automàticament segons el tipus de resposta, amb suport per **hot reload**.

## 🎯 Problema

### Necessitat Actual

1. **Outputs inconsistents**: Les respostes de l'agent varien en format segons el context
2. **Multi-tenant**: Diferents clients necessiten diferents formats de resposta
3. **Hot reload**: Canvis de configuració sense reconstruir runtimes
4. **Flexibilitat**: Definir formats nous sense tocar codi Python

### Limitacions d'ADK

- `output_schema` es defineix quan es crea l'agent (no es pot canviar per request)
- Requereix models Pydantic compilats (no es poden crear dinàmicament fàcilment)
- No hi ha suport natiu per schemas per tenant

## 💡 Solució Proposada

### Arquitectura Híbrida

**Dues capes complementàries:**

1. **Schema Registry** (Configuració): Carrega schemas des de JSON per tenant
2. **Response Transformer** (Wrapper): Intercepta respostes i aplica schemas dinàmicament

```
┌─────────────────────────────────────────────────────────────┐
│                    User Request                              │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│              ADK Agent (sense output_schema)                 │
│              Genera resposta en text pla                      │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│         Response Schema Transformer (Wrapper)                │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  1. Detecta tipus de resposta                        │   │
│  │     - Analitza tool_calls                            │   │
│  │     - Analitza keywords a la resposta                │   │
│  │     - Analitza user message                          │   │
│  └──────────────────────────────────────────────────────┘   │
│                       │                                      │
│  ┌────────────────────▼──────────────────────────────────┐   │
│  │  2. Selecciona schema del Registry                    │   │
│  │     - Per tenant_id                                   │   │
│  │     - Per tipus de resposta                           │   │
│  └──────────────────────────────────────────────────────┘   │
│                       │                                      │
│  ┌────────────────────▼──────────────────────────────────┐   │
│  │  3. Extreu dades estructurades del text               │   │
│  │     - Parsing intel·ligent                            │   │
│  │     - O usa LLM per extracció                         │   │
│  └──────────────────────────────────────────────────────┘   │
│                       │                                      │
│  ┌────────────────────▼──────────────────────────────────┐   │
│  │  4. Valida amb Pydantic model                         │   │
│  │     - Creada dinàmicament des de JSON Schema          │   │
│  └──────────────────────────────────────────────────────┘   │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│         SessionResponse amb dades estructurades              │
│  - reply: Text formatat (original)                          │
│  - structured_data: Dades validades segons schema            │
└─────────────────────────────────────────────────────────────┘
```

## 🏗️ Components

### 1. Schema Registry

**Ubicació**: `nodus-adk-runtime/src/nodus_adk_runtime/services/output_schema_registry.py`

**Responsabilitats**:
- Carregar schemas des de JSON config files
- Crear models Pydantic dinàmicament des de JSON Schema
- Hot reload quan canvia la configuració
- Gestionar schemas per tenant

**API**:
```python
registry = SchemaRegistry(config_path="config/output_schemas.json")
registry.load_schemas(tenant_id="default")
schema_model = registry.get_schema("memory_temporal", tenant_id="default")
registry.reload_if_changed(tenant_id="default")  # Hot reload
```

### 2. Response Schema Transformer

**Ubicació**: `nodus-adk-runtime/src/nodus_adk_runtime/services/response_schema_transformer.py`

**Responsabilitats**:
- Detectar tipus de resposta automàticament
- Seleccionar schema adequat del registry
- Extreure dades estructurades del text
- Validar amb Pydantic model
- Retornar resposta estructurada

**API**:
```python
transformer = ResponseSchemaTransformer(
    tenant_id="default",
    schema_registry=registry
)

structured_response = transformer.transform_response(
    response_text="...",
    user_message="...",
    tool_calls=[...]
)
```

### 3. Config File Format

**Ubicació**: `nodus-adk-runtime/config/output_schemas.json`

**Format JSON Schema estàndard**:
```json
{
  "schemas": {
    "memory_temporal": {
      "description": "Response for temporal memory queries",
      "properties": {
        "found": {
          "type": "boolean",
          "description": "Whether memory was found"
        },
        "date_recorded": {
          "type": "string",
          "format": "date",
          "description": "Date when memory was recorded (YYYY-MM-DD)"
        },
        "time_recorded": {
          "type": "string",
          "description": "Time when memory was recorded (HH:MM)"
        },
        "content": {
          "type": "string",
          "description": "The memory content"
        },
        "summary": {
          "type": "string",
          "description": "Brief summary"
        }
      },
      "required": ["found", "content"]
    },
    "calendar_event": {
      "description": "Response for calendar events",
      "properties": {
        "event_found": {"type": "boolean"},
        "event_id": {"type": "string"},
        "title": {"type": "string"},
        "date": {"type": "string"},
        "time": {"type": "string"},
        "location": {"type": "string"},
        "attendees": {
          "type": "array",
          "items": {"type": "string"}
        }
      },
      "required": ["event_found"]
    }
  }
}
```

## 🔄 Flow Detallat

### Pas 1: Detecció de Tipus de Resposta

El transformer analitza:

1. **Tool calls executats**:
   - `query_memory` + keywords temporals → `memory_temporal`
   - `query_memory` general → `memory_general`
   - `create_event`, `get_events` → `calendar_event`
   - `query_pages` → `document_query`

2. **Keywords a la resposta**:
   - "Memorium", "memòria", "recordat" + "data"/"quan" → `memory_temporal`
   - "esdeveniment", "event", "calendari" → `calendar_event`

3. **User message intent**:
   - Preguntes sobre "quan" → `memory_temporal`
   - Preguntes sobre calendar → `calendar_event`

### Pas 2: Selecció de Schema

```python
schema_name = transformer.detect_response_type(
    response_text="Al meu Memorium consta que...",
    user_message="quan vas fer...",
    tool_calls=[{"name": "query_memory"}]
)
# Returns: "memory_temporal"
```

### Pas 3: Extracció de Dades

**Opció A: Parsing intel·ligent** (ràpid)
- Regex patterns per extreure camps
- Basat en estructura coneguda de la resposta

**Opció B: LLM extraction** (més precís)
- Usa un LLM per extreure dades estructurades del text
- Més flexible però més lent

### Pas 4: Validació i Transformació

```python
# Validar amb Pydantic model creat dinàmicament
validated = schema_model.model_validate(extracted_data)
structured_dict = validated.model_dump(exclude_none=True)
```

## 📝 Exemple d'Ús

### Configuració Inicial

```python
# A assistant.py
from nodus_adk_runtime.services.output_schema_registry import get_schema_registry
from nodus_adk_runtime.services.response_schema_transformer import ResponseSchemaTransformer

# Crear registry i transformer
schema_registry = get_schema_registry(config_path="config/output_schemas.json")
schema_registry.load_schemas(tenant_id=user_ctx.tenant_id)

transformer = ResponseSchemaTransformer(
    tenant_id=user_ctx.tenant_id,
    schema_registry=schema_registry
)
```

### Aplicació al Flow

```python
# A add_message() després de recollir events
async for event in runner.run_async(...):
    # Recull resposta text
    response_parts.append(part.text)

reply_text = " ".join(response_parts)

# Transformar amb schema
structured_response = transformer.transform_response(
    response_text=reply_text,
    user_message=request.message,
    tool_calls=tool_calls,
)

# Retornar resposta estructurada
return SessionResponse(
    session_id=session.id,
    conversation_id=conversation_id,
    reply=structured_response["formatted_text"],
    structured_data=[StructuredData(
        type=structured_response["schema_name"],
        data=structured_response["structured_data"]
    )] if structured_response["schema_name"] else [],
    ...
)
```

### Hot Reload

```python
# Abans de processar request, verificar canvis
schema_registry.reload_if_changed(tenant_id=user_ctx.tenant_id)
```

## 🎨 Exemples de Schemas

### Schema: Memory Temporal

**Quan s'usa**: Quan l'usuari pregunta "quan vas fer X?" o "quan vaig dir Y?"

**Exemple de resposta**:
```json
{
  "found": true,
  "date_recorded": "2025-12-05",
  "time_recorded": "16:33",
  "content": "Posem el dimarts 9 a les 10 del matí...",
  "summary": "Memòria trobada del 5 de desembre sobre formació"
}
```

### Schema: Calendar Event

**Quan s'usa**: Quan es pregunta sobre esdeveniments del calendari

**Exemple de resposta**:
```json
{
  "event_found": true,
  "event_id": "70ngkfl516ds1211ekvi4umd8c",
  "title": "Formació en Nodus",
  "date": "2025-12-09",
  "time": "10:00-14:00",
  "location": "Martí Julià",
  "attendees": ["maria@mynodus.com", "xavi@mynodus.com"]
}
```

### Schema: Document Query

**Quan s'usa**: Quan es pregunta sobre documents a pàgines

**Exemple de resposta**:
```json
{
  "documents_found": true,
  "page_number": 1,
  "results": [
    {
      "title": "Informe Segalés",
      "score": 0.85,
      "snippet": "..."
    }
  ]
}
```

## ✅ Avantatges

1. **Hot Reload**: Canvis de configuració sense reconstruir runtime
2. **Multi-tenant**: Diferents schemas per tenant/client
3. **Flexibilitat**: Defineix schemas en JSON, no cal codi Python
4. **No intrusiu**: Funciona amb agents existents sense modificar-los
5. **Validació**: Pydantic valida automàticament les respostes
6. **Detecció automàtica**: Selecciona schema segons context

## ⚠️ Limitacions

1. **Extracció de dades**: Cal extreure dades estructurades del text (parsing o LLM)
2. **No és validació estricta**: L'agent pot no seguir el format (per això és millor `output_schema` directe quan és possible)
3. **Performance**: Extracció amb LLM afegeix latència

## 🔄 Comparació amb `output_schema` Directe

| Característica | `output_schema` Directe | Wrapper Transformer |
|---------------|-------------------------|---------------------|
| **Validació estricta** | ✅ Sí (el model força el format) | ⚠️ Post-validació |
| **Hot reload** | ❌ No (cal reconstruir agent) | ✅ Sí |
| **Multi-tenant** | ⚠️ Cal crear agents diferents | ✅ Un sol agent |
| **Flexibilitat** | ⚠️ Cal codi Python | ✅ JSON config |
| **Performance** | ✅ Més ràpid | ⚠️ Extracció afegeix latència |

## 🚀 Roadmap d'Implementació

### Fase 1: Schema Registry (Bàsica)
- [ ] Crear `SchemaRegistry` class
- [ ] Carregar schemas des de JSON
- [ ] Crear models Pydantic dinàmicament
- [ ] Hot reload bàsic

### Fase 2: Response Transformer (Bàsica)
- [ ] Crear `ResponseSchemaTransformer` class
- [ ] Detecció de tipus de resposta (tool_calls + keywords)
- [ ] Extracció bàsica amb regex/parsing
- [ ] Validació amb Pydantic

### Fase 3: Integració
- [ ] Integrar a `assistant.py` (add_message)
- [ ] Afegir structured_data a SessionResponse
- [ ] Testing amb casos reals

### Fase 4: Millores
- [ ] Extracció amb LLM (opcional, més precís)
- [ ] Schemas per tenant des de DB (no només JSON)
- [ ] UI per gestionar schemas (backoffice)
- [ ] Monitoring i métriques

## 📚 Referències

- [ADK Output Schema Docs](https://github.com/google/adk-python/tree/main/contributing/samples/output_schema_with_tools)
- [Pydantic Dynamic Models](https://docs.pydantic.dev/latest/concepts/models/#dynamic-model-creation)
- [JSON Schema Specification](https://json-schema.org/)

## 🤔 Decisions de Disseny

### Per què no només `output_schema` directe?

- **Hot reload**: `output_schema` requereix reconstruir l'agent
- **Multi-tenant**: Caldria crear múltiples agents (un per tenant)
- **Flexibilitat**: Canvis requereixen deploy de codi

### Per què wrapper i no modificar l'agent?

- **No intrusiu**: Funciona amb agents existents
- **Separation of concerns**: La lògica de format és separada de la lògica de l'agent
- **Reutilitzable**: El mateix agent pot tenir múltiples formats

### Per què no només wrapper?

- **Validació estricta**: `output_schema` directe força el format abans de generar resposta
- **Performance**: Validació post-processament afegeix latència
- **Millor UX**: L'agent genera directament el format correcte

## 💭 Casos d'Ús

### Cas 1: Client A vol respostes de memòria en format específic

```json
{
  "schemas": {
    "memory_temporal_client_a": {
      "properties": {
        "timestamp": {"type": "string"},
        "memory_text": {"type": "string"},
        "confidence": {"type": "number"}
      }
    }
  }
}
```

### Cas 2: Client B vol respostes de calendar amb camps addicionals

```json
{
  "schemas": {
    "calendar_event_client_b": {
      "properties": {
        "event": {"type": "object"},
        "recurrence": {"type": "string"},
        "reminders": {"type": "array"}
      }
    }
  }
}
```

### Cas 3: Hot reload per afegir nou schema

1. Editar `config/output_schemas.json`
2. Sistema detecta canvi automàticament
3. Carrega nou schema
4. Propera resposta usa nou format

## 🔍 Monitoring i Debugging

### Logs

```python
logger.info(
    "Response transformed with schema",
    schema_name="memory_temporal",
    tenant_id="default",
    validation_success=True
)
```

### Mètriques

- Nombre de transformacions per schema
- Taxa d'èxit de validació
- Temps d'extracció de dades
- Schemas més usats

## 📝 Notes d'Implementació

### Creació Dinàmica de Models Pydantic

```python
from pydantic import create_model, Field

# Crear model dinàmicament
MemoryTemporalModel = create_model(
    "MemoryTemporal",
    found=(bool, Field(...)),
    date_recorded=(Optional[str], Field(None)),
    content=(str, Field(...)),
)
```

### Compatibilitat amb ADK

- El wrapper funciona **després** que ADK genera la resposta
- No interfereix amb el flow normal de l'agent
- Compatible amb tots els tools existents

### Seguretat

- Validació de JSON Schema abans de crear model
- Sanitització de dades extretes
- Límits de mida per evitar DoS

---

**Data de creació**: 2025-12-06  
**Autor**: Nodus OS Team  
**Versió**: 1.0

