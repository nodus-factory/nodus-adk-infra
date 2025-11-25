# 📝 PROMPT MANAGEMENT AMB LANGFUSE

**Data implementació:** 2025-11-25  
**Estat:** ✅ OPERATIU

---

## 🎯 **OBJECTIU**

Gestionar centralment els prompts del sistema amb versionat, A/B testing i observabilitat completa via Langfuse.

---

## 📊 **ARQUITECTURA**

```
┌─────────────────────────────────────────────────────────┐
│                   ROOT AGENT BUILD                       │
└────────────────────┬────────────────────────────────────┘
                     │
                     ↓
         ┌───────────────────────┐
         │   PromptService       │
         │   (amb cache)         │
         └──────────┬────────────┘
                    │
        ┌───────────┴───────────┐
        │                       │
        ↓                       ↓
   ┌─────────┐          ┌────────────┐
   │ Langfuse│          │ Fallback   │
   │ Prompt  │          │ Hardcoded  │
   │ (v1)    │          │ (backup)   │
   └─────────┘          └────────────┘
        │                       │
        └───────────┬───────────┘
                    │
                    ↓
        ┌───────────────────────┐
        │ Root Agent Instruction│
        └───────────────────────┘
```

---

## 🔧 **COMPONENTS**

### **1. PromptService** 
`nodus-adk-runtime/src/nodus_adk_runtime/services/prompt_service.py`

**Funcions:**
- ✅ Fetch prompts des de Langfuse
- ✅ Automatic fallback si Langfuse no disponible
- ✅ Cache en memòria per performance
- ✅ Full OpenTelemetry tracing
- ✅ Rich logging (structlog)

**Mètodes:**
```python
get_prompt(name, fallback, label="production") -> str
get_prompt_metadata(name, label) -> Dict[str, Any]
clear_cache(name=None)
get_prompt_config(name, label) -> Dict[str, Any]
```

### **2. Root Agent (modificat)**
`nodus-adk-agents/src/nodus_adk_agents/root_agent.py`

**Canvis:**
- ✅ Usa `PromptService` per carregar instruction
- ✅ Manté `FALLBACK_INSTRUCTION` hardcoded (backup)
- ✅ Logs estructurats amb metadata del prompt
- ✅ Gestió d'errors robusta

### **3. Script de Creació**
`nodus-adk-infra/scripts/create_langfuse_prompts.py`

**Ús:**
```bash
python3 nodus-adk-infra/scripts/create_langfuse_prompts.py
```

---

## 📋 **PROMPTS GESTIONATS**

### **1. nodus-root-agent-instruction**

**Descripció:** Instruction principal del Personal Assistant  
**Label actual:** `production` (v1)  
**Mida:** 10,782 characters, 193 línies  
**Config:**
```json
{
  "model": "gemini-2.0-flash-exp",
  "temperature": 0.7,
  "max_tokens": 8192
}
```

**Contingut:**
- 🌍 Language rules (Catalan, Spanish, English)
- 🤝 A2A delegation rules
- ⚡ Parallel execution & complex tasks
- 🎯 Tool execution rules
- 📚 Few-shot examples
- ⚠️ HITL (Human-In-The-Loop) rules
- 🧠 Memory & context rules

---

## 🔍 **OBSERVABILITAT**

### **Spans OpenTelemetry**

Cada càrrega de prompt crea un span `prompt_service.get_prompt` amb:

```json
{
  "attributes": {
    "prompt.name": "nodus-root-agent-instruction",
    "prompt.label": "production",
    "prompt.source": "langfuse",  // o "fallback"
    "prompt.version": 1,
    "prompt.cache_hit": false,
    "prompt.fallback_used": false,
    "prompt.length": 10782
  },
  "events": [
    {"name": "fetching_from_langfuse"},
    {"name": "prompt_loaded_from_langfuse", "attributes": {"version": 1}}
  ]
}
```

### **Logs Estructurats**

```
✅ Prompt loaded from Langfuse
  prompt_name=nodus-root-agent-instruction
  prompt_version=1
  label=production
  source=langfuse
  fallback_used=False
  cache_hit=False
  length=10782
```

o si falla:

```
⚠️  Failed to load prompt from Langfuse, using hardcoded fallback
  prompt_name=nodus-root-agent-instruction
  label=production
  source=fallback
  fallback_used=True
  error=Connection timeout
```

### **Root Agent Build Logs**

```
Root agent built successfully
  agent_name=personal_assistant
  model=gemini-2.0-flash-exp
  prompt_source=langfuse
  prompt_version=1
  has_mcp_toolset=True
  has_memory_tool=True
  has_knowledge_tool=True
  tools_count=3
```

---

## 🚀 **ÚS BÀSIC**

### **Crear un nou prompt**

```python
from langfuse import Langfuse

langfuse = Langfuse(
    public_key="pk-lf-...",
    secret_key="sk-lf-...",
    host="http://localhost:3000"
)

langfuse.create_prompt(
    name="my-new-prompt",
    type="text",
    prompt="Your prompt text here...",
    labels=["production"],
    config={"model": "gemini-2.0-flash-exp", "temperature": 0.7}
)
```

