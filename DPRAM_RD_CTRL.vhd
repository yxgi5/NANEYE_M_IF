--------------------------------------------------------------------------------
-- AWAIBA GmbH
--------------------------------------------------------------------------------
-- MODUL NAME:  DPRAM_RD_CTRL
-- FILENAME:    dpram_rd_ctrl.vhd
-- AUTHOR:      Michael Heil - Ing. Büro für FPGA-Logic-Design
--              email:  michael.heil@fpga-logic-design.de
--
-- CREATED:     15.04.2007
--------------------------------------------------------------------------------
-- DESCRIPTION: Generates control signals for writing pwm data to DPRAM, and
--              control signals for frame grabber
--
--------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------
-- REVISIONS:
-- DATE         VERSION    AUTHOR      DESCRIPTION
-- 15.04.2007   01         M. Heil     Initial version
-- 16.04.2007   02         M. Heil     Resync after FRAMING_ERROR
-- 08.12.2009   03         M. Heil     Signal FRAME_START added for resync.
-- 02.12.2010   04         M. Heil     CLOCK used as Pixel-Clock
-- 02.01.2011   05         M. Heil     Row count reduced by 1
-- 11.01.2011   06         M. Heil     Skip first line
-- 24.10.2011   07         M. Heil     Modifications for NanEye3A
-- 13.01.2012   08         M. Heil     FRAME_START forces FSM to FRAME_BREAK
-- 30.03.2012   09         M. Heil     image format is always C_ROWS x C_OLUMNS
--                                     for NanEye2B the first line is invalid
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity DPRAM_RD_CTRL is
  generic (
    C_ROWS:                     integer:=250;                                   -- number of rows per frame
    C_COLUMNS:                  integer:=250;                                   -- number of columns per line
    C_ADDR_W:                   integer:=9);                                    -- address output width
  port (
    RESET:                      in  std_logic;                                  -- async. Reset
    SCLOCK:                     in  std_logic;                                  -- system clock
    CLOCK:                      in  std_logic;                                  -- readout clock
    NANEYE3A_NANEYE2B_N:        in  std_logic;                                  -- '0'=NANEYE2B, '1'=NANEYE3A
    FRAMING_ERROR:              in  std_logic;                                  -- frame sync error (sync to sclk)
    FRAME_START:                in  std_logic;                                  -- start of frame (sync to sclk)
    LINE_FINISHED:              in  std_logic;                                  -- end of line (sync to sclk)
    DPRAM_RD_PAGE:              in  std_logic;                                  -- page select signal (sync to sclk)
    DPRAM_RD_ADDR:              out std_logic_vector(C_ADDR_W-1 downto 0);      -- dpram read address
    DPRAM_RDAT_VALID:           out std_logic;                                  -- signals valid DPRAM read data
    H_SYNC:                     out std_logic;                                  -- horizontal sync
    V_SYNC:                     out std_logic);                                 -- vertical sync
end entity DPRAM_RD_CTRL;


architecture RTL of DPRAM_RD_CTRL is


subtype T_COL_CNT is integer range 0 to C_COLUMNS;
subtype T_ROW_CNT is integer range 0 to C_ROWS;
type T_STATES is (FRAME_BREAK,WAIT_LINE,DUMMY_LINE,LINE_VALID,LINE_BREAK);


