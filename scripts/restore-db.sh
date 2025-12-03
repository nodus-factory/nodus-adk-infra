#!/bin/bash
set -euo pipefail

# ============================================================================
# 🔄 RESTAURACIÓ DE BASE DE DADES
# ============================================================================
# Restaura la base de dades des d'un backup
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP_DIR="$PROJECT_ROOT/backups/database"

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

show_help() {
    echo "Usage: $0 [backup_file]"
    echo ""
    echo "Restaura la base de dades des d'un backup."
    echo ""
    echo "Arguments:"
    echo "  backup_file    Fitxer de backup a restaurar (opcional)"
    echo "                 Si no s'especifica, usa l'últim backup (latest.sql.gz)"
    echo ""
    echo "Exemples:"
    echo "  $0                                    # Restaura últim backup"
    echo "  $0 nodus_20251125_090000.sql.gz     # Restaura backup específic"
    echo ""
}

# Verificar ajuda
if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    show_help
    exit 0
fi

# Determinar fitxer de backup
if [ -n "${1:-}" ]; then
    BACKUP_FILE="$BACKUP_DIR/$1"
else
    BACKUP_FILE="$BACKUP_DIR/latest.sql.gz"
fi

# Verificar que existeix
if [ ! -f "$BACKUP_FILE" ]; then
    log_error "❌ Backup no trobat: $BACKUP_FILE"
    echo ""
    log_info "Backups disponibles:"
    ls -lh "$BACKUP_DIR"/*.sql.gz 2>/dev/null | awk '{print "  - " $9}' || echo "  (cap backup trobat)"
    exit 1
fi

# Confirmar
log_warn "⚠️  ATENCIÓ: Això eliminarà les dades actuals!"
log_info "📁 Backup: $(basename "$BACKUP_FILE")"
echo ""
read -p "Vols continuar? (yes/no): " -r
echo ""

if [ "$REPLY" != "yes" ]; then
    log_info "Operació cancel·lada"
    exit 0
fi

# Crear backup de seguretat abans
log_info "🔄 Creant backup de seguretat abans de restaurar..."
"$SCRIPT_DIR/backup-db.sh"

# Parar serveis que usen la BD
log_info "⏸️  Parant serveis..."
cd "$PROJECT_ROOT"
docker-compose stop backoffice llibreta adk-runtime

# Restaurar
log_info "📥 Restaurant base de dades..."

# Descomprimir si cal
if [[ "$BACKUP_FILE" == *.gz ]]; then
    gunzip -c "$BACKUP_FILE" | docker exec -i nodus-adk-postgres psql -U nodus -d nodus
else
    docker exec -i nodus-adk-postgres psql -U nodus -d nodus < "$BACKUP_FILE"
fi

if [ $? -eq 0 ]; then
    log_info "✅ Base de dades restaurada!"
else
    log_error "❌ Error al restaurar"
    exit 1
fi

# Reiniciar serveis
log_info "▶️  Reiniciant serveis..."
docker-compose start backoffice llibreta adk-runtime

log_info ""
log_info "✅ Restauració completada!"
log_info ""
log_warn "💡 Prova el login a: http://localhost:5002"


