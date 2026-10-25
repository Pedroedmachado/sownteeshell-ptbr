#!/usr/bin/env bash
# Instala a SownteeShell (sownteedev/dotfiles, branch sownteeshell) em Arch + Niri,
# já traduzida para pt-BR. Feito para rodar como usuário normal, dentro da sessão do Niri.
#
#   ./instalar-sownteeshell.sh            instalação completa (pergunta antes de mexer no Niri)
#   ./instalar-sownteeshell.sh --sem-niri não mexe em ~/.config/niri (só mostra o que adicionar)
#
# Não faz: trocar seu shell para zsh, instalar teclado vietnamita (fcitx5-lotus), greetd,
# tema do GRUB, Steam/Wallpaper Engine, Tailscale/WARP, Howdy. Isso fica a seu critério.

set -euo pipefail

KIT="$(cd -- "$(dirname -- "$0")" && pwd)"
DOT="$HOME/Dotfiles"
SHELL_DIR="$DOT/sownteeshell"
DOTF_DIR="$DOT/dotf"
REPO="https://github.com/sownteedev/dotfiles.git"
SEM_NIRI=0
[ "${1:-}" = "--sem-niri" ] && SEM_NIRI=1

verde() { printf '\033[32m%s\033[0m\n' "$*"; }
azul()  { printf '\033[34m%s\033[0m\n' "$*"; }
erro()  { printf '\033[31m[!] %s\033[0m\n' "$*" >&2; }
pergunta() { local r; read -r -p "$1 [s/N] " r; [[ "$r" =~ ^[sSyY]$ ]]; }

[ "$(id -u)" -eq 0 ] && { erro "Rode como seu usuário, não como root."; exit 1; }
[ -f /etc/arch-release ] || { erro "Esse script é para Arch Linux."; exit 1; }
command -v niri >/dev/null || { erro "Niri não está instalado."; exit 1; }

if command -v paru >/dev/null; then AUR=paru
elif command -v yay >/dev/null; then AUR=yay
else erro "Instale um helper do AUR (paru ou yay) antes."; exit 1; fi
azul "[*] Usando $AUR"

# ---------------------------------------------------------------- 1. pacotes
PACOTES=(
    git base-devel rustup python python-gobject python-yaml jq pciutils
    quickshell-git qt6-base qt6-declarative qt6-connectivity qt6-multimedia qt6-positioning
    qt6-5compat qt6-imageformats qt6-avif-image-plugin qt6-wayland qt6-svg
    xwayland-satellite xdg-desktop-portal xdg-desktop-portal-gnome xdg-desktop-portal-gtk
    pipewire pipewire-pulse wireplumber networkmanager upower geoclue power-profiles-daemon
    libnotify inotify-tools libcanberra cava cliphist wl-clipboard wl-mirror wtype
    slurp hyprpicker gpu-screen-recorder ffmpeg imagemagick zbar brightnessctl ddcutil
    matugen-bin swayidle wl-gammarelay-rs pacman-contrib
    inter-font ttf-material-symbols-variable ttf-nerd-fonts-symbols noto-fonts noto-fonts-emoji
    whitesur-icon-theme adw-gtk-theme
)
if lspci -nn 2>/dev/null | grep -Ei 'vga|3d|display' | grep -qi '8086'; then
    PACOTES+=(intel-media-driver libva-intel-driver)
fi
if pergunta "Instalar OCR em português (tesseract + dados por/eng)?"; then
    PACOTES+=(tesseract tesseract-data-por tesseract-data-eng)
fi

azul "[*] Instalando pacotes (pode demorar; quickshell-git compila do AUR)..."
"$AUR" -S --needed "${PACOTES[@]}"

# Locale pt_BR para datas e meses em português.
if ! locale -a 2>/dev/null | grep -qi '^pt_BR\.utf-\?8$'; then
    if pergunta "Ativar o locale pt_BR.UTF-8 (datas em português)? Precisa de sudo."; then
        sudo sed -i 's/^#\s*\(pt_BR\.UTF-8 UTF-8\)/\1/' /etc/locale.gen
        sudo locale-gen
    fi
fi

# ---------------------------------------------------------------- 2. código
mkdir -p "$DOT"
if [ -d "$SHELL_DIR/.git" ]; then
    azul "[*] $SHELL_DIR já existe; atualizando"
    "$KIT/atualizar-sownteeshell.sh" --sem-build
else
    git clone --depth=1 --branch=sownteeshell "$REPO" "$SHELL_DIR"
    python3 "$KIT/aplicar-ptbr.py" "$SHELL_DIR"
fi
[ -d "$DOTF_DIR/.git" ] || git clone --depth=1 --branch=dotf "$REPO" "$DOTF_DIR"