signal I_FRAMING_ERROR:    std_logic:='0';
signal I_FRAME_START:      std_logic:='0';
signal I_LINE_FINISHED:    std_logic:='0';
signal I_FRAMING_ERROR_1:  std_logic;
signal I_FRAMING_ERROR_2:  std_logic;
signal I_FRAMING_ERROR_3:  std_logic;
signal I_FRAME_START_1:    std_logic;
signal I_FRAME_START_2:    std_logic;
signal I_FRAME_START_3:    std_logic;
signal I_LINE_FINISHED_1:  std_logic;
signal I_LINE_FINISHED_2:  std_logic;
signal I_LINE_FINISHED_3:  std_logic;
signal I_FRAMING_ERROR_P:  std_logic;
signal I_FRAME_START_P:    std_logic;
signal I_LINE_FINISHED_P:  std_logic;
signal PRESENT_STATE:      T_STATES;
signal NEXT_STATE:         T_STATES;
signal LAST_STATE:         T_STATES;
signal I_FS_INT:           std_logic;
signal I_DPRAM_PAGE_1:     std_logic;
signal I_DPRAM_PAGE_2:     std_logic;
signal I_COL_CNT:          T_COL_CNT;
signal I_ROW_CNT:          T_ROW_CNT;
signal I_H_SYNC:           std_logic;
signal I_H_SYNC1:          std_logic;
signal I_V_SYNC:           std_logic;
signal I_V_SYNC1:          std_logic;
signal I_DPRAM_RDAT_VALID: std_logic;


begin
--------------------------------------------------------------------------------
-- Synchronization of the control signals
--------------------------------------------------------------------------------
FRAMING_ERR_SYNC: process(I_FRAMING_ERROR_P,SCLOCK)
begin
  if (I_FRAMING_ERROR_P = '1') then
    I_FRAMING_ERROR <= '0';
  elsif (rising_edge(SCLOCK)) then
    I_FRAMING_ERROR <= I_FRAMING_ERROR or FRAMING_ERROR;
  end if;
end process FRAMING_ERR_SYNC;


FRAME_START_SYNC: process(I_FRAME_START_P,SCLOCK)
begin
  if (I_FRAME_START_P = '1') then
    I_FRAME_START   <= '0';
  elsif (rising_edge(SCLOCK)) then
    I_FRAME_START   <= I_FRAME_START or FRAME_START;
  end if;
end process FRAME_START_SYNC;


LINE_FINISHED_SYNC: process(I_LINE_FINISHED_P,SCLOCK)
begin
  if (I_LINE_FINISHED_P = '1') then
    I_LINE_FINISHED <= '0';
  elsif (rising_edge(SCLOCK)) then
    I_LINE_FINISHED <= I_LINE_FINISHED or LINE_FINISHED;
  end if;
end process LINE_FINISHED_SYNC;


CTRL_SIG_SAMPLING: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_FRAMING_ERROR_1 <= '0';
    I_FRAMING_ERROR_2 <= '0';
    I_FRAMING_ERROR_3 <= '0';
    I_FRAME_START_1   <= '0';
    I_FRAME_START_2   <= '0';
    I_FRAME_START_3   <= '0';
    I_LINE_FINISHED_1 <= '0';
    I_LINE_FINISHED_2 <= '0';
    I_LINE_FINISHED_3 <= '0';
  elsif (rising_edge(CLOCK)) then
    I_FRAMING_ERROR_1 <= I_FRAMING_ERROR;
    I_FRAMING_ERROR_2 <= I_FRAMING_ERROR_1;
    I_FRAMING_ERROR_3 <= I_FRAMING_ERROR_2;
    I_FRAME_START_1   <= I_FRAME_START;
    I_FRAME_START_2   <= I_FRAME_START_1;
    I_FRAME_START_3   <= I_FRAME_START_2;
    I_LINE_FINISHED_1 <= I_LINE_FINISHED;
    I_LINE_FINISHED_2 <= I_LINE_FINISHED_1;
    I_LINE_FINISHED_3 <= I_LINE_FINISHED_2;
  end if;
end process CTRL_SIG_SAMPLING;

I_FRAMING_ERROR_P <= I_FRAMING_ERROR_2 and not I_FRAMING_ERROR_3;
I_FRAME_START_P   <= I_FRAME_START_2 and  not I_FRAME_START_3;
I_LINE_FINISHED_P <= I_LINE_FINISHED_2 and not I_LINE_FINISHED_3;


STATE_CHANGE: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    PRESENT_STATE <= FRAME_BREAK;
    LAST_STATE    <= FRAME_BREAK;
  elsif (rising_edge(CLOCK)) then
    PRESENT_STATE <= NEXT_STATE;
    LAST_STATE    <= PRESENT_STATE;
  end if;
