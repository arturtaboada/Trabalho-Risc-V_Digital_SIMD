#!/usr/bin/env python3
"""
rv_pipe_sim.py - Simulador CICLO-A-CICLO que reproduz EXATAMENTE a
microarquitetura da CPU RISC-V pipeline de 5 estagios deste projeto.

Objetivo: validar a logica (forwarding, stall load-use, branch/jump
resolvidos no EX, freeze por load_enable, write-through no banco de
registradores) sem depender do GHDL/Digital, e conferir os valores
esperados de test_vector.asm.

Cada estagio e' modelado como logica combinacional a partir do estado
atual dos registradores de pipeline; o estado seguinte e' commitado
na borda de subida - igual ao VHDL.
"""

M32 = 0xFFFFFFFF


def u32(x):
    return x & M32


def sext(v, bits):
    s = 1 << (bits - 1)
    return (v & ((1 << bits) - 1) ^ s) - s


# --------------------------- decodificador ---------------------------
def decode(instr):
    opcode = instr & 0x7F
    rd = (instr >> 7) & 0x1F
    funct3 = (instr >> 12) & 0x7
    rs1 = (instr >> 15) & 0x1F
    rs2 = (instr >> 20) & 0x1F
    funct7 = (instr >> 25) & 0x7F
    imm = 0
    if opcode in (0x03, 0x13, 0x67):          # I-type
        imm = sext(instr >> 20, 12)
    elif opcode == 0x23:                        # S-type
        imm = sext(((instr >> 25) << 5) | ((instr >> 7) & 0x1F), 12)
    elif opcode == 0x63:                        # B-type
        b = (((instr >> 31) & 1) << 12) | (((instr >> 7) & 1) << 11) | \
            (((instr >> 25) & 0x3F) << 5) | (((instr >> 8) & 0xF) << 1)
        imm = sext(b, 13)
    elif opcode in (0x37, 0x17):                # U-type
        imm = u32(instr & 0xFFFFF000)
    elif opcode == 0x6F:                        # J-type
        b = (((instr >> 31) & 1) << 20) | (((instr >> 12) & 0xFF) << 12) | \
            (((instr >> 20) & 1) << 11) | (((instr >> 21) & 0x3FF) << 1)
        imm = sext(b, 21)
    return opcode, rd, funct3, rs1, rs2, funct7, u32(imm)


# --------------------------- control unit ----------------------------
# alu_ctrl: 0000 ADD 0001 SUB 0010 AND 0011 OR 0100 XOR 0101 SLL 0110 SRL
def control(opcode, funct3, funct7):
    c = dict(RegWrite=0, MemtoReg=0, MemRead=0, MemWrite=0, ALUSrc=0,
             Branch=0, Jump=0, Jalr=0, Lui=0, Auipc=0, alu_ctrl=0)

    def rtype_ctrl():
        if funct3 == 0:
            return 1 if funct7 == 0x20 else 0        # SUB : ADD
        return {0b111: 2, 0b110: 3, 0b100: 4, 0b001: 5, 0b101: 6}.get(funct3, 0)

    def itype_ctrl():
        return {0b000: 0, 0b111: 2, 0b110: 3, 0b100: 4, 0b001: 5, 0b101: 6}.get(funct3, 0)

    if opcode == 0x33:      # R-type
        c.update(RegWrite=1, ALUSrc=0, alu_ctrl=rtype_ctrl())
    elif opcode == 0x13:    # OP-IMM
        c.update(RegWrite=1, ALUSrc=1, alu_ctrl=itype_ctrl())
    elif opcode == 0x03:    # LOAD (lw)
        c.update(RegWrite=1, MemtoReg=1, MemRead=1, ALUSrc=1, alu_ctrl=0)
    elif opcode == 0x23:    # STORE (sw)
        c.update(MemWrite=1, ALUSrc=1, alu_ctrl=0)
    elif opcode == 0x63:    # BRANCH
        c.update(Branch=1, ALUSrc=0, alu_ctrl=1)
    elif opcode == 0x6F:    # JAL
        c.update(RegWrite=1, Jump=1, alu_ctrl=0)
    elif opcode == 0x67:    # JALR
        c.update(RegWrite=1, Jump=1, Jalr=1, ALUSrc=1, alu_ctrl=0)
    elif opcode == 0x37:    # LUI
        c.update(RegWrite=1, Lui=1, ALUSrc=1, alu_ctrl=0)   # opA forcado a 0
    elif opcode == 0x17:    # AUIPC
        c.update(RegWrite=1, Auipc=1, ALUSrc=1, alu_ctrl=0)  # opA = pc
    return c


