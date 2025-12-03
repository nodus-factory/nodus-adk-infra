# LiteLLM Self-Hosted Integration

Aquest document explica com funciona la integració de **LiteLLM Proxy Server** dins de l'stack de Nodus ADK.

## Arquitectura

```
┌─────────────────┐
│  ADK Agents     │
│  (root_agent)   │
└────────┬────────┘
         │
         │ model="openai/gpt-4o"
         │
         ▼
┌─────────────────┐
│  LiteLLM Proxy  │  ← Self-hosted (port 4000)
│  (litellm)      │
└────────┬────────┘
         │
         │ Traducció: gpt-4o → openai/gpt-4o
         │
         ▼
┌─────────────────┐
│  LLM Providers  │
│  (OpenAI, etc.) │
└─────────────────┘
```

## Configuració

### 1. Models Disponibles

Els models es defineixen a `nodus-adk-infra/config/litellm/litellm_config.yaml`:

```yaml
model_list:
  - model_name: gpt-4o          # Nom que usen els agents
    litellm_params:
      model: openai/gpt-4o      # Model real a l'API
      
  - model_name: gemini-pro
    litellm_params:
      model: gemini/gemini-pro
```

### 2. Ús als Agents

Per usar un model a través de LiteLLM, simplement canvia el nom del model al `config`:

```python
# A nodus-adk-runtime/src/nodus_adk_runtime/api/assistant.py
agent = build_root_agent(
    config={
        "model": "openai/gpt-4o",  # ← Això passarà per LiteLLM Proxy
    }
)
```

**Format del model**: `provider/model-name`
- `openai/gpt-4o` → Usa OpenAI via LiteLLM
- `anthropic/claude-3-5-sonnet-20240620` → Usa Anthropic via LiteLLM
- `gemini/gemini-pro` → Usa Gemini via LiteLLM

### 3. Variables d'Entorn

Les claus API reals es configuren al contenidor `litellm`:

```yaml
# docker-compose.yml
litellm:
  environment:
    - OPENAI_API_KEY=${OPENAI_API_KEY}
    - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
    - GEMINI_API_KEY=${GOOGLE_API_KEY}
```

Els agents **NO** necessiten les claus reals, només la clau mestra del proxy:

```yaml
adk-runtime:
  environment:
    - OPENAI_API_BASE: http://litellm:4000
    - OPENAI_API_KEY: sk-nodus-master-key  # Clau del proxy, no la real
```

## Beneficis

1. **Seguretat**: Les claus API mai toquen el codi dels agents
2. **Abstracció**: Canvia models editant només `litellm_config.yaml`
3. **Logs Centralitzats**: Totes les crides passen pel proxy
4. **Cost Tracking**: El proxy registra tokens i costos
5. **Rate Limiting**: Pots configurar límits per tenant/user

## Afegir Nous Models

1. Edita `nodus-adk-infra/config/litellm/litellm_config.yaml`
2. Afegeix la nova entrada a `model_list`
3. Reinicia el contenidor: `docker-compose restart litellm`

## Debugging

Per veure logs del proxy:

```bash
docker logs nodus-adk-litellm -f
```

Per provar el proxy directament:

```bash
curl http://localhost:4000/v1/models \
  -H "Authorization: Bearer sk-nodus-master-key"
```

## Models Suportats

Els models suportats depenen de la configuració de LiteLLM. Per defecte suporta:
- OpenAI (gpt-4, gpt-3.5, etc.)
- Anthropic (claude-3, claude-3.5)
- Google Gemini
- Mistral
- Ollama (models locals)
- I molts més: https://docs.litellm.ai/docs/providers


