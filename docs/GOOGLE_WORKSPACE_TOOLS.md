# Google Workspace MCP Tools (86 tools)

Llista completa de les eines disponibles del servidor MCP `google-workspace`.

**Prefix**: `google__` (quan s'usen des del Root Agent)

---

## 📧 Gmail (20 tools)

### Cerca i Lectura
- `search_gmail_messages` - Cerca emails amb Gmail search operators
- `get_gmail_message_content` - Obté el contingut complet d'un email
- `get_gmail_messages_content_batch` - Obté múltiples emails en batch
- `get_gmail_thread_content` - Obté tot un thread de conversa
- `get_gmail_threads_content_batch` - Obté múltiples threads en batch
- `get_gmail_attachment_content` - Descarrega adjunts d'emails

### Enviament i Gestió
- `send_gmail_message` - Envia un nou email
- `draft_gmail_message` - Crea un esborrany d'email
- `modify_gmail_message_labels` - Afegeix/elimina etiquetes d'un email
- `batch_modify_gmail_message_labels` - Modifica etiquetes en batch

### Etiquetes
- `list_gmail_labels` - Llista totes les etiquetes disponibles
- `manage_gmail_label` - Crea/actualitza/elimina etiquetes

### Espais i Missatges (Google Chat)
- `list_spaces` - Llista espais de Google Chat
- `get_messages` - Obté missatges d'un espai
- `search_messages` - Cerca missatges en espais
- `send_message` - Envia missatge a un espai

---

## 📅 Calendar (5 tools)

- `list_calendars` - Llista tots els calendaris disponibles
- `get_events` - **[MÉS USAT]** Obté esdeveniments d'un calendari (requereix time_min i time_max)
- `create_event` - Crea un nou esdeveniment
- `modify_event` - Modifica un esdeveniment existent
- `delete_event` - Elimina un esdeveniment

**Nota crítica**: `get_events` SEMPRE requereix `time_min` i `time_max` en format ISO 8601.

---

## 📁 Drive (10 tools)

### Cerca i Navegació
- `list_drive_items` - Llista fitxers i carpetes
- `search_drive_files` - Cerca fitxers amb query syntax
- `list_docs_in_folder` - Llista documents en una carpeta específica

### Lectura i Descàrrega
- `get_drive_file_content` - Obté el contingut d'un fitxer
- `get_drive_file_permissions` - Obté permisos d'un fitxer
- `check_drive_file_public_access` - Verifica si un fitxer és públic

### Gestió
- `create_drive_file` - Crea un nou fitxer
- `update_drive_file` - Actualitza un fitxer existent
- `set_publish_settings` - Configura opcions de publicació

### Autenticació
- `start_google_auth` - Inicia el flux d'autenticació OAuth

---

## 📄 Google Docs (14 tools)

### Lectura
- `search_docs` - Cerca documents
- `get_doc_content` - Obté el contingut d'un document
- `inspect_doc_structure` - Inspecciona l'estructura d'un document
- `debug_table_structure` - Debugeja l'estructura de taules

### Escriptura i Modificació
- `create_doc` - Crea un nou document
- `modify_doc_text` - Modifica text d'un document
- `insert_doc_elements` - Insereix elements (text, taules, etc.)
- `insert_doc_image` - Insereix imatges
- `find_and_replace_doc` - Cerca i substitueix text
- `update_doc_headers_footers` - Actualitza capçaleres i peus de pàgina
- `batch_update_doc` - Actualitza múltiples elements en batch

### Comentaris
- `create_document_comment` - Crea un comentari
- `read_document_comments` - Llegeix comentaris
- `reply_to_document_comment` - Respon a un comentari
- `resolve_document_comment` - Resol un comentari

### Exportació
- `export_doc_to_pdf` - Exporta document a PDF

---

## 📊 Google Sheets (10 tools)

### Lectura
- `list_spreadsheets` - Llista fulls de càlcul
- `get_spreadsheet_info` - Obté informació d'un full de càlcul
- `read_sheet_values` - Llegeix valors d'un rang

### Escriptura
- `create_spreadsheet` - Crea un nou full de càlcul
- `create_sheet` - Crea una nova pestanya
- `modify_sheet_values` - Modifica valors d'un rang
- `create_table_with_data` - Crea una taula amb dades

### Comentaris
- `create_spreadsheet_comment` - Crea un comentari
- `read_spreadsheet_comments` - Llegeix comentaris
- `reply_to_spreadsheet_comment` - Respon a un comentari
- `resolve_spreadsheet_comment` - Resol un comentari

---

## 📽️ Google Slides (9 tools)

### Lectura
- `get_presentation` - Obté informació d'una presentació
- `get_page` - Obté una pàgina específica
- `get_page_thumbnail` - Obté miniatura d'una pàgina

### Escriptura
- `create_presentation` - Crea una nova presentació
- `batch_update_presentation` - Actualitza múltiples elements en batch

### Comentaris
- `create_presentation_comment` - Crea un comentari
- `read_presentation_comments` - Llegeix comentaris
- `reply_to_presentation_comment` - Respon a un comentari
- `resolve_presentation_comment` - Resol un comentari

---

## 📝 Google Forms (3 tools)

- `create_form` - Crea un nou formulari
- `get_form` - Obté informació d'un formulari
- `list_form_responses` - Llista respostes d'un formulari
- `get_form_response` - Obté una resposta específica

---

## ✅ Google Tasks (12 tools)

### Llistes de Tasques
- `list_task_lists` - Llista totes les llistes de tasques
- `get_task_list` - Obté una llista específica
- `create_task_list` - Crea una nova llista
- `update_task_list` - Actualitza una llista
- `delete_task_list` - Elimina una llista

### Tasques
- `list_tasks` - Llista tasques d'una llista
- `get_task` - Obté una tasca específica
- `create_task` - Crea una nova tasca
- `update_task` - Actualitza una tasca
- `delete_task` - Elimina una tasca
- `move_task` - Mou una tasca a una altra llista
- `clear_completed_tasks` - Esborra tasques completades

---

## 🔍 Google Custom Search (3 tools)

**Què fan?** Permeten crear cerques personalitzades a Google amb motors de cerca configurats prèviament. A diferència de cercar a Gmail/Drive/Docs (que cerquen dins de Workspace), aquestes tools cerquen a **Internet públic** però amb filtres personalitzats.

### Eines
- `search_custom` - Cerca personalitzada amb un motor de cerca configurat (CSE - Custom Search Engine)
- `search_custom_siterestrict` - Cerca restringida a llocs específics (ex: només dins de mynodus.com)
- `get_search_engine_info` - Obté informació del motor de cerca personalitzat

### Casos d'Ús
1. **Cerca en documentació pública**: Cercar només dins de docs.google.com, stackoverflow.com, etc.
2. **Cerca en el web corporatiu**: Cercar només dins dels dominis de l'empresa
3. **Cerca temàtica**: Motor configurat per cercar només contingut tècnic, legal, etc.
4. **Competència**: Cercar informació pública sobre competidors

**Nota**: Requereix tenir un **Google Programmable Search Engine (CSE)** configurat prèviament amb la seva API key i CX (Custom Search Engine ID).

---

## 📊 Resum per Categoria

| Categoria | Tools | Més Usades |
|-----------|-------|------------|
| **Gmail** | 20 | `search_gmail_messages`, `get_gmail_message_content`, `send_gmail_message` |
| **Calendar** | 5 | `get_events`, `create_event`, `modify_event` |
| **Drive** | 10 | `search_drive_files`, `get_drive_file_content`, `create_drive_file` |
| **Docs** | 14 | `get_doc_content`, `create_doc`, `modify_doc_text` |
| **Sheets** | 10 | `read_sheet_values`, `modify_sheet_values`, `create_spreadsheet` |
| **Slides** | 9 | `get_presentation`, `create_presentation` |
| **Forms** | 4 | `get_form`, `list_form_responses` |
| **Tasks** | 12 | `list_tasks`, `create_task`, `update_task` |
| **Search** | 3 | `search_custom` |
| **TOTAL** | **86** | |

---

## 🎯 Tools Més Importants per Personal Assistant

### Top 10 (ús diari)
1. `google__get_events` - Agenda diària
2. `google__search_gmail_messages` - Cerca emails
3. `google__get_gmail_message_content` - Llegir emails
4. `google__send_gmail_message` - Enviar emails
5. `google__search_drive_files` - Cerca documents
6. `google__get_doc_content` - Llegir documents
7. `google__create_event` - Crear reunions
8. `google__list_tasks` - Veure tasques pendents
9. `google__create_task` - Crear tasques
10. `google__read_sheet_values` - Llegir dades de fulls de càlcul

---

## 📝 Notes d'Ús

### Gmail Search Operators
```
is:unread              - Emails no llegits
is:starred             - Emails destacats
from:email@domain.com  - De un remitent
to:email@domain.com    - A un destinatari
subject:"text"         - Assumpte conté "text"
newer_than:1d          - Més nous que 1 dia
older_than:7d          - Més antics que 7 dies
has:attachment         - Té adjunts
filename:pdf           - Adjunts amb "pdf"
```

### Calendar Date Format
```
ISO 8601 amb timezone:
- "2025-11-29T00:00:00+01:00" (Europe/Madrid)
- "2025-11-29T00:00:00Z" (UTC)

SEMPRE especifica time_min i time_max!
```

### Drive Query Syntax
```
name contains 'report'                              - Nom conté "report"
mimeType='application/pdf'                          - Fitxers PDF
mimeType='application/vnd.google-apps.document'     - Google Docs
mimeType='application/vnd.google-apps.spreadsheet'  - Google Sheets
'me' in owners                                      - Fitxers meus
sharedWithMe                                        - Compartits amb mi
```

---

**Última actualització**: 29 novembre 2025

