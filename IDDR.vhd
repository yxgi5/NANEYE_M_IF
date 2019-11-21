LIBRARY ieee;
USE ieee.std_logic_1164.all; 

LIBRARY work;

ENTITY IDDR IS 
	PORT
	(
		inclock :       IN  STD_LOGIC;
		datain :        IN  STD_LOGIC;
		aclr :          IN  STD_LOGIC;
		dataout_h :     OUT  STD_LOGIC;
		dataout_l :     OUT  STD_LOGIC
	);
END IDDR;

ARCHITECTURE RTL OF IDDR IS 

SIGNAL	neg_reg_out :  STD_LOGIC;

BEGIN 

PROCESS(inclock,aclr)
BEGIN
IF (aclr = '1') THEN
	dataout_h <= '0';
ELSIF (RISING_EDGE(inclock)) THEN
	dataout_h <= datain;
END IF;
END PROCESS;

PROCESS(inclock,aclr)
BEGIN
IF (aclr = '1') THEN
	neg_reg_out <= '0';
ELSIF (FALLING_EDGE(inclock)) THEN
	neg_reg_out <= datain;
END IF;
END PROCESS; 

PROCESS(inclock,neg_reg_out)
BEGIN
IF (inclock = '1') THEN
	dataout_l <= neg_reg_out;
END IF;
END PROCESS;


END RTL;
