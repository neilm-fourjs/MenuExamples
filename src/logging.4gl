FUNCTION logIt(l_func STRING, l_msg STRING)
	DISPLAY SFMT("%1:%2: %3", CURRENT, l_func, l_msg)
END FUNCTION
