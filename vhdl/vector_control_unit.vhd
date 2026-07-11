library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- ============================================================================
-- Unidade de Controle VETORIAL (SIMD).
-- Reconhece os opcodes customizados e gera os controles do caminho vetorial.
-- Opcodes:
--   VEC_R = 1011011 : vadd/vsub/vsll/vsrl      (registrador-registrador)
--   VEC_I = 0001011 : vaddi/vslli/vsrli        (imediato transmitido/broadcast)
--   VEC_U = 0101011 : vauipc                   (PC+imm transmitido/broadcast)
-- Sai is_vector=1 nesses casos; para o resto o caminho escalar opera normal.
--
-- valu_op (igual a' vector_alu): 0000 ADD  0001 SUB  0101 SLL  0110 SRL
-- ============================================================================
entity vector_control_unit is
    Port (
        opcode_i    : in  STD_LOGIC_VECTOR(6 downto 0);
        funct3_i    : in  STD_LOGIC_VECTOR(2 downto 0);
        funct7_i    : in  STD_LOGIC_VECTOR(6 downto 0);

        is_vector_o : out STD_LOGIC;                    -- 1 = instrucao vetorial
        vreg_write_o: out STD_LOGIC;                    -- 1 = escreve no banco vetorial
        valu_src_o  : out STD_LOGIC;                    -- 1 = operando B = imediato broadcast
        vauipc_o    : out STD_LOGIC;                    -- 1 = operando A = broadcast(PC+imm)
        valu_op_o   : out STD_LOGIC_VECTOR(3 downto 0)
    );
end vector_control_unit;

architecture Behavioral of vector_control_unit is
    constant VEC_R : STD_LOGIC_VECTOR(6 downto 0) := "1011011";
    constant VEC_I : STD_LOGIC_VECTOR(6 downto 0) := "0001011";
    constant VEC_U : STD_LOGIC_VECTOR(6 downto 0) := "0101011";

    constant V_ADD : STD_LOGIC_VECTOR(3 downto 0) := "0000";
    constant V_SUB : STD_LOGIC_VECTOR(3 downto 0) := "0001";
    constant V_SLL : STD_LOGIC_VECTOR(3 downto 0) := "0101";
    constant V_SRL : STD_LOGIC_VECTOR(3 downto 0) := "0110";

    function op_from_f3(f3 : STD_LOGIC_VECTOR(2 downto 0)) return STD_LOGIC_VECTOR is
    begin
        case f3 is
            when "001"  => return V_SLL;
            when "101"  => return V_SRL;
            when others => return V_ADD;  -- 000
        end case;
    end function;
begin
    process(opcode_i, funct3_i, funct7_i)
    begin
        is_vector_o  <= '0';
        vreg_write_o <= '0';
        valu_src_o   <= '0';
        vauipc_o     <= '0';
        valu_op_o    <= V_ADD;

        case opcode_i is
            when VEC_R =>
                is_vector_o  <= '1';
                vreg_write_o <= '1';
                valu_src_o   <= '0';
                if funct3_i = "000" and funct7_i = "0100000" then
                    valu_op_o <= V_SUB;
                else
                    valu_op_o <= op_from_f3(funct3_i);
                end if;

            when VEC_I =>
                is_vector_o  <= '1';
                vreg_write_o <= '1';
                valu_src_o   <= '1';               -- operando B = imediato
                valu_op_o    <= op_from_f3(funct3_i);

            when VEC_U =>
                is_vector_o  <= '1';
                vreg_write_o <= '1';
                vauipc_o     <= '1';               -- operando A = broadcast(PC+imm)
                valu_op_o    <= V_ADD;

            when others =>
                null;
        end case;
    end process;
end Behavioral;
