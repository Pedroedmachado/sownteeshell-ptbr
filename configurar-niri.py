#!/usr/bin/env python3
"""Deixa a config do Niri do jeito que a SownteeShell espera, adaptada para desktop.

Por que existe: o painel de Configurações (Niri, Atalhos, Layout, Entrada, Animações,
Regras, Tela) e o Rust Core editam SEMPRE ~/Dotfiles/dotf/.config/niri. Se
~/.config/niri for uma cópia, nenhuma dessas opções faz efeito. Então:

  1. ~/.config/niri vira um link para ~/Dotfiles/dotf/.config/niri (a antiga vai para backup);
  2. os ajustes deste PC são feitos dentro de ~/Dotfiles/dotf/.config/niri:
     - monitores: mantém os seus (da config antiga ou do Niri em execução);
     - teclado: layout da config antiga, do `localectl` ou "br" (ABNT2);
     - tira o teclado vietnamita (fcitx5) e o DISPLAY fixo ":1";
     - variáveis da NVIDIA só se houver NVIDIA;
     - não inicia xwayland-satellite à mão no Niri >= 25.08 (o Niri já inicia);
     - Super+Enter / Super+E apontam para o terminal e o gerenciador de arquivos instalados.
  3. `niri validate`; se falhar, tudo volta como estava.

Pode rodar quantas vezes quiser.
Uso: configurar-niri.py [pasta-dotf]   (padrão: ~/Dotfiles/dotf)
"""
import json, re, shutil, subprocess, sys, time
from pathlib import Path

HOME = Path.home()
DOTF = Path(sys.argv[1]).expanduser() if len(sys.argv) > 1 else HOME / "Dotfiles/dotf"
SRC = DOTF / ".config/niri"
INC = SRC / "include"
DST = HOME / ".config/niri"
TS = time.strftime("%Y%m%d-%H%M%S")
ASSINATURA_AUTOR = "California Institute of Technology"

if not (SRC / "config.kdl").is_file() or not INC.is_dir():
    sys.exit(f"[!] Não achei {SRC}/config.kdl. Rode o instalador primeiro (ele clona o dotf).")

def tem(cmd):
    return shutil.which(cmd) is not None

def rodar(*cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=15)
    except (OSError, subprocess.TimeoutExpired):
        return None

def ler_kdl(pasta):
    texto = ""
    if pasta and pasta.exists():
        arquivos = [pasta] if pasta.is_file() else sorted(pasta.rglob("*.kdl"))
        for p in arquivos:
            try:
                texto += "\n" + p.read_text(encoding="utf-8")
            except OSError:
                pass
    return texto

def sem_comentarios(texto):
    return "\n".join(l for l in texto.split("\n") if not l.strip().startswith("//"))

def blocos(texto, nome):
    texto = sem_comentarios(texto)
    out, i = [], 0
    for m in re.finditer(r'^\s*' + nome + r'\b[^{\n]*\{', texto, re.M):
        if m.start() < i:
            continue
        prof, j = 0, m.end() - 1
        while j < len(texto):
            if texto[j] == "{":
                prof += 1
            elif texto[j] == "}":
                prof -= 1
                if prof == 0:
                    break
            j += 1
        out.append(texto[m.start():j + 1].strip())
        i = j + 1
    return out

# ------------------------------------------------------------ config antiga
link_ok = DST.is_symlink() and DST.resolve() == SRC.resolve()
antigo = ""
if DST.exists() and not link_ok:
    antigo = ler_kdl(DST.resolve() if DST.is_symlink() else DST)
# backups de execuções anteriores deste kit (que copiavam em vez de linkar)
backups = sorted(HOME.joinpath(".config").glob("niri.backup-*"), reverse=True)

# ------------------------------------------------------------ backup do dotf
BAK_DOTF = HOME / f".config/niri-dotf.backup-{TS}"
shutil.copytree(SRC, BAK_DOTF, symlinks=True)
BAK_DST = None

