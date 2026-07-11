library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- ============================================================================
-- Banco de 32 registradores de 32 bits.
--
-- Escrita na borda de subida (estagio WB). A leitura e' combinacional e
-- possui BYPASS de escrita-leitura ("write-through"): quando a instrucao em
-- WB escreve no mesmo registrador que esta' sendo lido no estagio ID, o dado
-- novo e' devolvido imediatamente. Isso resolve o hazard de dependencia com
-- 2 instrucoes de distancia, que o forwarding EX/MEM e MEM/WB nao cobre.
--
-- x0 sempre le 0 e nunca e' escrito.
-- ============================================================================
entity register_file is
    Port (
        clk   : in  STD_LOGIC;
        we    : in  STD_LOGIC;
        rs1   : in  STD_LOGIC_VECTOR (4 downto 0);
        rs2   : in  STD_LOGIC_VECTOR (4 downto 0);
        rd    : in  STD_LOGIC_VECTOR (4 downto 0);
        din   : in  STD_LOGIC_VECTOR (31 downto 0);
        dout1 : out STD_LOGIC_VECTOR (31 downto 0);
        dout2 : out STD_LOGIC_VECTOR (31 downto 0);
        -- Porta de leitura dedicada para depuracao (aferir estado interno)
        dbg_sel  : in  STD_LOGIC_VECTOR (4 downto 0);
        dbg_data : out STD_LOGIC_VECTOR (31 downto 0)
    );
end register_file;

architecture Behavioral of register_file is
    type reg_type is array (0 to 31) of STD_LOGIC_VECTOR (31 downto 0);
    signal registers : reg_type := (others => (others => '0'));
begin

    -- Leitura porta 1 (com bypass de escrita)
    dout1 <= (others => '0')                          when rs1 = "00000" else
             din                                       when (we = '1' and rd /= "00000" and rd = rs1) else
             registers(to_integer(unsigned(rs1)));

    -- Leitura porta 2 (com bypass de escrita)
    dout2 <= (others => '0')                          when rs2 = "00000" else
             din                                       when (we = '1' and rd /= "00000" and rd = rs2) else
             registers(to_integer(unsigned(rs2)));

    -- Leitura dedicada de depuracao: devolve o registrador escolhido por
    -- dbg_sel a qualquer momento (x0 sempre 0), independente do pipeline.
    dbg_data <= (others => '0') when dbg_sel = "00000" else
                registers(to_integer(unsigned(dbg_sel)));

    process (clk)
    begin
        if rising_edge(clk) then
            if we = '1' and rd /= "00000" then
                registers(to_integer(unsigned(rd))) <= din;
            end if;
        end if;
    end process;
end Behavioral;
