library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity alu is
    Port (
        alu_op_i     : in  STD_LOGIC_VECTOR(3 downto 0);
        operand_a_i  : in  STD_LOGIC_VECTOR(31 downto 0);
        operand_b_i  : in  STD_LOGIC_VECTOR(31 downto 0);
        result_o     : out STD_LOGIC_VECTOR(31 downto 0);
        zero_o       : out STD_LOGIC;
        carry_debug_o: out STD_LOGIC 
    );
end alu;

architecture Behavioral of alu is
begin
    process(alu_op_i, operand_a_i, operand_b_i)
        variable temp_add : unsigned(32 downto 0);
    begin
        zero_o <= '0';
        carry_debug_o <= '0';
        
        case alu_op_i is
            when "0000" => -- ADD / ADDI / AUIPC / LW / SW
                temp_add := unsigned("0" & operand_a_i) + unsigned("0" & operand_b_i);
                result_o <= std_logic_vector(temp_add(31 downto 0));
                carry_debug_o <= std_logic(temp_add(32)); 
                
            when "0001" => -- SUB / BNE / BEQ
                result_o <= std_logic_vector(unsigned(operand_a_i) - unsigned(operand_b_i));
                if (operand_a_i = operand_b_i) then
                    zero_o <= '1';
                end if;
                
            when "0010" => -- AND / ANDI
                result_o <= operand_a_i and operand_b_i;
                
            when "0011" => -- OR / ORI
                result_o <= operand_a_i or operand_b_i;
                
            when "0100" => -- XOR / XORI
                result_o <= operand_a_i xor operand_b_i;
                
            when "0101" => -- SLL / SLLI
                result_o <= std_logic_vector(shift_left(unsigned(operand_a_i), to_integer(unsigned(operand_b_i(4 downto 0)))));
                
            when "0110" => -- SRL / SRLI
                result_o <= std_logic_vector(shift_right(unsigned(operand_a_i), to_integer(unsigned(operand_b_i(4 downto 0)))));
                
            when others =>
                result_o <= (others => '0');
        end case;
    end process;
end Behavioral;