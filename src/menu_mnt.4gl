IMPORT FGL lib
&include "schema.inc"
DEFINE m_menus DYNAMIC ARRAY OF RECORD LIKE menus.*
MAIN
	DEFINE x      SMALLINT = 0
	DEFINE l_menu RECORD LIKE menus.*

	CALL lib.init()
	CALL lib.db_connect()

	CALL ui.Interface.setText("Menu Maint")
	CALL ui.Interface.setImage("fa-cog")

	DECLARE cur CURSOR FOR SELECT * FROM menus
	FOREACH cur INTO m_menus[x := x + 1].*
	END FOREACH
	CALL m_menus.deleteElement(x) -- delete the last empty row

	OPEN FORM f FROM "menu_mnt"
	DISPLAY FORM f
	DIALOG ATTRIBUTE(UNBUFFERED)
		DISPLAY ARRAY m_menus TO arr.*
			BEFORE ROW
				LET l_menu.* = m_menus[arr_curr()].*
				DISPLAY l_menu.m_img TO img
		END DISPLAY
		INPUT BY NAME l_menu.* ATTRIBUTE(WITHOUT DEFAULTS)
		END INPUT
		ON ACTION about
			CALL lib.about()
		ON ACTION close
			EXIT DIALOG
		ON ACTION quit
			EXIT DIALOG
	END DIALOG

	CALL lib.exit_program(0, "Program Finished")
END MAIN
--------------------------------------------------------------------------------------------------------------
FUNCTION cb_menu_types(l_cb ui.ComboBox)
	CALL l_cb.addItem("T", "Title")
	CALL l_cb.addItem("M", "Menu")
	CALL l_cb.addItem("F", "Program")
END FUNCTION
