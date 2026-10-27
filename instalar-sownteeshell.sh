#!/usr/bin/env bash
# Instala (ou conserta) a SownteeShell completa — todas as funções do vídeo do autor —
# em Arch Linux + Niri, num PC de mesa, já em pt-BR.
#
# Pode rodar de novo quando quiser: só instala o que falta e refaz os ajustes.
#
#   ./instalar-sownteeshell.sh             pergunta antes de cada parte opcional
#   ./instalar-sownteeshell.sh --sim       responde "sim" para tudo (inclusive greeter)
#   ./instalar-sownteeshell.sh --sem-niri  não mexe na config do Niri
#
# No fim roda ./verificar-sownteeshell.sh, que mostra função por função o que está ok.

set -euo pipefail

KIT="$(cd -- "$(dirname -- "$0")" && pwd)"
DOT="$HOME/Dotfiles"
SHELL_DIR="$DOT/sownteeshell"
DOTF_DIR="$DOT/dotf"
REPO="https://github.com/sownteedev/dotfiles.git"
WALLS="$HOME/Imagens/Wallpapers"
SIM_TUDO=0
SEM_NIRI=0
for a in "$@"; do
    case "$a" in
        --sim) SIM_TUDO=1 ;;
        --sem-niri) SEM_NIRI=1 ;;
        *) echo "Opção desconhecida: $a"; exit 2 ;;
    esac
done

verde() { printf '\033[32m%s\033[0m\n' "$*"; }
azul()  { printf '\033[34m%s\033[0m\n' "$*"; }
erro()  { printf '\033[31m[!] %s\033[0m\n' "$*" >&2; }
# pergunta "texto" [S|N]  — o segundo argumento é a resposta padrão (Enter)
pergunta() {
    local padrao="${2:-S}" r
    if [ "$SIM_TUDO" -eq 1 ]; then return 0; fi
    if [ "$padrao" = "S" ]; then read -r -p "$1 [S/n] " r; r="${r:-s}"
    else read -r -p "$1 [s/N] " r; r="${r:-n}"; fi
    [[ "$r" =~ ^[sSyY]$ ]]
}
instalado() { pacman -Qq "$1" >/dev/null 2>&1; }
tem() { command -v "$1" >/dev/null 2>&1; }

[ "$(id -u)" -eq 0 ] && { erro "Rode como seu usuário, não como root."; exit 1; }
[ -f /etc/arch-release ] || { erro "Esse script é para Arch Linux."; exit 1; }

# O paru/yay precisa funcionar com o pacman atual (um paru-bin antigo quebra com "libalpm.so.N").
compilar_paru() {
    azul "[*] Compilando o paru para a versão atual do pacman (uns 5 minutos)..."
    sudo pacman -Syu --needed --noconfirm git base-devel rust
    rm -rf /tmp/paru-src && git clone https://aur.archlinux.org/paru.git /tmp/paru-src
    for v in paru-bin paru-bin-debug; do pacman -Qq "$v" >/dev/null 2>&1 && sudo pacman -Rdd --noconfirm "$v"; done
    (cd /tmp/paru-src && makepkg -si --noconfirm)
}
AUR=""
if tem paru && paru --version >/dev/null 2>&1; then AUR=paru
elif tem yay && yay --version >/dev/null 2>&1; then AUR=yay
else
    compilar_paru
    paru --version >/dev/null 2>&1 || { erro "Não consegui instalar um paru funcionando."; exit 1; }
    AUR=paru
fi
azul "[*] Usando $AUR"

sudo -v
( while true; do sleep 60; sudo -n -v || exit; done ) 2>/dev/null &
SUDO_PID=$!
trap 'kill "$SUDO_PID" 2>/dev/null || true' EXIT

# ------------------------------------------------------------------ hardware
GPU="$(lspci -nn 2>/dev/null | grep -Ei 'vga|3d|display' || true)"
NVIDIA=0; INTEL=0
grep -qi nvidia <<<"$GPU" && NVIDIA=1
grep -qi '8086' <<<"$GPU" && INTEL=1
CAMERA=0; ls /dev/video* >/dev/null 2>&1 && CAMERA=1
BLUETOOTH=0; [ -d /sys/class/bluetooth ] && ls /sys/class/bluetooth/ 2>/dev/null | grep -q . && BLUETOOTH=1
azul "[*] NVIDIA: $NVIDIA · Intel: $INTEL · Webcam: $CAMERA · Bluetooth: $BLUETOOTH"

