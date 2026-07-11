library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- ============================================================================
-- Unidade de Controle - CPU RISC-V RV32I (pipeline 5 estagios)
--
-- Gera todos os sinais de controle a partir de opcode/funct3/funct7.
-- A codificacao da ALU (alu_ctrl, 4 bits) e' resolvida aqui, no estagio ID,
-- e propagada pelo registrador ID/EX.
--
-- Instrucoes suportadas:
--   add addi auipc sub | and andi or ori xor xori
--   sll slli srl srli   | lw lui sw | jal jalr beq bne
--
-- alu_ctrl:
--   0000 ADD  0001 SUB  0010 AND  0011 OR
--   0100 XOR  0101 SLL  0110 SRL
-- ============================================================================
entity control_unit is
    Port (
        opcode_i   : in  STD_LOGIC_VECTOR(6 downto 0);
        funct3_i   : in  STD_LOGIC_VECTOR(2 downto 0);
        funct7_i   : in  STD_LOGIC_VECTOR(6 downto 0);

        ALUSrc_o   : out STD_LOGIC;                    -- 1 = usa imediato como operando B
        MemtoReg_o : out STD_LOGIC;                    -- 1 = escreve dado da RAM (lw)
        RegWrite_o : out STD_LOGIC;                    -- 1 = escreve no banco de registradores
        MemRead_o  : out STD_LOGIC;                    -- 1 = leitura de memoria (lw)
        MemWrite_o : out STD_LOGIC;                    -- 1 = escrita em memoria (sw)
        Branch_o   : out STD_LOGIC;                    -- 1 = beq/bne
        Jump_o     : out STD_LOGIC;                    -- 1 = jal/jalr (salto incondicional)
        Jalr_o     : out STD_LOGIC;                    -- 1 = jalr (alvo = rs1 + imm)
        Lui_o      : out STD_LOGIC;                    -- 1 = lui  (operando A forcado a 0)
        Auipc_o    : out STD_LOGIC;                    -- 1 = auipc(operando A = PC)
        ALUCtrl_o  : out STD_LOGIC_VECTOR(3 downto 0)  -- operacao da ALU
    );
end control_unit;

architecture Behavioral of control_unit is

    constant OP_RTYPE  : STD_LOGIC_VECTOR(6 downto 0) := "0110011";
    constant OP_IMM    : STD_LOGIC_VECTOR(6 downto 0) := "0010011";
    constant OP_LOAD   : STD_LOGIC_VECTOR(6 downto 0) := "0000011";
    constant OP_STORE  : STD_LOGIC_VECTOR(6 downto 0) := "0100011";
    constant OP_BRANCH : STD_LOGIC_VECTOR(6 downto 0) := "1100011";
    constant OP_JAL    : STD_LOGIC_VECTOR(6 downto 0) := "1101111";
    constant OP_JALR   : STD_LOGIC_VECTOR(6 downto 0) := "1100111";
    constant OP_LUI    : STD_LOGIC_VECTOR(6 downto 0) := "0110111";
    constant OP_AUIPC  : STD_LOGIC_VECTOR(6 downto 0) := "0010111";

    constant ALU_ADD : STD_LOGIC_VECTOR(3 downto 0) := "0000";
    constant ALU_SUB : STD_LOGIC_VECTOR(3 downto 0) := "0001";
    constant ALU_AND : STD_LOGIC_VECTOR(3 downto 0) := "0010";
    constant ALU_OR  : STD_LOGIC_VECTOR(3 downto 0) := "0011";
    constant ALU_XOR : STD_LOGIC_VECTOR(3 downto 0) := "0100";
    constant ALU_SLL : STD_LOGIC_VECTOR(3 downto 0) := "0101";
    constant ALU_SRL : STD_LOGIC_VECTOR(3 downto 0) := "0110";

    -- Operacao da ALU escolhida por funct3 (comum a R-type e OP-IMM).
    -- Para R-type, funct3="000" ainda depende de funct7 (ADD vs SUB).
    signal ctrl_by_funct3 : STD_LOGIC_VECTOR(3 downto 0);

begin

    -- Decodificacao aritmetica/logica por funct3
    process(funct3_i)
    begin
        case funct3_i is
            when "000"  => ctrl_by_funct3 <= ALU_ADD; -- add/addi (SUB tratado abaixo)
            when "111"  => ctrl_by_funct3 <= ALU_AND; -- and/andi
            when "110"  => ctrl_by_funct3 <= ALU_OR;  -- or/ori
            when "100"  => ctrl_by_funct3 <= ALU_XOR; -- xor/xori
            when "001"  => ctrl_by_funct3 <= ALU_SLL; -- sll/slli
            when "101"  => ctrl_by_funct3 <= ALU_SRL; -- srl/srli
            when others => ctrl_by_funct3 <= ALU_ADD;
        end case;
    end process;

    process(opcode_i, funct3_i, funct7_i, ctrl_by_funct3)
    begin
        -- padrao: NOP (nao escreve nada)
        ALUSrc_o   <= '0';
        MemtoReg_o <= '0';
        RegWrite_o <= '0';
        MemRead_o  <= '0';
        MemWrite_o <= '0';
        Branch_o   <= '0';
        Jump_o     <= '0';
        Jalr_o     <= '0';
        Lui_o      <= '0';
        Auipc_o    <= '0';
        ALUCtrl_o  <= ALU_ADD;

        case opcode_i is
            when OP_RTYPE =>                 -- add sub and or xor sll srl
                RegWrite_o <= '1';
                if (funct3_i = "000" and funct7_i = "0100000") then
                    ALUCtrl_o <= ALU_SUB;   -- sub
                else
                    ALUCtrl_o <= ctrl_by_funct3;
                end if;

            when OP_IMM =>                   -- addi andi ori xori slli srli
                RegWrite_o <= '1';
                ALUSrc_o   <= '1';
                ALUCtrl_o  <= ctrl_by_funct3;

            when OP_LOAD =>                  -- lw
                RegWrite_o <= '1';
                MemtoReg_o <= '1';
                MemRead_o  <= '1';
                ALUSrc_o   <= '1';
                ALUCtrl_o  <= ALU_ADD;

            when OP_STORE =>                 -- sw
                MemWrite_o <= '1';
                ALUSrc_o   <= '1';
                ALUCtrl_o  <= ALU_ADD;

            when OP_BRANCH =>                -- beq bne
                Branch_o  <= '1';
                ALUCtrl_o <= ALU_SUB;

            when OP_JAL =>                   -- jal
                RegWrite_o <= '1';          -- grava PC+4
                Jump_o     <= '1';

            when OP_JALR =>                  -- jalr
                RegWrite_o <= '1';          -- grava PC+4
                Jump_o     <= '1';
                Jalr_o     <= '1';
                ALUSrc_o   <= '1';

            when OP_LUI =>                   -- lui: rd = imm
                RegWrite_o <= '1';
                ALUSrc_o   <= '1';
                Lui_o      <= '1';          -- operando A = 0  -> ADD => rd = imm
                ALUCtrl_o  <= ALU_ADD;

            when OP_AUIPC =>                 -- auipc: rd = PC + imm
                RegWrite_o <= '1';
                ALUSrc_o   <= '1';
                Auipc_o    <= '1';          -- operando A = PC
                ALUCtrl_o  <= ALU_ADD;

            when others =>
                null;
        end case;
    end process;
end Behavioral;
