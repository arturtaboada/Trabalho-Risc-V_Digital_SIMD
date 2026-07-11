# Processador RISC-V RV32I com pipeline e extensão vetorial (SIMD)

Processador RISC-V de 32 bits (subconjunto inteiro RV32I) com pipeline de 5
estágios, memórias de instrução e dados separadas com carga assíncrona,
tratamento de riscos por encaminhamento e congelamento, e uma extensão vetorial
(SIMD) de 128 bits (4 lanes de 32 bits). Implementação em VHDL para o simulador
Digital.

## Estrutura

- `vhdl/` — módulos VHDL do processador.
- `Circuito.dig` / `Circuito_SIMD.dig` — circuito do Digital (CPU + ROM + RAM + I/O).
- `programa.hex` / `programa_simd.hex` — programa de teste para a ROM.
- `test_vector.asm` / `programa_simd.asm` — código-fonte dos testes.
- `ferramentas/` — montador (assembler) e modelo de referência em Python.
- `RELATORIO.pdf` / `RELATORIO.tex` — relatório.

## Instruções suportadas

Escalar (RV32I): `add`, `addi`, `auipc`, `sub`, `and`, `andi`, `or`, `ori`,
`xor`, `xori`, `sll`, `slli`, `srl`, `srli`, `lw`, `lui`, `sw`, `jal`, `jalr`,
`beq`, `bne`.

Vetorial (SIMD): `vadd`, `vsub`, `vsll`, `vsrl` (registrador-registrador),
`vaddi`, `vslli`, `vsrli` (imediato difundido) e `vauipc`. A codificação está
descrita no relatório.

## Abrir no Digital

1. Abra o `Circuito.dig` (ou `Circuito_SIMD.dig`) no Digital. Ele contém o bloco
   VHDL do processador, a ROM de instruções, a RAM de dados e as entradas/saídas.
2. Mantenha os arquivos `.vhd` na mesma pasta do `.dig`. Caso o bloco VHDL peça o
   caminho do arquivo, aponte para `riscv_cpu.vhd` (ou `riscv_cpu_vector.vhd`).
   A ferramenta de síntese usada é o GHDL, com as opções `--std=08 --ieee=synopsys`.
3. Confira as conexões e, se necessário, ajuste posições de pinos das memórias.

### Montagem a partir do zero (se preferir)

1. **Bloco VHDL:** componente *External file (VHDL/Verilog)* apontando para o
   top-level (`riscv_cpu.vhd` / `riscv_cpu_vector.vhd`), com GHDL e as opções
   acima. Os pinos aparecem conforme a entidade.
2. **ROM de instruções:** componente *ROM*, `Addr Bits = 8`, `Data Bits = 32`.
   Em *Data*, use *Load from file* com `programa.hex` (`programa_simd.hex`).
3. **Conversão de endereço:** o PC é endereço de byte e a memória é endereçada
   por palavra; use um *Splitter* de entrada 32 e saída `2,8,22` e ligue a fatia
   de 8 bits (bits 9..2) ao endereço da memória.
4. **RAM de dados:** *RAM (Dual Port)*, `Addr Bits = 8`, `Data Bits = 32`.
   Ligue `dmem_addr_o` (via splitter) ao endereço, `dmem_wdata_o` ao dado de
   entrada, `dmem_we_o` à escrita, o clock ao clock e a saída de dado a
   `dmem_rdata_i`.
5. **Entradas:** *Clock* em `clk_i`, *In* de reset em `reset_i`, *In* (chave) em
   `load_enable_i` e *In* de 5 bits em `reg_sel_i`.
6. **Saídas de depuração:** `pc_debug_o`, `instr_debug_o`, `alu_result_debug_o`
   e `reg_debug_o` em displays hexadecimais; `hazard_stall_o` e
   `hazard_flush_o` em LEDs. Na versão SIMD, `vec_lane0..3_debug_o` em displays
   e `is_vector_debug_o` em LED.
7. **Executar:** dê `reset`, mantenha `load_enable = 0` e acione o clock.
   Selecione um registrador por `reg_sel_i` para observar seu valor em
   `reg_debug_o`.

## Testes em Python (ferramentas/)

O montador e o modelo de referência permitem conferir os programas de teste:

```
cd ferramentas
python3 rv_pipe_sim.py      # executa test_vector.asm e imprime os registradores
python3 rv_vec.py           # verifica a ALU vetorial e o programa SIMD
```

## Valores esperados

Escalar (`test_vector.asm`), registradores finais:
x1=0xA, x2=0x14, x4=0x1E, x5=0x28, x6=0x14, x8=0x1E, x9=0x1E, x10=0x1E,
x11=0x28, x12=0x28, x13=0x14, x14=0x3C, x15=1, x16=2, x17=3.

SIMD (`programa_simd.asm`), cada lane dos registradores vetoriais:
v1=[5,5,5,5], v2=[3,3,3,3], v3=[8,8,8,8], v4=[2,2,2,2], v5=[20,20,20,20],
v6=[2,2,2,2], v7=[40,40,40,40].
