#!/usr/bin/env python3
"""Traduz a SownteeShell para pt-BR e aplica ajustes regionais.

Uso:  python3 aplicar-ptbr.py [caminho-do-sownteeshell]   (padrão: ~/Dotfiles/sownteeshell)
      --forcar   aplica mesmo se já tiver sido aplicado antes

Pode rodar de novo depois de um `git pull` (use atualizar-sownteeshell.sh, que
restaura os arquivos originais, puxa a versão nova e reaplica).
"""
import json, os, re, sys
from pathlib import Path

AQUI = Path(__file__).resolve().parent
args = [a for a in sys.argv[1:] if not a.startswith("--")]
FORCAR = "--forcar" in sys.argv
ROOT = Path(args[0] if args else "~/Dotfiles/sownteeshell").expanduser().resolve()
MARCA = ROOT / ".ptbr-aplicado"

if not (ROOT / "shell.qml").is_file():
    sys.exit(f"[!] Não achei shell.qml em {ROOT}")
if MARCA.exists() and not FORCAR:
    sys.exit("[!] A tradução já foi aplicada. Use atualizar-sownteeshell.sh ou --forcar.")

T = json.load(open(AQUI / "traducao-ptbr.json", encoding="utf-8"))
# Títulos de janela com "SownteeShell" são usados nas regras do Niri: ficam em inglês.
T = {k: v for k, v in T.items() if k != v and not re.fullmatch(r"SownteeShell( [A-Z][a-z]+)+", k)}

KEYS = "label|note|title|text|description|message|accessibleName|tooltipText|placeholder|placeholderText|headline|subtitle|summary|hint|caption|body"
STR = r'"((?:[^"\\]|\\.)*)"'
RX_QSTR = re.compile(r'qsTr\(' + STR)
RX_LIT = re.compile(r'((?<![\w.])"?(?:' + KEYS + r')"?\s*:\s*)' + STR)
RX_RET = re.compile(r'(\breturn\s+)' + STR)
RX_ARR = re.compile(r'(property var \w*(?:Labels|Titles|Names)\w*:\s*\[)(.*)(\])')
RX_SEARCH = re.compile(r'searchEntry\(' + STR + r',\s*' + STR + r',\s*' + STR)
EXCL = ("EditableKeybindPill.qml", "WallpaperWorkshopFilters.qml")

# Textos usados em comparações no código não podem mudar fora do qsTr().
blob = []
for p in ROOT.rglob("*"):
    if ".git" in p.parts or not p.is_file() or p.suffix not in (".qml", ".js", ".py", ".rs", ".sh"):
        continue
    blob.append(p.read_text(encoding="utf-8", errors="ignore"))
blob = "\n".join(blob)
_cmp = {}
def comparado(s):
    if s not in _cmp:
        e = re.escape('"' + s + '"')
        _cmp[s] = bool(re.search(r'(===?|!==?|case|startsWith\(|endsWith\(|indexOf\(|includes\(|\[)\s*' + e, blob)
                       or re.search(e + r'\s*(===?|!==?|\]|:\s*\{)', blob))
    return _cmp[s]

def tr_lit(m):
    s = m.group(2)
    if s in T and not comparado(s):
        return m.group(1) + '"' + T[s] + '"'
    return m.group(0)

# Iniciais dos dias (Seg→Dom): o original usa "T" e "S" duas vezes cada.
DIAS = ["S", "T", "Q", "Q", "S", "S", "D"]
def dias(texto):
    i = [0]
    def r(m):
        if i[0] >= 7:
            return m.group(0)
        v = DIAS[i[0]]; i[0] += 1
        return f'qsTr("{v}")'
    return re.sub(r'qsTr\("[MTWFS]"\)', r, texto)

alterados = 0
for p in sorted(ROOT.rglob("*")):
    if ".git" in p.parts or p.suffix not in (".qml", ".js") or not p.is_file():
        continue
    rel = p.relative_to(ROOT).as_posix()
    orig = p.read_text(encoding="utf-8")
    txt = orig
    if rel.endswith(("CalendarSidebar.qml", "CalendarEventEditor.qml")):
        txt = dias(txt)
    txt = RX_QSTR.sub(lambda m: 'qsTr("' + T.get(m.group(1), m.group(1)) + '"', txt)
    if not rel.endswith(EXCL):
        linhas = []
        for ln in txt.split("\n"):
            ln = RX_LIT.sub(tr_lit, ln)
            ln = RX_RET.sub(tr_lit, ln)
            am = RX_ARR.search(ln)
            if am:
                corpo = re.sub(r'(?<!qsTr\()' + STR,
                               lambda m: '"' + T[m.group(1)] + '"' if m.group(1) in T and not comparado(m.group(1)) else m.group(0),
                               am.group(2))
                ln = ln[:am.start(2)] + corpo + ln[am.end(2):]
            linhas.append(ln)
        txt = "\n".join(linhas)
    if rel.endswith("SettingsHub.qml"):
        def busca(m):
            t, g, k = m.group(1), m.group(2), m.group(3)
            tt = T.get(t, t)
            gg = " · ".join(T.get(x, x) for x in g.split(" · "))
            kk = (k + " " + tt.lower() + " " + gg.lower().replace("·", " ")).strip()
            kk = re.sub(r"\s+", " ", kk)
            return f'searchEntry("{tt}", "{gg}", "{kk}"'
        txt = RX_SEARCH.sub(busca, txt)
        txt = txt.replace('"Inspect and tune your Niri configuration"',
                          '"Inspecione e ajuste a configuração do Niri"')
    if txt != orig:
        p.write_text(txt, encoding="utf-8")
        alterados += 1

