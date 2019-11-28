
-- library IEEE, UNISIM;
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;


entity LINE_PERIOD_CALC is
  generic (
    G_CLOCK_PERIOD_PS:          integer:=20833;                                 -- CLOCK period in ps (48MHz T=20833ns)
    -- F=36MHz T=27778ps TPP=12*T=333333ps TLINE=253*12*T=84333333ps=84333ns
    -- if TLINE=50000ns T=16469ps F=60.72MHz
    G_LINE_PERIOD_MIN_NS:       integer:=50000;                                 -- shortest possible time for one line
    -- if TLINE=120000ns T=39525ps F=25.3MHz
    G_LINE_PERIOD_MAX_NS:       integer:=120000);                               -- longest possible time for one line
  port (
    RESET:                      in  std_logic;                                  -- async. Reset
    CLOCK:                      in  std_logic;                                  -- system clock
    SCLOCK:                     in  std_logic;                                  -- sampling clock
    FRAME_START:                in  std_logic;                                  -- frame start from decoder
    PAR_DATA_EN:                in  std_logic;                                  -- deserialized word available from deserializer
    PIXEL_ERROR:                in  std_logic;                                  -- pixel error from deserializer
    LINE_END:                   in  std_logic;                                  -- line end pulse from deserializer
    LINE_PERIOD:                out std_logic_vector(15 downto 0));             -- line period in # of CLOCK cycles
end entity LINE_PERIOD_CALC;


architecture RTL of LINE_PERIOD_CALC is

constant C_LINE_PERIOD_MIN:     integer:= G_LINE_PERIOD_MIN_NS*1000/G_CLOCK_PERIOD_PS;
constant C_LINE_PERIOD_MAX:     integer:= G_LINE_PERIOD_MAX_NS*1000/G_CLOCK_PERIOD_PS;

type T_STATES is (IDLE,MEASURE,DONE);
subtype T_CNT is integer range 0 to 2*C_LINE_PERIOD_MAX;

signal I_PRESENT_STATE:         T_STATES:=IDLE;
signal I_CNT_EN:                std_logic:='0';
signal I_CNT_EN_1:              std_logic:='0';
signal I_CNT_EN_2:              std_logic:='0';
signal I_CNT_EN_3:              std_logic:='0';
signal I_LINE_PERIOD_CNT:       T_CNT:= 0;
signal I_LINE_PERIOD_REG:       std_logic_vector(LINE_PERIOD'range):= conv_std_logic_vector(C_LINE_PERIOD_MIN,LINE_PERIOD'length);


begin
--------------------------------------------------------------------------------
-- FSM
--------------------------------------------------------------------------------
FSM: process(SCLOCK)
begin
  if (rising_edge(SCLOCK)) then
    case I_PRESENT_STATE is
--------------------------------------------------------------------------------
-- IDLE: waiting for FRAME_START = '1'
--------------------------------------------------------------------------------
      when IDLE =>
        if (FRAME_START = '1') then
          I_PRESENT_STATE <= MEASURE;
        end if;
--------------------------------------------------------------------------------
-- MEASURE: measure the period of the first line
--------------------------------------------------------------------------------
      when MEASURE =>
        if (LINE_END = '1') then
          I_PRESENT_STATE <= DONE;
        end if;
--------------------------------------------------------------------------------
-- DONE: check whether C_LINE_PERIOD_MIN < I_LINE_PERIOD_CNT < C_LINE_PERIOD_MAX
--------------------------------------------------------------------------------
      when DONE =>
        I_PRESENT_STATE <= IDLE;
    end case;
  end if;
end process FSM;


--------------------------------------------------------------------------------
-- count enable
--------------------------------------------------------------------------------
CNT_EN: process(SCLOCK)
begin
  if (rising_edge(SCLOCK)) then
    if (I_PRESENT_STATE = MEASURE) then
      if (PIXEL_ERROR = '1') then
        I_CNT_EN <= '0';
      elsif (PAR_DATA_EN = '1') then
        I_CNT_EN <= '1';
      end if;
    else
      I_CNT_EN <= '0';
    end if;
  end if;
end process CNT_EN;


--------------------------------------------------------------------------------
-- synchronize I_CNT_EN to CLOCK
--------------------------------------------------------------------------------
SYNC: process(CLOCK)
begin
  if (rising_edge(CLOCK)) then
    I_CNT_EN_1 <= I_CNT_EN;
    I_CNT_EN_2 <= I_CNT_EN_1;
    I_CNT_EN_3 <= I_CNT_EN_2;
  end if;
end process SYNC;


--------------------------------------------------------------------------------
-- counter
--------------------------------------------------------------------------------
CNT: process(CLOCK)
begin
  if (rising_edge(CLOCK)) then
    if (I_CNT_EN_2 = '1') then
      if (I_LINE_PERIOD_CNT < 2*C_LINE_PERIOD_MAX) then
        I_LINE_PERIOD_CNT <= I_LINE_PERIOD_CNT + 1;
      else
        I_LINE_PERIOD_CNT <= I_LINE_PERIOD_CNT;
      end if;
    else
      I_LINE_PERIOD_CNT <= 0;
    end if;
  end if;
end process CNT;


--------------------------------------------------------------------------------
-- store counter value into output register
--------------------------------------------------------------------------------
CNT_REG: process(CLOCK)
begin
  if (rising_edge(CLOCK)) then
    if ((I_CNT_EN_3 = '1') and (I_CNT_EN_2 = '0')) then
      if ((I_LINE_PERIOD_CNT > C_LINE_PERIOD_MAX) or (I_LINE_PERIOD_CNT < C_LINE_PERIOD_MIN)) then
        I_LINE_PERIOD_REG <= conv_std_logic_vector(C_LINE_PERIOD_MIN,LINE_PERIOD'length);
      else
        I_LINE_PERIOD_REG <= conv_std_logic_vector(I_LINE_PERIOD_CNT,LINE_PERIOD'length);
      end if;
    end if;
  end if;
end process CNT_REG;


LINE_PERIOD <= I_LINE_PERIOD_REG;

end RTL;

