#!/usr/bin/env bash
# Atualiza a SownteeShell para a versão mais nova do autor e reaplica o pt-BR.
#   ./atualizar-sownteeshell.sh             atualiza, traduz e recompila os serviços
#   ./atualizar-sownteeshell.sh --sem-build não recompila os serviços em Rust
set -euo pipefail
KIT="$(cd -- "$(dirname -- "$0")" && pwd)"
SHELL_DIR="${SOWNTEESHELL_DIR:-$HOME/Dotfiles/sownteeshell}"

cd "$SHELL_DIR"
# Desfaz a tradução anterior (e qualquer edição local!) para o git pull não dar conflito.
if ! git diff --quiet; then
    git stash push -q -m "sownteeshell-ptbr-$(date +%Y%m%d-%H%M%S)"
    echo "[*] Alterações locais guardadas em 'git stash list' (inclui a tradução antiga)."
fi
rm -f .ptbr-aplicado
git pull --ff-only
python3 "$KIT/aplicar-ptbr.py" "$SHELL_DIR"

if [ "${1:-}" != "--sem-build" ]; then
    for d in core-daemon calendar-daemon; do
        cargo build --release --locked --manifest-path "backend/rust/$d/Cargo.toml"
    done
    install -m755 backend/rust/core-daemon/target/release/sownteeshell-core "$HOME/.local/lib/sownteeshell/sownteeshell-core.new"
    mv "$HOME/.local/lib/sownteeshell/sownteeshell-core.new" "$HOME/.local/lib/sownteeshell/sownteeshell-core"
    install -m755 backend/rust/calendar-daemon/target/release/sownteeshell-calendar-daemon "$HOME/.local/lib/sownteeshell/sownteeshell-calendar-daemon.new"
    mv "$HOME/.local/lib/sownteeshell/sownteeshell-calendar-daemon.new" "$HOME/.local/lib/sownteeshell/sownteeshell-calendar-daemon"
    systemctl --user restart sownteeshell-core.service sownteeshell-calendar.service || true
    echo "[ok] Atualizado. Recarregue o shell com Ctrl+Alt+R."
fi
