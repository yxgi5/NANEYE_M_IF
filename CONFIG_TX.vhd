--------------------------------------------------------------------------------
-- AWAIBA GmbH
--------------------------------------------------------------------------------
-- MODUL NAME:  CONFIG_TX
-- FILENAME:    config_tx.vhd
-- AUTHOR:      Michael Heil - Ing. B黵o f黵 FPGA-Logic-Design
--              email:  michael.heil@fpga-logic-design.de
--
-- CREATED:     18.02.2010
--------------------------------------------------------------------------------
-- DESCRIPTION: transmits configuration to the naneye2b sensor
--
--
--------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------
-- REVISIONS:
-- DATE         VERSION    AUTHOR      DESCRIPTION
-- 19.02.2010   01         M. Heil     Initial version
-- 02.01.2011   02         M. Heil     START input asynchronous
-- 14.03.2012   03         M. Heil     Activation of TX_OE until the start of
--                                     the next frame
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
-- use WORK.SENSOR_PROPERTIES_PKG.all;


entity CONFIG_TX is
  generic (
    CLOCK_PERIOD_PS:            integer:=10000;                                 -- system clock period
    BIT_PERIOD_NS:              integer:=10000;                                 -- data rate
    C_NO_CFG_BITS:              integer:=24;                                    -- serial bits
    --C_REG_CFG_BITS:             integer:=3;                                   -- don't change, 3 bit config reg address
    --IDLE_PERIOD_MAX_NS:         integer:=500000000;                             -- wait if no input, then send gain
    IDLE_PERIOD_MAX_NS:         integer:=500000000;                             -- wait if no input, then send gain
    CFG_REGS:                   integer:=2);                                    -- don't change, naneye-m has 2 regs, each reg has 16 bit

  port (
    RESET:                      in  std_logic;                                  -- async. reset
    CLOCK:                      in  std_logic;                                  -- system clock
    START:                      in  std_logic;                                  -- start of transmission (async. pulse)
    LINE_PERIOD:                in  std_logic_vector(15 downto 0);              -- line period in # of CLOCK cycles
    --INPUT:                      in  std_logic_vector(C_NO_CFG_BITS-1 downto 0); -- parallel tx data
    INPUT:                      in  std_logic_vector(15 downto 0);              -- parallel tx reg data
    RD_ADDR:                    out std_logic_vector(2 downto 0);               -- parallel tx read addr
    RD_EN:                      out std_logic;                                  -- parallel tx read enable
    TX_END:                     out std_logic;                                  -- signals end of transmission (pulse)
    TX_DAT:                     out std_logic;                                  -- serial tx data => sensor
    TX_CLK:                     out std_logic;                                  -- shift clock => sensor
    TX_OE:                      out std_logic);                                 -- output enable for TX_DAT & TX_CLK
end entity CONFIG_TX;


architecture RTL of CONFIG_TX is

subtype T_BIT_CNT is            integer range 0 to C_NO_CFG_BITS;
--constant C_CLK_DIV:             integer:=((BIT_PERIOD_NS*1000) / (2*CLOCK_PERIOD_PS));
constant C_CLK_DIV:             integer:=((((BIT_PERIOD_NS*1000) / (2*CLOCK_PERIOD_PS))+1)/2)*2; -- 确保是偶数分频
constant C_UPDATE_CODE:         std_logic_vector(3 downto 0):="1001";
-- constant C_WAIT_PERIOD_MAX:     integer:= IDLE_PERIOD_MAX_NS*1000/CLOCK_PERIOD_PS;
constant C_WAIT_PERIOD_MAX:     integer:= (IDLE_PERIOD_MAX_NS/CLOCK_PERIOD_PS)*1000;
-- constant C_WAIT_PERIOD_MAX:     std_logic_vector(31 downto 0):=conv_std_logic_vector((IDLE_PERIOD_MAX_NS/CLOCK_PERIOD_PS)*1000,32); 

component CLK_DIV is
   generic (
      DIV:                      integer:=16);
   port (
      RESET:                    in  std_logic;
      CLOCK:                    in  std_logic;
      ENABLE:                   in  std_logic;
      PULSE:                    out std_logic);