# ------------------------------------------------------------------ escolhas
echo
azul "Funções opcionais do vídeo (Enter = resposta em maiúscula):"
Q_WE=0; Q_CONTAS=0; Q_TAIL=0; Q_WARP=0; Q_HOWDY=0; Q_SUN=0; Q_GREET=0; Q_TEMA=0; Q_TERM=0; Q_ZSH=0; Q_NIRI=0
pergunta "  Papéis de parede animados do Wallpaper Engine + Steam Workshop (precisa ter o Wallpaper Engine na Steam)?" S && Q_WE=1
pergunta "  Login no Wallhaven/Steam dentro das Configurações (coleções, inscrições)?" S && Q_CONTAS=1
pergunta "  Botão do Tailscale nos controles rápidos?" S && Q_TAIL=1
pergunta "  Botão do Cloudflare WARP nos controles rápidos?" S && Q_WARP=1
if [ "$CAMERA" -eq 1 ]; then
    pergunta "  Desbloqueio por rosto (Howdy) com a webcam? Compila por ~15 min." N && Q_HOWDY=1
fi
pergunta "  Sunshine (streaming do PC para outros aparelhos)?" N && Q_SUN=1
if [ "$SIM_TUDO" -eq 1 ]; then
    azul "  (--sim não troca a tela de login; rode sem --sim para escolher)"
else
    pergunta "  Tela de login da SownteeShell (greetd) no lugar da atual? Troca o gerenciador de login." N && Q_GREET=1
fi
pergunta "  Tema do autor em apps GTK/Qt (cores do papel de parede, ícones WhiteSur, cursor, fonte SF Pro)?" S && Q_TEMA=1
pergunta "  Terminal do vídeo (Blackbox com as cores do papel de parede, fonte GeistMono, Super+Enter)?" S && Q_TERM=1
if [ "$Q_TERM" -eq 1 ]; then
    if [ "$SIM_TUDO" -eq 1 ]; then Q_ZSH=1
    else pergunta "    Usar o zsh do autor como shell padrão (prompt, autocompletar, eza/bat/fzf)?" S && Q_ZSH=1; fi
fi
if [ "$SEM_NIRI" -eq 0 ]; then
    pergunta "  Ajustar a config do Niri (necessário para as opções do Niri e da Tela funcionarem)?" S && Q_NIRI=1
fi
echo

# ------------------------------------------------------------------ 1. pacotes
PACOTES=(
    git base-devel python python-gobject python-yaml jq pciutils rsync
    qt6-base qt6-declarative qt6-svg qt6-wayland qt6-connectivity qt6-multimedia qt6-multimedia-ffmpeg
    qt6-positioning qt6-5compat qt6-imageformats qt6-avif-image-plugin qt5-wayland
    niri xwayland-satellite xdg-desktop-portal xdg-desktop-portal-gnome xdg-desktop-portal-gtk xdg-utils
    pipewire pipewire-pulse pipewire-alsa wireplumber libpulse
    networkmanager upower power-profiles-daemon polkit geoclue
    libnotify inotify-tools libcanberra cava cliphist wl-clipboard wl-mirror wtype slurp hyprpicker
    gpu-screen-recorder ffmpeg imagemagick zbar qrencode ddcutil brightnessctl
    swayidle wl-gammarelay-rs pacman-contrib
    gnome-keyring libsecret gcr-4 seahorse
    tesseract tesseract-data-por tesseract-data-eng
    inter-font otf-geist-mono-nerd noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra
    ttf-material-symbols-variable ttf-nerd-fonts-symbols ttf-dejavu ttf-rubik-vf
    whitesur-icon-theme adw-gtk-theme breeze-icons
    nautilus loupe
)
# provedores alternativos já instalados contam
tem quickshell || PACOTES+=(quickshell)
tem matugen || PACOTES+=(matugen-bin)
tem cargo || PACOTES+=(rustup)
[ "$BLUETOOTH" -eq 1 ] && PACOTES+=(bluez bluez-utils)
[ "$INTEL" -eq 1 ] && PACOTES+=(intel-media-driver libva-intel-driver)
[ "$NVIDIA" -eq 1 ] && PACOTES+=(libva-nvidia-driver egl-wayland)
if [ "$Q_TEMA" -eq 1 ]; then
    PACOTES+=(kvantum kvantum-qt5)
    instalado qt6ct || PACOTES+=(qt6ct-kde)
    instalado qt5ct || PACOTES+=(qt5ct-kde)
