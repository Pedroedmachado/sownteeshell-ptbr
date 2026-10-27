# SownteeShell em pt-BR para Arch + Niri (desktop)

Kit para deixar o Arch igual ao vídeo da [SownteeShell](https://github.com/sownteedev/dotfiles/tree/sownteeshell), traduzida para português e ajustada para PC de mesa (NVIDIA, sem bateria, monitor externo, teclado ABNT2).

## Trocar o KDE Plasma pela SownteeShell

Se o Arch está com o KDE Plasma, este comando faz a troca completa (pode rodar de dentro do próprio Plasma):

```bash
git clone https://github.com/Pedroedmachado/sownteeshell-ptbr.git ~/Dotfiles/sownteeshell-ptbr 2>/dev/null || git -C ~/Dotfiles/sownteeshell-ptbr pull
~/Dotfiles/sownteeshell-ptbr/trocar-kde.sh
```

Na ordem: instala o Niri, remove o Plasma, o SDDM e (se quiser) os apps do KDE sem levar junto o que a SownteeShell usa, guarda as configs do KDE em `~/.kde-backup-<data>`, roda o instalador abaixo e põe a tela de login (a da SownteeShell ou a de texto `tuigreet`). Na NVIDIA também liga o `modeset`. No fim, reinicie.

Se a tela de login não abrir: **Ctrl+Alt+F2**, entre com usuário e senha e rode `~/Dotfiles/sownteeshell-ptbr/trocar-kde.sh --so-login-texto` (ou só `niri-session`).

## Instalar ou consertar

Dentro da sessão do Niri, num terminal:

```bash
git clone https://github.com/Pedroedmachado/sownteeshell-ptbr.git ~/Dotfiles/sownteeshell-ptbr 2>/dev/null || git -C ~/Dotfiles/sownteeshell-ptbr pull
~/Dotfiles/sownteeshell-ptbr/instalar-sownteeshell.sh
```

Serve para instalar do zero **e** para consertar uma instalação que já existe (feita com o instalador do autor ou com a versão antiga deste kit). Ele pergunta no começo quais extras você quer (Enter aceita a opção em maiúscula). No fim mostra a conferência e pede para **sair e entrar de novo** na sessão.

## Conferir o que está funcionando

```bash
~/Dotfiles/sownteeshell-ptbr/verificar-sownteeshell.sh
```

Mostra cada função do vídeo com ✓, ✗ (com o comando que resolve) ou – (opcional). Não muda nada no sistema.

## O que estava quebrado e foi corrigido

| Problema | Causa | Correção |
|---|---|---|
| Opções do Niri, Atalhos, Layout, Entrada, Animações, Regras e **Tela** não faziam nada | O painel edita `~/Dotfiles/dotf/.config/niri`, mas o kit antigo copiava a config para `~/.config/niri` | `~/.config/niri` agora é um link para a pasta do dotf; os ajustes do PC são feitos lá |
| Seletor de papel de parede vazio | A tradução mudou a pasta para `~/Imagens/Wallpapers`, que ficava vazia | O instalador copia os papéis de parede do autor para lá e corrige a configuração salva |
| Adicionar conta na Agenda falhava | Faltava chaveiro (Secret Service); o do KDE saiu junto com o Plasma | Instala o gnome-keyring e destrava no login |
| Troca de cores travando às vezes | Ganchos do Matugen chamam programas do autor (Steam Adwaita, VS Code) | Ganchos protegidos com `|| true` |
| Botões Tailscale, WARP, Wallpaper Engine, Workshop, login Wallhaven/Steam, rosto | Pacotes e serviços opcionais não instalados | O instalador pergunta e instala cada um |
| Steam e apps X11 sem abrir | `DISPLAY ":1"` fixo na config do autor | Removido; o Niri define sozinho |
| Teclado americano, fcitx5 vietnamita | Config do notebook do autor | Layout ABNT2 (ou o seu), sem fcitx5 |
| Super+Enter / Super+E sem abrir nada | Apontavam para `blackbox-terminal` e `nautilus` | Apontam para os que você tem; o Nautilus é instalado |
| Atalhos "SownteeShell Configurações/Agenda" sem abrir | `~/.local/bin` fora do PATH da sessão | Adicionado em `~/.config/environment.d` |
| Dias da previsão em inglês | Lista fixa no código | Dom, Seg, Ter… |
| Eventos do Outlook somem | Fuso de Brasília não estava no mapa da Microsoft | Adicionados os fusos do Brasil |
| Uso alto de VRAM na NVIDIA | Problema conhecido do driver com compositores | Perfil da NVIDIA para Niri e Quickshell |

## Extras que o instalador pergunta

- **Wallpaper Engine + Workshop**: instala Steam, steamcmd e linux-wallpaperengine. Você precisa ter o Wallpaper Engine na sua conta Steam e instalá-lo uma vez pela Steam (com Proton) para baixar os assets.
- **Login no Wallhaven/Steam**: pyside6 + qt6-webengine, para coleções e inscrições dentro das Configurações.
- **Tailscale** e **Cloudflare WARP**: botões dos controles rápidos. No Tailscale, rode `sudo tailscale up` uma vez.
- **Desbloqueio por rosto (Howdy)**: só aparece se houver webcam. Compila por um tempo.
- **Sunshine**: streaming do PC.
- **Tela de login da SownteeShell (greetd)**: troca o gerenciador de login atual. Roda num Niri mínimo (o `cage` do autor fica bugado na NVIDIA), com o mesmo teclado do sistema. Para voltar: `sudo systemctl enable --force sddm` (ou o que você usava).

  Para trocar só a tela de login depois, sem reinstalar nada:

  ```bash
  ./configurar-greeter.sh           # SownteeShell no Niri
  ./configurar-greeter.sh --cage    # SownteeShell no cage (igual ao autor)
  ./configurar-greeter.sh --texto   # texto (tuigreet)
  ```

  Com mais de um monitor, a tela de senha fica só no principal (o mais à esquerda na sua sessão do Niri, no mesmo modo e Hz) e os outros ficam desligados durante o login. Rode o script de dentro da sessão para ele achar o monitor. Para escolher outro: `./configurar-greeter.sh --monitor HDMI-A-2` (nomes em `niri msg outputs`); para ligar todos: `--todos-monitores`.

  Se a tela de login der problema, o log dela fica em `journalctl -b -t sownteeshell-greeter-qs`.

  As cores e o fundo da tela de login aparecem depois de escolher um papel de parede (Super+M).
- **Tema do autor nos apps** (GTK/Qt, ícones WhiteSur, cursor, fonte SF Pro).
- **Terminal do vídeo**: Blackbox com as cores do papel de parede, fonte GeistMono, espaçamento do autor, aberto no Super+Enter e como terminal padrão das Configurações. Opcionalmente o **zsh do autor** (prompt, autocompletar, eza/bat/fzf); para voltar: `sudo chsh -s /bin/bash $USER`.

Também no instalador: cursor Dark_Cursor no Niri, nos apps GTK e nos apps X11 (Steam); papéis de parede do autor em `~/Imagens/Wallpapers`; e geração das cores na primeira instalação, para GTK, Qt/Kvantum e o terminal já abrirem com o tema.

## Depois de instalar

Em **Super+I → Integrações**:
- **Clima**: chave grátis em openweathermap.org (API → "Current weather" e "5 day forecast") e *Detectar localização* (ou digite, ex.: `-23.55,-46.63`).
- **KLIPY**: chave para GIFs (`g`) e figurinhas (`s`) no inicializador.
- **Wallhaven / Steam**: usuário e chave, se quiser coleções e Workshop.

### Agenda Google

A Agenda pede **o seu próprio** ID de cliente OAuth (o autor não distribui o dele):

1. Abra console.cloud.google.com, crie um projeto.
2. *APIs e serviços → Biblioteca*: ative **Google Calendar API** e **Google Tasks API**.
3. *Tela de permissão OAuth*: tipo **Externo**, adicione seu e-mail como usuário de teste.
4. *Credenciais → Criar credenciais → ID do cliente OAuth → App para computador*.
5. Na Agenda da SownteeShell: *Adicionar conta → Google*, cole o **ID do cliente** e a **chave secreta**.

Microsoft/Outlook é igual, com um "App registration" no portal do Azure (cliente público, redirecionamento `http://localhost`). iCloud usa CalDAV com senha de app.

## Atalhos principais

| Atalho | Ação |
|---|---|
| Alt+Espaço | Inicializador (`f` arquivos, `c` área de transferência, `=` calculadora, `e` emoji, `g` GIF, `s` figurinhas) |
| Super+I | Configurações |
| Super+L | Bloquear tela |
| Super+M | Papéis de parede |
| Super+Shift+S | Captura de tela com editor |
| Super+Shift+R | Iniciar/parar gravação |
| Ctrl+Alt+R | Recarregar o shell |
| Super+Enter / Super+E | Terminal / Arquivos |
| Alt+F4 | Fechar janela (sem janela: menu de energia) |
| Super+O | Visão geral |
| Super+Shift+V | Área de trabalho flutuante |
| Super+Shift+/ | Todos os atalhos |

Todos editáveis em Configurações → Niri → Atalhos.

## Atualizar

```bash
cd ~/Dotfiles/sownteeshell-ptbr && git pull && ./atualizar-sownteeshell.sh
```

Puxa a versão nova do autor, reaplica a tradução, recompila os serviços (e a tela de login, se instalada). Frases novas do autor aparecem em inglês até entrarem no `traducao-ptbr.json`.

## Arquivos

| Arquivo | Para quê |
|---|---|
| `trocar-kde.sh` | Remove o KDE Plasma e instala a SownteeShell no lugar |
| `instalar-sownteeshell.sh` | Instala ou conserta tudo |
| `verificar-sownteeshell.sh` | Confere função por função |
| `atualizar-sownteeshell.sh` | Atualiza e reaplica o pt-BR |
| `configurar-greeter.sh` | Escolhe a tela de login: SownteeShell no Niri, no cage ou texto (com backup e `niri validate`) |
| `configurar-niri.py` | Liga `~/.config/niri` ao dotf e faz os ajustes de desktop (com backup e `niri validate`) |
| `aplicar-ptbr.py` | Tradução e ajustes regionais |
| `traducao-ptbr.json` | As frases traduzidas |

## Desfazer

```bash
systemctl --user disable --now sownteeshell-core sownteeshell-calendar
rm ~/.config/niri && mv ~/.config/niri.backup-<data> ~/.config/niri   # se existir backup
```

## Observações

- A SownteeShell é o setup pessoal do [sownteedev](https://github.com/sownteedev/dotfiles) e não tem licença; este repositório só traz o kit de instalação e a tradução.
- Não instala: zsh, teclado vietnamita, tema do GRUB, apps pessoais do autor (VS Code, VMware, Zalo...).
- Funções de notebook (bateria, limite de carga, tampa) ficam escondidas sozinhas num desktop.
- Brilho pelo painel usa DDC/CI: ative no menu do monitor. TVs geralmente não têm.
