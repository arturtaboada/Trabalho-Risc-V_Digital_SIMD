library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity program_counter is
    Port (
        clk_i   : in  STD_LOGIC;
        reset_i : in  STD_LOGIC;
        we_i    : in  STD_LOGIC; -- Permite congelar o PC em caso de hazard
        din_i   : in  STD_LOGIC_VECTOR (31 downto 0);
        dout_o  : out STD_LOGIC_VECTOR (31 downto 0)
    );
end program_counter;

architecture Behavioral of program_counter is
    signal pc_reg : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
begin
    process(clk_i, reset_i)
    begin
        if reset_i = '1' then
            pc_reg <= (others => '0');
        elsif rising_edge(clk_i) then
            if we_i = '1' then
                pc_reg <= din_i;
            end if;
        end if;
    end process;
    
    dout_o <= pc_reg;
end Behavioral;