fi
if [ "$Q_TERM" -eq 1 ]; then
    PACOTES+=(blackbox-terminal)
    [ "$Q_ZSH" -eq 1 ] && PACOTES+=(zsh eza bat fzf chafa)
elif ! tem kitty && ! tem ghostty && ! tem alacritty && ! tem foot && ! tem wezterm && ! tem konsole; then
    PACOTES+=(blackbox-terminal)
fi
# Extras: cada grupo instala separado; se um falhar (build do AUR quebrado), o resto continua.
declare -A EXTRAS=()
[ "$Q_WE" -eq 1 ] && EXTRAS[WE]="steam steamcmd linux-wallpaperengine-git"
[ "$Q_CONTAS" -eq 1 ] && EXTRAS[CONTAS]="pyside6 qt6-webengine"
[ "$Q_TAIL" -eq 1 ] && EXTRAS[TAIL]="tailscale"
[ "$Q_WARP" -eq 1 ] && EXTRAS[WARP]="cloudflare-warp-bin"
[ "$Q_HOWDY" -eq 1 ] && EXTRAS[HOWDY]="howdy-git v4l-utils"
[ "$Q_SUN" -eq 1 ] && EXTRAS[SUN]="sunshine-bin"
[ "$Q_GREET" -eq 1 ] && EXTRAS[GREET]="greetd cage"

# Steam precisa do repositório multilib.
if [ "$Q_WE" -eq 1 ] && ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    azul "[*] Ativando o repositório multilib (necessário para a Steam)..."
    sudo cp /etc/pacman.conf "/etc/pacman.conf.bak-$(date +%Y%m%d-%H%M%S)"
    sudo sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
    sudo pacman -Syu
fi

FALTANDO=()
for p in "${PACOTES[@]}"; do
    instalado "$p" && continue
    if pacman -Si "$p" >/dev/null 2>&1 || "$AUR" -Si "$p" >/dev/null 2>&1; then FALTANDO+=("$p")
    else erro "Pacote '$p' não existe nos repositórios/AUR; pulando (o verificador mostra o que ficou faltando)."; fi
done
if [ "${#FALTANDO[@]}" -gt 0 ]; then
    azul "[*] Instalando ${#FALTANDO[@]} pacotes (os do AUR compilam; pode demorar)..."
    "$AUR" -S --needed "${FALTANDO[@]}" || erro "Algum pacote falhou; continuando. Rode o instalador de novo depois."
else
    verde "[ok] Pacotes já instalados"
fi
for g in "${!EXTRAS[@]}"; do
    read -r -a grupo <<<"${EXTRAS[$g]}"
    falta=(); for p in "${grupo[@]}"; do instalado "$p" || falta+=("$p"); done
    [ "${#falta[@]}" -eq 0 ] && continue
    azul "[*] Instalando extra: ${falta[*]}"
    "$AUR" -S --needed "${falta[@]}" || erro "Falhou: ${falta[*]} (o resto continua)."
done
if [ "$Q_TEMA" -eq 1 ] && ! instalado apple-fonts; then
    azul "[*] Instalando a fonte SF Pro (apple-fonts)..."
    "$AUR" -S --needed --mflags --skipinteg apple-fonts || erro "apple-fonts falhou; a interface usa Inter no lugar."
fi
# Sem isso o pacman pode remover essas libs junto com algum app (foi o que aconteceu ao tirar o KDE).
PROTEGER=()
for p in qt6-base qt6-declarative qt6-svg qt6-wayland qt6-multimedia qt6-multimedia-ffmpeg qt6-5compat \
    qt6-imageformats qt6-positioning qt6-connectivity xdg-desktop-portal-gnome xdg-desktop-portal-gtk gnome-keyring; do
    instalado "$p" && PROTEGER+=("$p")
