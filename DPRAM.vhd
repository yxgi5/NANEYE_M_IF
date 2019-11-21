--------------------------------------------------------------------------------
-- AWAIBA GmbH
--------------------------------------------------------------------------------
-- MODUL NAME:  DPRAM
-- FILENAME:    dpram.vhd
-- AUTHOR:      Michael Heil - Ing. Büro für FPGA-Logic-Design
--              email:  michael.heil@fpga-logic-design.de
--
-- CREATED:     13.01.2007
--------------------------------------------------------------------------------
-- DESCRIPTION: Dual-Port RAM mit unabhängigen Clocks
--              Bei der Synthese mit Xilinx XST wird automatisch ein BlockRAM
--              instantiiert
--------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------
-- REVISIONS:
-- DATE         VERSION    AUTHOR      DESCRIPTION
-- 13.01.2007   0.1        M. Heil
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity DPRAM is
   generic (
      A_WIDTH:  integer:=4;
      D_WIDTH:  integer:=16);
   port  (
      CLKA:     in  std_logic;
      CLKB:     in  std_logic;
      ENA:      in  std_logic;
      ENB:      in  std_logic;
      WEA:      in  std_logic;
      WEB:      in  std_logic;
      ADDRA:    in  std_logic_vector(A_WIDTH-1 downto 0);
      ADDRB:    in  std_logic_vector(A_WIDTH-1 downto 0);
      DIA:      in  std_logic_vector(D_WIDTH-1 downto 0);
      DIB:      in  std_logic_vector(D_WIDTH-1 downto 0);
      DOA:      out std_logic_vector(D_WIDTH-1 downto 0);
      DOB:      out std_logic_vector(D_WIDTH-1 downto 0));
end entity DPRAM;


architecture RTL of DPRAM is

type T_MEM is array (2**A_WIDTH-1 downto 0) of std_logic_vector(D_WIDTH-1 downto 0);
shared variable RAM: T_MEM;


begin

--------------------------------------------------------------------------------
-- Schreiben/Lesen Port A
--------------------------------------------------------------------------------
MEM_PROCA: process(CLKA)
begin
   if (rising_edge(CLKA)) then
      if (ENA = '1') then
         if (WEA = '1') then
            RAM(conv_integer(ADDRA)) := DIA;
         end if;
         DOA <= RAM(conv_integer(ADDRA));
      end if;
   end if;
end process MEM_PROCA;


--------------------------------------------------------------------------------
-- Schreiben/Lesen Port B
--------------------------------------------------------------------------------
MEM_PROCB: process(CLKB)
begin
   if (rising_edge(CLKB)) then
      if (ENB = '1') then
         if (WEB = '1') then
            RAM(conv_integer(ADDRB)) := DIB;
         end if;
         DOB <= RAM(conv_integer(ADDRB));
      end if;
   end if;
end process MEM_PROCB;


end RTL;

