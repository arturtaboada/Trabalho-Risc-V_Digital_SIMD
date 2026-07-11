library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity vector_alu is
    Port (
        alu_op_i     : in  STD_LOGIC_VECTOR(3 downto 0);
        operand_a_i  : in  STD_LOGIC_VECTOR(127 downto 0);
        operand_b_i  : in  STD_LOGIC_VECTOR(127 downto 0);
        result_o     : out STD_LOGIC_VECTOR(127 downto 0)
    );
end vector_alu;

architecture Behavioral of vector_alu is
    -- Separa os 128 bits em 4 caminhos paralelos de 32 bits (SIMD Lanes)
    signal a0, a1, a2, a3 : unsigned(31 downto 0);
    signal b0, b1, b2, b3 : unsigned(31 downto 0);
    signal r0, r1, r2, r3 : unsigned(31 downto 0);
begin
    a0 <= unsigned(operand_a_i(31 downto 0));
    a1 <= unsigned(operand_a_i(63 downto 32));
    a2 <= unsigned(operand_a_i(95 downto 64));
    a3 <= unsigned(operand_a_i(127 downto 96));

    b0 <= unsigned(operand_b_i(31 downto 0));
    b1 <= unsigned(operand_b_i(63 downto 32));
    b2 <= unsigned(operand_b_i(95 downto 64));
    b3 <= unsigned(operand_b_i(127 downto 96));

    process(alu_op_i, a0, a1, a2, a3, b0, b1, b2, b3)
    begin
        case alu_op_i is
            when "0000" => -- VADD / VADDI / VAUIPC
                r0 <= a0 + b0; r1 <= a1 + b1; r2 <= a2 + b2; r3 <= a3 + b3;
            when "0001" => -- VSUB
                r0 <= a0 - b0; r1 <= a1 - b1; r2 <= a2 - b2; r3 <= a3 - b3;
            when "0101" => -- VSLL / VSLLI (Shift Vetorial Esq)
                r0 <= shift_left(a0, to_integer(b0(4 downto 0)));
                r1 <= shift_left(a1, to_integer(b1(4 downto 0)));
                r2 <= shift_left(a2, to_integer(b2(4 downto 0)));
                r3 <= shift_left(a3, to_integer(b3(4 downto 0)));
            when "0110" => -- VSRL / VSRLI (Shift Vetorial Dir)
                r0 <= shift_right(a0, to_integer(b0(4 downto 0)));
                r1 <= shift_right(a1, to_integer(b1(4 downto 0)));
                r2 <= shift_right(a2, to_integer(b2(4 downto 0)));
                r3 <= shift_right(a3, to_integer(b3(4 downto 0)));
            when others =>
                r0 <= (others => '0'); r1 <= (others => '0'); 
                r2 <= (others => '0'); r3 <= (others => '0');
        end case;
    end process;

    -- Concatena os 4 caminhos devolvendo os 128 bits processados simultaneamente
    result_o <= std_logic_vector(r3) & std_logic_vector(r2) & std_logic_vector(r1) & std_logic_vector(r0);

end Behavioral;