done
[ "${#PROTEGER[@]}" -gt 0 ] && { sudo pacman -D --asexplicit "${PROTEGER[@]}" >/dev/null || true; }

# ------------------------------------------------------------------ 2. código
mkdir -p "$DOT"
[ -d "$DOTF_DIR/.git" ] || git clone --depth=1 --branch=dotf "$REPO" "$DOTF_DIR"
if [ -d "$SHELL_DIR/.git" ]; then
    azul "[*] Atualizando $SHELL_DIR e reaplicando o pt-BR..."
    "$KIT/atualizar-sownteeshell.sh" --sem-build
else
    git clone --depth=1 --branch=sownteeshell "$REPO" "$SHELL_DIR"
    python3 "$KIT/aplicar-ptbr.py" "$SHELL_DIR"
fi

# ------------------------------------------------------------------ 3. serviços da SownteeShell
azul "[*] Compilando os serviços em Rust e o plugin de imagens..."
if tem rustup; then rustup default >/dev/null 2>&1 || rustup default stable; fi
for d in core-daemon calendar-daemon; do
    CARGO_TARGET_DIR="$SHELL_DIR/backend/rust/$d/target" \
        cargo build --release --locked --manifest-path "$SHELL_DIR/backend/rust/$d/Cargo.toml"
