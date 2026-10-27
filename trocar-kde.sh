#!/usr/bin/env bash
# Troca o KDE Plasma pela SownteeShell (Niri) de vez.
#
# Ordem pensada para você nunca ficar sem desktop:
#   1. garante o Niri instalado (se algo der errado depois, dá para entrar com `niri-session` na TTY);
#   2. protege os pacotes que a SownteeShell usa e remove o Plasma, o SDDM e os apps do KDE;
#   3. guarda as configs do KDE numa pasta de backup (não apaga nada da sua home);
#   4. roda o instalador do kit (reinstala o que faltar, compila, tema, terminal, Niri);
#   5. troca a tela de login (SownteeShell ou tuigreet) e confere a NVIDIA.
#
# Pode rodar de dentro do Plasma ou do Niri. Pode rodar de novo se parar no meio.
#
#   ./trocar-kde.sh                 pergunta as escolhas
#   ./trocar-kde.sh --manter-apps   remove o Plasma mas mantém Dolphin, Kate, Okular, Ark...
#   ./trocar-kde.sh --login-texto   tela de login em texto (tuigreet), a mais garantida na NVIDIA
#   ./trocar-kde.sh --so-login-texto  só troca a tela de login para a de texto (conserto rápido pela TTY)

set -euo pipefail

KIT="$(cd -- "$(dirname -- "$0")" && pwd)"
TS="$(date +%Y%m%d-%H%M%S)"
MANTER_APPS=""; LOGIN=""; SO_LOGIN=0
for a in "$@"; do
    case "$a" in
        --manter-apps) MANTER_APPS=1 ;;
        --login-texto) LOGIN=texto ;;
        --login-sownteeshell) LOGIN=sownteeshell ;;
        --so-login-texto) LOGIN=texto; SO_LOGIN=1; MANTER_APPS=1 ;;
        *) echo "Opção desconhecida: $a"; exit 2 ;;
    esac
done

verde() { printf '\033[32m%s\033[0m\n' "$*"; }
azul()  { printf '\033[34m%s\033[0m\n' "$*"; }
erro()  { printf '\033[31m[!] %s\033[0m\n' "$*" >&2; }
pergunta() {
    local padrao="${2:-S}" r
    if [ "$padrao" = "S" ]; then read -r -p "$1 [S/n] " r; r="${r:-s}"
    else read -r -p "$1 [s/N] " r; r="${r:-n}"; fi
    [[ "$r" =~ ^[sSyY]$ ]]
}
instalado() { pacman -Qq "$1" >/dev/null 2>&1; }

[ "$(id -u)" -eq 0 ] && { erro "Rode como seu usuário, não como root."; exit 1; }
[ -f /etc/arch-release ] || { erro "Esse script é para Arch Linux."; exit 1; }

NVIDIA=0; lspci 2>/dev/null | grep -Ei 'vga|3d|display' | grep -qi nvidia && NVIDIA=1

# ------------------------------------------------------------------ escolhas
echo
azul "Trocar o KDE Plasma pela SownteeShell (Niri)"
if [ -z "$MANTER_APPS" ]; then
    MANTER_APPS=0
    pergunta "  Manter os apps do KDE (Dolphin, Kate, Okular, Ark, Gwenview, Konsole...)? Nautilus, Loupe e Blackbox entram no lugar." N && MANTER_APPS=1
fi
if [ -z "$LOGIN" ]; then
    echo "  Tela de login:"
    echo "    1) a da SownteeShell (igual ao vídeo)"
    echo "    2) texto (tuigreet) — simples e a mais garantida na NVIDIA"
    read -r -p "  Escolha [1/2] (Enter = 1) " r
    [ "${r:-1}" = 2 ] && LOGIN=texto || LOGIN=sownteeshell
fi
echo

sudo -v
( while true; do sleep 60; sudo -n -v || exit; done ) 2>/dev/null &
SUDO_PID=$!
trap 'kill "$SUDO_PID" 2>/dev/null || true' EXIT

if [ "$SO_LOGIN" -eq 0 ]; then
# ------------------------------------------------------------------ 1. Niri primeiro
azul "[1/5] Garantindo o Niri (rede de segurança: entra com 'niri-session' na TTY)..."
sudo pacman -S --needed --noconfirm niri xwayland-satellite xdg-desktop-portal-gnome xdg-desktop-portal-gtk \
    networkmanager pipewire pipewire-pulse wireplumber polkit greetd

# ------------------------------------------------------------------ 2. remover o KDE
azul "[2/5] Procurando os pacotes do KDE Plasma..."
mapfile -t TODOS < <(pacman -Qq)
REMOVER=()
add() { for p in "$@"; do instalado "$p" && REMOVER+=("$p"); done; }

