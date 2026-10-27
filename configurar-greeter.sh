#!/usr/bin/env bash
# Configura a tela de login (greetd). Por padrão, a da SownteeShell rodando dentro do Niri.
#
# Por quê: o greeter do autor roda no `cage` (wlroots). Na NVIDIA o cage desenha a tela
# toda bugada (faixas, imagem deslocada, campo de senha sem aparecer). O Niri já funciona
# bem na sua placa, então o greeter passa a usar um Niri mínimo, sem atalhos, que fecha
# sozinho depois do login.
#
# O script escreve o /etc/greetd/config.toml inteiro (guarda o anterior em .bak-<data>),
# então funciona vindo de qualquer estado: cage do autor, tuigreet ou uma config quebrada.
# Pode rodar quantas vezes quiser. O instalador e o atualizador chamam este script
# sempre que reinstalam a tela de login.
#
#   ./configurar-greeter.sh           tela da SownteeShell no Niri
#   ./configurar-greeter.sh --cage    tela da SownteeShell no cage (config do autor)
#   ./configurar-greeter.sh --texto   tela de texto (tuigreet), a mais garantida na NVIDIA

set -euo pipefail

CONF=/etc/greetd/config.toml
KDL=/etc/sownteeshell/greeter-niri.kdl
GREETER_DIR=/usr/share/sownteeshell/greeter
TEMA_DIR=/var/lib/sownteeshell/greeter
RUNTIME="$TEMA_DIR/runtime"
CORE=/usr/lib/sownteeshell/sownteeshell-core

azul()  { printf '\033[34m%s\033[0m\n' "$*"; }
verde() { printf '\033[32m%s\033[0m\n' "$*"; }
erro()  { printf '\033[31m[!] %s\033[0m\n' "$*" >&2; }

[ "$(id -u)" -eq 0 ] && { erro "Rode como seu usuário, não como root."; exit 1; }

MODO=niri
case "${1:-}" in
    "") ;;
    --cage|--desfazer) MODO=cage ;;
    --texto) MODO=texto ;;
    *) erro "Opção desconhecida: $1 (use --cage ou --texto)"; exit 1 ;;
esac

# Grava $1 em $CONF, guardando a config anterior se for diferente.
gravar_conf() {
    local novo="$1"
    if sudo test -f "$CONF" && ! sudo cmp -s "$novo" "$CONF"; then
        sudo cp "$CONF" "$CONF.bak-$(date +%Y%m%d-%H%M%S)"
    fi
    sudo install -D -m 0644 "$novo" "$CONF"
    rm -f "$novo"
}

if [ "$MODO" = texto ]; then
    sudo pacman -S --needed --noconfirm greetd-tuigreet
    TMP="$(mktemp)"
    cat >"$TMP" <<'TOML'
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --asterisks --greeting 'SownteeShell' --cmd niri-session"
user = "greeter"
TOML
    gravar_conf "$TMP"
    sudo systemctl enable --force greetd.service >/dev/null 2>&1
    verde "[ok] Tela de login de texto (tuigreet). Vale no próximo boot."
    exit 0
fi

[ -f "$GREETER_DIR/shell.qml" ] || {
    erro "A tela de login da SownteeShell não está instalada em $GREETER_DIR."
    erro "Rode ./instalar-sownteeshell.sh --greeter primeiro."
    exit 1
}
[ -x "$CORE" ] || erro "Falta $CORE; a tela de login abre, mas sem bateria/sessões. Rode o instalador de novo."

if [ "$MODO" = niri ]; then
    command -v niri >/dev/null || { erro "Niri não está instalado."; exit 1; }

    # Teclado da tela de senha: o mesmo do sistema (localectl), ABNT2 se não houver.
    LOCALE="$(localectl status 2>/dev/null || true)"
    campo() { sed -n "s/^ *$1: *//p" <<<"$LOCALE" | head -n1; }
    LAYOUT="$(campo 'X11 Layout')"; LAYOUT="${LAYOUT:-br}"
    VARIANTE="$(campo 'X11 Variant')"
    OPCOES="$(campo 'X11 Options')"
    # Linhas montadas fora do heredoc: dentro dele, ${X:+variant "$X"} perde as aspas
    # e o Niri recusa (variant intl).
    XKB_EXTRA=""
    [ -n "$VARIANTE" ] && XKB_EXTRA+=$'\n'"            variant \"$VARIANTE\""
    [ -n "$OPCOES" ] && XKB_EXTRA+=$'\n'"            options \"$OPCOES\""

    azul "[*] Tela de login no Niri (teclado: $LAYOUT${VARIANTE:+ / $VARIANTE})..."
    TMP="$(mktemp)"
    cat >"$TMP" <<KDL