done
"$SHELL_DIR/plugin/imagecache/build-imagecache"
LIBDIR="$HOME/.local/lib/sownteeshell"
mkdir -p "$LIBDIR" "$HOME/.config/systemd/user"
install -m755 "$SHELL_DIR/backend/rust/core-daemon/target/release/sownteeshell-core" "$LIBDIR/sownteeshell-core.new"
mv -f "$LIBDIR/sownteeshell-core.new" "$LIBDIR/sownteeshell-core"
install -m755 "$SHELL_DIR/backend/rust/calendar-daemon/target/release/sownteeshell-calendar-daemon" "$LIBDIR/sownteeshell-calendar-daemon.new"
mv -f "$LIBDIR/sownteeshell-calendar-daemon.new" "$LIBDIR/sownteeshell-calendar-daemon"
install -Dm755 "$SHELL_DIR/backend/cli/sownteeshell" "$HOME/.local/bin/sownteeshell"
APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
ICONS="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/scalable/apps"
for f in "$SHELL_DIR"/assets/applications/*.desktop; do install -Dm644 "$f" "$APPS/$(basename "$f")"; done
for f in "$SHELL_DIR"/assets/icons/sownteeshell-*.svg; do [ -f "$f" ] && install -Dm644 "$f" "$ICONS/$(basename "$f")"; done
install -m644 "$SHELL_DIR"/backend/systemd/user/*.service "$HOME/.config/systemd/user/"

# ~/.local/bin no PATH da sessão (os atalhos "SownteeShell Configurações/Agenda" usam o comando sownteeshell).
mkdir -p "$HOME/.config/environment.d"
printf 'PATH=$HOME/.local/bin:$PATH\n' > "$HOME/.config/environment.d/10-sownteeshell-path.conf"

systemctl --user daemon-reload
systemctl --user enable sownteeshell-core.service sownteeshell-calendar.service >/dev/null
if systemctl --user show-environment 2>/dev/null | grep -q WAYLAND_DISPLAY; then
    systemctl --user reset-failed sownteeshell-core.service sownteeshell-calendar.service 2>/dev/null || true
    systemctl --user restart sownteeshell-core.service sownteeshell-calendar.service || erro "Os serviços não subiram agora; sobem no próximo login."
fi

# ------------------------------------------------------------------ 4. cores (Matugen)
# A SownteeShell usa ~/Dotfiles/dotf/.config/matugen/config.toml direto. Os "post_hook" do autor
# chamam programas que você pode não ter (Steam Adwaita, VS Code...): sem isso a troca de cor falha.
python3 - "$DOTF_DIR/.config/matugen/config.toml" <<'PY'
import re, sys, os
p = sys.argv[1]
t = open(p, encoding="utf-8").read()
t = t.replace("post_hook =  'adwaita-steam-gtk -i'", "post_hook = 'command -v adwaita-steam-gtk >/dev/null && adwaita-steam-gtk -i || true'")
def guard(m):
    cmd = m.group(1)
    return m.group(0) if cmd.rstrip().endswith("|| true") else f"post_hook = '{cmd} || true'"
t = re.sub(r"post_hook\s*=\s*'([^']*)'", guard, t)
open(p, "w", encoding="utf-8").write(t)
PY
[ -e "$HOME/.config/matugen" ] && [ ! -L "$HOME/.config/matugen" ] && mv "$HOME/.config/matugen" "$HOME/.config/matugen.backup-$(date +%Y%m%d-%H%M%S)"
ln -sfn "$DOTF_DIR/.config/matugen" "$HOME/.config/matugen"

# ------------------------------------------------------------------ 5. tema GTK/Qt/ícones/cursor/fontes
ligar() {  # ligar origem destino  (guarda o que existia)
    local src="$1" dst="$2"
    [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ] && return 0
    if [ -e "$dst" ] || [ -L "$dst" ]; then mv "$dst" "$dst.backup-$(date +%Y%m%d-%H%M%S)"; fi
    mkdir -p "$(dirname "$dst")"; ln -s "$src" "$dst"
}
if [ "$Q_TEMA" -eq 1 ]; then
    azul "[*] Aplicando o tema do autor..."
    ligar "$DOTF_DIR/.fonts" "$HOME/.fonts"
    ligar "$DOTF_DIR/.icons" "$HOME/.icons"
    ligar "$DOTF_DIR/.config/fontconfig" "$HOME/.config/fontconfig"
    mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"
    G3="$HOME/.config/gtk-3.0/settings.ini"
    [ -f "$G3" ] && [ ! -L "$G3" ] && [ ! -f "$G3.antes-sownteeshell" ] && cp "$G3" "$G3.antes-sownteeshell"
    cp -f "$DOTF_DIR/.config/gtk-3.0/settings.ini" "$G3"
    ligar "$DOTF_DIR/.config/gtk-3.0/gtk.css" "$HOME/.config/gtk-3.0/gtk.css"
    ligar "$DOTF_DIR/.config/gtk-4.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"
    ligar "$DOTF_DIR/.config/gtk-4.0/gtk.css" "$HOME/.config/gtk-4.0/gtk.css"
    [ -d /usr/share/themes/adw-gtk3/gtk-4.0/assets ] && ligar /usr/share/themes/adw-gtk3/gtk-4.0/assets "$HOME/.config/gtk-4.0/assets"
    ligar "$DOTF_DIR/.config/qt5ct" "$HOME/.config/qt5ct"
    ligar "$DOTF_DIR/.config/qt6ct" "$HOME/.config/qt6ct"
    ligar "$DOTF_DIR/.config/Kvantum" "$HOME/.config/Kvantum"
    mkdir -p "$HOME/.config/qt5ct/colors" "$HOME/.config/qt6ct/colors"
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' || true
    gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark' || true
    gsettings set org.gnome.desktop.interface icon-theme 'WhiteSur' || true
    gsettings set org.gnome.desktop.interface cursor-theme 'Dark_Cursor' || true
    gsettings set org.gnome.desktop.interface cursor-size 24 || true
    if fc-list | grep -qi 'SF Pro Text'; then
        gsettings set org.gnome.desktop.interface font-name 'SF Pro Text 10.5' || true
    fi
    gsettings set org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close' || true
    # Cursor também nos apps X11 (Steam etc.)
    mkdir -p "$HOME/.icons/default"
    printf '[Icon Theme]\nInherits=Dark_Cursor\n' > "$HOME/.icons/default/index.theme"
    fc-cache -f >/dev/null 2>&1 || true
fi

# ------------------------------------------------------------------ 5b. terminal
if [ "$Q_TERM" -eq 1 ] && tem blackbox-terminal; then
    azul "[*] Configurando o Blackbox como no vídeo..."
    mkdir -p "$HOME/.local/share/blackbox/schemes"
    B=com.raggesilver.BlackBox
    gsettings set $B cursor-shape 1 || true
    gsettings set $B easy-copy-paste true || true
    gsettings set $B font 'GeistMono Nerd Font 11' || true
    gsettings set $B pretty true || true
    gsettings set $B style-preference 0 || true
    gsettings set $B terminal-cell-height 1.25 || true
    gsettings set $B terminal-padding '(uint32 30, uint32 30, uint32 30, uint32 30)' || true
    gsettings set $B theme-bold-is-bright true || true
    gsettings set $B theme-dark 'Custom' || true
    gsettings set $B theme-light 'Custom' || true
    # Terminal padrão das Configurações da SownteeShell
    SET="${XDG_CACHE_HOME:-$HOME/.cache}/sownteeshell/settings.json"
    if [ -f "$SET" ]; then
        python3 -c 'import json,sys; p=sys.argv[1]; d=json.load(open(p)); d["defaultTerminal"]="blackbox-terminal"; json.dump(d,open(p,"w"),indent=4)' "$SET" || true
    fi
fi
if [ "$Q_ZSH" -eq 1 ] && tem zsh; then
    ligar "$DOTF_DIR/.config/zsh" "$HOME/.config/zsh"
    grep -qF 'source "$HOME/.config/zsh/.zshrc"' "$HOME/.zshrc" 2>/dev/null || \
        printf '%s\n' 'source "$HOME/.config/zsh/.zshrc"' >> "$HOME/.zshrc"
    if [ "$(getent passwd "$USER" | cut -d: -f7)" != /usr/bin/zsh ]; then
        sudo chsh -s /usr/bin/zsh "$USER" && azul "[*] zsh virou o shell padrão (vale no próximo terminal). Voltar: sudo chsh -s /bin/bash $USER"
    fi
fi

# Pastas onde o Matugen grava as cores (GTK, Qt, Kvantum, Vesktop...) precisam existir.
python3 - "$DOTF_DIR/.config/matugen/config.toml" <<'PY'
import os, re, sys
t = open(sys.argv[1], encoding="utf-8").read()
for out in re.findall(r"output_path\s*=\s*['\"]([^'\"]+)['\"]", t):
    os.makedirs(os.path.dirname(os.path.expanduser(out)), exist_ok=True)
PY

# ------------------------------------------------------------------ 6. papéis de parede
mkdir -p "$WALLS/live"
if [ -z "$(find "$WALLS" -maxdepth 1 -type f -print -quit)" ]; then
    azul "[*] Copiando os papéis de parede do autor para $WALLS"
    cp -rn "$DOTF_DIR/.walls/." "$WALLS/" 2>/dev/null || true
fi
# Se as configurações salvas apontam para uma pasta que não existe, volta para ~/Imagens/Wallpapers.
SETTINGS="${XDG_CACHE_HOME:-$HOME/.cache}/sownteeshell/settings.json"
if [ -f "$SETTINGS" ]; then
    python3 - "$SETTINGS" "$WALLS" <<'PY'
import json, os, sys
p, walls = sys.argv[1], sys.argv[2]
try:
    d = json.load(open(p))
except Exception:
    sys.exit(0)
mudou = False
for k, padrao in (("wallFolderPath", walls), ("liveWallFolderPath", walls + "/live")):
    v = d.get(k)
    if isinstance(v, str) and v and not os.path.isdir(os.path.expanduser(v)):
        d[k] = padrao.replace(os.path.expanduser("~"), "~", 1); mudou = True
if mudou:
    json.dump(d, open(p, "w"), indent=4)
    print("[*] Pasta de papéis de parede corrigida nas configurações salvas")
PY
fi

# ------------------------------------------------------------------ 7. sistema
azul "[*] Ajustes do sistema..."
# Brilho de monitor externo (DDC/CI)
getent group i2c >/dev/null || sudo groupadd --system i2c
printf 'i2c-dev\n' | sudo tee /etc/modules-load.d/ddcutil.conf >/dev/null
printf '%s\n' 'KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0660"' | sudo tee /etc/udev/rules.d/70-ddcutil-i2c.rules >/dev/null
id -nG "$USER" | tr ' ' '\n' | grep -qx i2c || sudo usermod -aG i2c "$USER"
sudo modprobe i2c-dev || true
sudo udevadm control --reload-rules && sudo udevadm trigger --subsystem-match=i2c-dev || true
[ "$CAMERA" -eq 1 ] && { id -nG "$USER" | tr ' ' '\n' | grep -qx video || sudo usermod -aG video "$USER"; }

OUTRA_REDE=""
for u in systemd-networkd.service iwd.service dhcpcd.service connman.service; do
    systemctl is-active --quiet "$u" 2>/dev/null && OUTRA_REDE="$u"
done
if [ -z "$OUTRA_REDE" ]; then
    sudo systemctl enable --now NetworkManager.service >/dev/null 2>&1 || true
else
    azul "[*] Rede gerenciada por $OUTRA_REDE; NetworkManager não foi ativado (o painel de Wi-Fi/rede fica limitado)."
fi
sudo systemctl enable --now power-profiles-daemon.service >/dev/null 2>&1 || true
[ "$BLUETOOTH" -eq 1 ] && sudo systemctl enable --now bluetooth.service >/dev/null 2>&1 || true

# NVIDIA: evita o Niri/Quickshell segurarem centenas de MB de VRAM (recomendação da wiki do Niri).
if [ "$NVIDIA" -eq 1 ]; then
    sudo install -d /etc/nvidia/nvidia-application-profiles-rc.d
    sudo tee /etc/nvidia/nvidia-application-profiles-rc.d/50-sownteeshell-wayland.json >/dev/null <<'JSON'
{
    "rules": [
        { "pattern": { "feature": "procname", "matches": "niri" }, "profile": "Limit Free Buffer Pool On Wayland Compositors" },
        { "pattern": { "feature": "procname", "matches": "quickshell" }, "profile": "Limit Free Buffer Pool On Wayland Compositors" }
    ],
    "profiles": [
        { "name": "Limit Free Buffer Pool On Wayland Compositors", "settings": [ { "key": "GLVidHeapReuseRatio", "value": 0 } ] }
    ]
}
JSON
fi

# Datas em português
if ! locale -a 2>/dev/null | grep -qi '^pt_BR\.utf-\?8$'; then
    sudo sed -i 's/^#\s*\(pt_BR\.UTF-8 UTF-8\)/\1/' /etc/locale.gen
    sudo locale-gen >/dev/null
fi

# Chaveiro (Agenda Google/Microsoft guarda as contas nele): destrava no login.
DM_UNIT=""
[ -L /etc/systemd/system/display-manager.service ] && DM_UNIT="$(readlink -f /etc/systemd/system/display-manager.service)"
DM_UNIT="${DM_UNIT##*/}"; DM_PAM="${DM_UNIT%.service}"
[ "$Q_GREET" -eq 1 ] && DM_PAM=greetd
[ -z "$DM_PAM" ] && DM_PAM=login
if [ -f "/etc/pam.d/$DM_PAM" ] && ! grep -q pam_gnome_keyring "/etc/pam.d/$DM_PAM"; then
    sudo cp "/etc/pam.d/$DM_PAM" "/etc/pam.d/$DM_PAM.bak-sownteeshell"
    printf '%s\n' '-auth      optional     pam_gnome_keyring.so' '-session   optional     pam_gnome_keyring.so auto_start' \
        | sudo tee -a "/etc/pam.d/$DM_PAM" >/dev/null
    azul "[*] Chaveiro adicionado ao login ($DM_PAM)"