end component CLK_DIV;

signal I_IDLE_WATI_TIMEOUT:     std_logic;
signal I_IDLE_WATI_TIMEOUT_1:   std_logic;
signal I_IDLE_WATI_TIMEOUT_CNT: std_logic_vector(32 downto 0);
signal I_START_1:               std_logic;
signal I_START_2:               std_logic;
signal I_START_3:               std_logic;
signal I_START_P:               std_logic;
signal I_TX_START_P:            std_logic;
signal I_TX_START:              std_logic;
signal I_START_P_SCK:           std_logic;
signal I_START_P_SCK_1:         std_logic;
signal I_START_P_SCK_CNT:       std_logic_vector(1 downto 0);
signal I_ENABLE:                std_logic;
signal I_PULSE:                 std_logic;
signal I_PULSE_1:               std_logic;
signal I_SHIFT_EN:               std_logic;
--signal I_PULSE_2:               std_logic;
--signal I_PULSE_3:               std_logic;
signal I_PULSE_P:               std_logic;
signal I_PULSE_N:               std_logic;
signal I_BIT_CNT:               T_BIT_CNT;
signal I_SREG:                  std_logic_vector(C_NO_CFG_BITS-1 downto 0);
signal I_REG_CNT:               std_logic_vector(2 downto 0);       --  range must bigger than CFG_REGS
signal I_REG_CNT_PRE:           std_logic_vector(2 downto 0);       --  range must bigger than CFG_REGS
--signal I_TX_CLK:                std_logic;
signal I_REG_CNT_ADD_F:          std_logic;
signal I_TX_OE:                 std_logic;
signal I_TX_OE_1:               std_logic;
signal I_CFG_PERIOD:            std_logic;
signal I_CFG_PERIOD_1:          std_logic;
signal I_CFG_PERIOD_CNT:        std_logic_vector(16 downto 0);
signal I_CFG_PERIOD_END:        std_logic_vector(16 downto 0);
signal I_SET_TX_CLK:            std_logic;
signal I_RD_ADDR:               std_logic_vector(2 downto 0);       --  range must bigger than CFG_REGS, 考虑和 I_REG_CNT合并
--signal I_UPDATE_CODE:           std_logic_vector(3 downto 0);
signal I_RD_EN:                 std_logic;
signal I_RD_EN_1:               std_logic;

begin

--------------------------------------------------------------------------------
-- handle timeout
--------------------------------------------------------------------------------
TIME_OUT: process(RESET,CLOCK)
begin
    if (RESET = '1') then
        I_IDLE_WATI_TIMEOUT <= '0';
        I_IDLE_WATI_TIMEOUT_1 <= '0';
        I_IDLE_WATI_TIMEOUT_CNT <= (others => '0');
    elsif (rising_edge(CLOCK)) then
        I_IDLE_WATI_TIMEOUT_1 <= I_IDLE_WATI_TIMEOUT;
        if(I_START_P = '1') then
            I_IDLE_WATI_TIMEOUT_CNT <= (others => '0');
        elsif (I_IDLE_WATI_TIMEOUT_CNT = C_WAIT_PERIOD_MAX) then
            I_IDLE_WATI_TIMEOUT_CNT <= (others => '0');
            if (I_CFG_PERIOD = '0') then
                I_IDLE_WATI_TIMEOUT <= '1';
            else
                I_IDLE_WATI_TIMEOUT <= '0';
            end if;
        else
            I_IDLE_WATI_TIMEOUT_CNT <= I_IDLE_WATI_TIMEOUT_CNT + 1;
            I_IDLE_WATI_TIMEOUT <= '0';
        end if;
    end if;
end process TIME_OUT;

--------------------------------------------------------------------------------
-- synchronization of START signal
--------------------------------------------------------------------------------
START_SYNC: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_START_1 <= '0';
    I_START_2 <= '0';
    I_START_3 <= '0';
  elsif (rising_edge(CLOCK)) then
    I_START_1 <= START;
    I_START_2 <= I_START_1;
    I_START_3 <= I_START_2;
  end if;
end process START_SYNC;

I_START_P <= (I_START_2 and not I_START_3) or (I_IDLE_WATI_TIMEOUT and not I_IDLE_WATI_TIMEOUT_1);


