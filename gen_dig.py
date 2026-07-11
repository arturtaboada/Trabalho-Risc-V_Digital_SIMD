#!/usr/bin/env python3
"""
Gerador do arquivo Circuito.dig (formato do simulador Digital, hneemann).

Estrategia: usar TUNNELS (nets nomeados) para conectar os pinos, evitando
roteamento de fios pixel-a-pixel. Cada pino recebe um tunnel com o nome do
net; tunnels de mesmo nome ficam conectados. As coordenadas dos pinos das
memorias nativas (ROM / RAMDualPort / Splitter) foram derivadas de um arquivo
.dig funcional; as do bloco VHDL (ExternalFile) seguem a regra:
  entradas em (X, Y+20k) na ordem de externalInputs;
  saidas   em (X+20*Width, Y+20k) na ordem de externalOutputs.
"""

def esc(s):
    return (s.replace("&", "&amp;").replace('"', "&quot;")
             .replace("<", "&lt;").replace(">", "&gt;"))

def entry_str(k, v):
    return f'<entry><string>{k}</string><string>{esc(v)}</string></entry>'

def entry_int(k, v):
    return f'<entry><string>{k}</string><int>{v}</int></entry>'

def entry_data(k, v):
    return f'<entry><string>{k}</string><data>{v}</data></entry>'

def elem(name, attrs, x, y, extra=""):
    a = "".join(attrs)
    return (f'<visualElement><elementName>{name}</elementName>'
            f'<elementAttributes>{a}{extra}</elementAttributes>'
            f'<pos x="{x}" y="{y}"/></visualElement>')

def tunnel(net, x, y, rot=None):
    attrs = [entry_str("NetName", net)]
    if rot is not None:
        attrs.append(f'<entry><string>rotation</string><rotation rotation="{rot}"/></entry>')
    return elem("Tunnel", attrs, x, y)


class Dig:
    def __init__(self):
        self.els = []
        self.wires = []

    def add(self, e):
        self.els.append(e)

    def wire(self, x1, y1, x2, y2):
        self.wires.append((x1, y1, x2, y2))

    def xml(self):
        els = "\n".join(self.els)
        ws = "\n".join(f'<wire><p1 x="{a}" y="{b}"/><p2 x="{c}" y="{d}"/></wire>'
                       for (a, b, c, d) in self.wires)
        return ('<?xml version="1.0" encoding="utf-8"?>\n<circuit>\n<version>2</version>\n'
                '<attributes/>\n<visualElements>\n' + els +
                '\n</visualElements>\n<wires>\n' + ws +
                '\n</wires>\n<measurementOrdering/>\n</circuit>\n')


