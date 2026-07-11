library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity pipeline_reg_MEM_WB is
    Port (
        clk_i       : in  STD_LOGIC;
        reset_i     : in  STD_LOGIC;
        we_i        : in  STD_LOGIC; -- Habilita escrita (0 = congela, p/ load_enable)

        -- Controles (Apenas o que vai para o Banco de Registradores)
        RegWrite_i  : in  STD_LOGIC;
        MemtoReg_i  : in  STD_LOGIC;
        
        -- Dados
        read_data_i : in  STD_LOGIC_VECTOR(31 downto 0); -- Dado lido da RAM
        alu_result_i: in  STD_LOGIC_VECTOR(31 downto 0); -- Dado direto da ALU
        rd_i        : in  STD_LOGIC_VECTOR(4 downto 0);

        -- Controles de saída
        RegWrite_o  : out STD_LOGIC;
        MemtoReg_o  : out STD_LOGIC;
        
        -- Dados de saída
        read_data_o : out STD_LOGIC_VECTOR(31 downto 0);
        alu_result_o: out STD_LOGIC_VECTOR(31 downto 0);
        rd_o        : out STD_LOGIC_VECTOR(4 downto 0)
    );
end pipeline_reg_MEM_WB;

architecture Behavioral of pipeline_reg_MEM_WB is
begin
    process(clk_i, reset_i)
    begin
        if reset_i = '1' then
            RegWrite_o <= '0'; MemtoReg_o <= '0';
            read_data_o <= (others => '0'); alu_result_o <= (others => '0'); rd_o <= "00000";
        elsif rising_edge(clk_i) then
            if we_i = '1' then
                RegWrite_o <= RegWrite_i; MemtoReg_o <= MemtoReg_i;
                read_data_o <= read_data_i; alu_result_o <= alu_result_i; rd_o <= rd_i;
            end if;
        end if;
    end process;
end Behavioral;