--------------------------------------------------------------------------------
-- generation of divided clock
--------------------------------------------------------------------------------
I_CLK_DIV: CLK_DIV
   generic map (
      DIV                       => C_CLK_DIV)
   port map (
      RESET                     => RESET,
      CLOCK                     => CLOCK,
      ENABLE                    => I_ENABLE,
      PULSE                     => I_PULSE);


--------------------------------------------------------------------------------
-- synchronization of I_PULSE signal
--------------------------------------------------------------------------------
I_PULSE_SYNC: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_PULSE_1 <= '0';
    --I_PULSE_2 <= '0';
    --I_PULSE_3 <= '0';
  elsif (rising_edge(CLOCK)) then
    I_PULSE_1 <= I_PULSE;
    --I_PULSE_2 <= I_PULSE_1;
    --I_PULSE_3 <= I_PULSE_2;
  end if;
end process I_PULSE_SYNC;

I_PULSE_P <= I_PULSE and not I_PULSE_1;
I_PULSE_N <= not I_PULSE and I_PULSE_1;

--------------------------------------------
ENABLE_EVAL_PREPARE: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_ENABLE <= '0';
    I_TX_START <= '0';
    I_START_P_SCK <= '0';
    I_START_P_SCK_1 <= '0';
    I_START_P_SCK_CNT <= (others => '0');
    I_SHIFT_EN <= '0';
  else
    if (rising_edge(CLOCK)) then
        I_START_P_SCK_1 <= I_START_P_SCK;
        if ((I_PULSE_P = '1') and (I_START_P_SCK = '1')) then
            if (I_START_P_SCK_CNT = 2) then
                I_START_P_SCK_CNT <= (others => '0');
                I_START_P_SCK <= '0';
                I_TX_START <= '1';
            elsif (I_PULSE_P = '1') then
                I_START_P_SCK_CNT <= I_START_P_SCK_CNT + 1;
            end if;
        elsif (I_START_P) then
            I_START_P_SCK <= '1';
            I_ENABLE <= '1';
        elsif ((I_BIT_CNT = C_NO_CFG_BITS-1) and (I_PULSE_N = '1')) then
	        if (I_REG_CNT = CFG_REGS-1) then
                  I_ENABLE <= '0';
	        end if;
            I_TX_START <= '0';
            I_SHIFT_EN <= '0';
        elsif ((I_REG_CNT_ADD_F = '1') and (I_PULSE_P = '1')) then
            I_TX_START <= '1';
        else
          if ((I_TX_START = '1') and (I_PULSE_P = '1')) then
            I_SHIFT_EN <= '1';
          end if;
            I_ENABLE <= I_ENABLE;
        end if;
     end if;
  end if;
end process ENABLE_EVAL_PREPARE;
I_TX_START_P <= not I_START_P_SCK and I_START_P_SCK_1;



--------------------------------------------------------------------------------
-- Activate I_ENABLE after receiving a start-pulse
--------------------------------------------------------------------------------
ENABLE_EVAL: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_REG_CNT <= (others => '0');
    I_REG_CNT_PRE <= (others => '0');
    I_REG_CNT_ADD_F <= '0';
  elsif (rising_edge(CLOCK)) then
    -- if ((I_BIT_CNT = C_NO_CFG_BITS-1) and (I_TX_CLK = '1') and (I_PULSE = '1')) then
    if ((I_BIT_CNT = C_NO_CFG_BITS-1) and (I_PULSE_N = '1')) then
      if (I_REG_CNT = CFG_REGS-1) then
        I_REG_CNT <= (others => '0');
      else
        I_REG_CNT <= I_REG_CNT + 1;
        I_REG_CNT_ADD_F <= '1';
      end if;
    end if;
    if ((I_REG_CNT_ADD_F = '1') and (I_PULSE_N = '1')) then
        I_REG_CNT_ADD_F <= '0';
    end if;
    I_REG_CNT_PRE <= I_REG_CNT;
  end if;
end process ENABLE_EVAL;