def build(rom_data, code_file="riscv_cpu.vhd", ghdl_workdir=None):
    d = Dig()

    # ------------------ Bloco VHDL (CPU) ------------------
    Cx, Cy, W = 0, 0, 15
    ext_in = "clk_i,reset_i,load_enable_i,imem_data_i:32,dmem_rdata_i:32,reg_sel_i:5"
    ext_out = ("imem_addr_o:32,dmem_addr_o:32,dmem_wdata_o:32,dmem_we_o,"
               "pc_debug_o:32,instr_debug_o:32,alu_result_debug_o:32,reg_debug_o:32,"
               "hazard_stall_o,hazard_flush_o")
    ghdl_opts = "--std=08 --ieee=synopsys"
    if ghdl_workdir:
        ghdl_opts += f' --workdir="{ghdl_workdir}"'
    cpu_attrs = [
        '<entry><string>applicationType</string><appType>GHDL</appType></entry>',
        entry_str("ghdlOptions", ghdl_opts),
        entry_str("Label", "riscv_cpu"),
        entry_str("externalInputs", ext_in),
        entry_str("externalOutputs", ext_out),
        entry_int("Width", W),
        f'<entry><string>CodeFile</string><file>{esc(code_file)}</file></entry>',
    ]
    d.add(elem("ExternalFile", cpu_attrs, Cx, Cy))

    in_names = ["clk_i", "reset_i", "load_enable_i", "imem_data_i",
                "dmem_rdata_i", "reg_sel_i"]
    in_nets = ["clk", "reset", "load_en", "imem_data", "dmem_rdata", "reg_sel"]
    for i, net in enumerate(in_nets):
        d.add(tunnel(net, Cx, Cy + 20 * i))

    out_names = ["imem_addr_o", "dmem_addr_o", "dmem_wdata_o", "dmem_we_o",
                 "pc_debug_o", "instr_debug_o", "alu_result_debug_o", "reg_debug_o",
                 "hazard_stall_o", "hazard_flush_o"]
    out_nets = ["imem_addr", "dmem_addr", "dmem_wdata", "dmem_we",
                "pc_debug", "instr_debug", "alu_debug", "reg_debug",
                "hz_stall", "hz_flush"]
    ox = Cx + 20 * W
    for i, net in enumerate(out_nets):
        d.add(tunnel(net, ox, Cy + 20 * i))

    # ------------------ Entradas de controle ------------------
    d.add(elem("Clock", [entry_str("Label", "CLOCK")], -220, 0))
    d.add(tunnel("clk", -220, 0))

    d.add(elem("In", [entry_str("Label", "RESET")], -220, 60))
    d.add(tunnel("reset", -220, 60))

    d.add(elem("In", [entry_str("Label", "LOAD_ENABLE")], -220, 120))
    d.add(tunnel("load_en", -220, 120))

    d.add(elem("In", [entry_str("Label", "REG_SEL"), entry_int("Bits", 5)], -220, 180))
    d.add(tunnel("reg_sel", -220, 180))

    # ------------------ Memoria de Instrucoes (ROM) ------------------
    # Pinos (derivados): A@(Rx,Ry)  sel@(Rx,Ry+40)  D@(Rx+60,Ry+20)
    Rx, Ry = 640, -120
    rom_attrs = [entry_int("AddrBits", 8), entry_str("Label", "ROM_INSTR"),
                 entry_int("Bits", 32), entry_data("Data", rom_data)]
    d.add(elem("ROM", rom_attrs, Rx, Ry))
    d.add(tunnel("rom_addr", Rx, Ry))            # A
    d.add(tunnel("load_en", Rx, Ry + 40))        # sel/CS
    d.add(tunnel("imem_data", Rx + 60, Ry + 20)) # D

    # Splitter para converter endereco de byte -> palavra (bits [9:2])
    # in@(Sx,Sy) ; out "2,8,22" -> out1 (8 bits) @(Sx+20,Sy+20)
    Sx, Sy = 460, -20
    spl_attrs = [entry_str("Input Splitting", "32"),
                 entry_str("Output Splitting", "2,8,22")]
    d.add(elem("Splitter", spl_attrs, Sx, Sy))
    d.add(tunnel("imem_addr", Sx, Sy))       # entrada = endereco completo
    d.add(tunnel("rom_addr", Sx + 20, Sy + 20))  # saida bits[9:2]

    # ------------------ Memoria de Dados (RAMDualPort) ------------------
    # Pinos (derivados): ADDR@(Mx,My) Din@(My+20) we@(My+40) C@(My+60)
    #                    ld/sel@(My+80)  Dout@(Mx+60,My+40)
    Mx, My = 640, 140
    ram_attrs = [entry_int("AddrBits", 8), entry_int("Bits", 32),
                 entry_str("Label", "RAM_DADOS")]
    d.add(elem("RAMDualPort", ram_attrs, Mx, My))
    d.add(tunnel("ram_addr", Mx, My))          # ADDR
    d.add(tunnel("dmem_wdata", Mx, My + 20))   # Din
    d.add(tunnel("dmem_we", Mx, My + 40))      # we (str)
    d.add(tunnel("clk", Mx, My + 60))          # clock
    d.add(tunnel("load_en", Mx, My + 80))      # ld/CS
    d.add(tunnel("dmem_rdata", Mx + 60, My + 40))  # Dout

    Sx2, Sy2 = 460, 140
    d.add(elem("Splitter", spl_attrs, Sx2, Sy2))
    d.add(tunnel("dmem_addr", Sx2, Sy2))
    d.add(tunnel("ram_addr", Sx2 + 20, Sy2 + 20))

    # ------------------ Saidas de depuracao ------------------
    outs = [("PC", "pc_debug", 32), ("INSTR", "instr_debug", 32),
            ("ALU_RESULT", "alu_debug", 32), ("REG_DEBUG", "reg_debug", 32),
            ("HAZARD_STALL", "hz_stall", 1), ("HAZARD_FLUSH", "hz_flush", 1)]
    oy = -120
    for label, net, bits in outs:
        attrs = [entry_str("Label", label)]
        if bits != 1:
            attrs.append(entry_int("Bits", bits))
        d.add(elem("Out", attrs, 1000, oy))
        d.add(tunnel(net, 1000, oy))
        oy += 60

    return d.xml()


if __name__ == "__main__":
    import sys
    from rv_asm import assemble
    src = open("test_vector.asm").read()
    words, _ = assemble(src)
    data = ",".join(f"{w:x}" for w in words)
    xml = build(data)
    out = sys.argv[1] if len(sys.argv) > 1 else "Circuito.dig"
    open(out, "w").write(xml)
    print(f"gerado {out} ({len(xml)} bytes, {len(words)} instrucoes na ROM)")