# ---------------------------------------------------------------- 3. backends
azul "[*] Compilando os serviços em Rust..."
rustup default stable >/dev/null
for d in core-daemon calendar-daemon; do
    cargo build --release --locked --manifest-path "$SHELL_DIR/backend/rust/$d/Cargo.toml"
done
mkdir -p "$HOME/.local/lib/sownteeshell" "$HOME/.config/systemd/user"
install -m755 "$SHELL_DIR/backend/rust/core-daemon/target/release/sownteeshell-core" "$HOME/.local/lib/sownteeshell/"
install -m755 "$SHELL_DIR/backend/rust/calendar-daemon/target/release/sownteeshell-calendar-daemon" "$HOME/.local/lib/sownteeshell/"
install -Dm755 "$SHELL_DIR/backend/cli/sownteeshell" "$HOME/.local/bin/sownteeshell"
install -m644 "$SHELL_DIR"/backend/systemd/user/*.service "$HOME/.config/systemd/user/"
systemctl --user daemon-reload
systemctl --user enable --now sownteeshell-core.service sownteeshell-calendar.service || \
    erro "Não consegui iniciar os serviços agora; eles sobem no próximo login."

# ---------------------------------------------------------------- 4. matugen (cores)
mkdir -p "$HOME/.config" "$HOME/.cache/matugen" "$HOME/Imagens/Wallpapers/live"
if [ -e "$HOME/.config/matugen" ] && [ ! -L "$HOME/.config/matugen" ]; then
    mv "$HOME/.config/matugen" "$HOME/.config/matugen.backup-$(date +%Y%m%d-%H%M%S)"
fi
mkdir -p "$HOME/.config/matugen"
cp -r "$DOTF_DIR/.config/matugen/scripts" "$HOME/.config/matugen/" 2>/dev/null || true
cat > "$HOME/.config/matugen/config.toml" <<EOF
# Config mínima: só as cores da SownteeShell e do Niri.
# A config completa do autor (GTK, Qt, VS Code, Vesktop...) está em ~/Dotfiles/dotf/.config/matugen/config.toml
[config]
version_check = false

[templates.sownteeshell_colors]
input_path = '~/Dotfiles/dotf/.config/matugen/templates/sownteeshell/color.json'
output_path = '~/Dotfiles/sownteeshell/colors.json'

[templates.niri]
input_path = '~/Dotfiles/dotf/.config/matugen/templates/niri/colors.kdl'
output_path = '~/.cache/matugen/niri-colors.kdl'
EOF

# ---------------------------------------------------------------- 5. Niri
if [ "$SEM_NIRI" -eq 0 ] && pergunta "Trocar sua config do Niri pela estrutura da SownteeShell? (a atual vai para backup)"; then
    python3 "$KIT/configurar-niri.py" "$DOTF_DIR/.config/niri" || {
        erro "A configuração do Niri falhou; nada foi alterado. Rode de novo com --sem-niri para ver as linhas a adicionar."
    }
else
    azul "[*] Config do Niri não foi alterada. Adicione no seu config.kdl:"
    cat <<'EOF'

spawn-at-startup "sh" "-c" "exec \"$HOME/Dotfiles/sownteeshell/run-sownteeshell\""
spawn-at-startup "sh" "-c" "wl-paste --type text --watch cliphist store"
spawn-at-startup "sh" "-c" "wl-paste --type image --watch cliphist store"

binds {
    Alt+Space          { spawn-sh "quickshell ipc -p \"$HOME/Dotfiles/sownteeshell/shell.qml\" call launcher toggle"; }
    Mod+I              { spawn-sh "quickshell ipc -p \"$HOME/Dotfiles/sownteeshell/shell.qml\" call settings toggle"; }
    Mod+L              { spawn-sh "quickshell ipc -p \"$HOME/Dotfiles/sownteeshell/shell.qml\" call lockscreen lock"; }
    Mod+M              { spawn-sh "quickshell ipc -p \"$HOME/Dotfiles/sownteeshell/shell.qml\" call wallpaper toggle"; }
    Mod+Shift+S        { spawn-sh "quickshell ipc -p \"$HOME/Dotfiles/sownteeshell/shell.qml\" call capture screenshot"; }
    Mod+Shift+R        { spawn-sh "quickshell ipc -p \"$HOME/Dotfiles/sownteeshell/shell.qml\" call capture toggleRecording"; }
    Ctrl+Alt+R         { spawn-sh "killall quickshell; \"$HOME/Dotfiles/sownteeshell/run-sownteeshell\" -d"; }
}
EOF
fi

verde ""
verde "[ok] SownteeShell instalada em $SHELL_DIR"
verde "     Feche sua barra/notificações atuais e rode: $SHELL_DIR/run-sownteeshell"
verde "     Ou saia e entre de novo no Niri."