--------------------------------------------------------------------------------
-- bit counter
--------------------------------------------------------------------------------
BIT_CNT_EVAL: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_BIT_CNT <= 0;
  elsif (rising_edge(CLOCK)) then
    if (I_TX_OE = '1') then
      -- if ((I_TX_CLK = '1') and (I_PULSE = '1')) then
      if (I_PULSE_P = '1') then
        if ((I_REG_CNT = CFG_REGS-1) and (I_BIT_CNT = C_NO_CFG_BITS-1)) then 
            I_BIT_CNT <= 0;
        else
            if (I_REG_CNT_ADD_F = '1') then
              I_BIT_CNT <= 0;
            elsif (I_SHIFT_EN = '1') then
              I_BIT_CNT <= I_BIT_CNT + 1;
            end if;
        end if;
      else
        if (I_REG_CNT_PRE /= I_REG_CNT) then
            I_BIT_CNT <= 0;
        else
            I_BIT_CNT <= I_BIT_CNT;
        end if;
      end if;
    else
      I_BIT_CNT <= 0;
    end if;
  end if;
end process BIT_CNT_EVAL;


--------------------------------------------------------------------------------
-- Shift register
--------------------------------------------------------------------------------
SREG_EVAL: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_SREG <= (others => '0');
  elsif (rising_edge(CLOCK)) then
    if (I_ENABLE = '0') then
      --if (I_START_P = '1') then
        --I_SREG <= INPUT;
        --I_SREG <= C_UPDATE_CODE & I_RD_ADDR & INPUT & '0';
      --else
        I_SREG <= I_SREG;
      --end if;
    else -- (I_ENABLE = '1') 
      --if ((I_REG_CNT_ADD_F = '1') and (I_PULSE_P = '1')) then
      if (I_RD_EN_1 = '1') then
        --I_SREG <= INPUT;
        I_SREG <= C_UPDATE_CODE & I_RD_ADDR & INPUT & '0';

      -- if ((I_PULSE = '1') and (I_TX_CLK = '1')) then
      elsif ((I_SHIFT_EN = '1') and (I_PULSE_N = '1')) then
        I_SREG(C_NO_CFG_BITS-1 downto 1) <= I_SREG(C_NO_CFG_BITS-2 downto 0);
        I_SREG(0) <= '0';
      else
        I_SREG <= I_SREG;
      end if;
    end if;
  end if;
end process SREG_EVAL;


READ_WORDS: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_RD_EN <= '0';
    I_RD_EN_1 <= '0';
    I_RD_ADDR <= (others => '0');
  elsif (rising_edge(CLOCK)) then
    I_RD_EN_1 <= I_RD_EN;
    if (I_ENABLE = '0') then
        if (I_START_P = '1') then
            I_RD_EN <= '1';
            I_RD_ADDR <= (others => '0');
        else
            I_RD_EN <= '0';
        end if;
    else -- I_ENABLE = '1')
        --if ((I_REG_CNT = C_NO_CFG_BITS-1) and (I_PULSE_N = '1') and (I_REG_CNT < CFG_REGS-1)) then
        if ((I_BIT_CNT = C_NO_CFG_BITS-1) and (I_PULSE_N = '1')) then
            
            --I_RD_ADDR <= '0' & I_REG_CNT + "001";
            if(I_REG_CNT = CFG_REGS-1) then
                I_RD_ADDR <= (others => '0');
            else
                I_RD_EN <= '1';
                I_RD_ADDR <= I_REG_CNT + "001";
            end if;
        else
            I_RD_EN <= '0';
            if(I_REG_CNT = C_NO_CFG_BITS-1) then
                I_RD_ADDR <= (others => '0');
            end if;
        end if;
    end if;
  end if;
end process READ_WORDS;
--------------------------------------------------------------------------------
-- TX clock generation
--------------------------------------------------------------------------------
--TX_CLK_EVAL: process(RESET,CLOCK)
--begin
--  if (RESET = '1') then
--    I_TX_CLK <= '0';
--  elsif (rising_edge(CLOCK)) then
--    if (I_TX_OE = '1') then
--      if (I_PULSE = '1') then
--        I_TX_CLK <= not I_TX_CLK;
--      else
--        I_TX_CLK <= I_TX_CLK;
--      end if;
--    else
--      I_TX_CLK <= '0';
--    end if;
--  end if;
--end process TX_CLK_EVAL;