end process STATE_CHANGE;

FS_INT_EVAL: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_FS_INT <= '0';
  elsif (rising_edge(CLOCK)) then
    if (I_FRAME_START_P = '1') then
      I_FS_INT <= '1';
    elsif (I_LINE_FINISHED_P = '1') then
      I_FS_INT <= '0';
    else
      I_FS_INT <= I_FS_INT;
    end if;
  end if;
end process FS_INT_EVAL;


STATE_EVAL: process(PRESENT_STATE,I_FRAME_START_P,I_FRAMING_ERROR_P,I_LINE_FINISHED_P,I_COL_CNT,I_ROW_CNT)
begin
  case PRESENT_STATE is
--------------------------------------------------------------------------------
-- Frame Break
--------------------------------------------------------------------------------
    when FRAME_BREAK =>
      if (I_FRAMING_ERROR_P = '1') then
        NEXT_STATE <= PRESENT_STATE;
      --elsif (NANEYE3A_NANEYE2B_N = '0') then  -- NanEye2B
      --  if (I_FRAME_START_P = '1') then
      --    NEXT_STATE <= WAIT_LINE;
      --  else
      --    NEXT_STATE <= PRESENT_STATE;
      --  end if;
      else                                    -- NanEye3A
        if ((I_FS_INT = '1') and (I_LINE_FINISHED_P = '1')) then
          NEXT_STATE <= LINE_VALID;
        else
          NEXT_STATE <= PRESENT_STATE;
        end if;
      end if;
--------------------------------------------------------------------------------
-- Waiting line
--------------------------------------------------------------------------------
    when WAIT_LINE =>
      if ((I_FRAMING_ERROR_P = '1') or (I_FRAME_START_P = '1')) then
        NEXT_STATE <= FRAME_BREAK;
      elsif (I_COL_CNT = C_COLUMNS-1) then
        NEXT_STATE <= DUMMY_LINE;
      else
        NEXT_STATE <= PRESENT_STATE;
      end if;
--------------------------------------------------------------------------------
-- give out one line with DPRAM_RDAT_VALID = '0'
--------------------------------------------------------------------------------
    when DUMMY_LINE =>
      if ((I_FRAMING_ERROR_P = '1') or (I_FRAME_START_P = '1')) then
        NEXT_STATE <= FRAME_BREAK;
      elsif (I_COL_CNT = C_COLUMNS-1) then
        NEXT_STATE <= LINE_BREAK;
      else
        NEXT_STATE <= PRESENT_STATE;
      end if;
--------------------------------------------------------------------------------
-- Transmit one line
--------------------------------------------------------------------------------
    when LINE_VALID =>
      if ((I_FRAMING_ERROR_P = '1') or (I_FRAME_START_P = '1')) then
        NEXT_STATE <= FRAME_BREAK;
      elsif (I_COL_CNT = C_COLUMNS-1) then
        if (I_ROW_CNT = C_ROWS-1) then
          NEXT_STATE <= FRAME_BREAK;
        else
          NEXT_STATE <= LINE_BREAK;
        end if;
      else
        NEXT_STATE <= PRESENT_STATE;
      end if;
--------------------------------------------------------------------------------
-- Line Break
--------------------------------------------------------------------------------
    when LINE_BREAK =>
      if ((I_FRAMING_ERROR_P = '1') or (I_FRAME_START_P = '1')) then
        NEXT_STATE <= FRAME_BREAK;
      elsif (I_LINE_FINISHED_P = '1') then
        NEXT_STATE <= LINE_VALID;
      else
        NEXT_STATE <= PRESENT_STATE;
      end if;
   end case;
end process STATE_EVAL;


--------------------------------------------------------------------------------
-- Column counter
--------------------------------------------------------------------------------
COL_CNT_EVAL: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_COL_CNT <= 0;
  elsif (rising_edge(CLOCK)) then
    if ((PRESENT_STATE = WAIT_LINE) or (PRESENT_STATE = LINE_VALID) or (PRESENT_STATE = DUMMY_LINE)) then
      if (I_COL_CNT = C_COLUMNS-1) then
        I_COL_CNT <= 0;
      else
        I_COL_CNT <= I_COL_CNT + 1;
      end if;
    else
      I_COL_CNT <= 0;
    end if;
  end if;
