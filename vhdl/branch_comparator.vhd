library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity branch_comparator is
    Port (
        operand_a_i : in  STD_LOGIC_VECTOR (31 downto 0);
        operand_b_i : in  STD_LOGIC_VECTOR (31 downto 0);
        funct3_i    : in  STD_LOGIC_VECTOR (2 downto 0);
        branch_o    : out STD_LOGIC
    );
end branch_comparator;

architecture Behavioral of branch_comparator is
begin
    process(operand_a_i, operand_b_i, funct3_i)
    begin
        branch_o <= '0';
        case funct3_i is
            when "000" => -- BEQ (Branch if Equal)
                if (operand_a_i = operand_b_i) then 
                    branch_o <= '1'; 
                end if;
            when "001" => -- BNE (Branch if Not Equal)
                if (operand_a_i /= operand_b_i) then 
                    branch_o <= '1'; 
                end if;
            when others =>
                branch_o <= '0';
        end case;
    end process;
end Behavioral;