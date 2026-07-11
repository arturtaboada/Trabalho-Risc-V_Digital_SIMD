library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- ============================================================================
-- Banco de registradores VETORIAL: 32 x 128 bits (4 lanes de 32).
-- Leitura combinacional com BYPASS de escrita-leitura (write-through): se, no
-- mesmo ciclo, escreve-se em rd e le-se o mesmo endereco, a leitura ja' devolve
-- o dado novo, fechando o hazard de escrita/leitura no mesmo ciclo.
-- ============================================================================
entity vector_register_file is
    Port (
        clk         : in  STD_LOGIC;
        we          : in  STD_LOGIC;
        rs1         : in  STD_LOGIC_VECTOR (4 downto 0);
        rs2         : in  STD_LOGIC_VECTOR (4 downto 0);
        rd          : in  STD_LOGIC_VECTOR (4 downto 0);
        din         : in  STD_LOGIC_VECTOR (127 downto 0);
        dout1       : out STD_LOGIC_VECTOR (127 downto 0);
        dout2       : out STD_LOGIC_VECTOR (127 downto 0)
    );
end vector_register_file;

architecture Behavioral of vector_register_file is
    type vreg_type is array (0 to 31) of STD_LOGIC_VECTOR (127 downto 0);
    signal vregisters : vreg_type := (others => (others => '0'));
begin
    -- Leitura combinacional com bypass de escrita
    dout1 <= din when (we = '1' and rd = rs1) else
             vregisters(to_integer(unsigned(rs1)));
    dout2 <= din when (we = '1' and rd = rs2) else
             vregisters(to_integer(unsigned(rs2)));

    process (clk)
    begin
        if rising_edge(clk) then
            if we = '1' then
                vregisters(to_integer(unsigned(rd))) <= din;
            end if;
        end if;
    end process;
end Behavioral;
