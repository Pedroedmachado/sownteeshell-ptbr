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
#   ./configurar-greeter.sh --monitor DP-3      escolhe o monitor da tela de senha no Niri
#   ./configurar-greeter.sh --todos-monitores   deixa todos ligados (o cartão vai no primeiro)
#
# Com mais de um monitor, a tela de senha do autor só aceita digitação no primeiro que o
# compositor anuncia, que nem sempre é o principal. Por isso, no Niri, só o monitor
# principal fica ligado na tela de login: o mais à esquerda na sua sessão atual do Niri,
# no mesmo modo (resolução e Hz). Rode o script de dentro da sessão para ele achar.

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
MONITOR=""        # "" = automático; "*" = todos
while [ $# -gt 0 ]; do
    case "$1" in
        --cage|--desfazer) MODO=cage ;;
        --texto) MODO=texto ;;
        --monitor) MONITOR="${2:-}"; shift; [ -n "$MONITOR" ] || { erro "Faltou o nome: --monitor DP-3"; exit 1; } ;;
        --todos-monitores) MONITOR="*" ;;
        *) erro "Opção desconhecida: $1 (use --cage, --texto, --monitor NOME ou --todos-monitores)"; exit 1 ;;
    esac
    shift
done

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

    # Monitores: só o principal fica ligado (veja o topo do arquivo).
    MONITORES=""
    SAIDAS=""
    if [ "$MONITOR" != "*" ] && command -v jq >/dev/null; then
        SAIDAS="$(niri msg -j outputs 2>/dev/null | jq -r '.[] | select(.logical != null)
            | [.name, .logical.x, .logical.y, (.modes[.current_mode] // {} | "\(.width)x\(.height)@\(.refresh_rate)")] | @tsv' 2>/dev/null || true)"
    fi
    if [ "$MONITOR" = "*" ]; then
        azul "[*] Tela de login em todos os monitores."
    elif [ -z "$SAIDAS" ]; then
        [ -n "$MONITOR" ] && { erro "Rode de dentro da sessão do Niri para usar --monitor."; exit 1; }
        azul "[*] Fora da sessão do Niri: não sei qual é o monitor principal; deixo todos ligados."
    elif [ "$(wc -l <<<"$SAIDAS")" -gt 1 ] || [ -n "$MONITOR" ]; then
        if [ -z "$MONITOR" ]; then
            MONITOR="$(sort -t$'\t' -k2,2n -k3,3n <<<"$SAIDAS" | head -n1 | cut -f1)"
        elif ! cut -f1 <<<"$SAIDAS" | grep -qxF "$MONITOR"; then
            erro "Monitor $MONITOR não existe. Os que existem: $(cut -f1 <<<"$SAIDAS" | paste -sd' ')"
            exit 1
        fi
        while IFS=$'\t' read -r nome _ _ modo; do
            if [ "$nome" = "$MONITOR" ]; then
                # refresh_rate vem em mHz: 144001 -> 144.001
                hz="${modo##*@}"; modo="${modo%@*}"
                MONITORES+="output \"$nome\" {"$'\n'
                [[ "$hz" =~ ^[0-9]+$ ]] && MONITORES+="    mode \"$modo@$((hz / 1000)).$(printf '%03d' $((hz % 1000)))\""$'\n'
                MONITORES+="    position x=0 y=0"$'\n'"    focus-at-startup"$'\n'"}"$'\n'
            else
                MONITORES+="output \"$nome\" { off; }"$'\n'
            fi
        done <<<"$SAIDAS"
        azul "[*] Tela de senha só no monitor $MONITOR (os outros ficam desligados no login)."
    fi

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

$MONITORES
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
// para o greetd iniciar a sua sessão. A saída vai para o journal:
//   journalctl -b -t sownteeshell-greeter-qs
spawn-sh-at-startup "quickshell --no-color --path $GREETER_DIR 2>&1 | systemd-cat -t sownteeshell-greeter-qs; niri msg action quit --skip-confirmation"
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