def restaurar(msg):
    shutil.rmtree(SRC)
    shutil.copytree(BAK_DOTF, SRC, symlinks=True)
    if BAK_DST is not None:
        if DST.is_symlink() or DST.exists():
            DST.unlink() if DST.is_symlink() else shutil.rmtree(DST)
        BAK_DST.rename(DST)
    sys.exit(msg)

# ------------------------------------------------------------ link ~/.config/niri
if not link_ok:
    if DST.is_symlink() or DST.exists():
        BAK_DST = HOME / f".config/niri.backup-{TS}"
        DST.rename(BAK_DST)
    DST.parent.mkdir(parents=True, exist_ok=True)
    DST.symlink_to(SRC)

def editar(nome, fn):
    p = INC / nome
    if not p.is_file():
        return
    t = p.read_text(encoding="utf-8")
    t2 = fn(t)
    if t2 != t:
        p.write_text(t2, encoding="utf-8")

# ------------------------------------------------------------ monitores
saidas_atuais = (INC / "outputs.kdl").read_text(encoding="utf-8") if (INC / "outputs.kdl").is_file() else ""
monitores_msg = "mantidos"
if ASSINATURA_AUTOR in saidas_atuais or not blocos(saidas_atuais, "output"):
    fontes = [antigo] + [ler_kdl(b) for b in backups]
    saidas = []
    for f in fontes:
        saidas = [b for b in blocos(f, "output") if ASSINATURA_AUTOR not in b]
        if saidas:
            break
    if not saidas:
        r = rodar("niri", "msg", "-j", "outputs")
        if r and r.returncode == 0:
            try:
                dados = json.loads(r.stdout)
            except ValueError:
                dados = {}
            for nome, o in sorted(dados.items(), key=lambda kv: (kv[1].get("logical") or {}).get("x", 0)):
                lg = o.get("logical") or {}
                modo = None
                idx = o.get("current_mode")
                if idx is not None and o.get("modes"):
                    m = o["modes"][idx]
                    modo = f'{m["width"]}x{m["height"]}@{m["refresh_rate"] / 1000:.3f}'
                linhas = [f'output "{nome}" {{']
                if modo:
                    linhas.append(f'    mode "{modo}"')
                linhas.append(f'    scale {lg.get("scale", 1.0)}')
                linhas.append(f'    position x={lg.get("x", 0)} y={lg.get("y", 0)}')
                linhas.append("}")
                saidas.append("\n".join(linhas))
    (INC / "outputs.kdl").write_text(
        ("\n\n".join(saidas) + "\n") if saidas else
        "// Monitores: o Niri detecta sozinho. Ajuste em Configurações > Tela.\n",
        encoding="utf-8")
    monitores_msg = f"{len(saidas)} configurado(s)" if saidas else "automático"

# ------------------------------------------------------------ teclado
def achar_layout():
    for f in [antigo] + [ler_kdl(b) for b in backups]:
        f = sem_comentarios(f)
        m = re.search(r'(?<![\w-])layout\s+"([^"]+)"', f, re.M)
        if m:
            v = re.search(r'\bvariant\s+"([^"]*)"', f, re.M)
            o = re.search(r'\boptions\s+"([^"]*)"', f, re.M)
            return m.group(1), v.group(1) if v else "", o.group(1) if o else ""
    r = rodar("localectl", "status")
    if r and r.returncode == 0:
        m = re.search(r'X11 Layout:\s*(\S+)', r.stdout)
        v = re.search(r'X11 Variant:\s*(\S+)', r.stdout)
        if m:
            return m.group(1), v.group(1) if v else "", ""
    return "br", "", ""

atual_inc = sem_comentarios((INC / "input.kdl").read_text(encoding="utf-8"))
ja_tem = re.search(r'(?<![\w-])layout\s+"([^"]+)"', atual_inc, re.M)
if ja_tem and ja_tem.group(1) not in ("us,vi", "vi"):
    teclado_msg = f"{ja_tem.group(1)} (mantido)"