fi

# ------------------------------------------------------------------ 8. funções opcionais
if [ "$Q_WE" -eq 1 ]; then
    mkdir -p "$HOME/.local/share/Steam/steamapps/workshop/content/431960"
    [ -d "$HOME/.local/share/Steam/steamapps/common/wallpaper_engine/assets" ] || \
        azul "[*] Wallpaper Engine: abra a Steam, entre na conta e instale o Wallpaper Engine uma vez (Proton) para baixar os assets."
fi
if [ "$Q_TAIL" -eq 1 ]; then
    sudo systemctl enable --now tailscaled.service >/dev/null 2>&1 || true
    sudo tailscale set --operator="$USER" 2>/dev/null || azul "[*] Tailscale: rode 'sudo tailscale up' uma vez para entrar na conta."
fi
if [ "$Q_WARP" -eq 1 ]; then
    sudo systemctl enable --now warp-svc.service >/dev/null 2>&1 || true
    sleep 2
    warp-cli --accept-tos registration show >/dev/null 2>&1 || warp-cli --accept-tos registration new >/dev/null 2>&1 || \
        azul "[*] WARP: rode 'warp-cli registration new' depois."
fi
if [ "$Q_HOWDY" -eq 1 ] && tem howdy; then
    sudo install -Dm755 "$SHELL_DIR/backend/python/auth/howdy_face_manager.py" /usr/lib/sownteeshell/howdy-face-manager
    [ -f /etc/pam.d/quickshell ] && sudo /usr/lib/sownteeshell/howdy-face-manager migrate-pam || true
    azul "[*] Howdy: cadastre o rosto em Configurações → Bloqueio e rosto."