--------------------------------------------------------------------------------
-- TX output enable generation
--------------------------------------------------------------------------------
TX_OE_EVAL: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_TX_OE <= '0';
    I_TX_OE_1 <= '0';
  elsif (rising_edge(CLOCK)) then
    I_TX_OE_1 <= I_TX_OE;
    -- if ((I_BIT_CNT = C_NO_CFG_BITS-1) and (I_TX_CLK = '1') and (I_PULSE = '1')) then
    if ((I_BIT_CNT = C_NO_CFG_BITS-1) and (I_PULSE_N = '1') and (I_REG_CNT = CFG_REGS-1)) then
      I_TX_OE <= '0';
    -- elsif ((I_ENABLE = '1') and (I_PULSE = '1')) then
    elsif ((I_TX_START= '1') and (I_PULSE_P = '1')) then
      if (I_REG_CNT_ADD_F = '0') then
        I_TX_OE <= '1';
      else
        I_TX_OE <= '0';
      end if;
    else
      I_TX_OE <= I_TX_OE;
    end if;
  end if;
end process TX_OE_EVAL;


--------------------------------------------------------------------------------
-- counter for determining the duration of the configuration period
--------------------------------------------------------------------------------
CFG_PERIOD_CNT_EVAL: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_CFG_PERIOD_CNT <= (others => '0');
  elsif (rising_edge(CLOCK)) then
    if (I_CFG_PERIOD = '1') then
      I_CFG_PERIOD_CNT <= I_CFG_PERIOD_CNT + "01";
    else
      I_CFG_PERIOD_CNT <= (others => '0');
    end if;
  end if;
end process CFG_PERIOD_CNT_EVAL;


--------------------------------------------------------------------------------
-- I_CFG_END pipeleine register
--------------------------------------------------------------------------------
CFG_END_EVAL: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_CFG_PERIOD_END <= (others => '1');
  elsif (rising_edge(CLOCK)) then
    I_CFG_PERIOD_END <= LINE_PERIOD-x"120" & '0'; -- config结束前多少线就不允许再发了
  end if;
end process CFG_END_EVAL;


--------------------------------------------------------------------------------
-- I_CFG_PERIOD signals that the configuration period is active
--------------------------------------------------------------------------------
CFG_PERIOD_EVAL: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_CFG_PERIOD   <= '0';
    I_CFG_PERIOD_1 <= '0';
  elsif (rising_edge(CLOCK)) then
    I_CFG_PERIOD_1 <= I_CFG_PERIOD;
    if (I_START_P = '1') then
      I_CFG_PERIOD <= '1';
    elsif (I_CFG_PERIOD_CNT >= I_CFG_PERIOD_END) then
      I_CFG_PERIOD <= '0';
    else
      I_CFG_PERIOD <= I_CFG_PERIOD;
    end if;
  end if;
end process CFG_PERIOD_EVAL;


--------------------------------------------------------------------------------
-- activate I_SET_TX_CLK at the end of the configuration phase
--------------------------------------------------------------------------------
SET_TX_CLK_EVAL: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_SET_TX_CLK   <= '0';
  elsif (rising_edge(CLOCK)) then
    if (I_TX_START_P = '1') then
      I_SET_TX_CLK <= '0';
    elsif (I_CFG_PERIOD_CNT = I_CFG_PERIOD_END-x"10") then
      I_SET_TX_CLK <= '1';
    else
      I_SET_TX_CLK <= I_SET_TX_CLK;
    end if;
  end if;
end process SET_TX_CLK_EVAL;


TX_END <= I_CFG_PERIOD_1 and not I_CFG_PERIOD;

TX_DAT <= I_SREG(C_NO_CFG_BITS-1);
-- TX_CLK <= I_TX_CLK or I_SET_TX_CLK;
TX_CLK <= (I_PULSE or I_SET_TX_CLK) and not I_REG_CNT_ADD_F;
TX_OE  <= I_CFG_PERIOD;
RD_ADDR <= I_RD_ADDR;
RD_EN <= I_RD_EN;


end RTL;

