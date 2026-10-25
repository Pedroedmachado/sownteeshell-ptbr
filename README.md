# SownteeShell em pt-BR para Arch + Niri

Kit para instalar a [SownteeShell](https://github.com/sownteedev/dotfiles/tree/sownteeshell) traduzida para português.

## O que tem aqui

| Arquivo | Para quê |
|---|---|
| `instalar-sownteeshell.sh` | Instala tudo: pacotes, código, tradução, serviços e (se você aceitar) a config do Niri |
| `atualizar-sownteeshell.sh` | Puxa a versão nova do autor, reaplica a tradução e recompila |
| `aplicar-ptbr.py` | Só aplica a tradução e os ajustes regionais num checkout já existente |
| `configurar-niri.py` | Troca sua config do Niri pela estrutura que a SownteeShell espera (com backup) |
| `traducao-ptbr.json` | Dicionário com as ~1950 frases traduzidas. Edite aqui se quiser mudar algum texto |

## Instalação

Dentro da sessão do Niri, num terminal:

```bash
git clone https://github.com/Pedroedmachado/sownteeshell-ptbr.git ~/Dotfiles/sownteeshell-ptbr
cd ~/Dotfiles/sownteeshell-ptbr
./instalar-sownteeshell.sh
```

O script pergunta antes de: instalar o OCR, ativar o locale `pt_BR.UTF-8` (sudo) e trocar sua config do Niri.
Se preferir manter sua config do Niri como está, rode `./instalar-sownteeshell.sh --sem-niri` e ele mostra as linhas para colar.

Antes de testar, tire do seu `config.kdl` o que a SownteeShell substitui: Waybar, mako/dunst/swaync, fuzzel/wofi, swaylock, swaybg/hyprpaper. Depois rode `~/Dotfiles/sownteeshell/run-sownteeshell` ou saia e entre no Niri.

Os arquivos ficam em `~/Dotfiles/sownteeshell` e `~/Dotfiles/dotf` porque vários caminhos do autor apontam para lá.

## O que a config do Niri faz

- Guarda a sua em `~/.config/niri.backup-<data>`.
- Copia a estrutura do autor (`config.kdl` + `include/*.kdl`), que o painel de Configurações do shell sabe editar.
- Mantém seus monitores (blocos `output`) e o layout de teclado (ou `br` se não achar).
- Remove o teclado vietnamita (fcitx5), as variáveis da NVIDIA se você não tiver NVIDIA, e o `xwayland-satellite` duplicado no Niri ≥ 25.08.
- Troca o terminal e o gerenciador de arquivos pelos que você tem instalados.
- Roda `niri validate`; se der erro, restaura a sua config original.

## Atalhos principais

| Atalho | Ação |
|---|---|
| Alt+Espaço | Inicializador (prefixos: `f` arquivos, `c` área de transferência, `=` calculadora, `e` emoji) |
| Super+I | Configurações |
| Super+L | Bloquear tela |
| Super+M | Papéis de parede |
| Super+Shift+S | Captura de tela com editor |
| Super+Shift+R | Iniciar/parar gravação de tela |
| Ctrl+Alt+R | Recarregar o shell |
| Super+Enter | Terminal |
| Super+E | Arquivos |
| Alt+F4 | Fechar janela (sem janela aberta: menu de energia) |
| Super+O | Visão geral |
| Super+1…9 / Super+Shift+1…9 | Ir para / mover para a área de trabalho |
| Alt+←/→ | Focar coluna |
| Super+V / Super+F | Flutuante / tela cheia |
| Super+Shift+/ | Mostrar todos os atalhos |

Todos estão em `~/.config/niri/include/keybinds.kdl` e podem ser editados em Configurações → Niri → Atalhos.

## Ajustes regionais aplicados

- Interface inteira em português (barra, painéis, inicializador, Configurações, captura, notificações, calendário, tela de bloqueio). A busca das Configurações também aceita termos em português.
- Meses e datas em português (via `LC_TIME=pt_BR.UTF-8`).
- Iniciais da semana S T Q Q S S D.
- Clima com descrições em português (OpenWeather `lang=pt_br`).
- OCR em português + inglês (`tesseract-data-por`) no lugar do vietnamita.
- Calendário lunar vietnamita desligado por padrão (o botão continua no calendário).
- Teclado ABNT2 na tela de login quando o locale é pt_BR.
- Papéis de parede em `~/Imagens/Wallpapers` (e `.../live` para vídeos).
- Atualizações do sistema funcionam com `paru` além de `yay`.

## Depois de instalar

Em Configurações → Integrações coloque, se quiser:
- chave da OpenWeather (clima na barra e no painel esquerdo);
- chave da KLIPY (GIFs e figurinhas no inicializador);
- conta Google (Agenda e Tarefas).

Configurações → Avançado → Dependências mostra o que está faltando no seu sistema.

## Atualizar

```bash
cd ~/Dotfiles/sownteeshell-ptbr && git pull && ./atualizar-sownteeshell.sh
```

Isso guarda a tradução antiga num `git stash`, puxa a versão nova, reaplica a tradução e recompila os serviços. Frases que o autor adicionar depois vão aparecer em inglês até entrarem no `traducao-ptbr.json`.

## Desfazer

```bash
systemctl --user disable --now sownteeshell-core sownteeshell-calendar
rm -rf ~/.config/niri && mv ~/.config/niri.backup-<data> ~/.config/niri
```

## Observações

- A SownteeShell é o setup pessoal do [sownteedev](https://github.com/sownteedev/dotfiles) e não tem licença; este repositório só traz o kit de instalação e a tradução.
- Não instala: zsh como shell padrão, teclado vietnamita, greetd, tema do GRUB, Steam/Wallpaper Engine, Tailscale, WARP, Howdy. Os pacotes estão no instalador do autor (branch `install`) se quiser algum.
- O ícone padrão é o WhiteSur; para usar outro, defina `QS_ICON_THEME` ou mude o tema de ícones do GTK.