fi
if [ "$Q_SUN" -eq 1 ]; then
    systemctl --user daemon-reload
    for u in app-dev.lizardbyte.app.Sunshine.service sunshine.service; do
        systemctl --user cat "$u" >/dev/null 2>&1 && { systemctl --user enable --now "$u" >/dev/null 2>&1 || true; break; }
    done
fi
if [ "$Q_GREET" -eq 1 ]; then
    azul "[*] Instalando a tela de login (greetd)..."
    getent passwd greeter >/dev/null || sudo systemd-sysusers /usr/lib/sysusers.d/greetd.conf
    sudo usermod -aG video greeter 2>/dev/null || true
    sudo install -D -m 0755 "$SHELL_DIR/backend/rust/core-daemon/target/release/sownteeshell-core" /usr/lib/sownteeshell/sownteeshell-core
    sudo test -f /etc/greetd/config.toml && ! sudo test -f /etc/greetd/config.toml.antes-sownteeshell && \
        sudo cp /etc/greetd/config.toml /etc/greetd/config.toml.antes-sownteeshell
    sudo "$SHELL_DIR/scripts/system/deploy-greeter.sh" --privileged "$USER"
    TD=/var/lib/sownteeshell/greeter
    sudo test -f "$TD/settings.json" || printf '%s\n' '{"defaultSession":"niri","rememberLastSession":false}' \
        | sudo install -o "$USER" -g greeter -m 0640 /dev/stdin "$TD/settings.json"
    ATUAL=""
    [ -L /etc/systemd/system/display-manager.service ] && ATUAL="$(readlink -f /etc/systemd/system/display-manager.service)" && ATUAL="${ATUAL##*/}"
    if [ -n "$ATUAL" ] && [ "$ATUAL" != greetd.service ]; then
        printf '%s\n' "$ATUAL" | sudo tee /var/lib/sownteeshell/dm-anterior >/dev/null
        sudo systemctl disable "$ATUAL" || true
    fi
    ANTERIOR="$(cat /var/lib/sownteeshell/dm-anterior 2>/dev/null || true)"
    sudo systemctl enable --force greetd.service
    verde "[ok] Tela de login instalada; aparece no próximo boot."
    [ -n "$ANTERIOR" ] && verde "     Para voltar à anterior: sudo systemctl enable --force $ANTERIOR"
    verde "     Se a tela de login não abrir: Ctrl+Alt+F2, entre pelo terminal e rode o comando acima."
