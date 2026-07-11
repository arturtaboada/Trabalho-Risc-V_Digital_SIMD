library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity forwarding_unit is
    Port (
        ID_EX_Rs1_i      : in STD_LOGIC_VECTOR(4 downto 0);
        ID_EX_Rs2_i      : in STD_LOGIC_VECTOR(4 downto 0);
        EX_MEM_Rd_i      : in STD_LOGIC_VECTOR(4 downto 0);
        MEM_WB_Rd_i      : in STD_LOGIC_VECTOR(4 downto 0);
        EX_MEM_RegWrite_i: in STD_LOGIC;
        MEM_WB_RegWrite_i: in STD_LOGIC;
        ForwardA_o       : out STD_LOGIC_VECTOR(1 downto 0);
        ForwardB_o       : out STD_LOGIC_VECTOR(1 downto 0)
    );
end forwarding_unit;

architecture Behavioral of forwarding_unit is
begin
    process(ID_EX_Rs1_i, ID_EX_Rs2_i, EX_MEM_Rd_i, MEM_WB_Rd_i, EX_MEM_RegWrite_i, MEM_WB_RegWrite_i)
    begin
        ForwardA_o <= "00";
        ForwardB_o <= "00";

        -- EX Hazard Entrada A
        if (EX_MEM_RegWrite_i = '1' and EX_MEM_Rd_i /= "00000" and EX_MEM_Rd_i = ID_EX_Rs1_i) then
            ForwardA_o <= "10";
        -- MEM Hazard Entrada A
        elsif (MEM_WB_RegWrite_i = '1' and MEM_WB_Rd_i /= "00000" and MEM_WB_Rd_i = ID_EX_Rs1_i) then
            ForwardA_o <= "01";
        end if;

        -- EX Hazard Entrada B
        if (EX_MEM_RegWrite_i = '1' and EX_MEM_Rd_i /= "00000" and EX_MEM_Rd_i = ID_EX_Rs2_i) then
            ForwardB_o <= "10";
        -- MEM Hazard Entrada B
        elsif (MEM_WB_RegWrite_i = '1' and MEM_WB_Rd_i /= "00000" and MEM_WB_Rd_i = ID_EX_Rs2_i) then
            ForwardB_o <= "01";
        end if;
    end process;
end Behavioral;