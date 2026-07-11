# =============================================================
# test_vector.asm
# Programa de teste para a CPU RISC-V Pipeline 5 estágios
# Testa: forwarding EX/MEM e MEM/WB, stall load-use, branch,
#        operações R-type e acesso à memória.
# =============================================================

.text
.global _start

_start:

# -------------------------------------------------------
# PARTE 1 – Inicialização de registradores
# Resultado esperado: x1=10, x2=20, x3=0 (base de memória)
# -------------------------------------------------------
    addi x1, x0, 10        # x1 = 10
    addi x2, x0, 20        # x2 = 20
    addi x3, x0, 0         # x3 = 0  (endereço base)

# -------------------------------------------------------
# PARTE 2 – Operações R-type (exercita Forwarding Unit)
#
# Ciclos após add x4:  EX hazard  em x1 e x2
# Ciclos após add x5:  EX hazard  em x4
# Ciclos após sub x6:  MEM hazard em x5
# -------------------------------------------------------
    add  x4, x1, x2        # x4 = 30   (EX hazard: usa x1 e x2 recém escritos)
    add  x5, x4, x1        # x5 = 40   (EX hazard: usa x4 do ciclo anterior)
    sub  x6, x5, x2        # x6 = 20   (MEM hazard: usa x5)
    and  x7, x1, x2        # x7 =  0   (10 AND 20 = 0000_1010 AND 0001_0100 = 0)
    or   x8, x1, x2        # x8 = 30   (10 OR  20 = 0001_1110 = 30)
    xor  x9, x1, x2        # x9 = 30   (10 XOR 20 = 0001_1110 = 30)

# -------------------------------------------------------
# PARTE 3 – Acesso à memória (exercita load-use stall)
#
# sw não gera hazard (não lê resultado na próxima instrução)
# lw seguido de add DEVE gerar 1 ciclo de stall
# -------------------------------------------------------
    sw   x4, 0(x3)         # Mem[0]  = 30
    sw   x5, 4(x3)         # Mem[4]  = 40
    sw   x6, 8(x3)         # Mem[8]  = 20

    lw   x10, 0(x3)        # x10 = 30  (carrega Mem[0])
    add  x11, x10, x1      # x11 = 40  (load-use hazard: stall de 1 ciclo)
                            # Verifique hazard_stall_o = '1' neste ciclo

    lw   x12, 4(x3)        # x12 = 40
    lw   x13, 8(x3)        # x13 = 20  (sem stall: não usada imediatamente)
    add  x14, x12, x13     # x14 = 60  (MEM hazard: forwarding do MEM/WB)

# -------------------------------------------------------
# PARTE 4 – Branch (exercita flush do pipeline)
#
# beq x1, x1  →  sempre tomado (x1 == x1)
# As 2 instruções seguintes devem ser CANCELADAS (flush)
# -------------------------------------------------------
    beq  x1, x1, taken     # Branch tomado: salta para 'taken'
    addi x15, x0, 0xFF     # NÃO deve executar (flush)
    addi x16, x0, 0xFF     # NÃO deve executar (flush)

taken:
    addi x15, x0, 1        # x15 = 1  (confirma que branch funcionou)

# -------------------------------------------------------
# PARTE 5 – Branch não tomado (BNE com valores iguais)
# -------------------------------------------------------
    bne  x0, x0, not_taken  # Branch NÃO tomado (x0 == x0)
    addi x16, x0, 2         # x16 = 2  (deve executar normalmente)

not_taken:
    addi x17, x0, 3         # x17 = 3

# -------------------------------------------------------
# LOOP INFINITO – mantém CPU em estado observável
# -------------------------------------------------------
end_loop:
    beq  x0, x0, end_loop  # Loop infinito para observar sinais de debug

# =============================================================
# RESULTADOS ESPERADOS nos pinos de debug após execução:
#   x1  = 0x0000000A  (10)
#   x2  = 0x00000014  (20)
#   x4  = 0x0000001E  (30)
#   x5  = 0x00000028  (40)
#   x6  = 0x00000014  (20)
#   x7  = 0x00000000  (0)
#   x8  = 0x0000001E  (30)
#   x9  = 0x0000001E  (30)
#   x10 = 0x0000001E  (30)
#   x11 = 0x00000028  (40)
#   x12 = 0x00000028  (40)
#   x13 = 0x00000014  (20)
#   x14 = 0x0000003C  (60)
#   x15 = 0x00000001  (1  – branch tomado OK)
#   x16 = 0x00000002  (2  – branch NÃO tomado OK)
#   x17 = 0x00000003  (3)
#
# EVENTOS ESPERADOS de hazard:
#   hazard_stall_o = '1'  por 1 ciclo após o primeiro lw (load-use)
#   hazard_flush_o = '1'  por 1 ciclo após o beq tomado
# =============================================================