end process COL_CNT_EVAL;


--------------------------------------------------------------------------------
-- Row counter
--------------------------------------------------------------------------------
ROW_CNT_EVAL: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_ROW_CNT <= 0;
  elsif (rising_edge(CLOCK)) then
    if ((PRESENT_STATE = LINE_VALID) or (PRESENT_STATE = DUMMY_LINE)) then
      if (I_COL_CNT = C_COLUMNS-1) then
        if (I_ROW_CNT = C_ROWS-1) then
          I_ROW_CNT <= 0;
        else
          I_ROW_CNT <= I_ROW_CNT + 1;
        end if;
      else
        I_ROW_CNT <= I_ROW_CNT;
      end if;
    elsif (PRESENT_STATE = FRAME_BREAK) then
      I_ROW_CNT <= 0;
    else
      I_ROW_CNT <= I_ROW_CNT;
    end if;
  end if;
end process ROW_CNT_EVAL;


--------------------------------------------------------------------------------
-- DPRAM_RD_PAGE delay
--------------------------------------------------------------------------------
DPRAM_PAGE_DELAY: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_DPRAM_PAGE_1 <= '1';
    I_DPRAM_PAGE_2 <= '1';
  elsif (rising_edge(CLOCK)) then
    I_DPRAM_PAGE_1 <= DPRAM_RD_PAGE;
    I_DPRAM_PAGE_2 <= I_DPRAM_PAGE_1;
  end if;
end process DPRAM_PAGE_DELAY;


--------------------------------------------------------------------------------
-- HSYNC
--------------------------------------------------------------------------------
HSYNC_EVAL: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_H_SYNC  <= '0';
    I_H_SYNC1 <= '0';
  elsif (rising_edge(CLOCK)) then
    I_H_SYNC1 <= I_H_SYNC;
    if ((PRESENT_STATE = LINE_VALID) or (PRESENT_STATE = DUMMY_LINE)) then
      I_H_SYNC <= '1';
    else
      I_H_SYNC <= '0';
    end if;
  end if;
end process HSYNC_EVAL;


--------------------------------------------------------------------------------
-- VSYNC
--------------------------------------------------------------------------------
VSYNC_EVAL: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_V_SYNC  <= '0';
    I_V_SYNC1 <= '0';
  elsif (rising_edge(CLOCK)) then
    I_V_SYNC1 <= I_V_SYNC;
    if ((PRESENT_STATE = FRAME_BREAK) and (I_FRAME_START_P = '1')) then
      I_V_SYNC <= '1';
    elsif ((PRESENT_STATE = FRAME_BREAK) and (LAST_STATE = LINE_VALID)) then
      I_V_SYNC  <= '0';
    else
      I_V_SYNC <= I_V_SYNC;
    end if;
  end if;
end process VSYNC_EVAL;


--------------------------------------------------------------------------------
-- RDAT_VALID
--------------------------------------------------------------------------------
RDAT_VALID_EVAL: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_DPRAM_RDAT_VALID  <= '0';
  elsif (rising_edge(CLOCK)) then
    if (PRESENT_STATE = DUMMY_LINE) then
      I_DPRAM_RDAT_VALID <= '0';
    else
      I_DPRAM_RDAT_VALID <= '1';
    end if;
  end if;
end process RDAT_VALID_EVAL;


DPRAM_RD_ADDR(C_ADDR_W-1) <= I_DPRAM_PAGE_2;
DPRAM_RD_ADDR(C_ADDR_W-2 downto 0) <= conv_std_logic_vector(I_COL_CNT,C_ADDR_W-1);

DPRAM_RDAT_VALID <= I_DPRAM_RDAT_VALID;

H_SYNC <= I_H_SYNC1;
V_SYNC <= I_V_SYNC1;

end RTL;
