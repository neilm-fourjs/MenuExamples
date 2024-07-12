-- Arg  1:
-- M - MDI new GBC sidebar
-- m - MDI startMenu
-- t - MDI tabbed
-- S - SDI

-- Arg 2:
-- if starts with 'menu' then it used as the screen form to show.

IMPORT FGL lib
&include "schema.inc"

DEFINE m_menus DYNAMIC ARRAY OF RECORD LIKE menus.*
DEFINE m_menu  DYNAMIC ARRAY OF RECORD LIKE menus.*
DEFINE m_buttons DYNAMIC ARRAY OF RECORD
	text STRING,
	desc STRING,
	img  STRING,
	exec STRING
END RECORD
DEFINE m_buts      SMALLINT = 0
DEFINE m_menu_back LIKE menus.m_name
MAIN
	DEFINE x        SMALLINT
	DEFINE l_cmd    STRING
	DEFINE l_click  BOOLEAN
	DEFINE l_curRow SMALLINT

	RUN "env | sort > /tmp/env.gas"

	CALL ui.Interface.setText("Menu")
	CALL ui.Interface.setImage("fa-navicon")

	CALL lib.init()
	CALL lib.db_connect()

	IF base.Application.getArgument(2) MATCHES "menu*" THEN
		OPEN FORM f FROM base.Application.getArgument(2)
	ELSE
		OPEN FORM f FROM "menu"
	END IF
	DISPLAY FORM f
	CALL ui.Window.getCurrent().setText(SFMT("Menu - %1", TODAY))
	CALL ui.Window.getCurrent().setImage("fa-navicon")
	IF base.Application.getArgument(1) = "t" THEN
		CALL ui.Window.getCurrent().getNode().setAttribute("style", "tabbed")
	END IF

	CALL getMenu("main")
	IF base.Application.getArgument(1) = "m" OR base.Application.getArgument(1) = "t" THEN
		CALL buildStartMenu()
	END IF


	DISPLAY ARRAY m_menu TO menu.* ATTRIBUTE(UNBUFFERED, FOCUSONFIELD, CANCEL = FALSE, ACCEPT = FALSE)
		BEFORE DISPLAY
			LET l_curRow = m_menu.getLength() + 1
			CALL DIALOG.setCurrentRow("menu", l_curRow)
			DISPLAY SFMT("BDisp SetRow: %1 CR: %2", l_curRow, DIALOG.getCurrentRow("menu"))
			FOR x = 1 TO 15
				IF m_buttons[x].text IS NOT NULL THEN
					CALL DIALOG.setActionText("but" || (x USING "&&"), m_buttons[x].text)
					CALL DIALOG.setActionComment("but" || (x USING "&&"), m_buttons[x].desc)
					CALL DIALOG.setActionImage("but" || (x USING "&&"), m_buttons[x].img)
				ELSE
					CALL DIALOG.setActionHidden("but" || (x USING "&&"), TRUE)
				END IF
			END FOR

		BEFORE FIELD a04
			DISPLAY SFMT("BField: %1", DIALOG.getCurrentRow("menu"))
			LET l_click = FALSE

		AFTER FIELD a04
			DISPLAY SFMT("AField: %1", DIALOG.getCurrentRow("menu"))
			LET l_click = TRUE

		BEFORE ROW
			DISPLAY SFMT("BRow: %1", DIALOG.getCurrentRow("menu"))
			IF l_click THEN
				LET l_curRow = DIALOG.getCurrentRow("menu")
				IF m_menu[l_curRow].m_text IS NOT NULL THEN
					CALL lib.log(1, SFMT("Before row %1 '%2'", l_curRow, m_menu[l_curRow].m_text))
					CASE m_menu[l_curRow].m_type
						WHEN "f" -- SDI
							LET l_cmd = SFMT("fglrun mdiSwitch S %1 %2", m_menu[l_curRow].m_cmd, m_menu[l_curRow].m_args)
							CALL runProg(l_cmd)
						WHEN "F" -- MDI
							LET l_cmd = SFMT("fglrun %1 c %2", m_menu[l_curRow].m_cmd, m_menu[l_curRow].m_args)
							CALL runProg(l_cmd)
						WHEN "M"
							CALL getMenu(m_menu[l_curRow].m_child)
						WHEN "Q"
							EXIT DISPLAY
						WHEN "B"
							CALL getMenu(m_menu_back)
					END CASE
					LET l_curRow = m_menu.getLength() + 1
					CALL DIALOG.setCurrentRow("menu", l_curRow)
					DISPLAY SFMT("BRow SetRow: %1 CR: %2", l_curRow, DIALOG.getCurrentRow("menu"))
				END IF
			ELSE
				DISPLAY "Ignore"
			END IF

		AFTER ROW
			DISPLAY SFMT("ARow: %1", DIALOG.getCurrentRow("menu"))

		ON ACTION but01
			CALL runProg(m_buttons[1].exec)
		ON ACTION but02
			CALL runProg(m_buttons[2].exec)
		ON ACTION but03
			CALL runProg(m_buttons[3].exec)
		ON ACTION but04
			CALL runProg(m_buttons[4].exec)
		ON ACTION but05
			CALL runProg(m_buttons[5].exec)
		ON ACTION but06
			CALL runProg(m_buttons[6].exec)
		ON ACTION but07
			CALL runProg(m_buttons[7].exec)
		ON ACTION but08
			CALL runProg(m_buttons[8].exec)
		ON ACTION but09
			CALL runProg(m_buttons[9].exec)
		ON ACTION but10
			CALL runProg(m_buttons[10].exec)
		ON ACTION but11
			CALL runProg(m_buttons[11].exec)
		ON ACTION but12
			CALL runProg(m_buttons[12].exec)
		ON ACTION but13
			CALL runProg(m_buttons[13].exec)
		ON ACTION but14
			CALL runProg(m_buttons[14].exec)
		ON ACTION but15
			CALL runProg(m_buttons[15].exec)

		ON ACTION quit
			EXIT DISPLAY
		ON ACTION close
			EXIT DISPLAY
		ON ACTION about
			CALL lib.about()
	END DISPLAY
	CALL lib.exit_program(0, "Program Finished")
