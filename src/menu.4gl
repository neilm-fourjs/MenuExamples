IMPORT FGL lib
&include "schema.inc"

DEFINE m_menus     DYNAMIC ARRAY OF RECORD LIKE menus.*
DEFINE m_menu      DYNAMIC ARRAY OF RECORD LIKE menus.*
DEFINE m_menu_back LIKE menus.m_name
MAIN
	DEFINE x     SMALLINT
	DEFINE l_cmd STRING

	RUN "env | sort > /tmp/env.gas"

	CALL ui.Interface.setText("Menu")
	CALL ui.Interface.setImage("fa-navicon")

	CALL lib.init()
	CALL lib.db_connect()

	DECLARE cur CURSOR FOR SELECT * FROM menus
	FOREACH cur INTO m_menus[x := x + 1].*
	END FOREACH
	CALL m_menus.deleteElement(x) -- delete the last empty row

	IF base.Application.getArgument(2) MATCHES "menu*" THEN
		OPEN FORM f FROM base.Application.getArgument(2)
	ELSE
		OPEN FORM f FROM "menu"
	END IF
	DISPLAY FORM f
	CALL ui.Window.getCurrent().setText(SFMT("Menu - %1", TODAY))
	CALL ui.Window.getCurrent().setImage("fa-navicon")

	IF base.Application.getArgument(1) = "m" THEN
		CALL buildStartMenu()
	END IF

	CALL getMenu("main")
	DISPLAY ARRAY m_menu TO menu.* ATTRIBUTE(UNBUFFERED, FOCUSONFIELD, CANCEL = FALSE, ACCEPT = FALSE)
		BEFORE DISPLAY
			CALL DIALOG.setCurrentRow("menu", m_menu.getLength() + 1)
		BEFORE ROW
			LET x = arr_curr()
			IF m_menu[x].m_text IS NOT NULL THEN
				CALL lib.log(1, SFMT("Before row %1 '%2'", x, m_menu[x].m_text))
				CASE m_menu[x].m_type
					WHEN "f" -- SDI
						LET l_cmd = SFMT("fglrun mdiSwitch S %1 %2", m_menu[x].m_cmd, m_menu[x].m_args)
						RUN l_cmd WITHOUT WAITING
					WHEN "F" -- MDI
						LET l_cmd = SFMT("fglrun %1 %2", m_menu[x].m_cmd, m_menu[x].m_args)
						RUN l_cmd WITHOUT WAITING
					WHEN "M"
						CALL getMenu(m_menu[arr_curr()].m_child)
					WHEN "Q"
						EXIT DISPLAY
					WHEN "B"
						CALL getMenu(m_menu_back)
				END CASE
			END IF
			CALL DIALOG.setCurrentRow("menu", m_menu.getLength() + 1)
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
FUNCTION getMenu(l_name STRING) RETURNS()
	DEFINE x, y SMALLINT
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

	CALL buildStartMenuAdd(l_sm_root, "main" )

END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION buildStartMenuAdd( l_sm_menu om.DomNode, l_menu STRING )
	DEFINE x SMALLINT
	DEFINE l_sm_item om.DomNode
	FOR x = 1 TO m_menus.getLength()
		IF m_menus[x].m_name = l_menu THEN
			IF m_menus[x].m_type = "M" THEN
				LET l_sm_item = l_sm_menu.createChild("StartMenuGroup")
				CALL l_sm_item.setAttribute("text", m_menus[x].m_text)
				CALL buildStartMenuAdd(l_sm_item, m_menus[x].m_child )
			END IF
			IF m_menus[x].m_type = "F" THEN
				LET l_sm_item = l_sm_menu.createChild("StartMenuCommand")
				CALL l_sm_item.setAttribute("text", m_menus[x].m_text)
				CALL l_sm_item.setAttribute("comment", m_menus[x].m_desc)
				CALL l_sm_item.setAttribute("exec", SFMT("fglrun %1 %2", m_menus[x].m_cmd, m_menus[x].m_args))
			END IF
		END IF
	END FOR
END FUNCTION