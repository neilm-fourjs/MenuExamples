IMPORT FGL fgldialog
IMPORT FGL lib
IMPORT FGL lookup

&include "schema.inc"

DEFINE m_arr    DYNAMIC ARRAY OF RECORD LIKE customers.*
DEFINE m_curRow SMALLINT
DEFINE m_where  STRING
MAIN
	DEFINE l_cust        RECORD LIKE customers.*
	DEFINE l_email       LIKE customers.email
	DEFINE l_new         BOOLEAN = FALSE
	DEFINE l_dataChanged BOOLEAN = FALSE
	DEFINE l_mess        STRING
	DEFINE l_accept      BOOLEAN = FALSE
	DEFINE l_dirty       BOOLEAN = FALSE
	DEFINE l_mode        CHAR(1)

	CALL lib.init()

	CALL lib.db_connect()

	LET l_mode = base.Application.getArgument(2)

	CALL ui.Interface.setText("Customers")
	CALL ui.Interface.setImage("fa-users")
	OPEN FORM f FROM "cust_mnt"
	DISPLAY FORM f
	OPTIONS INPUT WRAP

	CALL ui.Window.getCurrent().setText(SFMT("%1 - %2", TODAY, ui.Window.getCurrent().getText()) )

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
					CALL DIALOG.setFieldActive("customers.*", FALSE) -- disable all the fields
				END IF

			BEFORE ROW
				DISPLAY SFMT("Before Row %1", arr_curr())
				CALL setRow(DIALOG, arr_curr()) RETURNING l_cust.*

			ON ACTION lookup
				VAR l_lookup lookup
				CALL l_lookup.init("customers", "cust_code, cust_name", "Code,Name", "1=1", "cust_code")
				LET l_lookup.allowUpdate = TRUE
				{VAR l_lookup lookup
				LET l_lookup.tableName    = "customers, countries"
				LET l_lookup.columnList   = "cust_code, cust_name, name"
				LET l_lookup.columnTitles = "Code, Name, Country"
				LET l_lookup.orderBy      = "cust_name"
				LET l_lookup.whereClause  = "customers.country = countries.country_code"}
				VAR l_cust_code LIKE customers.cust_code
				LET l_cust_code = l_lookup.lookup()
				VAR i INT
				IF l_cust_code IS NOT NULL THEN
					LET i = m_arr.search("cust_code", l_cust_code)
					CALL setRow(DIALOG, i) RETURNING l_cust.*
					CALL DIALOG.setCurrentRow("arr", i)
				END IF

			ON ACTION search
				CALL doConstruct()
				CALL getData()
				CALL setRow(DIALOG, 1) RETURNING l_cust.*

			ON ACTION first
				CALL setRow(DIALOG, 1) RETURNING l_cust.*

			ON ACTION next
				IF m_curRow < m_arr.getLength() THEN
					CALL setRow(DIALOG, m_curRow + 1) RETURNING l_cust.*
				END IF

			ON ACTION previous
				IF m_curRow > 1 THEN
					CALL setRow(DIALOG, m_curRow - 1) RETURNING l_cust.*
				END IF

			ON ACTION last
				CALL setRow(DIALOG, m_arr.getLength()) RETURNING l_cust.*

			ON ACTION delete
				IF fgl_winQuestion("Confirm", "Delete row?", "No", "Yes|No", "question", 0) = "Yes" THEN
					DELETE FROM customers WHERE cust_code = m_arr[m_curRow].cust_code
					CALL getData()
					CALL setRow(DIALOG, 1) RETURNING l_cust.*
				END IF

			ON ACTION insert
				INITIALIZE l_cust.* TO NULL
				LET l_new = TRUE
				NEXT FIELD cust_code

			ON ACTION update
				NEXT FIELD cust_code

		END DISPLAY

		INPUT BY NAME l_cust.* ATTRIBUTE(WITHOUT DEFAULTS)
			BEFORE INPUT
				LET l_accept = FALSE
				LET int_flag = FALSE
				LET l_dirty  = FALSE
				DISPLAY "Before Input"
				IF l_new THEN
					CALL DIALOG.setFieldActive("cust_code", TRUE)
				ELSE
					CALL DIALOG.setFieldActive("cust_code", FALSE)
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

			AFTER FIELD cust_code
				IF l_new THEN
					SELECT * FROM customers WHERE cust_code = l_cust.cust_code
					IF STATUS != NOTFOUND THEN
						CALL lib.showError(SFMT("Customer '%1' code already exists!", l_cust.cust_code CLIPPED))
						NEXT FIELD CURRENT
					END IF
				END IF

			ON ACTION save
				IF DIALOG.validate("customers.*") = 0 THEN
					LET l_accept = TRUE
					CALL DIALOG.accept()
				END IF

			ON ACTION cancel
				CALL DIALOG.cancel()

			AFTER INPUT
				DISPLAY SFMT("After Input int_flag: %1", int_flag)
				IF int_flag THEN
					MESSAGE "Cancelled"
					NEXT FIELD a_cust_code
				END IF
				IF NOT l_accept THEN
					IF l_dirty THEN
						IF fgl_winQuestion("Confirm", "Record touched, confirm abort?", "No", "Yes|No", "question", 0) == "No" THEN
							NEXT FIELD CURRENT
						END IF
						MESSAGE "Aborted"
					END IF
					NEXT FIELD a_cust_code
				END IF
				IF l_new THEN
					INSERT INTO customers VALUES l_cust.*
				ELSE
					UPDATE customers SET customers.* = l_cust.* WHERE cust_code = l_cust.cust_code
				END IF
				IF sqlca.sqlcode = 0 THEN
					LET l_mess = SFMT("Customer '%1' %2.", l_cust.cust_code, IIF(l_new, "Inserted", "Updated"))
					MESSAGE l_mess
				ELSE
					LET l_mess = SFMT("%1 of '%2' Failed: %3", IIF(l_new, "Insert", "Update"), l_cust.cust_code, SQLERRMESSAGE)
					ERROR l_mess
				END IF
				CALL lib.log(1, l_mess)
				LET l_dataChanged = TRUE
				NEXT FIELD a_cust_code
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
	LET l_stmt = SFMT("SELECT * FROM customers WHERE %1 ORDER BY cust_name", m_where)
	CALL m_arr.clear()
	DECLARE cur CURSOR FROM l_stmt
	FOREACH cur INTO m_arr[i := i + 1].*
	END FOREACH
	CALL m_arr.deleteElement(i)