def alu(op, a, b):
    a &= M32; b &= M32
    if op == 0:  return u32(a + b)
    if op == 1:  return u32(a - b)
    if op == 2:  return a & b
    if op == 3:  return a | b
    if op == 4:  return a ^ b
    if op == 5:  return u32(a << (b & 0x1F))
    if op == 6:  return a >> (b & 0x1F)
    return 0


def bcomp(a, b, funct3):
    if funct3 == 0b000: return 1 if a == b else 0   # beq
    if funct3 == 0b001: return 1 if a != b else 0   # bne
    return 0


class Sim:
    def __init__(self, imem):
        self.imem = imem            # lista de palavras
        self.reset_state()

    def reset_state(self):
        self.PC = 0
        self.regs = [0] * 32
        self.dmem = {}
        self.IFID = self.nop_ifid()
        self.IDEX = self.bubble_idex()
        self.EXMEM = self.bubble_exmem()
        self.MEMWB = self.bubble_memwb()

    def nop_ifid(self):
        return dict(pc=0, instr=0x00000013)  # addi x0,x0,0

    def bubble_idex(self):
        c = control(0, 0, 0)
        c.update(pc=0, data1=0, data2=0, imm=0, funct3=0, rs1=0, rs2=0, rd=0)
        return c

    def bubble_exmem(self):
        return dict(RegWrite=0, MemtoReg=0, MemRead=0, MemWrite=0,
                    alu_result=0, data2=0, rd=0)

    def bubble_memwb(self):
        return dict(RegWrite=0, MemtoReg=0, read_data=0, alu_result=0, rd=0)

    def rf_read(self, i, wb):
        # write-through: se WB escreve neste reg neste ciclo, devolve o dado
        if i == 0:
            return 0
        if wb['RegWrite'] and wb['rd'] == i and wb['rd'] != 0:
            return u32(self.wb_value(wb))
        return u32(self.regs[i])

    def wb_value(self, memwb):
        return memwb['read_data'] if memwb['MemtoReg'] else memwb['alu_result']

    def step(self, load_enable=0):
        pipe_we = 0 if load_enable else 1

        # ---------------- WB (combinacional) ----------------
        wb = self.MEMWB
        wb_data = u32(self.wb_value(wb))

        # ---------------- IF ----------------
        pc = self.PC
        idx = (pc >> 2)
        instr = self.imem[idx] if 0 <= idx < len(self.imem) else 0x00000013
        pc_plus4 = u32(pc + 4)

        # ---------------- ID ----------------
        ifid = self.IFID
        opcode, rd, f3, rs1, rs2, f7, imm = decode(ifid['instr'])
        c = control(opcode, f3, f7)
        data1 = self.rf_read(rs1, wb)
        data2 = self.rf_read(rs2, wb)

        # hazard unit (load-use)
        idex = self.IDEX
        stall = (idex['MemRead'] == 1 and idex['rd'] != 0 and
                 (idex['rd'] == rs1 or idex['rd'] == rs2))
        PCWrite = 0 if stall else 1
        IFIDWrite = 0 if stall else 1
        ControlMux = 1 if stall else 0

        # ---------------- EX ----------------
        exmem = self.EXMEM
        # forwarding
        def fwdA():
            if exmem['RegWrite'] and exmem['rd'] != 0 and exmem['rd'] == idex['rs1']:
                return exmem['alu_result']
            if wb['RegWrite'] and wb['rd'] != 0 and wb['rd'] == idex['rs1']:
                return wb_data
            return idex['data1']

        def fwdB():
            if exmem['RegWrite'] and exmem['rd'] != 0 and exmem['rd'] == idex['rs2']:
                return exmem['alu_result']
            if wb['RegWrite'] and wb['rd'] != 0 and wb['rd'] == idex['rs2']:
                return wb_data
            return idex['data2']

        aluA_fwd = u32(fwdA())
        aluB_fwd = u32(fwdB())
        if idex['Lui']:
            opA = 0
        elif idex['Auipc']:
            opA = idex['pc']
        else:
            opA = aluA_fwd
        opB = idex['imm'] if idex['ALUSrc'] else aluB_fwd
        alu_res = alu(idex['alu_ctrl'], opA, opB)
        btaken = bcomp(aluA_fwd, aluB_fwd, idex['funct3'])
        redirect = (idex['Branch'] and btaken) or idex['Jump']
        pc4_ex = u32(idex['pc'] + 4)
        ex_value = pc4_ex if idex['Jump'] else alu_res
        if idex['Jalr']:
            target = u32((aluA_fwd + idex['imm']) & ~1)
        else:
            target = u32(idex['pc'] + idex['imm'])

        # ---------------- MEM ----------------
        mem_addr = exmem['alu_result']
        read_data = u32(self.dmem.get(mem_addr & ~3, 0))

        # ================= COMMIT (borda de subida) =================
        # 1) escrita no banco de registradores (WB)
        if pipe_we and wb['RegWrite'] and wb['rd'] != 0:
            self.regs[wb['rd']] = wb_data
        # 2) escrita na RAM (MEM)
        if pipe_we and exmem['MemWrite']:
            self.dmem[mem_addr & ~3] = exmem['data2']

        if pipe_we:
            # MEM/WB <= EX/MEM (+ read_data)
            self.MEMWB = dict(RegWrite=exmem['RegWrite'], MemtoReg=exmem['MemtoReg'],
                              read_data=read_data, alu_result=exmem['alu_result'],
                              rd=exmem['rd'])
            # EX/MEM <= EX
            self.EXMEM = dict(RegWrite=idex['RegWrite'], MemtoReg=idex['MemtoReg'],
                              MemRead=idex['MemRead'], MemWrite=idex['MemWrite'],
                              alu_result=ex_value, data2=aluB_fwd, rd=idex['rd'])
            # ID/EX <= ID (com bubble em stall ou flush)
            if redirect or ControlMux:
                self.IDEX = self.bubble_idex()
            else:
                nc = dict(c)
                nc.update(pc=ifid['pc'], data1=data1, data2=data2, imm=imm,
                          funct3=f3, rs1=rs1, rs2=rs2, rd=rd)
                self.IDEX = nc
            # IF/ID
            if redirect:
                self.IFID = self.nop_ifid()
            elif IFIDWrite:
                self.IFID = dict(pc=pc, instr=instr)
            # PC
            if redirect:
                self.PC = target
            elif PCWrite:
                self.PC = pc_plus4

        return dict(pc=pc, instr=ifid['instr'], stall=int(stall),
                    flush=int(redirect), alu=alu_res)


def run(imem, cycles=80, trace=False):
    s = Sim(imem)
    log = []
    for cyc in range(cycles):
        info = s.step()
        log.append(info)
        if trace:
            print(f"c{cyc:02d} PC={info['pc']:04x} instr={info['instr']:08x} "
                  f"stall={info['stall']} flush={info['flush']}")
    return s, log


if __name__ == "__main__":
    import sys
    from rv_asm import assemble
    path = sys.argv[1] if len(sys.argv) > 1 else "test_vector.asm"
    src = open(path).read()
    words, labels = assemble(src)
    s, log = run(words, cycles=int(sys.argv[2]) if len(sys.argv) > 2 else 90,
                 trace=True)
    print("\nRegistradores finais:")
    for i in range(32):
        if s.regs[i]:
            print(f"  x{i:<2} = 0x{s.regs[i]:08x} ({s.regs[i]})")
