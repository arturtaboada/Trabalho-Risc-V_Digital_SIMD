#!/usr/bin/env python3
"""
rv_asm.py  -  Montador (assembler) minimalista para o subconjunto RV32I
usado no projeto (Arquitetura de Computadores / UFRJ).

Suporta: add addi auipc sub and andi or ori xor xori
         sll slli srl srli lw lui sw jal jalr beq bne
         + pseudo: nop, li (limitado a 12 bits), j label, mv
Rótulos (labels), comentários com '#', diretiva .text ignorada.

Uso:
    from rv_asm import assemble
    words = assemble(source_text)   # -> lista de inteiros de 32 bits
"""

import re

REG_ALIASES = {
    "zero": 0, "ra": 1, "sp": 2, "gp": 3, "tp": 4,
    "t0": 5, "t1": 6, "t2": 7, "s0": 8, "fp": 8, "s1": 9,
    "a0": 10, "a1": 11, "a2": 12, "a3": 13, "a4": 14, "a5": 15,
    "a6": 16, "a7": 17, "s2": 18, "s3": 19, "s4": 20, "s5": 21,
    "s6": 22, "s7": 23, "s8": 24, "s9": 25, "s10": 26, "s11": 27,
    "t3": 28, "t4": 29, "t5": 30, "t6": 31,
}


def parse_reg(tok):
    tok = tok.strip().lower()
    if tok.startswith("x"):
        return int(tok[1:])
    if tok in REG_ALIASES:
        return REG_ALIASES[tok]
    raise ValueError(f"registrador invalido: {tok}")


def parse_imm(tok, labels=None, cur=None, kind=None):
    tok = tok.strip()
    if labels is not None and tok in labels:
        target = labels[tok]
        return target - cur  # offset relativo (branch/jal)
    return int(tok, 0)


def _u(x, bits):
    return x & ((1 << bits) - 1)


# ---------------------------------------------------------------------------
def enc_r(f7, rs2, rs1, f3, rd, op):
    return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op