END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION setRow(d ui.Dialog, i INT) RETURNS(RECORD LIKE customers.*)
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
	CONSTRUCT BY NAME l_where ON customers.*
	IF int_flag THEN
		RETURN
	END IF
	LET l_stmt = SFMT("SELECT COUNT(*) FROM customers WHERE %1 ORDER BY cust_code", l_where)
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
	DEFINE l_cust        RECORD LIKE customers.*
	DEFINE l_row         INTEGER = 0
	DEFINE l_rpt_started BOOLEAN = FALSE

	DEFINE l_handler om.SaxDocumentHandler
	DISPLAY SFMT("FGLRESOUCEPATH=%1", fgl_getEnv("FGLRESOURCEPATH"))
	DECLARE rpt_cur CURSOR FOR SELECT * FROM customers
	FOREACH rpt_cur INTO l_cust.*
		IF l_cust.cust_code IS NULL THEN
			CONTINUE FOREACH
		END IF
		LET l_row += 1
		IF l_row = 1 THEN
			LET l_rpt_started = TRUE

			LET l_handler = lib.report_setup("cust1")
			IF l_handler IS NULL THEN RETURN END IF
			START REPORT rpt1 TO XML HANDLER l_handler

		END IF
		OUTPUT TO REPORT rpt1(l_row, l_cust.*)
	END FOREACH
	IF l_rpt_started THEN
		FINISH REPORT rpt1
	END IF
END FUNCTION
--------------------------------------------------------------------------------------------------------------
REPORT rpt1(l_row INT, l_cust RECORD LIKE customers.*)
	DEFINE l_rptTitle STRING = "Customer Report #1"
	DEFINE l_today    DATE
	FORMAT

		FIRST PAGE HEADER
			LET l_today = TODAY
			PRINT l_rptTitle, l_today
		ON EVERY ROW
			PRINT l_row, l_cust.*

END REPORT
