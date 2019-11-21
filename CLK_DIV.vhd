library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity CLK_DIV is
    generic (
        DIV:                      integer:=16);
    port (
        RESET:                    in  std_logic;
        CLOCK:                    in  std_logic;
        ENABLE:                   in  std_logic;
        PULSE:                    out std_logic);
end entity CLK_DIV;

architecture RTL of CLK_DIV is

signal I_PULSE:                 std_logic;
signal I_POS_CNT:               std_logic_vector(7 downto 0);
signal I_NEG_CNT:               std_logic_vector(7 downto 0);

-- constant C_CAL:                 std_logic_vector(0 downto 0):=conv_std_logic_vector(DIV,1);  

begin

POS_CNT: process(RESET,CLOCK)
begin
    if (RESET = '1') then
        I_POS_CNT <= (others => '0');
    elsif (rising_edge(CLOCK)) then
        if (ENABLE = '1') then
            if (I_POS_CNT = DIV-1) then
                I_POS_CNT <= (others => '0');
            else
                I_POS_CNT <= I_POS_CNT + '1';
            end if;
        else
            I_POS_CNT <= (others => '0');
        end if;
    end if;
end process POS_CNT;

NEG_CNT: process(RESET,CLOCK)
begin
    if (RESET = '1') then
        I_NEG_CNT <= (others => '0');
    elsif (falling_edge(CLOCK)) then
        if (ENABLE = '1') then
            if (I_NEG_CNT = DIV-1) then
                I_NEG_CNT <= (others => '0');
            else
                I_NEG_CNT <= I_NEG_CNT + '1';
            end if;
        else
            I_NEG_CNT <= (others => '0');
        end if;
    end if;
end process NEG_CNT;

OUT_DIV: process(RESET,CLOCK)
begin
    if (RESET = '1') then
        I_PULSE <= '0';
    elsif (rising_edge(CLOCK)) then
        if (ENABLE = '1') then
            -- if (C_CAL = 1) then
            if (conv_integer(DIV) mod 2 = 1) then
                if ((I_POS_CNT < (DIV+1)/2) and (I_NEG_CNT < (DIV+1)/2)) then
                    I_PULSE <= '1';
                else
                    I_PULSE <= '0';
                end if;
            else
                if (I_POS_CNT < DIV/2) then
                    I_PULSE <= '1';
                else
                    I_PULSE <= '0';
                end if;
            end if; 
        else
            I_PULSE <= '0';
        end if;
    end if;
end process OUT_DIV;

PULSE  <= I_PULSE;

end RTL;
