#!/usr/bin/env bash
# Faz a tela de login da SownteeShell rodar dentro do Niri em vez do cage.
#
# Por quê: o greeter do autor roda no `cage` (wlroots). Na NVIDIA o cage desenha a tela
# toda bugada (faixas, imagem deslocada, campo de senha sem aparecer). O Niri já funciona
# bem na sua placa, então o greeter passa a usar um Niri mínimo, sem atalhos, que fecha
# sozinho depois do login.
#
# Pode rodar quantas vezes quiser. O instalador e o atualizador chamam este script
# sempre que reinstalam a tela de login.
#
#   ./configurar-greeter.sh            aplica
#   ./configurar-greeter.sh --desfazer volta para o cage (config do autor)

set -euo pipefail

CONF=/etc/greetd/config.toml
KDL=/etc/sownteeshell/greeter-niri.kdl
GREETER_DIR=/usr/share/sownteeshell/greeter

azul()  { printf '\033[34m%s\033[0m\n' "$*"; }
verde() { printf '\033[32m%s\033[0m\n' "$*"; }
erro()  { printf '\033[31m[!] %s\033[0m\n' "$*" >&2; }

if [ "${1:-}" = --desfazer ]; then
    sudo sed -i "s#niri -c $KDL#cage -d -s -m extend -- quickshell --no-color --path $GREETER_DIR#" "$CONF"
    verde "[ok] Tela de login voltou para o cage."
    exit 0
fi

sudo test -f "$CONF" || { erro "Não achei $CONF; instale a tela de login primeiro."; exit 1; }
if ! sudo grep -q "quickshell --no-color --path $GREETER_DIR\|niri -c $KDL" "$CONF"; then
    erro "$CONF não é a tela de login da SownteeShell; nada mudou."
    exit 1
fi

# Layout do teclado da tela de senha: o mesmo do sistema (ABNT2 se não houver).
LAYOUT="$(localectl status 2>/dev/null | awk -F': *' '/X11 Layout/{print $2; exit}')"
VARIANTE="$(localectl status 2>/dev/null | awk -F': *' '/X11 Variant/{print $2; exit}')"
LAYOUT="${LAYOUT:-br}"

azul "[*] Tela de login: trocando o cage pelo Niri (teclado: $LAYOUT${VARIANTE:+ / $VARIANTE})..."
TMP="$(mktemp)"
cat >"$TMP" <<KDL
// Niri só para a tela de login da SownteeShell (gerado por configurar-greeter.sh).
// Sem atalhos: não dá para abrir nada além da tela de senha.

input {
    keyboard {
        xkb {
            layout "$LAYOUT"
            ${VARIANTE:+variant "$VARIANTE"}
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

sudo cp -n "$CONF" "$CONF.antes-niri" 2>/dev/null || true
sudo sed -i "s#cage -d -s -m extend -- quickshell --no-color --path $GREETER_DIR#niri -c $KDL#" "$CONF"
sudo grep -q "niri -c $KDL" "$CONF" || { erro "Não consegui trocar o comando em $CONF."; exit 1; }

verde "[ok] Tela de login agora roda no Niri. Vale no próximo boot (ou: sudo systemctl restart greetd)."
