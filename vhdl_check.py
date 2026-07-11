#!/usr/bin/env python3
"""
Verificador estatico leve de VHDL (nao e' um compilador).
Confere:
  1) Toda entity: extrai portas (nome, direcao).
  2) No topo (riscv_cpu): para cada 'component X ... end component', confere
     que os nomes de porta batem com a entity X real.
  3) Para cada instancia (port map), confere que todo formal referenciado
     existe na entity correspondente e que todos os formais foram conectados.
"""
import re, sys, glob, os

def strip_comments(t):
    return "\n".join(l.split("--", 1)[0] for l in t.splitlines())

def parse_entities(files):
    ents = {}
    for f in files:
        t = strip_comments(open(f).read())
        for m in re.finditer(r"entity\s+(\w+)\s+is(.*?)end\s+(entity\s+)?\1?\s*;",
                              t, re.I | re.S):
            name = m.group(1)
            body = m.group(2)
            pm = re.search(r"port\s*\((.*)\)\s*;", body, re.I | re.S)
            ports = {}
            if pm:
                # separar por ';' de topo
                decls = split_top(pm.group(1))
                for d in decls:
                    d = d.strip()
                    if not d:
                        continue
                    mm = re.match(r"([\w\s,]+):\s*(in|out|inout)\b", d, re.I)
                    if mm:
                        names = [x.strip() for x in mm.group(1).split(",")]
                        for nm in names:
                            ports[nm.lower()] = mm.group(2).lower()
            ents[name.lower()] = ports
    return ents

def split_top(s):
    depth = 0; cur = ""; out = []
    for ch in s:
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        if ch == ";" and depth == 0:
            out.append(cur); cur = ""
        else:
            cur += ch
    out.append(cur)
    return out

def parse_components(top_text):
    comps = {}
    for m in re.finditer(r"component\s+(\w+)\s+is(.*?)end\s+component\s*;",
                         top_text, re.I | re.S):
        name = m.group(1); body = m.group(2)
        pm = re.search(r"port\s*\((.*)\)\s*;", body, re.I | re.S)
        ports = {}
        if pm:
            for d in split_top(pm.group(1)):
                mm = re.match(r"([\w\s,]+):\s*(in|out|inout)\b", d.strip(), re.I)
                if mm:
                    for nm in mm.group(1).split(","):
                        ports[nm.strip().lower()] = mm.group(2).lower()
        comps[name.lower()] = ports
    return comps

def parse_instances(top_text):
    # LABEL: ENTITY port map ( formal => actual, ...);
    insts = []
    for m in re.finditer(r"(\w+)\s*:\s*(\w+)\s+port\s+map\s*\((.*?)\)\s*;",
                         top_text, re.I | re.S):
        label, ent, args = m.group(1), m.group(2), m.group(3)
        formals = re.findall(r"(\w+)\s*=>", args)
        insts.append((label, ent.lower(), [x.lower() for x in formals]))
    return insts

def main():
    vdir = sys.argv[1]
    top = sys.argv[2] if len(sys.argv) > 2 else "riscv_cpu.vhd"
    files = sorted(glob.glob(os.path.join(vdir, "*.vhd")))
    ents = parse_entities(files)
    top_text = strip_comments(open(os.path.join(vdir, top)).read())
    comps = parse_components(top_text)
    insts = parse_instances(top_text)

    errors = 0
    # 1) component vs entity
    for cname, cports in comps.items():
        if cname not in ents:
            print(f"[ERRO] component {cname} nao tem entity correspondente")
            errors += 1; continue
        eports = ents[cname]
        for p, dirn in cports.items():
            if p not in eports:
                print(f"[ERRO] component {cname}: porta '{p}' nao existe na entity")
                errors += 1
            elif eports[p] != dirn:
                print(f"[ERRO] component {cname}: porta '{p}' direcao {dirn} != entity {eports[p]}")
                errors += 1
        for p in eports:
            if p not in cports:
                print(f"[ERRO] component {cname}: falta declarar porta '{p}' (existe na entity)")
                errors += 1

    # 2) instancias vs entity (formais existem e todos conectados)
    for label, ent, formals in insts:
        if ent not in ents:
            # pode ser instancia de subcomponente ja checado; ignore se nao entity
            continue
        eports = ents[ent]
        for fp in formals:
            if fp not in eports:
                print(f"[ERRO] instancia {label} ({ent}): formal '{fp}' nao existe")
                errors += 1
        for p in eports:
            if p not in formals:
                print(f"[ERRO] instancia {label} ({ent}): porta '{p}' nao conectada")
                errors += 1

    print(f"\nEntities encontradas: {sorted(ents.keys())}")
    print(f"Instancias no topo: {[(l,e) for l,e,_ in insts]}")
    if errors == 0:
        print("\n== OK: nenhuma incompatibilidade de portas encontrada ==")
    else:
        print(f"\n== {errors} problema(s) encontrado(s) ==")
    return errors

if __name__ == "__main__":
    sys.exit(1 if main() else 0)
