--------------------------------------------------------------------------------
-- AWAIBA GmbH
--------------------------------------------------------------------------------
-- MODUL NAME:  DPRAM_WR_CTRL
-- FILENAME:    dpram_wr_ctrl.vhd
-- AUTHOR:      Michael Heil - Ing. Büro für FPGA-Logic-Design
--              email:  michael.heil@fpga-logic-design.de
--
-- CREATED:     14.05.2007
--------------------------------------------------------------------------------
-- DESCRIPTION: Generates control signals for writing sensor data to DPRAM
--
--
--------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------
-- REVISIONS:
-- DATE         VERSION    AUTHOR      DESCRIPTION
-- 14.05.2007   01         M. Heil     Initial version
-- 16.04.2007   02         M. Heil     Resync after FRAMING_ERROR
-- 10.07.2007   03         M. Heil     new signal: FILTER_EN, DPRAM_WE=>DATA_EN
-- 12.11.2009   04         M. Heil     modifications for NanEye
-- 02.01.2011   05         M. Heil     simplifications for new decoder
-- 11.01.2011   06         M. Heil     skip first line
-- 24.10.2011   07         M. Heil     Modifications for NanEye3A
-- 23.03.2012   08         M. Heil     Skipping of 1st line for NanEye2B removed
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity DPRAM_WR_CTRL is
  generic (
    C_ADDR_W:                   integer:=9);                                    -- address output width
  port (
    RESET:                      in  std_logic;                                  -- async. Reset
    CLOCK:                      in  std_logic;                                  -- system clock
    PULSE:                      in  std_logic;                                  -- address increment pulse
    PIXEL_ERROR:                in  std_logic;                                  -- start/stop bit error
    LINE_SYNC:                  in  std_logic;                                  -- line sync input
    FRAME_SYNC:                 in  std_logic;                                  -- frame sync input
    DPRAM_WR_ADDR:              out std_logic_vector(C_ADDR_W-1 downto 0);      -- dpram write address
    DPRAM_WE:                   out std_logic;                                  -- dpram write enable
    DPRAM_RD_PAGE:              out std_logic;                                  -- dpram read page select
    LINE_FINISHED:              out std_logic);                                 -- line finished
end entity DPRAM_WR_CTRL;


architecture RTL of DPRAM_WR_CTRL is

signal I_PULSE1:           std_logic:='0';
signal I_PULSE2:           std_logic:='0';
signal I_PIXEL_ERROR1:     std_logic:='0';
signal I_PIXEL_ERROR2:     std_logic:='0';
signal I_DPRAM_WR_PAGE:    std_logic:='0';
signal I_LINE_SYNC1:       std_logic:='0';
signal I_LINE_SYNC2:       std_logic:='0';
signal I_LINE_SYNC3:       std_logic:='0';
signal I_DPRAM_WR_ADDR:    std_logic_vector(C_ADDR_W-2 downto 0):=(others => '0');


begin

LINE_SYNC_DELAY: process(CLOCK)
begin
   if (rising_edge(CLOCK)) then
      I_LINE_SYNC1 <= LINE_SYNC;
      I_LINE_SYNC2 <= I_LINE_SYNC1;
      I_LINE_SYNC3 <= I_LINE_SYNC2;
   end if;
end process LINE_SYNC_DELAY;


PULSE_DELAY: process(CLOCK)
begin
   if (rising_edge(CLOCK)) then
      I_PULSE1 <= PULSE;
      I_PULSE2 <= I_PULSE1;
      I_PIXEL_ERROR1 <= PIXEL_ERROR;
      I_PIXEL_ERROR2 <= I_PIXEL_ERROR1;
   end if;
end process PULSE_DELAY;


--------------------------------------------------------------------------------
-- DPRAM write page signal (I_DPRAM_WR_PAGE), changes state once per line
--------------------------------------------------------------------------------
DPRAM_WR_PAGE_EVAL: process(CLOCK)
begin
   if (rising_edge(CLOCK)) then
      if (I_LINE_SYNC3 = '1') then
         I_DPRAM_WR_PAGE <= not I_DPRAM_WR_PAGE;
      else
         I_DPRAM_WR_PAGE <= I_DPRAM_WR_PAGE;
      end if;
   end if;
end process DPRAM_WR_PAGE_EVAL;


--------------------------------------------------------------------------------
-- DPRAM write address
--------------------------------------------------------------------------------
DPRAM_WR_EVAL: process(CLOCK)
begin
   if (rising_edge(CLOCK)) then
      if ((FRAME_SYNC = '1') or (I_LINE_SYNC3 = '1') or (I_PIXEL_ERROR2 = '1')) then
         I_DPRAM_WR_ADDR <= (others => '0');
      elsif (I_PULSE2 = '1') then
         I_DPRAM_WR_ADDR <= I_DPRAM_WR_ADDR + "01";
      end if;
   end if;
end process DPRAM_WR_EVAL;


DPRAM_WR_ADDR(C_ADDR_W-1) <= I_DPRAM_WR_PAGE;
DPRAM_WR_ADDR(C_ADDR_W-2 downto 0) <= I_DPRAM_WR_ADDR;

DPRAM_WE <= I_PULSE1;

DPRAM_RD_PAGE <= not I_DPRAM_WR_PAGE;

LINE_FINISHED <= I_LINE_SYNC3;

end RTL;