def enc_i(imm, rs1, f3, rd, op):
    return (_u(imm, 12) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op


def enc_s(imm, rs2, rs1, f3, op):
    imm = _u(imm, 12)
    hi = (imm >> 5) & 0x7F
    lo = imm & 0x1F
    return (hi << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (lo << 7) | op


def enc_b(imm, rs2, rs1, f3, op):
    imm = _u(imm, 13)  # bit0 sempre 0
    b12 = (imm >> 12) & 1
    b11 = (imm >> 11) & 1
    b10_5 = (imm >> 5) & 0x3F
    b4_1 = (imm >> 1) & 0xF
    return (b12 << 31) | (b10_5 << 25) | (rs2 << 20) | (rs1 << 15) | \
           (f3 << 12) | (b4_1 << 8) | (b11 << 7) | op


def enc_u(imm, rd, op):
    # imm ja e o valor de 20 bits que vai para os bits [31:12]
    return ((imm & 0xFFFFF) << 12) | (rd << 7) | op


def enc_j(imm, rd, op):
    imm = _u(imm, 21)
    b20 = (imm >> 20) & 1
    b10_1 = (imm >> 1) & 0x3FF
    b11 = (imm >> 11) & 1
    b19_12 = (imm >> 12) & 0xFF
    return (b20 << 31) | (b10_1 << 21) | (b11 << 20) | (b19_12 << 12) | (rd << 7) | op


# ---------------------------------------------------------------------------
def tokenize_operands(rest):
    # separa por virgula, tratando "off(reg)"
    return [t.strip() for t in rest.split(",")] if rest.strip() else []


def split_mem(tok):
    m = re.match(r"(-?\w+)\((\w+)\)", tok.strip())
    if not m:
        raise ValueError(f"formato de memoria invalido: {tok}")
    return int(m.group(1), 0), m.group(2)


def assemble(source):
    # Passo 1: coletar labels e linhas de instrucao
    lines = []
    for raw in source.splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        # diretivas ignoradas
        if line.startswith(".") and ":" not in line:
            continue
        lines.append(line)

    labels = {}
    prog = []  # (addr, mnemonic, operands_str)
    addr = 0
    for line in lines:
        # pode ter "label:" possivelmente seguido de instrucao
        while ":" in line:
            lbl, line = line.split(":", 1)
            lbl = lbl.strip()
            if lbl.startswith("."):
                lbl = None
            if lbl:
                labels[lbl] = addr
            line = line.strip()
        if not line:
            continue
        if line.startswith("."):
            continue
        parts = line.split(None, 1)
        mn = parts[0].lower()
        rest = parts[1] if len(parts) > 1 else ""
        prog.append((addr, mn, rest))
        addr += 4

    # Passo 2: codificar
    words = []
    for (a, mn, rest) in prog:
        ops = tokenize_operands(rest)
        w = encode(mn, ops, labels, a)
        words.append(w & 0xFFFFFFFF)
    return words, labels


def encode(mn, ops, labels, cur):
    R = {  # mnemonic -> (f7, f3)
        "add": (0b0000000, 0b000), "sub": (0b0100000, 0b000),
        "and": (0b0000000, 0b111), "or": (0b0000000, 0b110),
        "xor": (0b0000000, 0b100), "sll": (0b0000000, 0b001),
        "srl": (0b0000000, 0b101),
    }
    I = {  # mnemonic -> f3 (OP-IMM)
        "addi": 0b000, "andi": 0b111, "ori": 0b110,
        "xori": 0b100,
    }
    ISH = {"slli": (0b0000000, 0b001), "srli": (0b0000000, 0b101)}

    if mn == "nop":
        return enc_i(0, 0, 0b000, 0, 0b0010011)  # addi x0,x0,0
    if mn == "mv":
        rd = parse_reg(ops[0]); rs = parse_reg(ops[1])
        return enc_i(0, rs, 0b000, rd, 0b0010011)
    if mn in R:
        f7, f3 = R[mn]
        rd, rs1, rs2 = parse_reg(ops[0]), parse_reg(ops[1]), parse_reg(ops[2])
        return enc_r(f7, rs2, rs1, f3, rd, 0b0110011)
    if mn in I:
        f3 = I[mn]
        rd, rs1 = parse_reg(ops[0]), parse_reg(ops[1])
        imm = parse_imm(ops[2])
        return enc_i(imm, rs1, f3, rd, 0b0010011)
    if mn in ISH:
        f7, f3 = ISH[mn]
        rd, rs1 = parse_reg(ops[0]), parse_reg(ops[1])
        sh = parse_imm(ops[2]) & 0x1F
        return enc_i((f7 << 5) | sh, rs1, f3, rd, 0b0010011)
    if mn == "lw":
        rd = parse_reg(ops[0]); off, base = split_mem(ops[1])
        return enc_i(off, parse_reg(base), 0b010, rd, 0b0000011)
    if mn == "sw":
        rs2 = parse_reg(ops[0]); off, base = split_mem(ops[1])
        return enc_s(off, rs2, parse_reg(base), 0b010, 0b0100011)
    if mn == "lui":
        rd = parse_reg(ops[0]); imm = parse_imm(ops[1])
        return enc_u(imm, rd, 0b0110111)
    if mn == "auipc":
        rd = parse_reg(ops[0]); imm = parse_imm(ops[1])
        return enc_u(imm, rd, 0b0010111)
    if mn == "jal":
        if len(ops) == 1:  # jal label  -> rd=ra
            rd = 1; off = parse_imm(ops[0], labels, cur)
        else:
            rd = parse_reg(ops[0]); off = parse_imm(ops[1], labels, cur)
        return enc_j(off, rd, 0b1101111)
    if mn == "j":
        off = parse_imm(ops[0], labels, cur)
        return enc_j(off, 0, 0b1101111)
    if mn == "jalr":
        # jalr rd, offset(rs1)  ou  jalr rd, rs1, imm
        rd = parse_reg(ops[0])
        if "(" in ops[1]:
            off, base = split_mem(ops[1]); rs1 = parse_reg(base)
        else:
            rs1 = parse_reg(ops[1]); off = parse_imm(ops[2]) if len(ops) > 2 else 0
        return enc_i(off, rs1, 0b000, rd, 0b1100111)
    if mn in ("beq", "bne"):
        f3 = 0b000 if mn == "beq" else 0b001
        rs1, rs2 = parse_reg(ops[0]), parse_reg(ops[1])
        off = parse_imm(ops[2], labels, cur)
        return enc_b(off, rs2, rs1, f3, 0b1100011)
    raise ValueError(f"instrucao nao suportada: {mn}")


if __name__ == "__main__":
    import sys
    src = open(sys.argv[1]).read() if len(sys.argv) > 1 else ""
    words, labels = assemble(src)
    for i, w in enumerate(words):
        print(f"{i*4:04x}: {w:08x}")
