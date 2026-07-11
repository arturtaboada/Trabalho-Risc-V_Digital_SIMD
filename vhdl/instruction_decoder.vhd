library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- ============================================================================
-- Decodificador RV32I + extensao VETORIAL.
-- Igual ao da Parte 1, porem o gerador de imediatos reconhece tambem os
-- opcodes vetoriais imediatos:
--   VEC_I = 0001011 (vaddi/vslli/vsrli) -> imediato tipo I
--   VEC_U = 0101011 (vauipc)            -> imediato tipo U
-- ============================================================================
entity instruction_decoder is
    Port (
        instr_i  : in  STD_LOGIC_VECTOR (31 downto 0);
        rs1_o    : out STD_LOGIC_VECTOR (4 downto 0);
        rs2_o    : out STD_LOGIC_VECTOR (4 downto 0);
        rd_o     : out STD_LOGIC_VECTOR (4 downto 0);
        opcode_o : out STD_LOGIC_VECTOR (6 downto 0);
        funct3_o : out STD_LOGIC_VECTOR (2 downto 0);
        funct7_o : out STD_LOGIC_VECTOR (6 downto 0);
        imm_o    : out STD_LOGIC_VECTOR (31 downto 0)
    );
end instruction_decoder;

architecture Behavioral of instruction_decoder is
    signal opcode : STD_LOGIC_VECTOR(6 downto 0);
begin
    opcode   <= instr_i(6 downto 0);
    opcode_o <= opcode;
    funct3_o <= instr_i(14 downto 12);
    funct7_o <= instr_i(31 downto 25);
    rd_o     <= instr_i(11 downto 7);
    rs1_o    <= instr_i(19 downto 15);
    rs2_o    <= instr_i(24 downto 20);

    process(instr_i, opcode)
    begin
        imm_o <= (others => '0');
        case opcode is
            -- I-type: lw, addi/andi/..., jalr  E TAMBEM vaddi/vslli/vsrli (0001011)
            when "0000011" | "0010011" | "1100111" | "0001011" =>
                imm_o <= std_logic_vector(resize(signed(instr_i(31 downto 20)), 32));

            when "0100011" => -- S-type (sw)
                imm_o <= std_logic_vector(resize(signed(instr_i(31 downto 25) & instr_i(11 downto 7)), 32));

            when "1100011" => -- B-type (beq, bne)
                imm_o <= std_logic_vector(resize(signed(instr_i(31) & instr_i(7) & instr_i(30 downto 25) & instr_i(11 downto 8) & '0'), 32));

            -- U-type: lui, auipc E TAMBEM vauipc (0101011)
            when "0110111" | "0010111" | "0101011" =>
                imm_o <= instr_i(31 downto 12) & "000000000000";

            when "1101111" => -- J-type (jal)
                imm_o <= std_logic_vector(resize(signed(instr_i(31) & instr_i(19 downto 12) & instr_i(20) & instr_i(30 downto 21) & '0'), 32));

            when others =>
                imm_o <= (others => '0');
        end case;
    end process;
end Behavioral;
