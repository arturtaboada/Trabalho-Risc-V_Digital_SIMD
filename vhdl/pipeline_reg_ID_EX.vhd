library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- ============================================================================
-- Registrador de pipeline ID/EX.
--   we_i    : 0 congela (usado por load_enable_i)
--   flush_i : limpa o estagio (branch/jump tomado) inserindo bolha
--
-- A operacao da ALU chega ja' resolvida da unidade de controle no campo
-- ALUCtrl (4 bits). Propaga tambem os controles Jump, Jalr, Lui e Auipc.
-- ============================================================================
entity pipeline_reg_ID_EX is
    Port (
        clk_i       : in  STD_LOGIC;
        reset_i     : in  STD_LOGIC;
        we_i        : in  STD_LOGIC;
        flush_i     : in  STD_LOGIC;

        -- Controles de entrada
        RegWrite_i  : in  STD_LOGIC;
        MemtoReg_i  : in  STD_LOGIC;
        MemRead_i   : in  STD_LOGIC;
        MemWrite_i  : in  STD_LOGIC;
        Branch_i    : in  STD_LOGIC;
        Jump_i      : in  STD_LOGIC;
        Jalr_i      : in  STD_LOGIC;
        Lui_i       : in  STD_LOGIC;
        Auipc_i     : in  STD_LOGIC;
        ALUCtrl_i   : in  STD_LOGIC_VECTOR(3 downto 0);
        ALUSrc_i    : in  STD_LOGIC;

        -- Dados de entrada
        pc_i        : in  STD_LOGIC_VECTOR(31 downto 0);
        reg_data1_i : in  STD_LOGIC_VECTOR(31 downto 0);
        reg_data2_i : in  STD_LOGIC_VECTOR(31 downto 0);
        imm_i       : in  STD_LOGIC_VECTOR(31 downto 0);
        funct3_i    : in  STD_LOGIC_VECTOR(2 downto 0);
        rs1_i       : in  STD_LOGIC_VECTOR(4 downto 0);
        rs2_i       : in  STD_LOGIC_VECTOR(4 downto 0);
        rd_i        : in  STD_LOGIC_VECTOR(4 downto 0);

        -- Controles de saida
        RegWrite_o  : out STD_LOGIC;
        MemtoReg_o  : out STD_LOGIC;
        MemRead_o   : out STD_LOGIC;
        MemWrite_o  : out STD_LOGIC;
        Branch_o    : out STD_LOGIC;
        Jump_o      : out STD_LOGIC;
        Jalr_o      : out STD_LOGIC;
        Lui_o       : out STD_LOGIC;
        Auipc_o     : out STD_LOGIC;
        ALUCtrl_o   : out STD_LOGIC_VECTOR(3 downto 0);
        ALUSrc_o    : out STD_LOGIC;

        -- Dados de saida
        pc_o        : out STD_LOGIC_VECTOR(31 downto 0);
        reg_data1_o : out STD_LOGIC_VECTOR(31 downto 0);
        reg_data2_o : out STD_LOGIC_VECTOR(31 downto 0);
        imm_o       : out STD_LOGIC_VECTOR(31 downto 0);
        funct3_o    : out STD_LOGIC_VECTOR(2 downto 0);
        rs1_o       : out STD_LOGIC_VECTOR(4 downto 0);
        rs2_o       : out STD_LOGIC_VECTOR(4 downto 0);
        rd_o        : out STD_LOGIC_VECTOR(4 downto 0)
    );
end pipeline_reg_ID_EX;

architecture Behavioral of pipeline_reg_ID_EX is

    procedure clear(
        signal RegWrite_o : out STD_LOGIC; signal MemtoReg_o : out STD_LOGIC;
        signal MemRead_o  : out STD_LOGIC; signal MemWrite_o : out STD_LOGIC;
        signal Branch_o   : out STD_LOGIC; signal Jump_o     : out STD_LOGIC;
        signal Jalr_o     : out STD_LOGIC; signal Lui_o      : out STD_LOGIC;
        signal Auipc_o    : out STD_LOGIC; signal ALUCtrl_o  : out STD_LOGIC_VECTOR(3 downto 0);
        signal ALUSrc_o   : out STD_LOGIC) is
    begin
        RegWrite_o <= '0'; MemtoReg_o <= '0'; MemRead_o <= '0'; MemWrite_o <= '0';
        Branch_o <= '0'; Jump_o <= '0'; Jalr_o <= '0'; Lui_o <= '0'; Auipc_o <= '0';
        ALUCtrl_o <= "0000"; ALUSrc_o <= '0';
    end procedure;

begin
    process(clk_i, reset_i)
    begin
        if reset_i = '1' then
            clear(RegWrite_o, MemtoReg_o, MemRead_o, MemWrite_o, Branch_o,
                  Jump_o, Jalr_o, Lui_o, Auipc_o, ALUCtrl_o, ALUSrc_o);
            pc_o <= (others => '0'); reg_data1_o <= (others => '0');
            reg_data2_o <= (others => '0'); imm_o <= (others => '0');
            funct3_o <= "000"; rs1_o <= "00000"; rs2_o <= "00000"; rd_o <= "00000";

        elsif rising_edge(clk_i) then
            if we_i = '1' then
                if flush_i = '1' then
                    clear(RegWrite_o, MemtoReg_o, MemRead_o, MemWrite_o, Branch_o,
                          Jump_o, Jalr_o, Lui_o, Auipc_o, ALUCtrl_o, ALUSrc_o);
                    pc_o <= (others => '0'); reg_data1_o <= (others => '0');
                    reg_data2_o <= (others => '0'); imm_o <= (others => '0');
                    funct3_o <= "000"; rs1_o <= "00000"; rs2_o <= "00000"; rd_o <= "00000";
                else
                    RegWrite_o <= RegWrite_i; MemtoReg_o <= MemtoReg_i;
                    MemRead_o  <= MemRead_i;  MemWrite_o <= MemWrite_i;
                    Branch_o   <= Branch_i;   Jump_o     <= Jump_i;
                    Jalr_o     <= Jalr_i;     Lui_o      <= Lui_i;
                    Auipc_o    <= Auipc_i;    ALUCtrl_o  <= ALUCtrl_i;
                    ALUSrc_o   <= ALUSrc_i;
                    pc_o <= pc_i; reg_data1_o <= reg_data1_i; reg_data2_o <= reg_data2_i;
                    imm_o <= imm_i; funct3_o <= funct3_i;
                    rs1_o <= rs1_i; rs2_o <= rs2_i; rd_o <= rd_i;
                end if;
            end if;
        end if;
    end process;
end Behavioral;