# grupos e metapacotes
mapfile -t G_PLASMA < <(pacman -Qgq plasma 2>/dev/null || true)
add plasma-meta plasma-desktop plasma "${G_PLASMA[@]}"
# peças do Plasma que às vezes vêm fora do grupo
for p in "${TODOS[@]}"; do
    case "$p" in
        plasma-*|kwin|kwin-*|kscreen|kscreenlocker|kde-gtk-config|kdeplasma-addons|kinfocenter|kmenuedit|\
        ksystemstats|kwallet-pam|kwalletmanager|powerdevil|bluedevil|discover|drkonqi|systemsettings|\
        xdg-desktop-portal-kde|polkit-kde-agent|sddm|sddm-kcm|breeze|breeze-gtk|breeze-plymouth|oxygen|oxygen-sounds|\
        milou|kactivitymanagerd|kgamma|kpipewire|ksshaskpass|libplasma|plasma5support|print-manager|spectacle|\
        flatpak-kcm|kde-cli-tools|kglobalacceld|kdeconnect|krdp|aurorae|layer-shell-qt|ocean-sound-theme|qqc2-breeze-style)
            REMOVER+=("$p") ;;
    esac
done
if [ "$MANTER_APPS" -eq 0 ]; then
    mapfile -t G_APPS < <(pacman -Qgq kde-applications 2>/dev/null || true)
    add kde-applications-meta "${G_APPS[@]}" dolphin konsole kate kwrite okular ark gwenview elisa kcalc filelight \
        partitionmanager kdialog khelpcenter konqueror kfind yakuake kolourpaint skanpage haruna
fi
mapfile -t REMOVER < <(printf '%s\n' "${REMOVER[@]}" | sort -u)

if [ "${#REMOVER[@]}" -eq 0 ]; then
    verde "[ok] Não achei pacotes do KDE Plasma; pulando a remoção."
else
    # O que a SownteeShell usa não pode sair junto como "dependência órfã".
    PROTEGER=(niri xwayland-satellite networkmanager pipewire pipewire-pulse pipewire-alsa wireplumber polkit
        greetd quickshell qt6-base qt6-declarative qt6-svg qt6-wayland qt6-multimedia qt6-multimedia-ffmpeg
        qt6-5compat qt6-imageformats qt6-positioning qt6-connectivity qt5-wayland qt6ct qt5ct qt6ct-kde qt5ct-kde
        kvantum breeze-icons xdg-desktop-portal xdg-desktop-portal-gnome xdg-desktop-portal-gtk gnome-keyring
        upower power-profiles-daemon bluez bluez-utils ffmpeg mesa vulkan-icd-loader egl-wayland
        nvidia nvidia-dkms nvidia-open nvidia-open-dkms nvidia-utils lib32-nvidia-utils libva-nvidia-driver
        noto-fonts noto-fonts-emoji ttf-dejavu sudo base-devel git)
    P=(); for p in "${PROTEGER[@]}"; do instalado "$p" && P+=("$p"); done
    sudo pacman -D --asexplicit "${P[@]}" >/dev/null

    echo
    azul "Vão sair ${#REMOVER[@]} pacotes do KDE (e as dependências que só eles usavam):"
    printf '%s\n' "${REMOVER[@]}" | column -c "$(tput cols 2>/dev/null || echo 100)"
    echo
    if ! pergunta "Remover agora?" S; then erro "Cancelado; nada foi removido."; exit 1; fi
    # -u: o que ainda for necessário para outro pacote fica (não trava a remoção inteira).
    sudo pacman -Rnsu --noconfirm "${REMOVER[@]}" || erro "Algum pacote não saiu; o resto foi removido."
    # Sobras: dependências do KDE que ficaram órfãs.
    mapfile -t ORFAOS < <(pacman -Qdtq 2>/dev/null | grep -E '^(kf6-|kf5-|kio|kirigami|kwayland|kdecoration|kglobalaccel|kpipewire|plasma|libkscreen|libksysguard|kuserfeedback|phonon|packagekit-qt)' || true)
    [ "${#ORFAOS[@]}" -gt 0 ] && { sudo pacman -Rns --noconfirm "${ORFAOS[@]}" || true; }
    verde "[ok] KDE Plasma removido"
fi