# ---------- ajustes regionais ----------
def patch(rel, antigo, novo, obrigatorio=True):
    p = ROOT / rel
    if not p.is_file():
        print(f"[aviso] {rel} não existe; ajuste ignorado"); return
    t = p.read_text(encoding="utf-8")
    if novo in t:
        return
    if antigo not in t:
        print(f"[aviso] trecho não encontrado em {rel}; ajuste ignorado (o autor pode ter mudado o arquivo)")
        return
    p.write_text(t.replace(antigo, novo, 1), encoding="utf-8")

# OCR: português + inglês (pacote tesseract-data-por) em vez de vietnamita.
p = ROOT / "service/capture/OcrService.qml"
if p.is_file():
    t = p.read_text(encoding="utf-8")
    t2 = re.sub(r'\bvie\b', 'por', t).replace(
        '"OCR requires tesseract with English or Vietnamese data"',
        '"O OCR precisa do tesseract com dados em português ou inglês"')
    if t2 != t:
        p.write_text(t2, encoding="utf-8")

# Clima com descrições em português.
patch("backend/rust/core-daemon/src/weather.rs",
      '.append_pair("units", "metric")',
      '.append_pair("units", "metric")\n                .append_pair("lang", "pt_br")')

# Calendário lunar vietnamita desligado por padrão (dá para ligar no calendário).
patch("Config.qml", "property bool calendarShowLunar: true", "property bool calendarShowLunar: false")

# Tela de login: teclado ABNT2 quando o locale for pt_BR.
patch("backend/rust/core-daemon/src/greeter.rs",
      'if locale.to_ascii_lowercase().starts_with("vi") {\n        "vi".into()\n    } else {',
      'if locale.to_ascii_lowercase().starts_with("vi") {\n        "vi".into()\n    } else if locale.to_ascii_lowercase().starts_with("pt_br") {\n        "br".into()\n    } else {')

# Pastas de papel de parede padrão em ~/Imagens/Wallpapers.
for rel in ("Config.qml", "backend/rust/core-daemon/src/settings/defaults.json",
            "widget/settings/WallpaperSettingsPage.qml"):
    p = ROOT / rel
    if p.is_file():
        t = p.read_text(encoding="utf-8")
        t2 = t.replace("~/Dotfiles/dotf/.walls", "~/Imagens/Wallpapers")
        if t2 != t:
            p.write_text(t2, encoding="utf-8")

# Script de inatividade: caminho do shell relativo ao próprio repositório.
patch("scripts/power/idle-session-manager.sh",
      'readonly SHELL_CONFIG="${HOME}/Dotfiles/sownteeshell/shell.qml"',
      'readonly SHELL_CONFIG="$(cd -- "$(dirname -- "$0")/../.." && pwd)/shell.qml"')

# Datas e nomes de meses em português.
patch("run-sownteeshell",
      'exec quickshell -p "$root/shell.qml" "$@"',
      'if locale -a 2>/dev/null | grep -qi "^pt_BR\\.utf-\\?8$"; then\n'
      '    export LC_TIME="${SOWNTEESHELL_LC_TIME:-pt_BR.UTF-8}"\n'
      'fi\n'
      'exec quickshell -p "$root/shell.qml" "$@"')

# Atualizações do sistema: aceita paru quando yay não está instalado.
patch("backend/rust/core-daemon/src/updates.rs",
      'let Some(yay) = command_path("yay") else {',
      'let Some(yay) = command_path("yay").or_else(|| command_path("paru")) else {')
patch("scripts/system/package-updates.sh",
      "        yay --sudo /usr/bin/sudo",
      '        "$(command -v yay || command -v paru)" --sudo /usr/bin/sudo')

MARCA.write_text("pt-BR aplicado\n")
print(f"[ok] Tradução aplicada em {alterados} arquivos de {ROOT}")
