
IMPORT FGL lib
MAIN
	DEFINE l_cmd STRING
	DEFINE x SMALLINT
	CALL lib.init()
	LET l_cmd = SFMT("fglrun %1 .", base.Application.getArgument(2))
	FOR x = 3 TO base.Application.getArgumentCount()
		LET l_cmd = l_cmd.append( SFMT(" %1", base.Application.getArgument(x)))
	END FOR
	CALL lib.log(1, SFMT("cmd: %1", l_cmd))
	RUN l_cmd WITHOUT WAITING
END MAIN