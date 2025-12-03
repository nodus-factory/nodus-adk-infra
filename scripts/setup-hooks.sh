#!/bin/bash
set -euo pipefail

# ============================================================================
# ⚙️  CONFIGURACIÓ DE GIT HOOKS
# ============================================================================
# Instal·la git hooks per backups automàtics
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GIT_HOOKS_DIR="$PROJECT_ROOT/.git/hooks"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

log_info "⚙️  Configurant Git hooks per backups automàtics..."
echo ""

# Verificar que estem dins d'un repositori Git
if [ ! -d "$PROJECT_ROOT/.git" ]; then
    log_warn "❌ No és un repositori Git!"
    exit 1
fi

# Crear directori de hooks si no existeix
mkdir -p "$GIT_HOOKS_DIR"

# ============================================================================
# PRE-COMMIT HOOK
# ============================================================================
log_step "1/3 Creant pre-commit hook..."

cat > "$GIT_HOOKS_DIR/pre-commit" << 'EOF'
#!/bin/bash
# Git hook: pre-commit
# Crea backup automàtic abans de cada commit

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BACKUP_SCRIPT="$PROJECT_ROOT/nodus-adk-infra/scripts/backup-db.sh"

# Solo ejecutar si Docker está running
if docker ps &> /dev/null; then
    echo "🔄 Creant backup automàtic..."
    
    if [ -f "$BACKUP_SCRIPT" ]; then
        "$BACKUP_SCRIPT"
        
        if [ $? -eq 0 ]; then
            echo "✅ Backup completat!"
        else
            echo "⚠️  Backup fallit (continuant amb commit)"
        fi
    else
        echo "⚠️  Script de backup no trobat (skip)"
    fi
else
    echo "⚠️  Docker no està running (skip backup)"
fi

echo ""
EOF

chmod +x "$GIT_HOOKS_DIR/pre-commit"
log_info "✅ Pre-commit hook instal·lat"

# ============================================================================
# POST-MERGE HOOK (restauració opcional)
# ============================================================================
log_step "2/3 Creant post-merge hook..."

cat > "$GIT_HOOKS_DIR/post-merge" << 'EOF'
#!/bin/bash
# Git hook: post-merge
# Avisa si cal restaurar la base de dades després d'un merge/pull

echo ""
echo "💡 RECORDATORI: Si has fet pull amb canvis de DB, considera:"
echo "   ./nodus-adk-infra/scripts/restore-db.sh"
echo ""
EOF

chmod +x "$GIT_HOOKS_DIR/post-merge"
log_info "✅ Post-merge hook instal·lat"

# ============================================================================
# VERIFICAR RCLONE
# ============================================================================
log_step "3/3 Verificant rclone..."

if ! command -v rclone &> /dev/null; then
    log_warn "⚠️  rclone no instal·lat"
    echo ""
    echo "Per pujar backups a Google Drive:"
    echo "  1. Instal·la rclone:  brew install rclone"
    echo "  2. Configura Drive:   rclone config"
    echo "  3. Selecciona:        Google Drive"
    echo "  4. Nom remote:        drive"
    echo ""
else
    if rclone listremotes | grep -q "drive:"; then
        log_info "✅ rclone configurat amb Google Drive"
    else
        log_warn "⚠️  rclone instal·lat però no configurat"
        echo ""
        echo "Configura Google Drive:"
        echo "  rclone config"
        echo ""
    fi
fi

# ============================================================================
# RESUM
# ============================================================================
echo ""
log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_info "✅ GIT HOOKS CONFIGURATS"
log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
log_info "📦 Hooks instal·lats:"
log_info "   ✓ pre-commit  → Backup automàtic abans de commit"
log_info "   ✓ post-merge  → Avís després de pull/merge"
echo ""
log_info "🎯 Ara cada vegada que facis commit:"
log_info "   1. Es crearà un backup automàtic"
log_info "   2. Es pujarà a Google Drive (si configurat)"
log_info "   3. Es mantindran últims 3 locals i 10 a Drive"
echo ""
log_info "📚 Comandes útils:"
log_info "   Backup manual:   ./nodus-adk-infra/scripts/backup-db.sh"
log_info "   Restaurar:       ./nodus-adk-infra/scripts/restore-db.sh"
echo ""
log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""