else:
    lay, var, opt = achar_layout()
    if lay in ("us,vi", "vi"):
        lay, var = "br", ""
    def teclado(t):
        novas = [f'            layout "{lay}"']
        if var:
            novas.append(f'            variant "{var}"')
        if opt:
            novas.append(f'            options "{opt}"')
        # troca a linha do layout do autor (comentada) ou um layout vietnamita
        t2, n = re.subn(r'^[ \t]*//\s*layout\s+"us,vi"[ \t]*$', "\n".join(novas), t, count=1, flags=re.M)
        if n == 0:
            t2, n = re.subn(r'^[ \t]*layout\s+"(?:us,vi|vi)"[ \t]*$', "\n".join(novas), t, count=1, flags=re.M)
        if n == 0:
            t2 = re.sub(r'(xkb\s*\{)', r'\1\n' + "\n".join(novas), t, count=1)
        return t2
    editar("input.kdl", teclado)
    teclado_msg = lay + (f" ({var})" if var else "")

# ------------------------------------------------------------ versão do Niri / GPU
r = rodar("niri", "--version")
v = re.search(r'(\d+)\.(\d+)', r.stdout if r else "")
niri_ver = (int(v.group(1)), int(v.group(2))) if v else (0, 0)
r = rodar("lspci")
nvidia = bool(r) and bool(re.search(r'(vga|3d|display).*nvidia', r.stdout, re.I))

# ------------------------------------------------------------ ambiente
def ambiente(t):
    fora = ["QT_IM_MODULE", "XMODIFIERS", "SDL_IM_MODULE", "GLFW_IM_MODULE", "INPUT_METHOD"]
    if niri_ver >= (25, 8) or niri_ver == (0, 0):
        fora.append("DISPLAY ")
    if not nvidia:
        fora += ["GBM_BACKEND", "__GLX_VENDOR_LIBRARY_NAME"]
    if not tem("qt6ct"):
        fora.append("QT_QPA_PLATFORMTHEME")
    return "\n".join(l for l in t.split("\n") if not any(l.strip().startswith(f) for f in fora))
editar("environment.kdl", ambiente)

# ------------------------------------------------------------ autostart
def autostart(t):
    out = []
    for l in t.split("\n"):
        if "fcitx5" in l and not l.strip().startswith("//"):
            continue
        if '"xwayland-satellite"' in l and niri_ver >= (25, 8):
            continue
        out.append(l)
    return "\n".join(out)
editar("autostart.kdl", autostart)

# ------------------------------------------------------------ terminal e arquivos
TERMS = ("blackbox-terminal", "ghostty", "kitty", "alacritty", "foot", "wezterm", "konsole", "gnome-terminal", "ptyxis")
FMS = ("nautilus", "thunar", "dolphin", "nemo", "pcmanfm-qt", "pcmanfm")
term = next((c for c in TERMS if tem(c)), None)
fm = next((c for c in FMS if tem(c)), None)
def binds(t):
    if term:
        t = re.sub(r'(Mod\+Return[^\n]*\{\s*spawn\s+)"[^"]+"', r'\1"' + term + '"', t, count=1)
    if fm:
        t = re.sub(r'(Mod\+E\s[^\n]*\{\s*spawn\s+)"[^"]+"', r'\1"' + fm + '"', t, count=1)
    return t
editar("keybinds.kdl", binds)

# ------------------------------------------------------------ valida
if tem("niri"):
    r = rodar("niri", "validate", "-c", str(SRC / "config.kdl"))
    if r is None or r.returncode != 0:
        print((r.stdout + r.stderr) if r else "niri validate não rodou", file=sys.stderr)
        restaurar("[!] O Niri recusou a config ajustada. Tudo foi restaurado como estava.")

# remove o backup do dotf se nada mudou
if ler_kdl(BAK_DOTF) == ler_kdl(SRC):
    shutil.rmtree(BAK_DOTF)
    bak_msg = ""
else:
    bak_msg = f" · backup: {BAK_DOTF}"

print(f"[ok] Niri: ~/.config/niri -> {SRC}" + (f" (antiga em {BAK_DST})" if BAK_DST else ""))
print(f"     Teclado: {teclado_msg} · Monitores: {monitores_msg} · Terminal: {term or 'nenhum'} · Arquivos: {fm or 'nenhum'}"
      f" · NVIDIA: {'sim' if nvidia else 'não'}{bak_msg}")