### **Actualitzar un prompt**

1. Ves a http://localhost:3000/prompts
2. Selecciona el prompt
3. Edita el contingut
4. Desa → crea versió nova automàticament
5. Assigna label `production` a la nova versió
6. Clear cache (opcional): `prompt_service.clear_cache("nodus-root-agent-instruction")`

### **A/B Testing**

```python
# Crear versió staging
langfuse.create_prompt(
    name="nodus-root-agent-instruction",
    prompt="... versió nova amb canvis ...",
    labels=["staging"]  # ← Nova label
)

# Al codi, decidir quina versió usar:
import random

label = "production"
if random.random() < 0.2:  # 20% staging
    label = "staging"

instruction = prompt_service.get_prompt(
    name="nodus-root-agent-instruction",
    fallback=FALLBACK_INSTRUCTION,
    label=label
)
```

---

## 🛡️ **ESTRATÈGIA DE FALLBACK**

### **Nivells de seguretat:**

1. **Langfuse disponible** → Usa prompt de Langfuse (v1, v2, etc.)
2. **Langfuse down** → Usa `FALLBACK_INSTRUCTION` (hardcoded)
3. **PromptService error** → Usa `FALLBACK_INSTRUCTION` (hardcoded)

### **Garanties:**

- ✅ El sistema **SEMPRE** té un prompt funcional
- ✅ **ZERO downtime** si Langfuse falla
- ✅ Fallback és **IDÈNTIC** al prompt de producció
- ✅ Logs clars sobre quin prompt s'ha usat

---

## 📈 **MÈTRIQUES**

### **Cache Efficiency**

```sql
SELECT 
  attributes->>'prompt.cache_hit' as cache_hit,
  COUNT(*) as count,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) as percentage
FROM traces
WHERE span_name = 'prompt_service.get_prompt'
GROUP BY cache_hit
```

### **Fallback Rate**

```sql
SELECT 
  COUNT(CASE WHEN attributes->>'prompt.source' = 'fallback' THEN 1 END)::float / 
  COUNT(*)::float * 100 as fallback_rate_percentage
FROM traces
WHERE span_name = 'prompt_service.get_prompt'
```

### **Versions Usage**

```sql
SELECT 
  attributes->>'prompt.version' as version,
  COUNT(*) as usage_count
FROM traces
WHERE 
  span_name = 'prompt_service.get_prompt' AND
  attributes->>'prompt.name' = 'nodus-root-agent-instruction'
GROUP BY version
ORDER BY usage_count DESC
```

---

## 🔧 **MANTENIMENT**

### **Actualitzar FALLBACK_INSTRUCTION**

**Important:** Mantenir sincronitzat amb Langfuse!

1. Actualitza el prompt a Langfuse
2. Copia el text exacte
3. Actualitza `FALLBACK_INSTRUCTION` a `root_agent.py`
4. Commit ambdós canvis junts

### **Clear Cache**

```python
# Des del codi
prompt_service.clear_cache("nodus-root-agent-instruction")

# O reiniciar el servei
docker-compose restart adk-runtime
```

### **Rollback a versió anterior**

```python
# Opció 1: Canviar label a Langfuse UI
# Ves a /prompts → nodus-root-agent-instruction → v3 → Set label "production"

# Opció 2: Via SDK
langfuse.create_prompt(
    name="nodus-root-agent-instruction",
    prompt="... contingut de v3 ...",
    labels=["production"]
)
```

---

## 🎯 **BEST PRACTICES**

1. ✅ **Sempre testa** prompts nous amb label `staging` primer
2. ✅ **Monitora** fallback_rate (hauria de ser < 1%)
3. ✅ **Documenta** canvis significatius al prompt
4. ✅ **Sincronitza** FALLBACK_INSTRUCTION amb producció
5. ✅ **Usa SemVer** per versions: v1.0.0, v1.1.0, v2.0.0
6. ✅ **A/B testing** abans de deployar canvis majors

---

## 📚 **LINKS ÚTILS**

- **Langfuse UI:** http://localhost:3000/prompts
- **Traces:** http://localhost:3000/traces (buscar `prompt_service.get_prompt`)
- **Documentació Langfuse:** https://langfuse.com/docs/prompt-management
- **Script creació:** `nodus-adk-infra/scripts/create_langfuse_prompts.py`

---

## ✅ **STATUS**

- [x] PromptService implementat amb observabilitat
- [x] Root agent modificat per usar PromptService
- [x] Prompt `nodus-root-agent-instruction` creat a Langfuse (v1)
- [x] Fallback strategy implementada
- [x] Cache en memòria per performance
- [x] OpenTelemetry tracing complet
- [x] Logs estructurats (structlog)
- [x] Script de creació de prompts
- [x] Documentació completa

🎉 **SISTEMA COMPLETAMENT OPERATIU!**


