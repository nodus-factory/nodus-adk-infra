# 💾 Backups de Base de Dades

Aquest directori conté els backups locals de la base de dades PostgreSQL.

## 📁 Estructura

```
backups/database/
├── nodus_YYYYMMDD_HHMMSS.sql.gz      # Backups comprimits
├── langfuse_YYYYMMDD_HHMMSS.sql.gz   # Backups de Langfuse
└── latest.sql.gz                      # Symlink a l'últim backup
```

## 🔄 Backups Automàtics

Els backups es creen automàticament:
- ✅ Abans de cada **git commit** (via pre-commit hook)
- ✅ Es pugen automàticament a **Google Drive**
- ✅ Es mantenen **3 locals** i **10 a Drive**

## 🚀 Comandes

### Crear backup manual
```bash
./scripts/backup-db.sh
```

### Restaurar últim backup
```bash
./scripts/restore-db.sh
```

### Restaurar backup específic
```bash
./scripts/restore-db.sh nodus_20251125_090000.sql.gz
```

### Configurar hooks (primer cop)
```bash
./scripts/setup-hooks.sh
```

## ☁️ Google Drive

Els backups es pugen automàticament a Google Drive a la carpeta:
```
nodus-adk-backups/
```

**Configuració necessària:**
```bash
# 1. Instal·lar rclone
brew install rclone

# 2. Configurar Google Drive
rclone config

# 3. Seleccionar:
#    - Type: Google Drive
#    - Name: drive
#    - Follow prompts
```

## 📊 Política de Retenció

| Ubicació | Backups | Període |
|----------|---------|---------|
| **Local** | 3 | ~1 setmana |
| **Google Drive** | 10 | ~1 mes |

## ⚠️ Important

- ❌ Els fitxers `.sql.gz` **NO** es commitegen a Git (massa grans)
- ✅ Es guarden a Google Drive automàticament
- ✅ Time Machine captura aquest directori (backups locals)

## 🔍 Verificar Backups

### Locals
```bash
ls -lh backups/database/*.sql.gz
```

### Google Drive
```bash
rclone ls drive:nodus-adk-backups/
```

## 🛟 Recuperació d'Emergència

Si necessites restaurar completament:

```bash
# 1. Descarregar backup de Drive
rclone copy drive:nodus-adk-backups/nodus_YYYYMMDD_HHMMSS.sql.gz backups/database/

# 2. Restaurar
./scripts/restore-db.sh nodus_YYYYMMDD_HHMMSS.sql.gz
```

---

**Data última actualització:** 2025-11-25


