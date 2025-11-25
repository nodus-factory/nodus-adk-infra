# 📹 Integración de nodus-recorder-pwa con nodus-adk

**Guía de Implementación para Desarrolladores**

---

## 📚 Tabla de Contenidos

1. [Visión General](#1-visión-general)
2. [Arquitectura del Sistema](#2-arquitectura-del-sistema)
3. [Componentes Involucrados](#3-componentes-involucrados)
4. [Flujo de Datos Completo](#4-flujo-de-datos-completo)
5. [Implementación Paso a Paso](#5-implementación-paso-a-paso)
6. [Testing y Validación](#6-testing-y-validación)
7. [Troubleshooting](#7-troubleshooting)
8. [Anexos](#8-anexos)

---

## 1. Visión General

### 1.1 Objetivo

Integrar **nodus-recorder-pwa** (PWA especializada en grabación) con **nodus-adk** para permitir que los agentes de IA puedan iniciar grabaciones de audio/video/pantalla delegando la tarea a una aplicación externa especializada.

### 1.2 Caso de Uso Principal

```
Usuario: "Grábame la reunión"
   ↓
Personal Assistant (Root Agent ADK)
   ↓
Lanza → nodus-recorder-pwa (ventana popup)
   ↓
Graba en background hasta completar
   ↓
Procesa con IA (transcripción, resumen, tareas)
   ↓
Retorna resultados → Llibreta UI
```

### 1.3 Por Qué Esta Arquitectura

- **Separación de responsabilidades**: Llibreta es para conversación, Recorder para grabación
- **Experiencia dedicada**: La PWA puede ejecutarse en background sin interferir con llibreta
- **Reutilizable**: Otros agentes pueden usar el recorder
- **Escalable**: El recorder puede evolucionar independientemente

---

## 2. Arquitectura del Sistema

### 2.1 Diagrama de Componentes

```
┌─────────────────────────────────────────────────────────────┐
│                    USUARIO (Browser)                        │
│  ┌──────────────────┐              ┌──────────────────┐    │
│  │ nodus-llibreta   │              │ nodus-recorder   │    │
│  │ (Puerto 5002)    │◄────────────►│ (Puerto 5005)    │    │
│  │ Chat UI          │  postMessage │ PWA Grabación    │    │
│  └────────┬─────────┘              └────────┬─────────┘    │
└───────────┼─────────────────────────────────┼──────────────┘
            │                                  │
            │ WebSocket                        │ HTTP POST
            │                                  │
            ▼                                  ▼
┌──────────────────────────────────────────────────────────────┐
│              NODUS ADK RUNTIME (Puerto 8080)                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Runner     │  │  Recording   │  │  WebSocket   │      │
│  │  (Agentes)   │  │   Handler    │  │   Manager    │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
└─────────┼──────────────────┼──────────────────┼──────────────┘
          │                  │                  │
          │                  │                  │
          ▼                  ▼                  ▼
┌──────────────────────────────────────────────────────────────┐
│                    SERVICIOS BACKEND                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  PostgreSQL  │  │   MinIO      │  │  Backoffice  │      │
│  │  (Base datos)│  │ (Audio files)│  │   (Auth)     │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│                  NODUS ADK AGENTS (Procesos)                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Root Agent   │  │  Email Agent │  │ Meeting      │      │
│  │ (Puerto 8000)│  │ (Puerto 8004)│  │ Processor    │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└──────────────────────────────────────────────────────────────┘
```

### 2.2 Stack Tecnológico

| Componente | Tecnología | Puerto |
|------------|-----------|---------|
| **nodus-llibreta** | React + Vite + Express | 5002 |
| **nodus-recorder-pwa** | React/Vue/Vanilla JS | 5005 |
| **nodus-adk-runtime** | FastAPI + Python | 8080 |
| **nodus-adk-agents** | Google ADK + Python | 8000+ |
| **PostgreSQL** | Base de datos | 5432 |
| **MinIO** | Object Storage | 9000 |
| **nodus-backoffice** | Node.js + Express | 5001 |

---

## 3. Componentes Involucrados

### 3.1 Root Agent (Personal Assistant)

**Ubicación**: `nodus-adk-agents/src/nodus_adk_agents/root_agent.py`

**Responsabilidades**:
- Detectar intención del usuario ("record me", "graba", etc.)
- Invocar el `RecorderTool`
- Gestionar el ciclo de vida de la grabación

**Dependencias**:
```python
from google.adk.agents import LlmAgent
from google.adk.tools import BaseTool
from .tools.recorder_tool import RecorderTool
```

### 3.2 RecorderTool (Nuevo)

**Ubicación**: `nodus-adk-agents/src/nodus_adk_agents/tools/recorder_tool.py`

**Responsabilidades**:
- Crear sesión de grabación
- Generar URL para la PWA con parámetros
- Retornar HITL card para que Llibreta muestre UI

**Interface**:
```python
class RecorderTool(BaseTool):
    async def run_async(
        args: {
            "recording_type": "audio" | "video" | "screen",
            "title": str,
            "duration_minutes": int
        },
        tool_context: ToolContext
    ) -> {
        "_hitl_required": True,
        "recorder_url": str,
        "recording_id": str,
        "ui_action": {...}
    }
```

### 3.3 Recording Handler (Nuevo)

**Ubicación**: `nodus-adk-runtime/src/nodus_adk_runtime/handlers/recording_handler.py`

**Responsabilidades**:
- Recibir audio/video cuando termina la grabación
- Transcribir si es necesario
- Invocar agente para procesar contenido
- Notificar a Llibreta vía WebSocket

**Endpoints**:
```python
POST /api/recordings/complete  # Llamado por nodus-recorder-pwa
GET  /api/recordings/{id}      # Consultar estado
DELETE /api/recordings/{id}    # Cancelar/eliminar
```

### 3.4 Llibreta UI Components (Nuevos)

**Ubicación**: `nodus-llibreta/client/src/components/`

**Componentes**:
1. `RecordingHitlCard.tsx` - Mostrar botón "Start Recording"
2. `RecordingStatusPanel.tsx` - Mostrar progreso en tiempo real
3. `RecordingResultCard.tsx` - Mostrar resumen/acciones extraídas

### 3.5 nodus-recorder-pwa (Modificado)

**Ubicación**: `nodus-recorder-pwa/` (repositorio externo)

**Modificaciones necesarias**:
1. Aceptar parámetros vía URL query params
2. Enviar callback a runtime cuando termina
3. Comunicarse con window.opener (llibreta) vía postMessage

---

## 4. Flujo de Datos Completo

### 4.1 Fase 1: Inicio de Grabación

```
┌──────────┐
│ Usuario  │ "Grábame la reunión"
└────┬─────┘
     │
     ▼
┌─────────────────┐
│ Llibreta Chat   │ POST /api/chat
└────┬────────────┘
     │
     ▼
┌─────────────────────┐
│ ADK Runtime Runner  │ Enruta al Root Agent
└────┬────────────────┘
     │
     ▼
┌──────────────────┐
│   Root Agent     │ Detecta intent → Llama recorder_tool
└────┬─────────────┘
     │
     ▼
┌──────────────────┐
│  RecorderTool    │ Crea sesión, genera URL
└────┬─────────────┘
     │
     ▼ return
{
  "_hitl_required": true,
  "recorder_url": "http://localhost:5005/record?id=abc&type=audio",
  "recording_id": "abc-123",
  "ui_action": {
    "type": "open_recorder",
    "button_text": "Start Recording"
  }
}
     │
     ▼
┌──────────────────┐
│ Llibreta Chat    │ Recibe evento, renderiza RecordingHitlCard
└────┬─────────────┘
     │
     ▼
┌──────────────────┐
│ Usuario          │ Click "Start Recording"
└────┬─────────────┘
     │
     ▼ window.open()
┌──────────────────┐
│ nodus-recorder   │ Se abre en popup
│ (PWA)            │
└──────────────────┘
```

### 4.2 Fase 2: Grabación Activa

```
┌──────────────────┐
│ nodus-recorder   │
│ (PWA)            │
│                  │
│ 🔴 Grabando...   │ getUserMedia()
│ Timer: 00:45     │ MediaRecorder API
│                  │
└────┬─────────────┘
     │
     │ postMessage cada 5 segundos
     ▼
┌──────────────────┐
│ Llibreta         │
│ (window.opener)  │
│                  │
│ Status:          │ addEventListener('message')
│ Recording 00:45  │
└──────────────────┘
```

### 4.3 Fase 3: Finalización y Procesamiento

```
┌──────────────────┐
│ nodus-recorder   │ Usuario para grabación
│ (PWA)            │
└────┬─────────────┘
     │
     │ POST /api/recordings/complete
     ▼
┌──────────────────────────────────┐
│ ADK Runtime - Recording Handler  │
└────┬─────────────────────────────┘
     │
     ├─► 1. Guardar audio en MinIO
     │
     ├─► 2. Transcribir (Whisper vía Backoffice)
     │
     ├─► 3. Invocar Meeting Processor Agent
     │      ↓
     │      "Resume esta reunión"
     │      ↓
     │      Agent analiza y retorna:
     │      - Resumen (3 frases)
     │      - Action items (quién/qué/cuándo)
     │      - Temas clave
     │      - Decisiones tomadas
     │
     └─► 4. Guardar en PostgreSQL
     │
     ├─► 5. WebSocket → Llibreta
     │      {
     │        "type": "recording_complete",
     │        "recording_id": "abc-123",
     │        "summary": "...",
     │        "action_items": [...]
     │      }
     │
     ▼
┌──────────────────┐
│ Llibreta Chat    │ Muestra ResultCard con resumen
└──────────────────┘
```

---

## 5. Implementación Paso a Paso

### PASO 1: Crear RecorderTool

**Archivo**: `nodus-adk-agents/src/nodus_adk_agents/tools/recorder_tool.py`

```python
"""
RecorderTool - Tool para iniciar grabaciones con nodus-recorder-pwa

Este tool permite al Root Agent iniciar grabaciones delegando
la tarea a una PWA especializada.
"""

from typing import Any, Dict, Optional
from google.adk.tools import BaseTool, ToolContext
from google.adk import types
import uuid
import structlog

logger = structlog.get_logger()


class RecorderTool(BaseTool):
    """
    Tool para iniciar grabaciones de audio/video/pantalla.
    
    Cuando el usuario dice "Grábame la reunión", este tool:
    1. Crea una sesión de grabación en la base de datos
    2. Genera una URL parametrizada para nodus-recorder-pwa
    3. Retorna un HITL card para que Llibreta muestre el botón
    
    Attributes:
        runtime_url: URL del ADK Runtime (para callbacks)
        recorder_url: URL base de nodus-recorder-pwa
    """
    
    def __init__(
        self,
        runtime_url: str = "http://localhost:8080",
        recorder_url: str = "http://localhost:5005",
    ):
        self.runtime_url = runtime_url
        self.recorder_url = recorder_url
        self.name = "start_recording"
        self.description = (
            "Iniciar grabación de audio, video o pantalla. "
            "Usa esto cuando el usuario pida grabar una reunión, "
            "nota de voz, presentación, etc."
        )
    
    def _get_declaration(self) -> types.FunctionDeclaration:
        """
        Define el esquema JSON del tool para que el LLM sepa cómo usarlo.
        
        El LLM verá esta declaración y aprenderá:
        - Qué parámetros necesita
        - Qué tipo de datos espera
        - Cuándo debe usarse este tool
        """
        return types.FunctionDeclaration(
            name=self.name,
            description=self.description,
            parameters={
                "type": "object",
                "properties": {
                    "recording_type": {
                        "type": "string",
                        "enum": ["audio", "video", "screen"],
                        "description": (
                            "Tipo de grabación: "
                            "'audio' para reuniones/notas de voz, "
                            "'video' para presentaciones con cámara, "
                            "'screen' para capturas de pantalla"
                        ),
                    },
                    "title": {
                        "type": "string",
                        "description": (
                            "Título descriptivo de la grabación. "
                            "Ej: 'Reunión con cliente', 'Daily standup', etc."
                        ),
                    },
                    "duration_minutes": {
                        "type": "integer",
                        "description": "Duración máxima en minutos (default: 60)",
                        "default": 60,
                        "minimum": 1,
                        "maximum": 180,  # Máximo 3 horas
                    },
                    "auto_transcribe": {
                        "type": "boolean",
                        "description": (
                            "Si true, transcribe automáticamente al finalizar"
                        ),
                        "default": True,
                    },
                },
                "required": ["recording_type", "title"],
            },
        )
    
    async def run_async(
        self,
        *,
        args: Dict[str, Any],
        tool_context: ToolContext,
    ) -> Dict[str, Any]:
        """
        Ejecuta el tool: crea la sesión de grabación y retorna HITL card.
        
        Args:
            args: Parámetros del tool (recording_type, title, etc.)
            tool_context: Contexto de ejecución (session_id, user_id, etc.)
        
        Returns:
            Dict con:
            - _hitl_required: True (para mostrar confirmación)
            - recorder_url: URL para abrir la PWA
            - recording_id: ID único de esta grabación
            - ui_action: Metadata para la UI de Llibreta
        """
        # 1. Extraer parámetros
        recording_type = args.get("recording_type", "audio")
        title = args.get("title", "Grabación sin título")
        duration_minutes = args.get("duration_minutes", 60)
        auto_transcribe = args.get("auto_transcribe", True)
        
        # 2. Obtener contexto de la invocación
        session_id = tool_context._invocation_context.session_id
        user_id = tool_context._invocation_context.user_id
        
        # 3. Generar ID único para esta grabación
        recording_id = str(uuid.uuid4())
        
        logger.info(
            "Creating recording session",
            recording_id=recording_id,
            user_id=user_id,
            session_id=session_id,
            recording_type=recording_type,
            title=title,
            duration_minutes=duration_minutes,
        )
        
        # 4. Construir URL parametrizada para nodus-recorder-pwa
        recorder_url = (
            f"{self.recorder_url}/record"
            f"?id={recording_id}"
            f"&type={recording_type}"
            f"&title={title}"
            f"&duration={duration_minutes}"
            f"&session={session_id}"
            f"&user={user_id}"
            f"&callback={self.runtime_url}/api/recordings/complete"
            f"&transcribe={str(auto_transcribe).lower()}"
        )
        
        # 5. Preparar metadata para la UI
        ui_metadata = {
            "type": "open_recorder",
            "url": recorder_url,
            "button_text": "Iniciar Grabación",
            "button_icon": self._get_icon_for_type(recording_type),
            "popup_config": {
                "width": 600,
                "height": 800,
                "resizable": True,
            },
            "display": {
                "title": title,
                "subtitle": f"Tipo: {recording_type} • Máx: {duration_minutes} min",
                "color": "cyan",
            },
        }
        
        # 6. Retornar resultado
        return {
            "_hitl_required": True,
            "action": "start_recording",
            "action_description": f"Iniciar grabación de {recording_type}: {title}",
            "recording_id": recording_id,
            "recorder_url": recorder_url,
            "recording_type": recording_type,
            "title": title,
            "duration_minutes": duration_minutes,
            "auto_transcribe": auto_transcribe,
            "ui_action": ui_metadata,
            "message_to_user": (
                f"He preparado la grabación '{title}'. "
                f"Haz clic en 'Iniciar Grabación' cuando estés listo."
            ),
        }
    
    def _get_icon_for_type(self, recording_type: str) -> str:
        """Helper para elegir el icono apropiado"""
        icons = {
            "audio": "mic",
            "video": "video",
            "screen": "monitor",
        }
        return icons.get(recording_type, "mic")
```

**Registrar el tool**:

```python
# nodus-adk-agents/src/nodus_adk_agents/tools/__init__.py

from .recorder_tool import RecorderTool

__all__ = ["RecorderTool"]
```

---

### PASO 2: Integrar RecorderTool en Root Agent

**Archivo**: `nodus-adk-agents/src/nodus_adk_agents/root_agent.py`

```python
# ... imports existentes ...
from .tools.recorder_tool import RecorderTool

def build_root_agent(
    mcp_adapter: Any,
    memory_service: Any,
    user_context: Any,
    config: Dict[str, Any],
    domain_agents: Optional[List[Any]] = None,
    knowledge_tool: Optional[Any] = None,
    enable_a2a: bool = True,
    a2a_tools: Optional[List[Any]] = None,
) -> Any:
    """
    Construye el Root Agent (Personal Assistant) con todas sus capacidades.
    """
    from google.adk.agents import LlmAgent
    
    logger.info("Building Root Agent with recording capabilities")
    
    # 1. Crear RecorderTool
    recorder_tool = RecorderTool(
        runtime_url=config.get("runtime_url", "http://localhost:8080"),
        recorder_url=config.get("recorder_url", "http://localhost:5005"),
    )
    
    # 2. Construir lista de tools
    tools = [
        recorder_tool,  # ← NUEVO TOOL
        # ... otros tools existentes ...
    ]
    
    # 3. Si hay domain agents (A2A), añadir sus tools
    if a2a_tools:
        tools.extend(a2a_tools)
    
    # 4. Actualizar instrucción para incluir capacidades de grabación
    instruction = FALLBACK_INSTRUCTION + """

📹 CAPACIDADES DE GRABACIÓN (NUEVO):

Puedes iniciar grabaciones de audio, video o pantalla usando el tool `start_recording`.

**Cuándo usar este tool**:
- Usuario dice "grábame", "record me", "grava'm"
- Usuario quiere capturar una reunión, presentación, nota de voz
- Usuario pide grabar su pantalla

**Cómo detectar el tipo de grabación**:
- "grábame la reunión" → audio
- "graba mi presentación" → video (si mencionan cámara) o screen (si mencionan pantalla)
- "captura mi pantalla" → screen
- "nota de voz" → audio

**Ejemplos de uso**:

Ejemplo 1 - Audio:
Usuario: "Grábame la reunión con el cliente"
Tu acción: start_recording(recording_type="audio", title="Reunión con el cliente")
Tu respuesta: "He preparado la grabación 'Reunión con el cliente'. Haz clic en 'Iniciar Grabación' cuando estés listo."

Ejemplo 2 - Video:
Usuario: "Graba mi presentación en video por 45 minutos"
Tu acción: start_recording(recording_type="video", title="Presentación", duration_minutes=45)
Tu respuesta: "Listo para grabar tu presentación en video durante 45 minutos."

**IMPORTANTE**: 
- NO pidas confirmación antes de llamar al tool
- Extrae todos los parámetros del lenguaje natural del usuario
- Mantén el idioma del usuario en tu respuesta
"""
    
    # 5. Construir el agente
    agent = LlmAgent(
        name="root_agent",
        model=config.get("model", "gemini-2.0-flash-exp"),
        instruction=instruction,
        tools=tools,
    )
    
    return agent
```

---

### PASO 3: Crear Recording Handler en Runtime

**Archivo**: `nodus-adk-runtime/src/nodus_adk_runtime/handlers/recording_handler.py`

```python
"""
Recording Handler - Endpoints para gestionar grabaciones
"""

from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from typing import Optional, Dict, Any
import structlog

logger = structlog.get_logger()
router = APIRouter(prefix="/api/recordings", tags=["recordings"])


@router.post("/complete")
async def recording_complete(
    recording_id: str = Form(...),
    session_id: str = Form(...),
    user_id: str = Form(...),
    recording_type: str = Form(...),
    title: str = Form(...),
    duration_seconds: int = Form(...),
    audio_file: Optional[UploadFile] = File(None),
    transcript: Optional[str] = Form(None),
):
    """
    Endpoint llamado por nodus-recorder-pwa cuando completa la grabación.
    
    Flujo:
    1. Guardar archivo en storage
    2. Transcribir si es necesario
    3. Procesar con agent
    4. Guardar en DB
    5. Notificar a Llibreta
    """
    logger.info(
        "Recording completed",
        recording_id=recording_id,
        session_id=session_id,
        duration_seconds=duration_seconds,
    )
    
    try:
        # 1. Guardar archivo
        audio_url = None
        if audio_file:
            audio_url = await save_to_storage(recording_id, audio_file)
        
        # 2. Transcribir si necesario
        if not transcript and audio_file:
            transcript = await transcribe_audio(audio_file)
        
        # 3. Procesar con agent
        result = await process_with_agent(
            recording_id=recording_id,
            transcript=transcript,
            duration=duration_seconds,
        )
        
        # 4. Guardar en DB
        await save_to_database(
            recording_id=recording_id,
            session_id=session_id,
            user_id=user_id,
            title=title,
            audio_url=audio_url,
            transcript=transcript,
            summary=result["summary"],
            action_items=result["action_items"],
        )
        
        # 5. Notificar vía WebSocket
        await notify_completion(session_id, result)
        
        return {
            "status": "success",
            "recording_id": recording_id,
            "summary": result["summary"],
            "action_items": result["action_items"],
        }
    
    except Exception as e:
        logger.error("Error processing recording", error=str(e))
        raise HTTPException(status_code=500, detail=str(e))
```

---

### PASO 4: Crear UI Components en Llibreta

#### RecordingHitlCard Component

**Archivo**: `nodus-llibreta/client/src/components/RecordingHitlCard.tsx`

```typescript
import { useState } from "react";
import { Mic, Video, Monitor } from "lucide-react";
import { Button } from "@/components/ui/button";
import { toast } from "@/hooks/use-toast";

interface RecordingHitlCardProps {
  recordingId: string;
  recorderUrl: string;
  recordingType: "audio" | "video" | "screen";
  title: string;
  durationMinutes: number;
  onStart?: () => void;
  onCancel?: () => void;
}

export function RecordingHitlCard({
  recordingId,
  recorderUrl,
  recordingType,
  title,
  durationMinutes,
  onStart,
  onCancel,
}: RecordingHitlCardProps) {
  const [isOpening, setIsOpening] = useState(false);

  const Icon = 
    recordingType === "audio" ? Mic : 
    recordingType === "video" ? Video : 
    Monitor;

  const handleStart = async () => {
    setIsOpening(true);

    try {
      const width = 600;
      const height = 800;
      const left = Math.floor((window.screen.width - width) / 2);
      const top = Math.floor((window.screen.height - height) / 2);

      const popup = window.open(
        recorderUrl,
        `nodus_recorder_${recordingId}`,
        `width=${width},height=${height},left=${left},top=${top},resizable=yes`
      );

      if (!popup) {
        throw new Error("No se pudo abrir la ventana. Permite popups.");
      }

      // Escuchar mensajes del recorder
      const handleMessage = (event: MessageEvent) => {
        if (event.data.type === "recording_complete" && 
            event.data.recording_id === recordingId) {
          toast({
            title: "Grabación completada",
            description: "Procesando tu grabación...",
          });
          onStart?.();
          window.removeEventListener("message", handleMessage);
        }
      };

      window.addEventListener("message", handleMessage);

    } catch (error) {
      toast({
        title: "Error",
        description: error.message,
        variant: "destructive",
      });
      setIsOpening(false);
    }
  };

  return (
    <div className="glass-surface border neon-border-cyan rounded-xl p-4">
      <div className="flex items-start gap-4 mb-4">
        <div className="p-3 rounded-lg bg-acid-1/20">
          <Icon className="h-6 w-6 text-acid-1" />
        </div>
        <div className="flex-1">
          <h3 className="font-semibold text-white mb-1">Iniciar Grabación</h3>
          <p className="text-sm text-gray-300">{title}</p>
          <p className="text-xs text-gray-400">
            {recordingType} • Máx: {durationMinutes} min
          </p>
        </div>
      </div>

      <div className="flex gap-2">
        <Button
          onClick={handleStart}
          disabled={isOpening}
          className="flex-1 bg-acid-1/20 hover:bg-acid-1/30 text-acid-1"
        >
          <Icon className="h-4 w-4 mr-2" />
          {isOpening ? "Abriendo..." : "Iniciar Grabación"}
        </Button>

        <Button onClick={onCancel} variant="ghost">
          Cancelar
        </Button>
      </div>
    </div>
  );
}
```

#### RecordingResultCard Component

**Archivo**: `nodus-llibreta/client/src/components/RecordingResultCard.tsx`

```typescript
import { CheckCircle2, FileText, Flag } from "lucide-react";

interface ActionItem {
  assignee: string;
  task: string;
  deadline: string;
}

interface RecordingResultCardProps {
  title: string;
  summary: string;
  actionItems: ActionItem[];
  topics: string[];
}

export function RecordingResultCard({
  title,
  summary,
  actionItems,
  topics,
}: RecordingResultCardProps) {
  return (
    <div className="glass-surface border neon-border-cyan rounded-xl p-5">
      {/* Header */}
      <div className="flex items-start gap-3 mb-4">
        <CheckCircle2 className="h-5 w-5 text-green-400" />
        <div>
          <h3 className="font-semibold text-white">
            Grabación completada: {title}
          </h3>
        </div>
      </div>

      {/* Resumen */}
      <div className="bg-black/30 rounded-lg p-4 mb-4">
        <div className="flex items-center gap-2 mb-2">
          <FileText className="h-4 w-4 text-acid-1" />
          <h4 className="text-sm font-semibold text-white">Resumen</h4>
        </div>
        <p className="text-sm text-gray-300">{summary}</p>
      </div>

      {/* Action Items */}
      {actionItems.length > 0 && (
        <div className="bg-black/30 rounded-lg p-4 mb-4">
          <div className="flex items-center gap-2 mb-3">
            <Flag className="h-4 w-4 text-acid-2" />
            <h4 className="text-sm font-semibold text-white">
              Action Items ({actionItems.length})
            </h4>
          </div>
          <ul className="space-y-2">
            {actionItems.map((item, idx) => (
              <li key={idx} className="flex items-start gap-2 text-sm">
                <span className="text-acid-1">→</span>
                <div>
                  <span className="text-white font-medium">{item.assignee}:</span>{" "}
                  <span className="text-gray-300">{item.task}</span>
                  {item.deadline && (
                    <span className="text-xs text-gray-400 ml-2">
                      ({item.deadline})
                    </span>
                  )}
                </div>
              </li>
            ))}
          </ul>
        </div>
      )}

      {/* Temas */}
      {topics.length > 0 && (
        <div className="flex flex-wrap gap-2">
          {topics.map((topic, idx) => (
            <span
              key={idx}
              className="px-2 py-1 text-xs bg-acid-1/10 text-acid-1 rounded"
            >
              {topic}
            </span>
          ))}
        </div>
      )}
    </div>
  );
}
```

---

### PASO 5: Adaptar nodus-recorder-pwa

**Archivo**: `nodus-recorder-pwa/src/RecorderApp.tsx`

```typescript
import { useEffect, useState, useRef } from "react";
import { Square } from "lucide-react";

interface RecordingParams {
  id: string;
  type: "audio" | "video" | "screen";
  title: string;
  duration: number;
  session: string;
  user: string;
  callback: string;
}

export function RecorderApp() {
  const [params, setParams] = useState<RecordingParams | null>(null);
  const [isRecording, setIsRecording] = useState(false);
  const [elapsedSeconds, setElapsedSeconds] = useState(0);
  
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const chunksRef = useRef<Blob[]>([]);

  // Leer parámetros de URL
  useEffect(() => {
    const urlParams = new URLSearchParams(window.location.search);
    
    setParams({
      id: urlParams.get("id") || "",
      type: (urlParams.get("type") as any) || "audio",
      title: urlParams.get("title") || "Sin título",
      duration: parseInt(urlParams.get("duration") || "60"),
      session: urlParams.get("session") || "",
      user: urlParams.get("user") || "",
      callback: urlParams.get("callback") || "http://localhost:8080/api/recordings/complete",
    });
  }, []);

  // Auto-iniciar grabación
  useEffect(() => {
    if (params && !isRecording) {
      setTimeout(() => startRecording(), 2000);
    }
  }, [params]);

  const startRecording = async () => {
    if (!params) return;

    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      
      const recorder = new MediaRecorder(stream);
      chunksRef.current = [];

      recorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          chunksRef.current.push(event.data);
        }
      };

      recorder.onstop = () => handleRecordingComplete();

      recorder.start(1000);
      mediaRecorderRef.current = recorder;
      setIsRecording(true);

      // Timer
      const timer = setInterval(() => {
        setElapsedSeconds((prev) => prev + 1);
      }, 1000);

      // Notificar inicio
      if (window.opener) {
        window.opener.postMessage({
          type: "recording_started",
          recording_id: params.id,
        }, "*");
      }

    } catch (err) {
      console.error("Error starting recording:", err);
    }
  };

  const stopRecording = () => {
    if (mediaRecorderRef.current) {
      mediaRecorderRef.current.stop();
      mediaRecorderRef.current.stream.getTracks().forEach(track => track.stop());
    }
    setIsRecording(false);
  };

  const handleRecordingComplete = async () => {
    if (!params) return;

    try {
      const blob = new Blob(chunksRef.current, { type: "audio/webm" });

      const formData = new FormData();
      formData.append("recording_id", params.id);
      formData.append("session_id", params.session);
      formData.append("user_id", params.user);
      formData.append("recording_type", params.type);
      formData.append("title", params.title);
      formData.append("duration_seconds", elapsedSeconds.toString());
      formData.append("audio_file", blob, `recording_${params.id}.webm`);

      const response = await fetch(params.callback, {
        method: "POST",
        body: formData,
      });

      if (!response.ok) {
        throw new Error(`Upload failed: ${response.status}`);
      }

      // Notificar completado
      if (window.opener) {
        window.opener.postMessage({
          type: "recording_complete",
          recording_id: params.id,
        }, "*");
      }

      // Cerrar ventana
      setTimeout(() => window.close(), 2000);

    } catch (err) {
      console.error("Error uploading:", err);
    }
  };

  if (!params) return <div>Cargando...</div>;

  return (
    <div className="flex flex-col items-center justify-center min-h-screen bg-black text-white p-8">
      <h1 className="text-2xl font-bold mb-8">{params.title}</h1>

      <div className="text-6xl font-mono font-bold text-cyan-400 mb-8">
        {Math.floor(elapsedSeconds / 60)}:{(elapsedSeconds % 60).toString().padStart(2, "0")}
      </div>

      {isRecording && (
        <button
          onClick={stopRecording}
          className="flex items-center gap-3 px-8 py-4 bg-red-500 hover:bg-red-600 rounded-lg"
        >
          <Square className="h-6 w-6" />
          <span>Detener Grabación</span>
        </button>
      )}
    </div>
  );
}
```

---

### PASO 6: Configurar Docker Compose

**Archivo**: `nodus-adk-infra/docker-compose.yml`

Añadir servicio:

```yaml
services:
  # ... servicios existentes ...

  nodus-recorder:
    build:
      context: ../nodus-recorder-pwa
      dockerfile: Dockerfile.dev
    container_name: nodus-recorder
    ports:
      - "5005:5000"
    environment:
      - RUNTIME_URL=http://adk-runtime:8080
      - BACKOFFICE_URL=http://backoffice:5001
      - JWT_JWKS_URL=http://backoffice:5001/.well-known/jwks.json
    networks:
      - nodus-network
    volumes:
      - ../nodus-recorder-pwa:/app
      - /app/node_modules
    depends_on:
      - backoffice
      - adk-runtime
```

---

## 6. Testing y Validación

### 6.1 Tests Unitarios

**Archivo**: `nodus-adk-agents/tests/test_recorder_tool.py`

```python
import pytest
from nodus_adk_agents.tools.recorder_tool import RecorderTool

@pytest.fixture
def recorder_tool():
    return RecorderTool(
        runtime_url="http://localhost:8080",
        recorder_url="http://localhost:5005",
    )

@pytest.mark.asyncio
async def test_generates_valid_url(recorder_tool):
    class MockToolContext:
        class MockInvocationContext:
            session_id = "test-session-123"
            user_id = "user-456"
        _invocation_context = MockInvocationContext()
    
    result = await recorder_tool.run_async(
        args={
            "recording_type": "audio",
            "title": "Test Meeting",
            "duration_minutes": 30,
        },
        tool_context=MockToolContext(),
    )
    
    assert result["_hitl_required"] is True
    assert result["recording_type"] == "audio"
    assert "type=audio" in result["recorder_url"]
```

### 6.2 Test Manual Checklist

```
□ Setup
  □ Todos los servicios corriendo
  □ nodus-recorder en localhost:5005
  □ nodus-llibreta en localhost:5002

□ Flujo Audio
  □ Usuario: "Grábame la reunión"
  □ Agent responde con HITL card
  □ Click "Iniciar Grabación"
  □ Popup se abre
  □ Permisos solicitados
  □ Timer funciona
  □ Detener funciona
  □ Popup se cierra
  □ Llibreta muestra resultado

□ Edge Cases
  □ Usuario cierra popup → No crash
  □ Red cae durante upload → Error manejado
  □ Sin permisos → Error claro
```

---

## 7. Troubleshooting

### Problema: Popup no se abre

**Solución**: Verificar bloqueador de popups del navegador.

```typescript
const popup = window.open(recorderUrl, ...);
if (!popup) {
  alert("Por favor permite popups para este sitio");
}
```

### Problema: Audio no se sube

**Causa**: Archivo demasiado grande

**Solución**: Aumentar límite en nginx/FastAPI

```python
# FastAPI
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
)

@app.middleware("http")
async def set_max_body_size(request, call_next):
    request.scope["max_body_size"] = 50 * 1024 * 1024  # 50 MB
    return await call_next(request)
```

### Problema: WebSocket no notifica

**Diagnóstico**:

```typescript
// En Llibreta
const ws = new WebSocket('ws://localhost:8080/ws');
ws.onmessage = (event) => {
  console.log('[WS] Message:', event.data);
};
```

---

## 8. Anexos

### 8.1 Schema de Base de Datos

```sql
CREATE TABLE IF NOT EXISTS recordings (
    id UUID PRIMARY KEY,
    session_id UUID NOT NULL,
    user_id UUID NOT NULL,
    title VARCHAR(255) NOT NULL,
    recording_type VARCHAR(20) NOT NULL,
    duration_seconds INTEGER NOT NULL,
    audio_url TEXT,
    transcript TEXT,
    summary TEXT,
    action_items JSONB DEFAULT '[]'::jsonb,
    topics JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_recordings_session ON recordings(session_id);
CREATE INDEX idx_recordings_user ON recordings(user_id);
```

### 8.2 Variables de Entorno

```bash
# Recording Configuration
RECORDER_URL=http://localhost:5005
RUNTIME_URL=http://localhost:8080
MAX_RECORDING_DURATION_MINUTES=180
AUTO_TRANSCRIBE=true

# Storage
RECORDING_STORAGE_BACKEND=minio
MINIO_ENDPOINT=localhost:9000
MINIO_BUCKET_RECORDINGS=recordings

# Transcription
TRANSCRIPTION_SERVICE=backoffice
TRANSCRIPTION_LANGUAGE=auto
```

### 8.3 Diagrama de Secuencia

```
Usuario → Llibreta → Root Agent → RecorderTool
  ↓
HITL Card → Click → window.open(PWA)
  ↓
PWA → MediaRecorder → Grabar
  ↓
Stop → Upload → Runtime Handler
  ↓
Transcribe → Process → Save → WebSocket
  ↓
Llibreta → Mostrar Resultado
```

---

## Conclusión

Esta guía proporciona todos los pasos necesarios para integrar nodus-recorder-pwa con nodus-adk.

### Próximos Pasos

1. Clonar nodus-recorder-pwa
2. Implementar RecorderTool
3. Añadir Recording Handler
4. Crear UI components
5. Modificar PWA
6. Actualizar docker-compose
7. Testing

---

**Autor**: Equipo Nodus Factory  
**Fecha**: Noviembre 2025  
**Versión**: 1.0

