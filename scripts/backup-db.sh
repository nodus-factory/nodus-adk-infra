#!/bin/bash
set -euo pipefail

# ============================================================================
# 💾 BACKUP AUTOMÀTIC DE BASE DE DADES
# ============================================================================
# Crea backups SQL comprimits i els puja a Google Drive
# Manté últims 3 locals i últims 10 a Drive
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP_DIR="$PROJECT_ROOT/backups/database"
DATE=$(date +%Y%m%d_%H%M%S)
DRIVE_FOLDER="nodus-adk-backups"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Verificar que Docker està running
if ! docker ps &> /dev/null; then
    log_error "Docker no està running!"
    exit 1
fi

# Verificar que PostgreSQL està accessible
if ! docker exec nodus-adk-postgres pg_isready -U nodus &> /dev/null; then
    log_error "PostgreSQL no està accessible!"
    exit 1
fi

# Crear directori de backups
mkdir -p "$BACKUP_DIR"

log_info "🔄 Iniciant backup de base de dades..."
log_info "📁 Directori local: $BACKUP_DIR"
log_info "📅 Data: $DATE"
echo ""

# ============================================================================
# BACKUP BASE DE DADES PRINCIPAL (nodus)
# ============================================================================
log_step "1/3 Creant backup de 'nodus' database..."
NODUS_BACKUP="$BACKUP_DIR/nodus_${DATE}.sql"

docker exec nodus-adk-postgres pg_dump -U nodus nodus > "$NODUS_BACKUP"

if [ $? -eq 0 ]; then
    # Comprimir backup
    gzip "$NODUS_BACKUP"
    NODUS_BACKUP="${NODUS_BACKUP}.gz"
    
    SIZE=$(du -h "$NODUS_BACKUP" | cut -f1)
    log_info "✅ Backup 'nodus' creat: nodus_${DATE}.sql.gz ($SIZE)"
    
    # Crear symlink a l'últim backup
    ln -sf "nodus_${DATE}.sql.gz" "$BACKUP_DIR/latest.sql.gz"
else
    log_error "❌ Error al fer backup de 'nodus'"
    exit 1
fi

# ============================================================================
# BACKUP LANGFUSE (si existeix)
# ============================================================================
log_step "2/3 Verificant Langfuse..."
if docker exec nodus-adk-postgres psql -U nodus -lqt | cut -d \| -f 1 | grep -qw langfuse_db; then
    log_info "💾 Creant backup de 'langfuse_db'..."
    LANGFUSE_BACKUP="$BACKUP_DIR/langfuse_${DATE}.sql"
    
    docker exec nodus-adk-postgres pg_dump -U nodus langfuse_db > "$LANGFUSE_BACKUP"
    
    if [ $? -eq 0 ]; then
        gzip "$LANGFUSE_BACKUP"
        SIZE=$(du -h "${LANGFUSE_BACKUP}.gz" | cut -f1)
        log_info "✅ Backup 'langfuse_db' creat: langfuse_${DATE}.sql.gz ($SIZE)"
    fi
else
    log_warn "⚠️  Base de dades 'langfuse_db' no trobada (skip)"
fi

# ============================================================================
# PUJAR A GOOGLE DRIVE (si rclone està configurat)
# ============================================================================
log_step "3/3 Pujant backups a Google Drive..."

if command -v rclone &> /dev/null; then
    # Verificar si està configurat
    if rclone listremotes | grep -q "drive:"; then
        log_info "☁️  Pujant a Google Drive..."
        
        # Crear carpeta si no existeix
        rclone mkdir "drive:$DRIVE_FOLDER" 2>/dev/null || true
        
        # Pujar backups
        rclone copy "$NODUS_BACKUP" "drive:$DRIVE_FOLDER/" --progress
        
        if [ -f "${LANGFUSE_BACKUP}.gz" ]; then
            rclone copy "${LANGFUSE_BACKUP}.gz" "drive:$DRIVE_FOLDER/" --progress
        fi
        
        log_info "✅ Backups pujats a Google Drive: $DRIVE_FOLDER/"
        
        # Mantenir només últims 10 a Drive
        log_info "🧹 Netejant backups antics a Drive (mantenint últims 10)..."
        REMOTE_FILES=$(rclone lsf "drive:$DRIVE_FOLDER/" | grep "^nodus_" | sort -r)
        FILES_TO_DELETE=$(echo "$REMOTE_FILES" | tail -n +11)
        
        if [ -n "$FILES_TO_DELETE" ]; then
            echo "$FILES_TO_DELETE" | while read -r file; do
                rclone delete "drive:$DRIVE_FOLDER/$file"
                log_info "   Eliminat: $file"
            done
        fi
        
    else
        log_warn "⚠️  rclone no està configurat amb 'drive:'"
        log_warn "   Executa: rclone config"
        log_warn "   Backups guardats només localment"
    fi
else
    log_warn "⚠️  rclone no instal·lat"
    log_warn "   Instal·la: brew install rclone"
    log_warn "   Configura: rclone config"
    log_warn "   Backups guardats només localment"
fi

# ============================================================================
# NETEJA DE BACKUPS LOCALS (mantenir últims 3)
# ============================================================================
log_info "🧹 Netejant backups locals (mantenint últims 3)..."
cd "$BACKUP_DIR"
ls -t nodus_*.sql.gz 2>/dev/null | tail -n +4 | xargs -r rm
ls -t langfuse_*.sql.gz 2>/dev/null | tail -n +4 | xargs -r rm

# ============================================================================
# RESUM
# ============================================================================
echo ""
log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_info "📊 RESUM DEL BACKUP"
log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

LOCAL_COUNT=$(ls -1 "$BACKUP_DIR"/*.sql.gz 2>/dev/null | grep -v latest | wc -l | tr -d ' ')
LOCAL_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)

log_info "   📁 Backups locals: $LOCAL_COUNT"
log_info "   💾 Mida total: $LOCAL_SIZE"
log_info "   📍 Ubicació: $BACKUP_DIR"

if command -v rclone &> /dev/null && rclone listremotes | grep -q "drive:"; then
    DRIVE_COUNT=$(rclone lsf "drive:$DRIVE_FOLDER/" 2>/dev/null | grep "^nodus_" | wc -l | tr -d ' ')
    log_info "   ☁️  Backups a Drive: $DRIVE_COUNT"
    log_info "   📂 Carpeta Drive: $DRIVE_FOLDER"
fi

echo ""
log_info "✅ Backup completat amb èxit!"
log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
