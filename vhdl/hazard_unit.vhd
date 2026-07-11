library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity hazard_unit is
    Port (
        IF_ID_Rs1_i     : in STD_LOGIC_VECTOR(4 downto 0);
        IF_ID_Rs2_i     : in STD_LOGIC_VECTOR(4 downto 0);
        ID_EX_Rd_i      : in STD_LOGIC_VECTOR(4 downto 0);
        ID_EX_MemRead_i : in STD_LOGIC;
        PCWrite_o       : out STD_LOGIC;
        IF_ID_Write_o   : out STD_LOGIC;
        ControlMux_o    : out STD_LOGIC
    );
end hazard_unit;

architecture Behavioral of hazard_unit is
begin
    process(IF_ID_Rs1_i, IF_ID_Rs2_i, ID_EX_Rd_i, ID_EX_MemRead_i)
    begin
        PCWrite_o <= '1';
        IF_ID_Write_o <= '1';
        ControlMux_o <= '0';

        -- Load-Use Hazard Detection
        if (ID_EX_MemRead_i = '1' and (ID_EX_Rd_i = IF_ID_Rs1_i or ID_EX_Rd_i = IF_ID_Rs2_i)) then
            PCWrite_o <= '0';
            IF_ID_Write_o <= '0';
            ControlMux_o <= '1'; 
        end if;
    end process;
end Behavioral;