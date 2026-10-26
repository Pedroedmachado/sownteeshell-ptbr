#!/usr/bin/env bash
# Confere, função por função, se tudo que aparece no vídeo da SownteeShell tem o que precisa.
# Não muda nada no sistema. Rode dentro da sessão do Niri:
#   ~/Dotfiles/sownteeshell-ptbr/verificar-sownteeshell.sh
# Cada linha com ✗ traz o comando que resolve. "–" é opcional/informativo.

DOT="$HOME/Dotfiles"
SHELL_DIR="$DOT/sownteeshell"
DOTF_DIR="$DOT/dotf"
SETTINGS="${XDG_CACHE_HOME:-$HOME/.cache}/sownteeshell/settings.json"
OK=0; FALHA=0; OPC=0

ok()    { printf '  \033[32m✓\033[0m %s\n' "$1"; OK=$((OK + 1)); }
falha() { printf '  \033[31m✗\033[0m %s\n      → %s\n' "$1" "$2"; FALHA=$((FALHA + 1)); }
opc()   { printf '  \033[33m–\033[0m %s\n      → %s\n' "$1" "$2"; OPC=$((OPC + 1)); }
secao() { printf '\n\033[1m%s\033[0m\n' "$1"; }
tem() { command -v "$1" >/dev/null 2>&1; }
pkg() { pacman -Qq "$1" >/dev/null 2>&1; }
ativo_user() { systemctl --user is-active --quiet "$1" 2>/dev/null; }
ativo_sys() { systemctl is-active --quiet "$1" 2>/dev/null; }
cfg() {  # valor de uma chave do settings.json
    [ -f "$SETTINGS" ] || return 0
    python3 -c 'import json,sys; v=json.load(open(sys.argv[1])).get(sys.argv[2],""); print(v if isinstance(v,str) else json.dumps(v))' "$SETTINGS" "$1" 2>/dev/null
}
precisa() {  # precisa "descrição" comando pacote
    if tem "$2"; then ok "$1"; else falha "$1 (falta $2)" "paru -S $3"; fi
}
KIT_CMD="~/Dotfiles/sownteeshell-ptbr/instalar-sownteeshell.sh"

# ------------------------------------------------------------------
secao "Base"
precisa "Quickshell" quickshell quickshell
precisa "Niri" niri niri
if [ -f "$SHELL_DIR/shell.qml" ]; then ok "SownteeShell em $SHELL_DIR"; else falha "SownteeShell não está em $SHELL_DIR" "$KIT_CMD"; fi
if [ -f "$SHELL_DIR/.ptbr-aplicado" ]; then ok "Tradução pt-BR aplicada"; else falha "Tradução não aplicada" "~/Dotfiles/sownteeshell-ptbr/atualizar-sownteeshell.sh"; fi
if pgrep -af quickshell 2>/dev/null | grep -q sownteeshell; then ok "Shell rodando"; else falha "Shell não está rodando" "Ctrl+Alt+R ou $SHELL_DIR/run-sownteeshell -d"; fi
for s in sownteeshell-core sownteeshell-calendar; do
    if ativo_user "$s.service"; then ok "Serviço $s ativo"
    else falha "Serviço $s parado" "systemctl --user enable --now $s.service; journalctl --user -u $s -n 30"; fi
done
if [ -s "$SHELL_DIR/plugin/imagecache/qml/Native/ImageCache/libnativeimagecacheplugin.so" ]; then ok "Plugin de cache de imagens compilado"
else falha "Plugin de imagens não compilado (miniaturas)" "$SHELL_DIR/plugin/imagecache/build-imagecache"; fi
if tem sownteeshell; then ok "Comando sownteeshell no PATH (atalhos Configurações/Agenda)"
else falha "~/.local/bin fora do PATH (atalhos SownteeShell Configurações/Agenda não abrem)" "$KIT_CMD e entrar de novo na sessão"; fi
if pkg xdg-desktop-portal-gnome; then ok "Portal GNOME (captura de tela de apps, seletor de arquivos)"
else falha "Falta xdg-desktop-portal-gnome" "paru -S xdg-desktop-portal-gnome"; fi
for outro in waybar mako dunst swaync fnott swaybg hyprpaper swaylock; do
    pgrep -x "$outro" >/dev/null 2>&1 && falha "$outro está rodando e briga com a SownteeShell" "tire o $outro do autostart do Niri e: pkill $outro"
