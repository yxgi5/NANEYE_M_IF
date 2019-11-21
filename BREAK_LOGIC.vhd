library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity BREAK_LOGIC is
  port (
    RESET:                      in  std_logic;                                  -- async. Reset
    CLOCK:                      in  std_logic;                                  -- readout clock
    CONFIG_EN:                  in  std_logic;                                  -- 
    SYNC_START:                 in  std_logic;                                  -- 
    DEC_OUT_EN:                 in  std_logic;                                  -- 
    BREAK_N_OUTPUT:             out std_logic_vector(1 downto 0));               -- 
end entity BREAK_LOGIC;


architecture RTL of BREAK_LOGIC is

signal I_BREAK_N:               std_logic_vector(1 downto 0);
    
begin

BREAK_N_0: process(RESET,CLOCK)
begin
    if (RESET = '1') then
        I_BREAK_N(0) <= '1';
    elsif (rising_edge(CLOCK)) then
        if (CONFIG_EN = '1') then
            I_BREAK_N(0) <= '0';
        elsif (SYNC_START = '1') then
            I_BREAK_N(0) <= '1';
        end if;
    end if;
end process BREAK_N_0;

BREAK_N_1: process(RESET,CLOCK)
begin
    if (RESET = '1') then
        I_BREAK_N(1) <= '1';
    elsif (rising_edge(CLOCK)) then
        if (SYNC_START = '1') then
            I_BREAK_N(1) <= '0';
        elsif (DEC_OUT_EN = '1') then
            I_BREAK_N(1) <= '1';
        end if;
    end if;
end process BREAK_N_1;

BREAK_N_OUTPUT  <= I_BREAK_N;

end RTL;