# ------------------------------------------------------------------ 3. configs do KDE para backup
azul "[3/5] Guardando as configs do KDE em ~/.kde-backup-$TS ..."
BK="$HOME/.kde-backup-$TS"
mover() { for f in "$@"; do [ -e "$f" ] || [ -L "$f" ] || continue; mkdir -p "$BK/$(dirname "${f#$HOME/}")"; mv "$f" "$BK/${f#$HOME/}"; done; }
shopt -s nullglob
mover "$HOME"/.config/{plasma*,kde*,kwin*,kscreen*,ksmserverrc,kglobalshortcutsrc,khotkeysrc,kactivitymanagerd*,\
kcminputrc,kxkbrc,krunnerrc,kded*,powermanagementprofilesrc,powerdevilrc,baloofilerc,systemsettingsrc,\
plasmashellrc,plasmarc,kwalletrc,kiorc,ktimezonedrc,breezerc,klaunchrc,kconf_updaterc,xdg-desktop-portal-kderc,\
spectaclerc,discoverrc,akonadi*,kdeconnect,autostart/org.kde.*,autostart/*plasma*}
if [ "$MANTER_APPS" -eq 0 ]; then
    mover "$HOME"/.config/{dolphinrc,konsolerc,katerc,kwriterc,okularrc,okularpartrc,arkrc,gwenviewrc,elisarc,kcalcrc}
fi
mover "$HOME"/.local/share/{plasma*,kscreen,kactivitymanagerd,baloo,kwin,kded6,kded5,konsole,dolphin,sddm,kxmlgui5}
mover "$HOME"/.cache/{plasma*,kwin,ksycoca*,krunner*,kscreen*,icon-cache.kcache}
shopt -u nullglob
[ -d "$BK" ] && verde "[ok] Backup em $BK (apague quando quiser)" || verde "[ok] Nenhuma config do KDE para guardar"

# ------------------------------------------------------------------ 4. instalador do kit
azul "[4/5] Rodando o instalador da SownteeShell (as perguntas dele vêm agora)..."
if [ "$LOGIN" = sownteeshell ]; then
    "$KIT/instalar-sownteeshell.sh" --greeter || erro "O instalador parou; rode ./instalar-sownteeshell.sh de novo depois."
else
    "$KIT/instalar-sownteeshell.sh" --sem-greeter || erro "O instalador parou; rode ./instalar-sownteeshell.sh de novo depois."
fi

fi  # SO_LOGIN

# ------------------------------------------------------------------ 5. login e NVIDIA
azul "[5/5] Tela de login e NVIDIA..."
if [ "$NVIDIA" -eq 1 ]; then
    MODESET="$(cat /sys/module/nvidia_drm/parameters/modeset 2>/dev/null || echo '?')"
    if [ "$MODESET" != Y ]; then
        printf 'options nvidia_drm modeset=1 fbdev=1\n' | sudo tee /etc/modprobe.d/nvidia-modeset.conf >/dev/null
        sudo mkinitcpio -P >/dev/null 2>&1 || erro "mkinitcpio falhou; rode 'sudo mkinitcpio -P' antes de reiniciar."
        azul "[*] NVIDIA: modeset ligado (precisa para o Niri e a tela de login); vale depois de reiniciar."
    fi
fi

DM_ATUAL=""
[ -L /etc/systemd/system/display-manager.service ] && DM_ATUAL="$(basename "$(readlink -f /etc/systemd/system/display-manager.service)")"
if [ "$LOGIN" = texto ] || [ "$DM_ATUAL" != greetd.service ]; then
    # tuigreet: escolhido, ou a tela da SownteeShell não foi instalada (sem isso não sobraria tela de login).
    [ "$LOGIN" = sownteeshell ] && erro "A tela de login da SownteeShell não ficou ativa; usando a de texto (tuigreet) por enquanto."
    sudo pacman -S --needed --noconfirm greetd-tuigreet
    sudo test -f /etc/greetd/config.toml && sudo cp /etc/greetd/config.toml "/etc/greetd/config.toml.bak-$TS"
    sudo tee /etc/greetd/config.toml >/dev/null <<'TOML'
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --asterisks --greeting 'SownteeShell' --cmd niri-session"
user = "greeter"
TOML
    for dm in sddm lightdm gdm lxdm ly; do systemctl is-enabled --quiet "$dm.service" 2>/dev/null && sudo systemctl disable "$dm.service" || true; done
    sudo systemctl enable --force greetd.service
    # Chaveiro destrava no login também pelo greetd.
    if [ -f /etc/pam.d/greetd ] && ! grep -q pam_gnome_keyring /etc/pam.d/greetd; then
        printf '%s\n' '-auth      optional     pam_gnome_keyring.so' '-session   optional     pam_gnome_keyring.so auto_start' \
            | sudo tee -a /etc/pam.d/greetd >/dev/null
    fi
fi

echo
verde "[ok] KDE Plasma trocado pela SownteeShell."
verde "     Reinicie o PC: sudo reboot"
verde "     Se a tela de login não abrir: Ctrl+Alt+F2, entre com usuário e senha e rode:"
verde "       ~/Dotfiles/sownteeshell-ptbr/trocar-kde.sh --so-login-texto   (troca para a tela de texto)"
verde "     ou só 'niri-session' para entrar direto."