// Niri só para a tela de login da SownteeShell (gerado por configurar-greeter.sh).
// Sem atalhos: não dá para abrir nada além da tela de senha.

input {
    keyboard {
        xkb {
            layout "$LAYOUT"$XKB_EXTRA
        }
        numlock
    }
    touchpad { tap; }
}

hotkey-overlay { skip-at-startup; }
prefer-no-csd
screenshot-path null

gestures {
    hot-corners { off; }
}

layout {
    gaps 0
    border { off; }
    focus-ring { off; }
    background-color "#000000"
}

animations { off; }

window-rule {
    open-fullscreen true
    draw-border-with-background false
}

// Abre a tela de login; quando ela termina (login feito), fecha este Niri
// para o greetd iniciar a sua sessão.
spawn-sh-at-startup "quickshell --no-color --path $GREETER_DIR; niri msg action quit --skip-confirmation"
KDL

    if ! niri validate -c "$TMP" >/dev/null 2>&1; then
        niri validate -c "$TMP" || true
        rm -f "$TMP"
        erro "A config do Niri para a tela de login não passou no 'niri validate'; nada mudou."
        exit 1
    fi
    sudo install -D -m 0644 "$TMP" "$KDL"
    rm -f "$TMP"
    COMPOSITOR="niri -c $KDL"
else
    command -v cage >/dev/null || sudo pacman -S --needed --noconfirm cage
    azul "[*] Tela de login no cage (config do autor)..."
    COMPOSITOR="cage -d -s -m extend -- quickshell --no-color --path $GREETER_DIR"
fi

# Mesmo ambiente que o deploy-greeter.sh do autor passa ao greeter; só o compositor muda.
AMBIENTE="HOME=$RUNTIME XDG_CACHE_HOME=$RUNTIME/cache XDG_CONFIG_HOME=$RUNTIME/config XDG_DATA_HOME=$RUNTIME/data"
AMBIENTE+=" GREETD_DEFAULT_USER=$USER GREETD_SESSION_NAME=Niri"
AMBIENTE+=" GREETD_THEME_PATH=$TEMA_DIR/colors.json GREETD_BACKGROUND_PATH=$TEMA_DIR/background.json"
AMBIENTE+=" GREETD_PROFILE_PATH=$TEMA_DIR/profile.json GREETD_SETTINGS_PATH=$TEMA_DIR/settings.json"
AMBIENTE+=" SOWNTEE_CORE_BINARY=$CORE"

TMP="$(mktemp)"
cat >"$TMP" <<TOML
[terminal]
vt = 1

[default_session]
command = "env $AMBIENTE systemd-cat --identifier=sownteeshell-greeter $COMPOSITOR"
user = "greeter"
TOML
gravar_conf "$TMP"

# Pastas que o greeter usa (o deploy do autor cria; refaz caso tenham sumido).
sudo install -d -o greeter -g greeter -m 0700 "$RUNTIME" "$RUNTIME/cache" "$RUNTIME/config" "$RUNTIME/data"
sudo test -f "$TEMA_DIR/settings.json" || printf '%s\n' '{"defaultSession":"niri","rememberLastSession":false}' \
    | sudo install -o "$USER" -g greeter -m 0640 /dev/stdin "$TEMA_DIR/settings.json"
sudo usermod -aG video greeter 2>/dev/null || true
sudo systemctl enable --force greetd.service >/dev/null 2>&1

verde "[ok] Tela de login da SownteeShell no ${MODO}. Vale no próximo boot."
sudo test -f "$TEMA_DIR/colors.json" || \
    azul "     As cores e o fundo dela aparecem depois de escolher um papel de parede (Super+M)."
verde "     Se não abrir: Ctrl+Alt+F2, entre pelo terminal e rode: $0 --texto"
