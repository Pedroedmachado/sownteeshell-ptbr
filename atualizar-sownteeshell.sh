#!/usr/bin/env bash
# Atualiza a SownteeShell para a versão mais nova do autor e reaplica o pt-BR.
#   ./atualizar-sownteeshell.sh             atualiza, traduz, recompila e reinicia os serviços
#   ./atualizar-sownteeshell.sh --sem-build só atualiza e traduz (o instalador usa assim)
set -euo pipefail
KIT="$(cd -- "$(dirname -- "$0")" && pwd)"
SHELL_DIR="${SOWNTEESHELL_DIR:-$HOME/Dotfiles/sownteeshell}"
cd "$SHELL_DIR"

# Ícones que o Matugen recolore ficam dentro do repositório: guarda e devolve depois.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
for f in assets/icons/sownteeshell-settings.svg assets/icons/sownteeshell-calendar.svg assets/icons/sownteeshell-connect.svg; do
    [ -f "$f" ] && cp "$f" "$TMP/"
done

# Desfaz a tradução anterior (e qualquer edição local) para o git pull não dar conflito.
if ! git diff --quiet; then
    git stash push -q -m "sownteeshell-ptbr-$(date +%Y%m%d-%H%M%S)"
    echo "[*] Alterações locais guardadas em 'git stash list' (inclui a tradução antiga)."
fi
rm -f .ptbr-aplicado
# fetch + reset aguenta force-push do autor; se a rede falhar, reaplica a tradução na versão atual.
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if git fetch --depth=1 origin "$BRANCH"; then
    git reset -q --hard FETCH_HEAD
else
    echo "[!] Não consegui baixar a versão nova; reaplicando a tradução na versão atual."
    git checkout -q -- .
fi
python3 "$KIT/aplicar-ptbr.py" "$SHELL_DIR"
for f in "$TMP"/*.svg; do [ -f "$f" ] && cp "$f" assets/icons/; done

if [ "${1:-}" != "--sem-build" ]; then
    LIB="$HOME/.local/lib/sownteeshell"
    for d in core-daemon calendar-daemon; do
        CARGO_TARGET_DIR="backend/rust/$d/target" cargo build --release --locked --manifest-path "backend/rust/$d/Cargo.toml"
    done
    install -m755 backend/rust/core-daemon/target/release/sownteeshell-core "$LIB/sownteeshell-core.new"
    mv -f "$LIB/sownteeshell-core.new" "$LIB/sownteeshell-core"
    install -m755 backend/rust/calendar-daemon/target/release/sownteeshell-calendar-daemon "$LIB/sownteeshell-calendar-daemon.new"
    mv -f "$LIB/sownteeshell-calendar-daemon.new" "$LIB/sownteeshell-calendar-daemon"
    install -m644 backend/systemd/user/*.service "$HOME/.config/systemd/user/"
    install -Dm755 backend/cli/sownteeshell "$HOME/.local/bin/sownteeshell"
    plugin/imagecache/build-imagecache
    systemctl --user daemon-reload
    systemctl --user restart sownteeshell-core.service sownteeshell-calendar.service || true
    # A tela de login usa uma cópia própria; atualiza se estiver instalada.
    if [ -d /usr/share/sownteeshell/greeter ]; then
        echo "[*] Atualizando a tela de login (pede a senha)..."
        # O deploy do autor reescreve a config do greetd; depois volta o modo que estava.
        MODO_LOGIN=""
        sudo grep -q tuigreet /etc/greetd/config.toml 2>/dev/null && MODO_LOGIN=--texto
        sudo grep -q 'cage -d' /etc/greetd/config.toml 2>/dev/null && MODO_LOGIN=--cage
        sudo install -D -m 0755 backend/rust/core-daemon/target/release/sownteeshell-core /usr/lib/sownteeshell/sownteeshell-core
        sudo scripts/system/deploy-greeter.sh --privileged "$USER" >/dev/null
        "$KIT/configurar-greeter.sh" $MODO_LOGIN >/dev/null || echo "[!] Rode ./configurar-greeter.sh para ajustar a tela de login."
    fi
    echo "[ok] Atualizado. Recarregue o shell com Ctrl+Alt+R."
fi