def build_vec(rom_data, code_file="riscv_cpu_vector.vhd"):
    """Circuito SIMD: mesma base, entidade vetorial (saidas extras de lane)."""
    d = Dig()
    Cx, Cy, W = 0, 0, 15
    ext_in = "clk_i,reset_i,load_enable_i,imem_data_i:32,dmem_rdata_i:32,reg_sel_i:5"
    ext_out = ("imem_addr_o:32,dmem_addr_o:32,dmem_wdata_o:32,dmem_we_o,"
               "pc_debug_o:32,instr_debug_o:32,alu_result_debug_o:32,reg_debug_o:32,"
               "hazard_stall_o,hazard_flush_o,"
               "vec_lane0_debug_o:32,vec_lane1_debug_o:32,vec_lane2_debug_o:32,"
               "vec_lane3_debug_o:32,is_vector_debug_o")
    cpu_attrs = [
        '<entry><string>applicationType</string><appType>GHDL</appType></entry>',
        entry_str("ghdlOptions", "--std=08 --ieee=synopsys"),
        entry_str("Label", "riscv_cpu_vector"),
        entry_str("externalInputs", ext_in),
        entry_str("externalOutputs", ext_out),
        entry_int("Width", W),
        f'<entry><string>CodeFile</string><file>{esc(code_file)}</file></entry>',
    ]
    d.add(elem("ExternalFile", cpu_attrs, Cx, Cy))

    in_nets = ["clk", "reset", "load_en", "imem_data", "dmem_rdata", "reg_sel"]
    for i, net in enumerate(in_nets):
        d.add(tunnel(net, Cx, Cy + 20 * i))

    out_nets = ["imem_addr", "dmem_addr", "dmem_wdata", "dmem_we",
                "pc_debug", "instr_debug", "alu_debug", "reg_debug",
                "hz_stall", "hz_flush",
                "vlane0", "vlane1", "vlane2", "vlane3", "is_vec"]
    ox = Cx + 20 * W
    for i, net in enumerate(out_nets):
        d.add(tunnel(net, ox, Cy + 20 * i))

    # controles
    d.add(elem("Clock", [entry_str("Label", "CLOCK")], -220, 0));           d.add(tunnel("clk", -220, 0))
    d.add(elem("In", [entry_str("Label", "RESET")], -220, 60));             d.add(tunnel("reset", -220, 60))
    d.add(elem("In", [entry_str("Label", "LOAD_ENABLE")], -220, 120));      d.add(tunnel("load_en", -220, 120))
    d.add(elem("In", [entry_str("Label", "REG_SEL"), entry_int("Bits", 5)], -220, 180)); d.add(tunnel("reg_sel", -220, 180))

    # ROM
    Rx, Ry = 640, -120
    rom_attrs = [entry_int("AddrBits", 8), entry_str("Label", "ROM_INSTR"),
                 entry_int("Bits", 32), entry_data("Data", rom_data)]
    d.add(elem("ROM", rom_attrs, Rx, Ry))
    d.add(tunnel("rom_addr", Rx, Ry)); d.add(tunnel("load_en", Rx, Ry + 40))
    d.add(tunnel("imem_data", Rx + 60, Ry + 20))
    spl_attrs = [entry_str("Input Splitting", "32"), entry_str("Output Splitting", "2,8,22")]
    Sx, Sy = 460, -20
    d.add(elem("Splitter", spl_attrs, Sx, Sy))
    d.add(tunnel("imem_addr", Sx, Sy)); d.add(tunnel("rom_addr", Sx + 20, Sy + 20))

    # RAM
    Mx, My = 640, 160
    ram_attrs = [entry_int("AddrBits", 8), entry_int("Bits", 32), entry_str("Label", "RAM_DADOS")]
    d.add(elem("RAMDualPort", ram_attrs, Mx, My))
    d.add(tunnel("ram_addr", Mx, My)); d.add(tunnel("dmem_wdata", Mx, My + 20))
    d.add(tunnel("dmem_we", Mx, My + 40)); d.add(tunnel("clk", Mx, My + 60))
    d.add(tunnel("load_en", Mx, My + 80)); d.add(tunnel("dmem_rdata", Mx + 60, My + 40))
    Sx2, Sy2 = 460, 160
    d.add(elem("Splitter", spl_attrs, Sx2, Sy2))
    d.add(tunnel("dmem_addr", Sx2, Sy2)); d.add(tunnel("ram_addr", Sx2 + 20, Sy2 + 20))

    # saidas de depuracao (escalares + vetoriais)
    outs = [("PC", "pc_debug", 32), ("INSTR", "instr_debug", 32),
            ("ALU_RESULT", "alu_debug", 32), ("REG_DEBUG", "reg_debug", 32),
            ("HAZARD_STALL", "hz_stall", 1), ("HAZARD_FLUSH", "hz_flush", 1),
            ("VEC_LANE0", "vlane0", 32), ("VEC_LANE1", "vlane1", 32),
            ("VEC_LANE2", "vlane2", 32), ("VEC_LANE3", "vlane3", 32),
            ("IS_VECTOR", "is_vec", 1)]
    oy = -160
    for label, net, bits in outs:
        attrs = [entry_str("Label", label)]
        if bits != 1:
            attrs.append(entry_int("Bits", bits))
        d.add(elem("Out", attrs, 1000, oy)); d.add(tunnel(net, 1000, oy)); oy += 60
    return d.xml()
