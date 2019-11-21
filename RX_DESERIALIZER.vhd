--------------------------------------------------------------------------------
-- AWAIBA GmbH
--------------------------------------------------------------------------------
-- MODUL NAME:  RX_DESERIALIZER
-- FILENAME:    rx_deserializer.vhd
-- AUTHOR:      Michael Heil - Ing. Büro für FPGA-Logic-Design
--              email:  michael.heil@fpga-logic-design.de
--
-- CREATED:     12.11.2009
--------------------------------------------------------------------------------
-- DESCRIPTION: deserializes decoded sensor data stream, detects frame- and
--              line-sync phases
--
--------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------
-- REVISIONS:
-- DATE         VERSION    AUTHOR      DESCRIPTION
-- 12.11.2009   01         M. Heil     Initial version
-- 02.03.2010   02         M. Heil     Debug outputs added
-- 03.01.2011   03         M. Heil     corrections: skip first line, generate
--                                     resync signal for the decoder
-- 24.10.2011   04         M. Heil     Modifications for NanEye3A
-- 17.01.2012   05         M. Heil     FRAME_START always forces the FSM to IDLE
-- 06.03.2012   06         M. Heil     Line period measurement added
-- 05.11.2013   07         M. Heil     Line period measurement removed, check for
--                                     validity of first pixel added, reception
--                                     of first line enabled
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;


entity RX_DESERIALIZER is
  generic (
    C_ROWS:                     integer:=250;                                   -- number of rows per frame
    C_COLUMNS:                  integer:=250);                                  -- number of columns per line
  port (
    RESET:                      in  std_logic;                                  -- async. Reset
    CLOCK:                      in  std_logic;                                  -- system clock
    -- NANEYE3A_NANEYE2B_N:        in  std_logic;                                  -- '0'=NANEYE2B, '1'=NANEYE3A
    FRAME_START:                in  std_logic;                                  -- frame start pulse
    SER_INPUT:                  in  std_logic;                                  -- serial input data
    SER_INPUT_EN:               in  std_logic;                                  -- input data valid
    DEC_RSYNC:                  out std_logic;                                  -- resynchronize decoder
    PAR_OUTPUT:                 out std_logic_vector(11 downto 0);              -- parallel output data
    PAR_OUTPUT_EN:              out std_logic;                                  -- output data valid
    PIXEL_ERROR:                out std_logic;                                  -- start/stop bit error
    LINE_END:                   out std_logic;                                  -- signals end of one line
    LINE_PERIOD:                out std_logic_vector(15 downto 0);              -- line period in # of CLOCK cycles
    ERROR_OUT:                  out std_logic;                                  -- start/stop error
    DEBUG_OUT:                  out std_logic_vector(15 downto 0));             -- debug outputs
end entity RX_DESERIALIZER;


architecture RTL of RX_DESERIALIZER is

constant C_INPUT_EN_CNT_WIDTH:  integer:=8;
constant C_INPUT_EN_CNT_END:    std_logic_vector(C_INPUT_EN_CNT_WIDTH-1 downto 0):=conv_std_logic_vector(255,C_INPUT_EN_CNT_WIDTH);

type T_STATES is (IDLE,FR_START,LINE_VALID,LINE_SYNC,INC_ROW_CNT,FRAME_END);

signal I_PRESENT_STATE:         T_STATES;
signal I_LAST_STATE:            T_STATES;
signal I_SREG:                  std_logic_vector(11 downto 0);
signal I_BIT_CNT_EN:            std_logic;
signal I_BIT_CNT:               std_logic_vector(3 downto 0);
signal I_OUTREG_LOAD:           std_logic;
signal I_OUTREG_LOAD1:          std_logic;
signal I_PIXEL_ERROR:           std_logic;
signal I_COL_CNT:               std_logic_vector(8 downto 0);
signal I_ROW_CNT:               std_logic_vector(8 downto 0);
signal I_OUTPUT:                std_logic_vector(11 downto 0);
signal I_OUTPUT_EN:             std_logic;
signal I_LINE_END:              std_logic;
signal I_INPUT_EN_CNT:          std_logic_vector(C_INPUT_EN_CNT_WIDTH-1 downto 0);
signal I_FRAME_START_PULSE:     std_logic;


begin
--------------------------------------------------------------------------------
-- fsm for synchronisation to the bit stream
--------------------------------------------------------------------------------
FSM_EVAL: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_PRESENT_STATE <= IDLE;
    I_LAST_STATE    <= IDLE;
  elsif (rising_edge(CLOCK)) then
    I_LAST_STATE <= I_PRESENT_STATE;
    case I_PRESENT_STATE is
--------------------------------------------------------------------------------
-- IDLE: waiting for frame-start
--------------------------------------------------------------------------------
      when IDLE =>
        if (FRAME_START = '1') then
          I_PRESENT_STATE <= FR_START;
        else
          I_PRESENT_STATE <= I_PRESENT_STATE;
        end if;