END MAIN
--------------------------------------------------------------------------------------------------------------
FUNCTION runProg(l_cmd STRING) RETURNS()
	CALL lib.log(1, SFMT("Run: %1", l_cmd))
	RUN l_cmd WITHOUT WAITING
END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION getMenu(l_name STRING) RETURNS()
	DEFINE x, y SMALLINT
	IF m_menus.getLength() = 0 THEN -- Read Menus
		DECLARE cur CURSOR FOR SELECT * FROM menus
		FOREACH cur INTO m_menus[x := x + 1].*
		END FOREACH
		CALL m_menus.deleteElement(x) -- delete the last empty row
	END IF

	CALL m_menu.clear()
	CALL lib.log(1, SFMT("Load menu '%1' ...", l_name))
	FOR x = 1 TO m_menus.getLength()
		IF m_menus[x].m_name = l_name THEN
			IF m_menus[x].m_type = "T" THEN
				CALL ui.Interface.setText(m_menus[x].m_text)
				DISPLAY m_menus[x].m_text TO menu_title
			ELSE
				LET m_menu[y := y + 1].* = m_menus[x].*
			END IF
			IF m_menus[x].m_child IS NOT NULL THEN
				LET m_menu_back = m_menus[x].m_child
			END IF
		END IF
	END FOR
	IF l_name = "main" THEN
		LET m_menu[y := y + 1].m_text = "Exit Program"
		LET m_menu[y].m_type          = "Q"
		LET m_menu[y].m_desc          = "Completely close the application"
		LET m_menu[y].m_img           = "fa-power-off"
	ELSE
		LET m_menu[y := y + 1].m_text = "Back"
		LET m_menu[y].m_desc          = "Go back to the previous menu"
		LET m_menu[y].m_type          = "B"
		LET m_menu[y].m_img           = "fa-arrow-left"
	END IF
	LET m_menu[y := y + 1].m_text = NULL -- hidden last row.
END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION buildStartMenu()
	DEFINE l_sm_root om.DomNode

	LET l_sm_root = ui.Interface.getRootNode()
	LET l_sm_root = l_sm_root.createChild("StartMenu")
	CALL lib.log(1, "buildStartMenu")
	CALL buildStartMenuAdd(l_sm_root, "main")

END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION buildStartMenuAdd(l_sm_menu om.DomNode, l_menu STRING)
	DEFINE x         SMALLINT
	DEFINE l_cmd     STRING
	DEFINE l_sm_item om.DomNode
	CALL lib.log(1, SFMT("buildStartMenuAdd(%1) menu len: %2", l_menu, m_menus.getLength() ))
	FOR x = 1 TO m_menus.getLength()
		IF m_menus[x].m_name = l_menu THEN
			IF m_menus[x].m_type = "M" THEN
				LET l_sm_item = l_sm_menu.createChild("StartMenuGroup")
				CALL l_sm_item.setAttribute("text", m_menus[x].m_text)
				CALL buildStartMenuAdd(l_sm_item, m_menus[x].m_child)
			END IF

			IF m_menus[x].m_type = "F" OR m_menus[x].m_type = "f" THEN
				LET m_buts = m_buts + 1
				IF m_menus[x].m_type = "F" THEN
					LET l_cmd = SFMT("fglrun %1 c %2", m_menus[x].m_cmd, m_menus[x].m_args)
				ELSE
					LET l_cmd = SFMT("fglrun mdiSwitch S %1 %2", m_menus[x].m_cmd, m_menus[x].m_args)
				END IF
				LET m_buttons[m_buts].exec = l_cmd
				LET m_buttons[m_buts].text = m_menus[x].m_text
				LET m_buttons[m_buts].desc = m_menus[x].m_desc
				LET m_buttons[m_buts].img  = m_menus[x].m_img
			END IF

			IF m_menus[x].m_type = "F" THEN
				LET l_sm_item = l_sm_menu.createChild("StartMenuCommand")
				CALL l_sm_item.setAttribute("text", m_menus[x].m_text)
				CALL l_sm_item.setAttribute("comment", m_menus[x].m_desc)
				CALL l_sm_item.setAttribute("exec", l_cmd)
			END IF
		END IF
	END FOR
END FUNCTION
