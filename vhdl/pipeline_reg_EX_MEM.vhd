library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity pipeline_reg_EX_MEM is
    Port (
        clk_i       : in  STD_LOGIC;
        reset_i     : in  STD_LOGIC;
        we_i        : in  STD_LOGIC; -- Habilita escrita (0 = congela, p/ load_enable)

        -- Controles
        RegWrite_i  : in  STD_LOGIC;
        MemtoReg_i  : in  STD_LOGIC;
        MemRead_i   : in  STD_LOGIC;
        MemWrite_i  : in  STD_LOGIC;
        
        -- Dados
        alu_result_i: in  STD_LOGIC_VECTOR(31 downto 0);
        reg_data2_i : in  STD_LOGIC_VECTOR(31 downto 0); -- Dado para instrução Store
        rd_i        : in  STD_LOGIC_VECTOR(4 downto 0);

        -- Controles de saída
        RegWrite_o  : out STD_LOGIC;
        MemtoReg_o  : out STD_LOGIC;
        MemRead_o   : out STD_LOGIC;
        MemWrite_o  : out STD_LOGIC;
        
        -- Dados de saída
        alu_result_o: out STD_LOGIC_VECTOR(31 downto 0);
        reg_data2_o : out STD_LOGIC_VECTOR(31 downto 0);
        rd_o        : out STD_LOGIC_VECTOR(4 downto 0)
    );
end pipeline_reg_EX_MEM;

architecture Behavioral of pipeline_reg_EX_MEM is
begin
    process(clk_i, reset_i)
    begin
        if reset_i = '1' then
            RegWrite_o <= '0'; MemtoReg_o <= '0'; MemRead_o <= '0'; MemWrite_o <= '0';
            alu_result_o <= (others => '0'); reg_data2_o <= (others => '0'); rd_o <= "00000";
        elsif rising_edge(clk_i) then
            if we_i = '1' then
                RegWrite_o <= RegWrite_i; MemtoReg_o <= MemtoReg_i;
                MemRead_o <= MemRead_i; MemWrite_o <= MemWrite_i;
                alu_result_o <= alu_result_i; reg_data2_o <= reg_data2_i; rd_o <= rd_i;
            end if;
        end if;
    end process;
end Behavioral;