--------------------------------------------------------------------------------
-- FR_START: frame-start received
--------------------------------------------------------------------------------
      when FR_START =>
        I_PRESENT_STATE <= LINE_VALID;
--------------------------------------------------------------------------------
-- LINE_VALID: waiting until one row was completely received
-- each row contains C_COLUMNS-1 pixels
-- the last row contains C_COLUMNS-2 pixels
--------------------------------------------------------------------------------
      when LINE_VALID =>
        if (FRAME_START = '1') then
          I_PRESENT_STATE <= FR_START;
        else
          --if (NANEYE3A_NANEYE2B_N = '0') then         -- NanEye2B
            --if (I_ROW_CNT < C_ROWS-1) then
              --if (I_COL_CNT = C_COLUMNS-1) then
                --I_PRESENT_STATE <= LINE_SYNC;
              --else
                --I_PRESENT_STATE <= I_PRESENT_STATE;
              --end if;
            --else
              --if (I_COL_CNT = C_COLUMNS-2) then
                --I_PRESENT_STATE <= FRAME_END;
              --else
                --I_PRESENT_STATE <= I_PRESENT_STATE;
              --end if;
            --end if;
          --else                                        -- NanyEye3A
            if (I_COL_CNT = C_COLUMNS) then
              if (I_ROW_CNT = C_ROWS-1) then
                I_PRESENT_STATE <= FRAME_END;
              else
                I_PRESENT_STATE <= LINE_SYNC;
              end if;
            else
              I_PRESENT_STATE <= I_PRESENT_STATE;
            end if;
          --end if;
        end if;
--------------------------------------------------------------------------------
-- LINE_SYNC: waiting for line sync
--------------------------------------------------------------------------------
      when LINE_SYNC =>
        if (FRAME_START = '1') then
          I_PRESENT_STATE <= FR_START;
        else
          if (I_SREG = "000000000000") then
            I_PRESENT_STATE <= INC_ROW_CNT;
          else
            I_PRESENT_STATE <= I_PRESENT_STATE;
          end if;
        end if;
--------------------------------------------------------------------------------
-- INC_ROW_CNT: increment row counter
--------------------------------------------------------------------------------
      when INC_ROW_CNT =>
        if (FRAME_START = '1') then
          I_PRESENT_STATE <= FR_START;
        else
          I_PRESENT_STATE <= LINE_VALID;
        end if;
--------------------------------------------------------------------------------
-- FRAME_END: complete frame received, switch to IDLE
--------------------------------------------------------------------------------
      when FRAME_END =>
        I_PRESENT_STATE <= IDLE;
    end case;
  end if;
end process FSM_EVAL;


--------------------------------------------------------------------------------
-- shift register
--------------------------------------------------------------------------------
SREG_EVAL: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_SREG <= (others => '0');
  elsif (rising_edge(CLOCK)) then
    if ((I_PRESENT_STATE = IDLE) or (I_PRESENT_STATE = FR_START) or (I_PIXEL_ERROR = '1')) then
      I_SREG <= (others => '0');
    elsif (SER_INPUT_EN = '1') then
      I_SREG(11 downto 1) <= I_SREG(10 downto 0);
      I_SREG(0) <= SER_INPUT;
    else
      I_SREG <= I_SREG;
    end if;
  end if;
end process SREG_EVAL;


--------------------------------------------------------------------------------
-- bit counter is enabled after receiving the first pixel with valid start-
-- bit after a frame start / line end
--------------------------------------------------------------------------------
BIT_CNT_EN_EVAL: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_BIT_CNT_EN <= '0';
  elsif (rising_edge(CLOCK)) then
    if (I_PIXEL_ERROR = '1') then
      I_BIT_CNT_EN <= '0';
    elsif (I_PRESENT_STATE = LINE_VALID) then
      if (I_SREG(11) = '1') then
        I_BIT_CNT_EN <= '1';
      else
        I_BIT_CNT_EN <= I_BIT_CNT_EN;
      end if;
    else
      I_BIT_CNT_EN <= '0';
    end if;
  end if;
end process BIT_CNT_EN_EVAL;


--------------------------------------------------------------------------------
-- bit counter for generating the load-pulses for the parallel register
--------------------------------------------------------------------------------
BIT_CNT_EVAL: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_BIT_CNT <= (others => '0');
  elsif (rising_edge(CLOCK)) then
    if (I_BIT_CNT_EN = '1') then
      if (SER_INPUT_EN = '1') then
        if (I_BIT_CNT = "1011") then
          I_BIT_CNT <= "0000";
        else
          I_BIT_CNT <= I_BIT_CNT + "01";
        end if;
      else
        I_BIT_CNT <= I_BIT_CNT;
      end if;
    else
      I_BIT_CNT <= (others => '0');
    end if;
  end if;
end process BIT_CNT_EVAL;


