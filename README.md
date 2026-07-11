# LEIAME — o que foi feito e como usar

Este pacote finaliza o projeto a partir do seu código original. Abaixo está,
de forma transparente, **tudo o que foi alterado e por quê**, seguido do passo
a passo para importar no Digital e verificar.

---

## 1. Por que o código precisou ser completado

O `control_unit.vhd` original decodificava apenas 4 classes de opcode (R-type,
`lw`, `sw`, `branch`) por um esquema `ALUOp` de 2 bits. Ele **não** suportava
`addi`/`andi`/`ori`/`xori`/`slli`/`srli`, nem `sub` (não separava `funct7`), nem
`lui`, `auipc`, `jal`, `jalr`. O próprio `test_vector.asm` usa `addi` em quase
toda linha — ou seja, não rodaria como estava. "Finalizar" o projeto exigiu,
portanto, completar a decodificação e o caminho de dados.

Nada foi copiado de trabalhos de terceiros: os repositórios de referência foram
usados apenas para entender o **formato** do arquivo `.dig` do Digital (que é
público). O layout dos circuitos aqui é próprio.

## 2. Alterações por arquivo (Parte 1)

Mantidos sem alteração: `alu.vhd`, `branch_comparator.vhd`,
`forwarding_unit.vhd`, `hazard_unit.vhd`, `program_counter.vhd`,
`pipeline_reg_IF_ID.vhd`, `pipeline_reg_EX_MEM.vhd`, `pipeline_reg_MEM_WB.vhd`.

Completados/reescritos:

- **`instruction_decoder.vhd`** — acrescentada a saída `funct7_o` (necessária
  para diferenciar `add`/`sub` e os deslocamentos).
- **`control_unit.vhd`** — reescrito. Passa a receber `opcode/funct3/funct7` e a
  emitir todos os controles (`ALUSrc`, `MemtoReg`, `RegWrite`, `MemRead`,
  `MemWrite`, `Branch`, `Jump`, `Jalr`, `Lui`, `Auipc`) e o código de ALU de 4
  bits (`ALUCtrl`). Suporta todas as 21 instruções exigidas.
- **`register_file.vhd`** — acrescentado *write-through* (bypass de escrita) nas
  duas portas de leitura, fechando o hazard de distância 3.
- **`pipeline_reg_ID_EX.vhd`** — o campo `ALUOp` (2 bits) virou `ALUCtrl` (4
  bits) e foram acrescentados os controles `Jump`, `Jalr`, `Lui`, `Auipc`.
- **`riscv_cpu.vhd`** — caminho de dados completado: MUX do operando A
  (`lui`→0, `auipc`→PC), link `PC+4` para saltos, `redirect = (branch tomado) OU
  salto`, alvos de `jalr`/`branch`, *flush* de IF/ID e ID/EX no redirecionamento.
  A interface externa (portas do top-level) foi **preservada**.

## 3. Alterações e adições (Parte 2 — SIMD)

Reaproveita todos os módulos escalares acima. Seus componentes vetoriais
(`vector_alu.vhd`, `vector_register_file.vhd`, `vector_forwarding_unit.vhd`,
`vector_pipeline_regs.vhd`) foram integrados; as adições:

- **`vector_control_unit.vhd`** (novo) — decodifica os opcodes vetoriais.
- **`vector_pipeline_regs.vhd`** — acrescentados a habilitação `we_i` (para
  congelar junto com o resto no `load_enable`) e os registradores **EX/MEM** e
  **MEM/WB** vetoriais, que faltavam para o caminho vetorial ter os mesmos 5
  estágios do escalar (necessário para o forwarding vetorial funcionar).
- **`vector_register_file.vhd`** — acrescentado *write-through*, como no escalar.
- **`instruction_decoder.vhd`** (versão da Parte 2) — o gerador de imediato passa
  a reconhecer os opcodes vetoriais imediatos.
- **`riscv_cpu_vector.vhd`** (novo) — top-level integrado: núcleo escalar +
  caminho vetorial em paralelo, compartilhando busca, decodificação, detecção de
  hazard, congelamento e *flush*. Expõe saídas de depuração das 4 lanes.

A codificação das instruções vetoriais está documentada no `RELATORIO.md`
(seção 5.1).

## 4. Como a lógica foi verificada

Sem GHDL/Digital no ambiente de desenvolvimento, a lógica foi validada com um
**modelo ciclo-a-ciclo em Python** que reproduz a mesma microarquitetura
(`ferramentas/`). Para reproduzir:

```
cd ferramentas
python3 rv_pipe_sim.py      # roda test_vector.asm -> confere os registradores
python3 rv_vec.py           # testa a ALU vetorial e o programa SIMD
python3 vhdl_check.py ../Parte1_Escalar/vhdl riscv_cpu.vhd
python3 vhdl_check.py ../Parte2_SIMD/vhdl   riscv_cpu_vector.vhd
```

Todos os testes passam (registradores finais idênticos aos esperados; nenhuma
incompatibilidade de portas).

## 5. Importante sobre os arquivos `.dig`

Os arquivos `Circuito.dig` e `Circuito_SIMD.dig` foram **gerados
programaticamente** e têm XML válido, mas **não pôde ser aberto/validado dentro
do Digital neste ambiente**. Eles usam *tunnels* (nets nomeados) para que a
conectividade seja explícita e fácil de conferir. Ao abrir no Digital:

1. Coloque os `.vhd` na **mesma pasta** do `.dig` (o bloco VHDL aponta para
   `riscv_cpu.vhd` / `riscv_cpu_vector.vhd` por caminho relativo). Se o Digital
   pedir o caminho, aponte para o arquivo do top-level.
2. Confira que o bloco VHDL (elemento *"External file (VHDL/Verilog)"*) tem as
   entradas e saídas listadas exatamente como na entidade.
3. Se algum pino nativo (ROM/RAM) não casar perfeitamente, é rápido reposicionar
   pelo próprio Digital — os *tunnels* já indicam o net de cada pino.

Se preferir montar do zero (garantido), siga a seção 6.

## 6. Montagem manual no Digital (garantida)

1. **Importar o VHDL:** menu de componentes → *External file (VHDL/Verilog)* →
   aponte para `riscv_cpu.vhd` (ou `riscv_cpu_vector.vhd`). Selecione GHDL como
   ferramenta e as opções `--std=08 --ieee=synopsys`. Os pinos aparecem
   conforme a entidade.
2. **ROM de instruções:** componente *ROM*, `Addr Bits = 8`, `Data Bits = 32`.
   Em *Data*, use *"Load from file"* apontando para `programa.hex`
   (`programa_simd.hex` na Parte 2), ou cole os valores.
3. **Conversão de endereço:** o PC é endereço de byte; a ROM/RAM são endereçadas
   por palavra. Use um *Splitter* de entrada 32 e saída `2,8,22` e ligue a fatia
   de 8 bits (bits 9..2) ao endereço da memória.
4. **RAM de dados:** componente *RAM (Dual Port)*, `Addr Bits = 8`,
   `Data Bits = 32`. Ligue `dmem_addr_o` (via splitter) ao endereço,
   `dmem_wdata_o` ao dado de entrada, `dmem_we_o` à escrita, o clock ao clock, e
   a saída de dado a `dmem_rdata_i`.
5. **Entradas:** um *Clock* em `clk_i`, um *In* de reset em `reset_i`, um *In*
   (chave) em `load_enable_i`, e um *In* de 5 bits em `reg_sel_i`.
6. **Saídas de depuração:** ligue `pc_debug_o`, `instr_debug_o`,
   `alu_result_debug_o`, `reg_debug_o` a displays hexadecimais e
   `hazard_stall_o`/`hazard_flush_o` a LEDs. Na Parte 2, ligue também
   `vec_lane0..3_debug_o` a displays e `is_vector_debug_o` a um LED.
7. **Rodar:** dê `reset`, mantenha `load_enable = 0` e acione o clock (passo a
   passo ou automático). Selecione um registrador por `reg_sel_i` para observar
   seu valor em `reg_debug_o`.

## 7. Valores esperados (conferência rápida)

Parte 1 (`test_vector.asm`), registradores finais:
x1=0xA, x2=0x14, x4=0x1E, x5=0x28, x6=0x14, x8=0x1E, x9=0x1E, x10=0x1E,
x11=0x28, x12=0x28, x13=0x14, x14=0x3C, x15=1, x16=2, x17=3.

Parte 2 (`programa_simd.asm`), cada lane dos registradores vetoriais:
v1=[5,5,5,5], v2=[3,3,3,3], v3=[8,8,8,8], v4=[2,2,2,2], v5=[20,20,20,20],
v6=[2,2,2,2], v7=[40,40,40,40].
