library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- ============================================================================
-- Registradores de pipeline do caminho VETORIAL.
-- Estrutura espelhando o escalar: ID/EX -> EX/MEM -> MEM/WB, todos com
--   we_i    : 0 congela (usado por load_enable_i, mantendo o freeze coerente)
--   reset_i : zera o estagio
--   flush_i : (apenas ID/EX) insere bolha em desvio/salto tomado
-- ============================================================================

-- ------------------------- ID/EX -------------------------
entity vector_pipeline_reg_ID_EX is
    Port (
        clk_i        : in  STD_LOGIC;
        reset_i      : in  STD_LOGIC;
        we_i         : in  STD_LOGIC;
        flush_i      : in  STD_LOGIC;

        vreg_write_i : in  STD_LOGIC;
        valu_op_i    : in  STD_LOGIC_VECTOR(3 downto 0);
        valu_src_i   : in  STD_LOGIC;
        vauipc_i     : in  STD_LOGIC;
        vdata1_i     : in  STD_LOGIC_VECTOR(127 downto 0);
        vdata2_i     : in  STD_LOGIC_VECTOR(127 downto 0);
        vrs1_i       : in  STD_LOGIC_VECTOR(4 downto 0);
        vrs2_i       : in  STD_LOGIC_VECTOR(4 downto 0);
        vrd_i        : in  STD_LOGIC_VECTOR(4 downto 0);

        vreg_write_o : out STD_LOGIC;
        valu_op_o    : out STD_LOGIC_VECTOR(3 downto 0);
        valu_src_o   : out STD_LOGIC;
        vauipc_o     : out STD_LOGIC;
        vdata1_o     : out STD_LOGIC_VECTOR(127 downto 0);
        vdata2_o     : out STD_LOGIC_VECTOR(127 downto 0);
        vrs1_o       : out STD_LOGIC_VECTOR(4 downto 0);
        vrs2_o       : out STD_LOGIC_VECTOR(4 downto 0);
        vrd_o        : out STD_LOGIC_VECTOR(4 downto 0)
    );
end vector_pipeline_reg_ID_EX;

architecture Behavioral of vector_pipeline_reg_ID_EX is
    procedure clear(
        signal vw : out STD_LOGIC; signal op : out STD_LOGIC_VECTOR(3 downto 0);
        signal sr : out STD_LOGIC; signal au : out STD_LOGIC;
        signal d1 : out STD_LOGIC_VECTOR(127 downto 0); signal d2 : out STD_LOGIC_VECTOR(127 downto 0);
        signal s1 : out STD_LOGIC_VECTOR(4 downto 0); signal s2 : out STD_LOGIC_VECTOR(4 downto 0);
        signal rd : out STD_LOGIC_VECTOR(4 downto 0)) is
    begin
        vw <= '0'; op <= "0000"; sr <= '0'; au <= '0';
        d1 <= (others => '0'); d2 <= (others => '0');
        s1 <= "00000"; s2 <= "00000"; rd <= "00000";
    end procedure;
begin
    process(clk_i, reset_i)
    begin
        if reset_i = '1' then
            clear(vreg_write_o, valu_op_o, valu_src_o, vauipc_o, vdata1_o, vdata2_o, vrs1_o, vrs2_o, vrd_o);
        elsif rising_edge(clk_i) then
            if we_i = '1' then
                if flush_i = '1' then
                    clear(vreg_write_o, valu_op_o, valu_src_o, vauipc_o, vdata1_o, vdata2_o, vrs1_o, vrs2_o, vrd_o);
                else
                    vreg_write_o <= vreg_write_i;
                    valu_op_o    <= valu_op_i;
                    valu_src_o   <= valu_src_i;
                    vauipc_o     <= vauipc_i;
                    vdata1_o     <= vdata1_i;
                    vdata2_o     <= vdata2_i;
                    vrs1_o       <= vrs1_i;
                    vrs2_o       <= vrs2_i;
                    vrd_o        <= vrd_i;
                end if;
            end if;
        end if;
    end process;
end Behavioral;


-- ------------------------- EX/MEM -------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity vector_pipeline_reg_EX_MEM is
    Port (
        clk_i        : in  STD_LOGIC;
        reset_i      : in  STD_LOGIC;
        we_i         : in  STD_LOGIC;

        vreg_write_i : in  STD_LOGIC;
        vresult_i    : in  STD_LOGIC_VECTOR(127 downto 0);
        vrd_i        : in  STD_LOGIC_VECTOR(4 downto 0);

        vreg_write_o : out STD_LOGIC;
        vresult_o    : out STD_LOGIC_VECTOR(127 downto 0);
        vrd_o        : out STD_LOGIC_VECTOR(4 downto 0)
    );
end vector_pipeline_reg_EX_MEM;

architecture Behavioral of vector_pipeline_reg_EX_MEM is
begin
    process(clk_i, reset_i)
    begin
        if reset_i = '1' then
            vreg_write_o <= '0'; vresult_o <= (others => '0'); vrd_o <= "00000";
        elsif rising_edge(clk_i) then
            if we_i = '1' then
                vreg_write_o <= vreg_write_i;
                vresult_o    <= vresult_i;
                vrd_o        <= vrd_i;
            end if;
        end if;
    end process;
end Behavioral;


-- ------------------------- MEM/WB -------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity vector_pipeline_reg_MEM_WB is
    Port (
        clk_i        : in  STD_LOGIC;
        reset_i      : in  STD_LOGIC;
        we_i         : in  STD_LOGIC;

        vreg_write_i : in  STD_LOGIC;
        vresult_i    : in  STD_LOGIC_VECTOR(127 downto 0);
        vrd_i        : in  STD_LOGIC_VECTOR(4 downto 0);

        vreg_write_o : out STD_LOGIC;
        vresult_o    : out STD_LOGIC_VECTOR(127 downto 0);
        vrd_o        : out STD_LOGIC_VECTOR(4 downto 0)
    );
end vector_pipeline_reg_MEM_WB;

architecture Behavioral of vector_pipeline_reg_MEM_WB is
begin
    process(clk_i, reset_i)
    begin
        if reset_i = '1' then
            vreg_write_o <= '0'; vresult_o <= (others => '0'); vrd_o <= "00000";
        elsif rising_edge(clk_i) then
            if we_i = '1' then
                vreg_write_o <= vreg_write_i;
                vresult_o    <= vresult_i;
                vrd_o        <= vrd_i;
            end if;
        end if;
    end process;
end Behavioral;