--------------------------------------------------------------------------------
-- load-signal for the parallel output register
--------------------------------------------------------------------------------
OUTREG_LOAD_EVAL: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_OUTREG_LOAD  <= '0';
    I_OUTREG_LOAD1 <= '0';
  elsif (rising_edge(CLOCK)) then
    I_OUTREG_LOAD1 <= I_OUTREG_LOAD;
    if (I_PRESENT_STATE = LINE_VALID) then
      if ((I_BIT_CNT_EN = '0') and (I_SREG(11) = '1') and (I_SREG(0) = '0')) then
        I_OUTREG_LOAD <= '1';
      elsif (I_BIT_CNT = "1011") then
        I_OUTREG_LOAD <= SER_INPUT_EN;
      else
        I_OUTREG_LOAD <= '0';
      end if;
    else
      I_OUTREG_LOAD <= '0';
    end if;
  end if;
end process OUTREG_LOAD_EVAL;


--------------------------------------------------------------------------------
-- activate error, if one pixel doesn't have a valid start-bit or stop-bit
--------------------------------------------------------------------------------
ERROR_EVAL: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_PIXEL_ERROR <= '0';
  elsif (rising_edge(CLOCK)) then
    if (I_PRESENT_STATE = LINE_VALID) then
      if ((I_OUTREG_LOAD1 = '1') and ((I_OUTPUT(11) = '0') or (I_OUTPUT(0) = '1'))) then
        I_PIXEL_ERROR <= '1';
      else
        I_PIXEL_ERROR <= '0';
      end if;
    else
      I_PIXEL_ERROR <= '0';
    end if;
  end if;
end process ERROR_EVAL;


--------------------------------------------------------------------------------
-- count number of pixels per line
--------------------------------------------------------------------------------
COL_CNT_EVAL: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_COL_CNT <= (others => '0');
  elsif (rising_edge(CLOCK)) then
    if ((I_PRESENT_STATE = FR_START) or (I_PRESENT_STATE = LINE_SYNC) or (I_PIXEL_ERROR = '1')) then
      I_COL_CNT <= (others => '0');
    elsif (I_PRESENT_STATE = LINE_VALID) then
      if (I_OUTREG_LOAD1 = '1') then
        I_COL_CNT <= I_COL_CNT + "01";
      else
        I_COL_CNT <= I_COL_CNT;
      end if;
    else
      I_COL_CNT <= I_COL_CNT;
    end if;
  end if;
end process COL_CNT_EVAL;


--------------------------------------------------------------------------------
-- count number of rows per frame
--------------------------------------------------------------------------------
ROW_CNT_EVAL: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_ROW_CNT <= (others => '0');
  elsif (rising_edge(CLOCK)) then
    if (I_PRESENT_STATE = FR_START) then
      I_ROW_CNT <= (others => '0');
    elsif (I_PRESENT_STATE = INC_ROW_CNT) then
      I_ROW_CNT <= I_ROW_CNT + "01";
    else
      I_ROW_CNT <= I_ROW_CNT;
    end if;
  end if;
end process ROW_CNT_EVAL;


--------------------------------------------------------------------------------
-- parallel output register
--------------------------------------------------------------------------------
OUTPUT_EVAL: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_OUTPUT <= (others => '0');
  elsif (rising_edge(CLOCK)) then
    if (I_OUTREG_LOAD = '1') then
      I_OUTPUT <= I_SREG;
    else
      I_OUTPUT <= I_OUTPUT;
    end if;
  end if;
end process OUTPUT_EVAL;


--------------------------------------------------------------------------------
-- generating PAR_OUTPUT_EN
--------------------------------------------------------------------------------
OUTPUT_EN_EVAL: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_OUTPUT_EN <= '0';
  elsif (rising_edge(CLOCK)) then
    I_OUTPUT_EN <= I_OUTREG_LOAD1;
  end if;
end process OUTPUT_EN_EVAL;


--------------------------------------------------------------------------------
-- I_LINE_END = pulse after the last pixel of each line was received
--------------------------------------------------------------------------------
LINE_END_EVAL: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_LINE_END <= '0';
  elsif (rising_edge(CLOCK)) then
    if (((I_PRESENT_STATE = LINE_SYNC) and (I_LAST_STATE = LINE_VALID)) or (I_PRESENT_STATE = FRAME_END)) then
      I_LINE_END <= '1';
    else
      I_LINE_END <= '0';
    end if;
  end if;
end process LINE_END_EVAL;


DEC_RSYNC      <= '1' when ((I_PRESENT_STATE = INC_ROW_CNT) or (I_PIXEL_ERROR = '1')) else '0';
PAR_OUTPUT     <= I_OUTPUT;
PAR_OUTPUT_EN  <= I_OUTPUT_EN;
LINE_END       <= I_LINE_END;
PIXEL_ERROR    <= I_PIXEL_ERROR;
ERROR_OUT      <= '0';
DEBUG_OUT <= (others => '0');

end RTL;
