#!/usr/bin/env python3
"""
rv_vec.py - Codificacao e modelo das instrucoes VETORIAIS (SIMD 4x32).

Codificacao (opcodes customizados RISC-V, fora do RV32I base):
  VEC_R = 1011011 : vadd vsub vsll vsrl  (registrador-registrador)
        vadd f3=000 f7=0000000 | vsub f3=000 f7=0100000 | vsll f3=001 | vsrl f3=101
  VEC_I = 0001011 : vaddi vslli vsrli    (imediato transmitido a todas as lanes)
        vaddi f3=000 | vslli f3=001 | vsrli f3=101
  VEC_U = 0101011 : vauipc               (PC+imm transmitido a todas as lanes)

Cada registrador vetorial tem 128 bits = 4 lanes de 32 bits:
  vN = [ lane3(127:96) | lane2(95:64) | lane1(63:32) | lane0(31:0) ]

Este modelo confere: (1) a ALU vetorial lane-a-lane; (2) um pequeno programa.
"""

M32 = 0xFFFFFFFF


def lanes(v):
    return [(v >> (32 * i)) & M32 for i in range(4)]


def pack(ls):
    v = 0
    for i in range(4):
        v |= (ls[i] & M32) << (32 * i)
    return v


def valu(op, a, b):
    la, lb = lanes(a), lanes(b)
    out = []
    for x, y in zip(la, lb):
        if op == 0:    out.append((x + y) & M32)              # vadd
        elif op == 1:  out.append((x - y) & M32)              # vsub
        elif op == 5:  out.append((x << (y & 31)) & M32)      # vsll
        elif op == 6:  out.append(x >> (y & 31))              # vsrl
        else:          out.append(0)
    return pack(out)


# --------------------------- encode ---------------------------
def enc_vr(f7, vs2, vs1, f3, vd):
    return (f7 << 25) | (vs2 << 20) | (vs1 << 15) | (f3 << 12) | (vd << 7) | 0b1011011


def enc_vi(imm, vs1, f3, vd):
    return ((imm & 0xFFF) << 20) | (vs1 << 15) | (f3 << 12) | (vd << 7) | 0b0001011


VEC = {
    "vadd": ("R", 0b0000000, 0b000, 0),
    "vsub": ("R", 0b0100000, 0b000, 1),
    "vsll": ("R", 0b0000000, 0b001, 5),
    "vsrl": ("R", 0b0000000, 0b101, 6),
    "vaddi": ("I", None, 0b000, 0),
    "vslli": ("I", None, 0b001, 5),
    "vsrli": ("I", None, 0b101, 6),
}


def reg(t):
    t = t.strip().lower()
    if t.startswith("v"): return int(t[1:])
    if t.startswith("x"): return int(t[1:])
    raise ValueError(t)


def enc(mn, ops):
    kind, f7, f3, _ = VEC[mn]
    if kind == "R":
        vd, vs1, vs2 = reg(ops[0]), reg(ops[1]), reg(ops[2])
        return enc_vr(f7, vs2, vs1, f3, vd)
    else:
        vd, vs1, imm = reg(ops[0]), reg(ops[1]), int(ops[2], 0)
        return enc_vi(imm, vs1, f3, vd)


# --------------------------- modelo sequencial ---------------------------
def run_vec(prog):
    """prog: lista de (mn, ops). Retorna banco vetorial (32 x 128b)."""
    vregs = [0] * 32
    for mn, ops in prog:
        kind, f7, f3, aluop = VEC[mn]
        if kind == "R":
            vd, vs1, vs2 = reg(ops[0]), reg(ops[1]), reg(ops[2])
            vregs[vd] = valu(aluop, vregs[vs1], vregs[vs2])
        else:
            vd, vs1, imm = reg(ops[0]), reg(ops[1]), int(ops[2], 0)
            bcast = pack([imm & M32] * 4)
            vregs[vd] = valu(aluop, vregs[vs1], bcast)
    return vregs


if __name__ == "__main__":
    # 1) Teste unitario da ALU vetorial com lanes DISTINTAS
    a = pack([10, 20, 30, 40])
    b = pack([1, 2, 3, 4])
    assert lanes(valu(0, a, b)) == [11, 22, 33, 44], "vadd"
    assert lanes(valu(1, a, b)) == [9, 18, 27, 36], "vsub"
    assert lanes(valu(5, a, pack([1, 1, 1, 1]))) == [20, 40, 60, 80], "vsll"
    assert lanes(valu(6, pack([16, 16, 16, 16]), pack([1, 2, 4, 0]))) == [8, 4, 1, 16], "vsrl"
    print("ALU vetorial (4 lanes distintas): OK")
    print("  vadd [10,20,30,40]+[1,2,3,4] =", lanes(valu(0, a, b)))
    print("  vsub                          =", lanes(valu(1, a, b)))
    print("  vsrl [16,16,16,16]>>[1,2,4,0] =", lanes(valu(6, pack([16]*4), pack([1,2,4,0]))))

    # 2) Programa vetorial (init por broadcast; demonstra 4 ALUs em paralelo)
    prog = [
        ("vaddi", ["v1", "v0", "5"]),    # v1 = [5,5,5,5]
        ("vaddi", ["v2", "v0", "3"]),    # v2 = [3,3,3,3]
        ("vadd",  ["v3", "v1", "v2"]),   # v3 = [8,8,8,8]
        ("vsub",  ["v4", "v1", "v2"]),   # v4 = [2,2,2,2]
        ("vslli", ["v5", "v1", "2"]),    # v5 = [20,20,20,20]
        ("vsrli", ["v6", "v1", "1"]),    # v6 = [2,2,2,2]
        ("vsll",  ["v7", "v1", "v2"]),   # v7 = [5<<3,...] = [40,...]
    ]
    vr = run_vec(prog)
    exp = {1: [5]*4, 2: [3]*4, 3: [8]*4, 4: [2]*4, 5: [20]*4, 6: [2]*4, 7: [40]*4}
    print("\nPrograma vetorial:")
    ok = True
    for r, e in exp.items():
        got = lanes(vr[r])
        s = "OK" if got == e else "**MISMATCH**"
        if got != e: ok = False
        print(f"  v{r} = {got}  esperado {e}  {s}")
    print("\nSIMD OK" if ok else "\nFALHA")

    # dump ROM (hex) do programa vetorial p/ Digital
    words = [enc(mn, ops) for mn, ops in prog]
    words.append(0x0000006F)  # jal x0,0  -> loop infinito (parada observavel)
    open("programa_simd.hex", "w").write("v2.0 raw\n" + "\n".join(f"{w:08x}" for w in words) + "\n")
    print("\nROM SIMD:", ",".join(f"{w:x}" for w in words))
