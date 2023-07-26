IMPORT FGL fgldialog
IMPORT FGL lib
IMPORT FGL lookup

&include "schema.inc"

DEFINE m_arr    DYNAMIC ARRAY OF RECORD LIKE stock.*
DEFINE m_curRow SMALLINT
DEFINE m_where  STRING
MAIN
	DEFINE l_stk         RECORD LIKE stock.*
	DEFINE l_new         BOOLEAN = FALSE
	DEFINE l_dataChanged BOOLEAN = FALSE
	DEFINE l_mess        STRING
	DEFINE l_accept      BOOLEAN = FALSE
	DEFINE l_dirty       BOOLEAN = FALSE
	DEFINE l_mode        CHAR(1)
	CALL lib.init()

	CALL lib.db_connect()

	LET l_mode = base.Application.getArgument(2)

	CALL ui.Interface.setText("Stock")
	CALL ui.Interface.setImage("fa-diamond")
	OPEN FORM f FROM "stk_mnt"
	DISPLAY FORM f
	OPTIONS INPUT WRAP

	LET m_where = " 1=1"
	CALL getData()

	DIALOG ATTRIBUTES(UNBUFFERED)
		DISPLAY ARRAY m_arr TO arr.*
			BEFORE DISPLAY
				CALL DIALOG.getForm().setElementHidden("group1", FALSE)
				LET l_new = FALSE
				IF l_dataChanged THEN
					CALL getData()
					LET l_dataChanged = FALSE
				END IF
				IF l_mode = "E" THEN
					CALL DIALOG.setActionActive("update", FALSE)
					CALL DIALOG.setActionActive("insert", FALSE)
					CALL DIALOG.setActionActive("delete", FALSE)
					CALL DIALOG.setFieldActive("stock.*", FALSE) -- disable all the fields
				END IF

			BEFORE ROW
				DISPLAY SFMT("Before Row %1", arr_curr())
				CALL setRow(DIALOG, arr_curr()) RETURNING l_stk.*

			ON ACTION lookup
				VAR l_lookup lookup
				CALL l_lookup.init("stock", "stock_code, stock_cat, description", "Code,Cat,Desc", "1=1", "stock_code")
				LET l_lookup.allowUpdate = TRUE

				VAR l_stk_code LIKE stock.stock_code
				LET l_stk_code = l_lookup.lookup()
				VAR i INT
				IF l_stk_code IS NOT NULL THEN
					LET i = m_arr.search("stock_code", l_stk_code)
					CALL setRow(DIALOG, i) RETURNING l_stk.*
					CALL DIALOG.setCurrentRow("arr", i)
				END IF

			ON ACTION search
				CALL doConstruct()
				CALL getData()
				CALL setRow(DIALOG, 1) RETURNING l_stk.*

			ON ACTION first
				CALL setRow(DIALOG, 1) RETURNING l_stk.*

			ON ACTION next
				IF m_curRow < m_arr.getLength() THEN
					CALL setRow(DIALOG, m_curRow + 1) RETURNING l_stk.*
				END IF

			ON ACTION previous
				IF m_curRow > 1 THEN
					CALL setRow(DIALOG, m_curRow - 1) RETURNING l_stk.*
				END IF

			ON ACTION last
				CALL setRow(DIALOG, m_arr.getLength()) RETURNING l_stk.*

			ON ACTION delete
				IF fgl_winQuestion("Confirm", "Delete row?", "No", "Yes|No", "question", 0) = "Yes" THEN
					DELETE FROM stock WHERE stock_code = m_arr[m_curRow].stock_code
					CALL getData()
					CALL setRow(DIALOG, 1) RETURNING l_stk.*
				END IF

			ON ACTION insert
				INITIALIZE l_stk.* TO NULL
				LET l_new = TRUE
				NEXT FIELD stock_code

			ON ACTION update
				NEXT FIELD stock_code

		END DISPLAY

		INPUT BY NAME l_stk.* ATTRIBUTE(WITHOUT DEFAULTS)
			BEFORE INPUT
				LET l_accept = FALSE
				LET int_flag = FALSE
				LET l_dirty  = FALSE
				DISPLAY "Before Input"
				IF l_new THEN
					CALL DIALOG.setFieldActive("stock_code", TRUE)
				ELSE
					CALL DIALOG.setFieldActive("stock_code", FALSE)
				END IF
				CALL DIALOG.setActionActive("dialogtouched", TRUE)
				CALL DIALOG.setActionActive("save", FALSE)
				CALL DIALOG.setActionActive("cancel", FALSE)

			ON ACTION dialogtouched
				LET l_dirty = TRUE
				DISPLAY "Touched"
				CALL DIALOG.setActionActive("dialogtouched", FALSE)
				CALL DIALOG.setActionActive("save", TRUE)
				CALL DIALOG.setActionActive("cancel", TRUE)

			AFTER FIELD stock_code
				IF l_new THEN
					SELECT * FROM stock WHERE stock_code = l_stk.stock_code
					IF STATUS != NOTFOUND THEN
						CALL lib.showError(SFMT("Stock Item '%1' code already exists!", l_stk.stock_code CLIPPED))
						NEXT FIELD CURRENT
					END IF
				END IF

			ON ACTION save
				IF DIALOG.validate("stock.*") = 0 THEN
					LET l_accept = TRUE
					CALL DIALOG.accept()
				END IF

			ON ACTION cancel
				CALL DIALOG.cancel()

			AFTER INPUT
				DISPLAY SFMT("After Input int_flag: %1", int_flag)
				IF int_flag THEN
					MESSAGE "Cancelled"
					NEXT FIELD a_stock_code
				END IF
				IF NOT l_accept THEN
					IF l_dirty THEN
						IF fgl_winQuestion("Confirm", "Record touched, confirm abort?", "No", "Yes|No", "question", 0) == "No" THEN
							NEXT FIELD CURRENT
						END IF
						MESSAGE "Aborted"
					END IF
					NEXT FIELD a_stock_code
				END IF
				IF l_new THEN
					INSERT INTO stock VALUES l_stk.*
				ELSE
					UPDATE stock SET stock.* = l_stk.* WHERE stock_code = l_stk.stock_code
				END IF
				IF sqlca.sqlcode = 0 THEN
					LET l_mess = SFMT("Stock Item '%1' %2.", l_stk.stock_code, IIF(l_new, "Inserted", "Updated"))
					MESSAGE l_mess
				ELSE
					LET l_mess = SFMT("%1 of '%2' Failed: %3", IIF(l_new, "Insert", "Update"), l_stk.stock_code, SQLERRMESSAGE)
					ERROR l_mess
				END IF
				CALL lib.log(1, l_mess)
				LET l_dataChanged = TRUE
				NEXT FIELD a_stock_code
		END INPUT

		ON ACTION report
			CALL doReport()

		ON ACTION about
			CALL lib.about()

		ON ACTION quit
			EXIT DIALOG

		ON ACTION close
			EXIT DIALOG
	END DIALOG

	CALL lib.exit_program(0, "Program Finished")