done

# ------------------------------------------------------------------
secao "Config do Niri (Configurações → Niri, Atalhos, Layout, Tela)"
NIRI_DOTF="$DOTF_DIR/.config/niri"
if [ -L "$HOME/.config/niri" ] && [ "$(readlink -f "$HOME/.config/niri")" = "$(readlink -f "$NIRI_DOTF")" ]; then
    ok "~/.config/niri aponta para $NIRI_DOTF (as opções do painel fazem efeito)"
else
    falha "~/.config/niri não é o link para $NIRI_DOTF — as opções do Niri e da Tela no painel não fazem nada" "python3 ~/Dotfiles/sownteeshell-ptbr/configurar-niri.py"
fi
if [ -f "$NIRI_DOTF/config.kdl" ] && niri validate -c "$NIRI_DOTF/config.kdl" >/dev/null 2>&1; then ok "Config do Niri válida"
else falha "Config do Niri com erro" "niri validate -c $NIRI_DOTF/config.kdl"; fi
if grep -q 'California Institute of Technology' "$NIRI_DOTF/include/outputs.kdl" 2>/dev/null; then
    falha "Monitores ainda são os do notebook do autor" "python3 ~/Dotfiles/sownteeshell-ptbr/configurar-niri.py"
else ok "Monitores configurados para este PC"; fi
if grep -Eq '^\s*layout\s+"' "$NIRI_DOTF/include/input.kdl" 2>/dev/null; then ok "Layout de teclado definido ($(grep -Eo '^\s*layout\s+"[^"]+"' "$NIRI_DOTF/include/input.kdl" | head -1 | cut -d'"' -f2))"
else falha "Teclado no padrão americano (sem layout)" "python3 ~/Dotfiles/sownteeshell-ptbr/configurar-niri.py"; fi
if grep -Eq '^\s*[^/]*fcitx' "$NIRI_DOTF/include/autostart.kdl" "$NIRI_DOTF/include/environment.kdl" 2>/dev/null; then
    falha "Teclado vietnamita (fcitx5) ainda ativo" "python3 ~/Dotfiles/sownteeshell-ptbr/configurar-niri.py"
else ok "Sem fcitx5 (teclado vietnamita)"; fi
if grep -Eq '^\s*DISPLAY\s+":1"' "$NIRI_DOTF/include/environment.kdl" 2>/dev/null; then
    falha "DISPLAY fixo em :1 (apps X11 como a Steam podem não abrir)" "python3 ~/Dotfiles/sownteeshell-ptbr/configurar-niri.py"
else ok "DISPLAY do Xwayland automático"; fi
TERM_BIND="$(grep -Eo 'Mod\+Return[^{]*\{ *spawn "[^"]+"' "$NIRI_DOTF/include/keybinds.kdl" 2>/dev/null | grep -Eo '"[^"]+"$' | tr -d '"')"
if [ -n "$TERM_BIND" ] && tem "$TERM_BIND"; then ok "Super+Enter abre $TERM_BIND"
else falha "Super+Enter chama '${TERM_BIND:-?}', que não está instalado" "python3 ~/Dotfiles/sownteeshell-ptbr/configurar-niri.py"; fi
FM_BIND="$(grep -Eo 'Mod\+E\s[^{]*\{ *spawn "[^"]+"' "$NIRI_DOTF/include/keybinds.kdl" 2>/dev/null | grep -Eo '"[^"]+"$' | tr -d '"')"
if [ -n "$FM_BIND" ] && tem "$FM_BIND"; then ok "Super+E abre $FM_BIND"
else falha "Super+E chama '${FM_BIND:-?}', que não está instalado" "paru -S nautilus"; fi
if pgrep -af 'wl-paste.*cliphist' >/dev/null 2>&1; then ok "Histórico da área de transferência gravando"
else falha "cliphist não está gravando (prefixo c no inicializador fica vazio)" "confira os spawn-at-startup de wl-paste em include/autostart.kdl e entre de novo"; fi
if pgrep -f niri-floating-daemon >/dev/null 2>&1; then ok "Daemon de janelas flutuantes por área de trabalho"
else falha "Daemon de flutuantes parado (Super+Shift+V)" "confira o spawn-at-startup do niri-floating-daemon.py e entre de novo"; fi

# ------------------------------------------------------------------
secao "Barra e painel direito"
if ativo_sys NetworkManager.service && tem nmcli; then ok "Wi-Fi/Ethernet (NetworkManager)"
else falha "NetworkManager parado" "sudo systemctl enable --now NetworkManager"; fi
if [ -d /sys/class/bluetooth ] && ls /sys/class/bluetooth | grep -q .; then
    if ativo_sys bluetooth.service && tem bluetoothctl; then ok "Bluetooth"
    else falha "Bluetooth parado ou sem bluetoothctl" "paru -S bluez bluez-utils && sudo systemctl enable --now bluetooth"; fi
else opc "Bluetooth: este PC não tem adaptador (o botão fica indisponível)" "normal em desktop sem Bluetooth"; fi
if ativo_user pipewire-pulse.service || ativo_user pipewire-pulse.socket; then ok "Áudio (PipeWire)"; else falha "pipewire-pulse parado" "paru -S pipewire-pulse wireplumber"; fi
precisa "Controle de volume pelas teclas (pactl)" pactl libpulse
precisa "Visualizador de áudio (Cava)" cava cava
if ativo_sys power-profiles-daemon.service; then ok "Modos de energia"; else falha "power-profiles-daemon parado" "paru -S power-profiles-daemon && sudo systemctl enable --now power-profiles-daemon"; fi
precisa "Luz noturna" wl-gammarelay-rs wl-gammarelay-rs
precisa "Inatividade / bloqueio automático" swayidle swayidle
precisa "Atualizações de pacotes" checkupdates pacman-contrib
if tem paru || tem yay; then ok "Atualizações do AUR ($(tem paru && echo paru || echo yay))"; else falha "Sem paru/yay" "instale o paru"; fi
precisa "QR code para compartilhar Wi-Fi" qrencode qrencode
if tem ddcutil; then
    if id -nG | tr ' ' '\n' | grep -qx i2c; then
        n="$(timeout 20 ddcutil detect --brief 2>/dev/null | grep -c '^Display')"
        if [ "${n:-0}" -gt 0 ]; then ok "Brilho dos monitores por DDC/CI ($n monitor(es))"
        else opc "Nenhum monitor respondeu ao DDC/CI (brilho no painel fica indisponível)" "ative DDC/CI no menu do monitor; TVs costumam não ter"; fi
    elif getent group i2c | grep -qw "$USER"; then falha "Grupo i2c ainda não vale nesta sessão" "saia e entre de novo"
    else falha "Sem acesso ao DDC/CI" "$KIT_CMD"; fi
else falha "Brilho de monitor externo (falta ddcutil)" "paru -S ddcutil"; fi
if tem tailscale; then
    if ativo_sys tailscaled.service; then
        if tailscale status >/dev/null 2>&1; then ok "Tailscale"; else opc "Tailscale instalado mas sem login" "sudo tailscale up && sudo tailscale set --operator=$USER"; fi
    else falha "tailscaled parado" "sudo systemctl enable --now tailscaled"; fi
else opc "Botão do Tailscale sem o Tailscale" "paru -S tailscale (ou rode o instalador e responda s)"; fi
if tem warp-cli; then
    if ativo_sys warp-svc.service; then
        if warp-cli --accept-tos registration show >/dev/null 2>&1; then ok "Cloudflare WARP"; else falha "WARP sem registro" "warp-cli --accept-tos registration new"; fi
    else falha "warp-svc parado" "sudo systemctl enable --now warp-svc"; fi
else opc "Botão do WARP sem o WARP" "paru -S cloudflare-warp-bin"; fi

# ------------------------------------------------------------------
secao "Painel esquerdo (clima, música, sistema, timer)"
if [ -n "$(cfg apiWeather)" ]; then ok "Chave do OpenWeather configurada"
else opc "Clima sem chave do OpenWeather" "crie grátis em openweathermap.org/api e cole em Super+I → Integrações → Clima"; fi
if [ -n "$(cfg latLon)" ]; then ok "Localização do clima: $(cfg latLon)"
else opc "Localização do clima vazia" "Super+I → Integrações → Detectar localização (ou digite lat,lon, ex.: -23.55,-46.63)"; fi
[ -x /usr/lib/geoclue-2.0/demos/agent ] && ok "GeoClue (detectar localização)" || falha "GeoClue sem o agente" "paru -S geoclue"
if python3 -c 'import yaml' 2>/dev/null; then ok "Letras sincronizadas (python-yaml)"; else falha "Falta python-yaml (letras)" "paru -S python-yaml"; fi
if tem nvidia-smi || ls /sys/class/drm/card*/device/gpu_busy_percent >/dev/null 2>&1; then ok "Gráfico de GPU"; else opc "Uso de GPU indisponível" "normal sem nvidia-smi/amdgpu"; fi

# ------------------------------------------------------------------
secao "Inicializador (Alt+Espaço)"
precisa "Colar direto (wtype)" wtype wtype
if [ -n "$(cfg launcherKlipyApiKey)" ]; then ok "GIFs e figurinhas (KLIPY)"
else opc "Prefixos g/s (GIFs e figurinhas) sem chave KLIPY" "pegue a chave em klipy.com e cole em Super+I → Integrações → KLIPY"; fi
if tem flatpak; then ok "Desinstalar apps Flatpak pelo inicializador"; else opc "Flatpak não instalado" "opcional: paru -S flatpak"; fi

# ------------------------------------------------------------------
secao "Captura (Super+Shift+S / Super+Shift+R)"
precisa "Seleção de região" slurp slurp
precisa "Conta-gotas de cor" hyprpicker hyprpicker
precisa "Área de transferência" wl-copy wl-clipboard
precisa "Imagens (ImageMagick)" magick imagemagick
precisa "Leitor de QR code" zbarimg zbar
precisa "Google Lens (abre o navegador)" xdg-open xdg-utils
if tem gpu-screen-recorder; then
    if getcap /usr/bin/gsr-kms-server 2>/dev/null | grep -q cap_sys_admin; then ok "Gravação de tela (gpu-screen-recorder)"
    else falha "gsr-kms-server sem permissão (gravação de tela pede senha ou falha)" "sudo setcap cap_sys_admin+ep /usr/bin/gsr-kms-server"; fi
else falha "Gravação de tela (falta gpu-screen-recorder)" "paru -S gpu-screen-recorder"; fi
if tem tesseract; then
    langs="$(tesseract --list-langs 2>/dev/null)"
    if grep -qx por <<<"$langs" && grep -qx eng <<<"$langs"; then ok "OCR português + inglês"
    else falha "OCR sem português/inglês" "paru -S tesseract-data-por tesseract-data-eng"; fi
else falha "OCR (falta tesseract)" "paru -S tesseract tesseract-data-por tesseract-data-eng"; fi

# ------------------------------------------------------------------
secao "Papéis de parede e cores (Super+M)"
precisa "Cores do Material You (Matugen)" matugen matugen-bin
precisa "Vídeos e miniaturas (ffmpeg)" ffprobe ffmpeg
if pkg qt6-multimedia-ffmpeg; then ok "Papel de parede em vídeo (Qt Multimedia FFmpeg)"; else falha "Falta o backend de vídeo do Qt" "paru -S qt6-multimedia-ffmpeg"; fi
WF="$(cfg wallFolderPath)"; WF="${WF:-~/Imagens/Wallpapers}"; WFX="${WF/#\~/$HOME}"
if [ -d "$WFX" ] && [ -n "$(find "$WFX" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \) -print -quit)" ]; then
    ok "Pasta de papéis de parede com imagens ($WF)"
else falha "Pasta de papéis de parede vazia ou inexistente ($WF) — o seletor fica vazio" "$KIT_CMD (copia os do autor) ou mude em Super+I → Papéis de parede"; fi
MC="$DOTF_DIR/.config/matugen/config.toml"
if [ -f "$MC" ]; then
    if grep -E "post_hook" "$MC" | grep -vq '|| true'; then falha "Ganchos do Matugen sem proteção (troca de cor pode falhar)" "$KIT_CMD"
    else ok "Config do Matugen pronta"; fi
else falha "Falta $MC" "$KIT_CMD"; fi
if [ -f "$SHELL_DIR/colors.json" ]; then ok "Paleta gerada (colors.json)"; else opc "Paleta ainda não gerada" "escolha um papel de parede em Super+M"; fi
if tem linux-wallpaperengine; then
    ok "Wallpaper Engine (renderizador)"
    precisa "  Steam" steam steam
    precisa "  Downloads do Workshop (steamcmd)" steamcmd steamcmd
    if [ -d "$HOME/.local/share/Steam/steamapps/common/wallpaper_engine/assets" ]; then ok "  Assets do Wallpaper Engine"
    else falha "  Assets do Wallpaper Engine não baixados (cenas não abrem)" "Steam → instale o Wallpaper Engine (Propriedades → Compatibilidade → Proton) uma vez"; fi
    [ -n "$(cfg steamUsername)" ] && ok "  Usuário da Steam configurado" || opc "  Usuário da Steam vazio" "Super+I → Integrações → Steam"
else opc "Wallpaper Engine não instalado (abas Workshop ficam vazias)" "paru -S linux-wallpaperengine-git steam steamcmd"; fi
if python3 -c 'import PySide6.QtWebEngineWidgets' 2>/dev/null; then ok "Login no Wallhaven/Steam (SownteeShell Connect)"
else opc "Login no Wallhaven/Steam indisponível" "paru -S pyside6 qt6-webengine"; fi

# ------------------------------------------------------------------
secao "Agenda (Google, Microsoft, iCloud)"
if busctl --user list 2>/dev/null | grep -q 'org.freedesktop.secrets'; then ok "Chaveiro (Secret Service) disponível"
else falha "Sem chaveiro — adicionar conta na Agenda falha" "paru -S gnome-keyring libsecret gcr-4 e entre de novo"; fi
if pgrep -x gnome-keyring-d >/dev/null 2>&1 || pgrep -f gnome-keyring-daemon >/dev/null 2>&1; then ok "gnome-keyring rodando"
else opc "gnome-keyring não está rodando agora" "inicia sozinho quando a Agenda pedir; se não, confira o autostart do Niri"; fi
opc "Google Agenda/Tarefas pede o seu próprio ID de cliente OAuth" "veja a seção 'Agenda Google' no README do kit"

# ------------------------------------------------------------------
secao "Bloqueio, rosto e login"
if [ -f /etc/pam.d/login ]; then ok "Senha na tela de bloqueio (PAM)"; else falha "Falta /etc/pam.d/login" "paru -S pambase"; fi
if tem howdy; then
    [ -x /usr/lib/sownteeshell/howdy-face-manager ] && ok "Desbloqueio por rosto (Howdy)" || falha "Howdy sem a ponte das Configurações" "$KIT_CMD"
else
    if ls /dev/video* >/dev/null 2>&1; then opc "Desbloqueio por rosto não instalado" "rode o instalador e responda s no Howdy"
    else opc "Desbloqueio por rosto: sem webcam" "precisa de uma webcam (de preferência IR)"; fi
fi
DM=""; [ -L /etc/systemd/system/display-manager.service ] && { DM="$(readlink -f /etc/systemd/system/display-manager.service)"; DM="${DM##*/}"; }
if [ "$DM" = greetd.service ] && [ -f /usr/share/sownteeshell/greeter/shell.qml ]; then ok "Tela de login da SownteeShell (greetd)"
else opc "Tela de login atual: ${DM:-nenhuma (TTY)}" "para usar a do vídeo: rode o instalador e responda s em 'Tela de login'"; fi

# ------------------------------------------------------------------
secao "Aparência e sistema"
fc-list 2>/dev/null | grep -qi 'Material Symbols Rounded' && ok "Ícones Material Symbols" || falha "Falta a fonte de ícones (aparecem quadrados)" "paru -S ttf-material-symbols-variable"
fc-list 2>/dev/null | grep -qi 'Inter' && ok "Fonte Inter" || falha "Falta a fonte Inter" "paru -S inter-font"
fc-list 2>/dev/null | grep -qi 'SF Pro' && ok "Fonte SF Pro (igual ao vídeo)" || opc "Sem SF Pro (usa outra fonte)" "paru -S --mflags --skipinteg apple-fonts"
{ [ -d /usr/share/icons/WhiteSur ] || [ -d "$HOME/.local/share/icons/WhiteSur" ]; } && ok "Ícones WhiteSur" || falha "Falta o tema de ícones WhiteSur (ícones genéricos)" "paru -S whitesur-icon-theme"
locale -a 2>/dev/null | grep -qi '^pt_BR\.utf-\?8$' && ok "Locale pt_BR (datas em português)" || falha "Locale pt_BR desativado" "sudo sed -i 's/^#pt_BR.UTF-8/pt_BR.UTF-8/' /etc/locale.gen && sudo locale-gen"
if lspci 2>/dev/null | grep -Ei 'vga|3d' | grep -qi nvidia; then
    [ -f /etc/nvidia/nvidia-application-profiles-rc.d/50-sownteeshell-wayland.json ] && ok "NVIDIA: perfil de VRAM para Niri/Quickshell" || falha "NVIDIA sem o perfil de VRAM do Niri" "$KIT_CMD"
    pkg libva-nvidia-driver && ok "NVIDIA: decodificação de vídeo por hardware (VA-API)" || opc "NVIDIA sem VA-API" "paru -S libva-nvidia-driver"
fi

# ------------------------------------------------------------------
secao "Terminal, cursor e tema dos apps"
if tem blackbox-terminal; then
    ok "Terminal Blackbox"
    [ "$(gsettings get com.raggesilver.BlackBox theme-dark 2>/dev/null)" = "'Custom'" ] && ok "  Blackbox usando as cores do papel de parede" || \
        falha "  Blackbox sem o tema Custom" "$KIT_CMD (responda s no terminal)"
    [ -f "$HOME/.local/share/blackbox/schemes/custom.json" ] && ok "  Esquema de cores do Blackbox gerado" || \
        falha "  Esquema do Blackbox não gerado" "escolha um papel de parede em Super+M"
else opc "Blackbox (terminal do vídeo) não instalado" "rode o instalador e responda s em 'Terminal do vídeo'"; fi
fc-list 2>/dev/null | grep -qi 'GeistMono Nerd' && ok "Fonte GeistMono Nerd (terminal)" || falha "Falta a fonte do terminal" "paru -S otf-geist-mono-nerd"
if [ "$(getent passwd "$USER" | cut -d: -f7)" = /usr/bin/zsh ]; then
    [ -e "$HOME/.config/zsh/.zshrc" ] && ok "zsh do autor" || falha "zsh sem a config do autor" "$KIT_CMD"
else opc "Shell padrão não é o zsh do vídeo" "opcional: rode o instalador e responda s no zsh"; fi
CUR="$(grep -Eo 'xcursor-theme\s+"[^"]+"' "$DOTF_DIR/.config/niri/include/cursor.kdl" 2>/dev/null | cut -d'"' -f2)"
if [ -n "$CUR" ] && { [ -d "$HOME/.icons/$CUR" ] || [ -d "/usr/share/icons/$CUR" ] || [ -d "$HOME/.local/share/icons/$CUR" ]; }; then
    ok "Cursor $CUR no Niri"
else falha "Cursor '${CUR:-?}' do Niri não está instalado (aparece o cursor padrão)" "$KIT_CMD (responda s no tema)"; fi
[ "$(gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null)" = "'${CUR:-Dark_Cursor}'" ] && ok "Cursor nos apps GTK" || \
    falha "Cursor dos apps GTK diferente do Niri" "gsettings set org.gnome.desktop.interface cursor-theme '${CUR:-Dark_Cursor}'"
grep -qs "Inherits=${CUR:-Dark_Cursor}" "$HOME/.icons/default/index.theme" && ok "Cursor nos apps X11 (Steam)" || \
    falha "Apps X11 com cursor padrão" "$KIT_CMD"
[ -f "$HOME/.config/Kvantum/matugen/matugen.kvconfig" ] && ok "Tema Qt (Kvantum) com as cores do papel de parede" || \
    falha "Tema Qt ainda não gerado" "escolha um papel de parede em Super+M"
[ -f "$HOME/.config/gtk-4.0/colors.css" ] && ok "Tema GTK com as cores do papel de parede" || \
    falha "Cores GTK ainda não geradas" "escolha um papel de parede em Super+M"

# ------------------------------------------------------------------
printf '\n\033[1mResumo:\033[0m \033[32m%d ok\033[0m · \033[31m%d com problema\033[0m · \033[33m%d opcionais/avisos\033[0m\n' "$OK" "$FALHA" "$OPC"
[ "$FALHA" -eq 0 ]
