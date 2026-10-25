#!/usr/bin/env python3
"""Instala a estrutura de config do Niri da SownteeShell (config.kdl + include/*.kdl),
guardando a sua config atual em ~/.config/niri.backup-<data>.

Mantém da sua config antiga: os blocos `output` (monitores) e o layout de teclado.
Remove o que é do setup do autor e não serve aqui: teclado vietnamita (fcitx5),
variáveis da NVIDIA quando não há NVIDIA, xwayland-satellite duplicado.
Se `niri validate` reclamar, restaura a config antiga e sai com erro.
"""
import os, re, shutil, subprocess, sys, time
from pathlib import Path

SRC = Path(sys.argv[1]).expanduser()
DST = Path("~/.config/niri").expanduser()
TS = time.strftime("%Y%m%d-%H%M%S")
BAK = DST.with_name(f"niri.backup-{TS}")

def tem(cmd): return shutil.which(cmd) is not None

# ---- lê a config antiga (config.kdl + includes)
antigo = ""
if DST.exists():
    for p in sorted(DST.resolve().rglob("*.kdl")):
        try: antigo += "\n" + p.read_text(encoding="utf-8")
        except OSError: pass

def blocos(texto, nome):
    out, i = [], 0
    for m in re.finditer(r'^\s*' + nome + r'\b[^{\n]*\{', texto, re.M):
        if m.start() < i: continue
        prof, j = 0, m.end() - 1
        while j < len(texto):
            if texto[j] == "{": prof += 1
            elif texto[j] == "}":
                prof -= 1
                if prof == 0: break
            j += 1
        out.append(texto[m.start():j + 1].strip()); i = j + 1
    return out

saidas = [b for b in blocos(antigo, "output") if not b.lstrip().startswith("//")]
lay = re.search(r'^\s*layout\s+"([^"]+)"', antigo, re.M)
var = re.search(r'^\s*variant\s+"([^"]*)"', antigo, re.M)
opt = re.search(r'^\s*options\s+"([^"]*)"', antigo, re.M)

# ---- backup e cópia
if DST.is_symlink():
    DST.rename(BAK)
elif DST.exists():
    shutil.move(str(DST), str(BAK))
shutil.copytree(SRC, DST, symlinks=False)
inc = DST / "include"

def editar(nome, fn):
    p = inc / nome
    p.write_text(fn(p.read_text(encoding="utf-8")), encoding="utf-8")

# monitores
(inc / "outputs.kdl").write_text(
    ("\n\n".join(saidas) + "\n") if saidas else
    "// Seus monitores. Ajuste em Configurações > Tela da SownteeShell ou veja `niri msg outputs`.\n",
    encoding="utf-8")

# teclado
def teclado(t):
    linhas = [f'            layout "{lay.group(1) if lay else "br"}"']
    if var and var.group(1): linhas.append(f'            variant "{var.group(1)}"')
    if opt and opt.group(1): linhas.append(f'            options "{opt.group(1)}"')
    return t.replace('            // layout "us,vi"', "\n".join(linhas), 1)
editar("input.kdl", teclado)

# variáveis de ambiente
nvidia = False
try:
    nvidia = "nvidia" in subprocess.run(["lspci"], capture_output=True, text=True).stdout.lower()
except OSError: pass
def ambiente(t):
    fora = ["QT_IM_MODULE", "XMODIFIERS", "SDL_IM_MODULE", "GLFW_IM_MODULE", "INPUT_METHOD", "DISPLAY "]
    if not nvidia: fora += ["GBM_BACKEND", "__GLX_VENDOR_LIBRARY_NAME"]
    if not tem("qt6ct"): fora += ["QT_QPA_PLATFORMTHEME"]
    return "\n".join(l for l in t.split("\n") if not any(l.strip().startswith(f) for f in fora))
editar("environment.kdl", ambiente)

# autostart
try:
    v = re.search(r'(\d+)\.(\d+)', subprocess.run(["niri", "--version"], capture_output=True, text=True).stdout)
    niri_ver = (int(v.group(1)), int(v.group(2))) if v else (0, 0)
except OSError: niri_ver = (0, 0)
def autostart(t):
    out = []
    for l in t.split("\n"):
        if "fcitx5" in l: continue
        if '"xwayland-satellite"' in l and niri_ver >= (25, 8): continue  # o Niri já inicia sozinho
        if "gnome-keyring-daemon" in l and not tem("gnome-keyring-daemon"): continue
        out.append(l)
    return "\n".join(out)
editar("autostart.kdl", autostart)

# terminal e gerenciador de arquivos
term = next((c for c in ("blackbox-terminal", "ghostty", "kitty", "alacritty", "foot", "wezterm", "konsole", "gnome-terminal") if tem(c)), None)
fm = next((c for c in ("nautilus", "thunar", "dolphin", "nemo", "pcmanfm-qt", "pcmanfm") if tem(c)), None)
def binds(t):
    if term: t = t.replace('spawn "blackbox-terminal"', f'spawn "{term}"')
    if fm: t = t.replace('spawn "nautilus"', f'spawn "{fm}"')
    else: t = "\n".join(l for l in t.split("\n") if 'spawn "nautilus"' not in l)
    return t
editar("keybinds.kdl", binds)

# ---- valida
r = subprocess.run(["niri", "validate", "-c", str(DST / "config.kdl")], capture_output=True, text=True)
if r.returncode != 0:
    print(r.stdout + r.stderr, file=sys.stderr)
    shutil.rmtree(DST)
    if BAK.exists(): BAK.rename(DST)
    sys.exit("[!] O Niri recusou a config nova (versão antiga do Niri?). A sua config original foi restaurada.")

print(f"[ok] Config do Niri instalada. A antiga está em {BAK}")
print(f"     Teclado: {lay.group(1) if lay else 'br'} · Monitores copiados: {len(saidas)} · Terminal: {term or 'blackbox-terminal (não instalado)'}")
