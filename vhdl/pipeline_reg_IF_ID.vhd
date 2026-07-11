library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity pipeline_reg_IF_ID is
    Port (
        clk_i       : in  STD_LOGIC;
        reset_i     : in  STD_LOGIC;
        we_i        : in  STD_LOGIC; -- Vem do Hazard Unit
        flush_i     : in  STD_LOGIC; -- Ativado em saltos tomados
        pc_i        : in  STD_LOGIC_VECTOR (31 downto 0);
        instr_i     : in  STD_LOGIC_VECTOR (31 downto 0);
        pc_o        : out STD_LOGIC_VECTOR (31 downto 0);
        instr_o     : out STD_LOGIC_VECTOR (31 downto 0)
    );
end pipeline_reg_IF_ID;

architecture Behavioral of pipeline_reg_IF_ID is
begin
    process(clk_i, reset_i)
    begin
        if reset_i = '1' then
            pc_o <= (others => '0');
            instr_o <= (others => '0');
        elsif rising_edge(clk_i) then
            if flush_i = '1' then
                pc_o <= (others => '0');
                -- Insere instrução NOP (addi x0, x0, 0)
                instr_o <= "00000000000000000000000000010011"; 
            elsif we_i = '1' then
                pc_o <= pc_i;
                instr_o <= instr_i;
            end if;
        end if;
    end process;
end Behavioral;