fi

# ------------------------------------------------------------------ 9. Niri
if [ "$Q_NIRI" -eq 1 ]; then
    python3 "$KIT/configurar-niri.py" "$DOTF_DIR" || erro "Config do Niri não foi alterada (veja a mensagem acima)."
fi

# ------------------------------------------------------------------ 9b. primeiras cores
# Sem isso Qt/Kvantum/Blackbox ficam sem tema até trocar o papel de parede pela primeira vez.
if [ ! -f "$SHELL_DIR/colors.json" ] && tem matugen; then
    azul "[*] Gerando as cores iniciais a partir do papel de parede padrão..."
    "$DOTF_DIR/.config/matugen/scripts/prepare-gtk-runtime.sh" >/dev/null 2>&1 || true
    "$SHELL_DIR/scripts/theme/matugen-wallpaper-theme.sh" --config "$DOTF_DIR/.config/matugen/config.toml" \
        --mode dark --quiet "$DOTF_DIR/.walls/flower-plant-petal.jpg" >/dev/null 2>&1 || \
        erro "Não gerou as cores agora; escolha um papel de parede em Super+M."
fi

# ------------------------------------------------------------------ 10. conferência
echo
"$KIT/verificar-sownteeshell.sh" || true
echo
verde "[ok] Pronto. Saia da sessão e entre de novo (precisa para os grupos i2c/vídeo e o PATH)."
verde "     Depois: Super+I → Integrações para as chaves de clima (OpenWeather) e GIFs (KLIPY)."
