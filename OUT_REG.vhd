library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity OUT_REG is
  generic (
    D_WIDTH:  integer:=16);
  port (
    RESET:                      in  std_logic;                                  -- async. Reset
    CLOCK:                      in  std_logic;                                  -- readout clock
    RDAT_VALID:                 in  std_logic;                                  -- 
    PAR_INPUT:                  in std_logic_vector(D_WIDTH-1 downto 0);        -- 
    PAR_OUTPUT:                 out std_logic_vector(D_WIDTH-1 downto 0));        -- 
end entity OUT_REG;

architecture RTL of OUT_REG is

constant    C_RDAT_INVALID_VALUE:   std_logic_vector(D_WIDTH-1 downto 0):=conv_std_logic_vector(0,D_WIDTH); --std_logic_vector(D_WIDTH-1 downto 0):=(others => '0');
signal      I_OUTPUT:               std_logic_vector(D_WIDTH-1 downto 0);
signal      I_RDAT_VALID_SW_OUT:    std_logic_vector(D_WIDTH-1 downto 0);

begin

RDAT_VALID_SW: process(RDAT_VALID,PAR_INPUT,CLOCK)
begin
    if (RDAT_VALID = '1') then
        I_RDAT_VALID_SW_OUT <= PAR_INPUT;
    else
        I_RDAT_VALID_SW_OUT <= C_RDAT_INVALID_VALUE;
    end if;
end process RDAT_VALID_SW;

OUT_PUT_LATCH: process(RESET,CLOCK)
begin
    if (RESET = '1') then
        I_OUTPUT <= (others => '0');
    elsif (rising_edge(CLOCK)) then
        I_OUTPUT <= I_RDAT_VALID_SW_OUT;
    end if;
end process OUT_PUT_LATCH;

PAR_OUTPUT  <= I_OUTPUT;

end RTL;