END MAIN
--------------------------------------------------------------------------------------------------------------
FUNCTION getData() RETURNS()
	DEFINE i      INT
	DEFINE l_stmt STRING
	LET l_stmt = SFMT("SELECT * FROM stock WHERE %1 ORDER BY description", m_where)
	CALL m_arr.clear()
	DECLARE cur CURSOR FROM l_stmt
	FOREACH cur INTO m_arr[i := i + 1].*
	END FOREACH
	CALL m_arr.deleteElement(i)
END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION setRow(d ui.Dialog, i INT) RETURNS(RECORD LIKE stock.*)
	LET m_curRow = i
	DISPLAY SFMT("Set Row %1", m_curRow)
	CALL d.setCurrentRow("arr", m_curRow)

	CALL d.setActionActive("previous", m_curRow > 1)
	CALL d.setActionActive("first", m_curRow > 1)
	CALL d.setActionActive("next", m_curRow < m_arr.getLength())
	CALL d.setActionActive("last", m_curRow < m_arr.getLength())

	DISPLAY SFMT("Row %1 of %2 Criteria: %3", m_curRow, m_arr.getLength(), IIF(m_where == " 1=1", "All", m_where)) TO stat
	RETURN m_arr[m_curRow]
END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION doConstruct() RETURNS()
	DEFINE l_where STRING
	DEFINE l_stmt  STRING
	DEFINE l_cnt   INT
	LET int_flag = FALSE
	CONSTRUCT BY NAME l_where ON stock.*
	IF int_flag THEN
		RETURN
	END IF
	LET l_stmt = SFMT("SELECT COUNT(*) FROM stock WHERE %1 ORDER BY stock_code", l_where)
	DISPLAY SFMT("SQL: %1", l_stmt)
	DECLARE cnt_cur CURSOR FROM l_stmt
	OPEN cnt_cur
	FETCH cnt_cur INTO l_cnt
	CLOSE cnt_cur
	IF l_cnt = 0 THEN
		ERROR "No Rows Found"
		LET l_where = " 1=1"
	END IF
	LET m_where = l_where
END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION doReport()
	DEFINE l_stk         RECORD LIKE stock.*
	DEFINE l_row         INTEGER = 0
	DEFINE l_rpt_started BOOLEAN = FALSE
	DEFINE l_handler om.SaxDocumentHandler

	DECLARE rpt_cur CURSOR FOR SELECT * FROM stock ORDER BY stock_cat, stock_code
	FOREACH rpt_cur INTO l_stk.*
		IF l_stk.stock_code IS NULL THEN
			CONTINUE FOREACH
		END IF
		LET l_row += 1
		IF l_row = 1 THEN
			LET l_handler = lib.report_setup("stock0, stock1, stock2, stkxls")
			IF l_handler IS NULL THEN RETURN END IF
			LET l_rpt_started = TRUE
			START REPORT rpt1 TO XML HANDLER l_handler
		END IF
		OUTPUT TO REPORT rpt1(l_row, l_stk.*)
	END FOREACH
	IF l_rpt_started THEN
		FINISH REPORT rpt1
		CALL lib.report_finish()
	END IF
END FUNCTION
--------------------------------------------------------------------------------------------------------------
REPORT rpt1(l_row INT, l_stk RECORD LIKE stock.*)
	DEFINE l_rptTitle STRING = "Stock Report"
	DEFINE l_today    DATE
	DEFINE l_cat_desc LIKE stock_cat.cat_name
	DEFINE l_cat_row  SMALLINT
	DEFINE l_tot_free_stock INT

	ORDER EXTERNAL BY l_stk.stock_cat

	FORMAT

		FIRST PAGE HEADER
			LET l_today = TODAY
			PRINT l_rptTitle, l_today

		BEFORE GROUP OF l_stk.stock_cat
			SELECT cat_name INTO l_cat_desc FROM stock_cat WHERE catid = l_stk.stock_cat
			IF STATUS = NOTFOUND THEN
				LET l_cat_desc = "Not Found!"
			END IF
			LET l_cat_row = 0
			LET l_tot_free_stock = 0
			PRINT l_cat_desc

		ON EVERY ROW
			LET l_cat_row += 1
			LET l_tot_free_stock += l_stk.free_stock
			PRINT l_row, l_cat_row, l_tot_free_stock, l_stk.*

END REPORT
