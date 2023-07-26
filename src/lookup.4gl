--------------------------------------------------------------------------------
#+ Dynamic Lookup - by Neil J Martin ( neilm@4js.com )
#+ This library is intended as an example of useful library code for use with
#+ Genero 4.00 >
#+
#+ No warrantee of any kind, express or implied, is included with this software;
#+ use at your own risk, responsibility for damages (if any) to anyone resulting
#+ from the use of this software rests entirely with the user.
--------------------------------------------------------------------------------
-- There a few different ways this library can be used:
-- 	DEFINE l_lookup lookup.lookup
--	CALL l_lookup.init( "countries", "*", "Code,Country", "1=1", "country_name")
--	DISPLAY "Selected value:",  l_lookup.lookup()
--
-- or
--
-- 	DEFINE l_lookup lookup2.lookup
--	LET l_lookup.tableName = "colours"
--	LET l_lookup.columnList =  "*"
--	LET l_lookup.columnTitles = "Key,Name,Hex"
--	LET l_lookup.orderBy = "colour_name"
--	DISPLAY "Selected value:", l_lookup.lookup()
--
-- or
--
--	DEFINE l_lookup lookup.lookup
--	LET l_lookup.sql_count = "SELECT COUNT(*) FROM customer"
--	LET l_lookup.columnTitles = "Code,Name,Address"
--	LET l_lookup.sql_getData = "SELECT customer.customer_code, customer.customer_name, addresses.line1 FROM customer, addresses WHERE customer.del_addr = addresses.rec_key ORDER BY customer_name"
--	LET l_lookup.windowTitle = "Customers"
--	DISPLAY "Selected value:", l_lookup.lookup()
--

IMPORT FGL fgldialog
IMPORT FGL lib

&define GL_DBGMSG(l_lev, l_msg) CALL lib.log(l_lev, l_msg)

PUBLIC TYPE lookup RECORD
	tableName      STRING,             -- Table name
	columnList     STRING,             -- List of Columns, comma separated
	columnTitles   STRING,             -- Headings ( defaults to column names ), comma separated
	whereClause    STRING,             -- where clause ( defaults to 1=1 )
	orderBy        STRING,             -- Order by ( optional )
	maxColWidth    SMALLINT,           -- Largest column width ( default is coded as 40 )
	isKeySerial    BOOLEAN,            -- Is the key a serial column?
	allowUpdate    BOOLEAN,            -- Allow update of a row ( WIP )
	allowInsert    BOOLEAN,            -- Allow insert of a row ( WIP )
	allowDelete    BOOLEAN,            -- Allow Delete of a row ( WIP )
	sql_count      STRING,             -- SQL for select count of rows
	sql_getData    STRING,             -- Main select for fetching the data
	totalRecords   INTEGER,            -- Total row count from select count
	totalFields    SMALLINT,           -- Number of fields
	sqlQueryHandle base.SqlHandle,     -- The SQL Handle for the main select SQL
	dsp_fields DYNAMIC ARRAY OF RECORD -- The array of fields selected
		name  STRING,
		type  STRING,
		width INTEGER
	END RECORD,
	fields DYNAMIC ARRAY OF RECORD -- The array of fields selected
		name STRING,
		type STRING
	END RECORD,
	inputVBox       om.DomNode,
	columnTitlesArr DYNAMIC ARRAY OF STRING, -- Column headiing array based on 'columnTitles'
	formName        STRING,                  -- Form name in AUI tree, used by client stored settings
	windowTitle     STRING,                  -- Window title, defaults to "Listing from 'tablename'"
	theDialog       ui.Dialog,               -- The dialog object
	selectedKey     STRING,                  -- the selected first column
	currentRow      INTEGER                  -- current row in the display array
END RECORD

PUBLIC FUNCTION (this lookup) lookup() RETURNS STRING
	DEFINE l_key                                         STRING
	DEFINE x                                             SMALLINT
	DEFINE l_frm, l_grid, l_tabl, l_tabc, l_edit, l_curr om.DomNode
	DEFINE l_hbx, l_sp, l_titl                           om.DomNode
	DEFINE l_event                                       STRING

	IF NOT this.checkLookupParams() THEN
		RETURN NULL
	END IF

	GL_DBGMSG(2, SFMT("lookup: windowTitle = %1", this.windowTitle))
	GL_DBGMSG(2, SFMT("lookup: sql_getData = %1", this.sql_getData))
	GL_DBGMSG(2, SFMT("lookup: table       = %1", this.tableName))
	GL_DBGMSG(2, SFMT("lookup: column	     = %1", this.columnList))
	GL_DBGMSG(2, SFMT("lookup: titles	     = %1", this.columnTitles))
	GL_DBGMSG(2, SFMT("lookup: where       = %1", this.whereClause))
	GL_DBGMSG(2, SFMT("lookup: orderby     = %1", this.orderBy))
	GL_DBGMSG(2, SFMT("lookup: maxColWidth = %1", this.maxColWidth))

-- Check to make sure there are records.
	LET this.totalRecords = this.countRows(this.whereClause)
	IF this.totalRecords < 1 THEN
		CALL lib.showError(%"No Records Found")
		RETURN NULL
	END IF

-- build the main sql if it's not already defined
	IF this.sql_getData IS NULL THEN
		LET this.sql_getData = SFMT("SELECT %1 FROM %2 WHERE %3", this.columnList, this.tableName, this.whereClause)
		IF this.orderBy IS NOT NULL THEN
			LET this.sql_getData = this.sql_getData CLIPPED, SFMT(" ORDER BY %1", this.orderBy)
		END IF
		GL_DBGMSG(2, SFMT("lookup: sql_getData = %1 BUILT", this.sql_getData))
	END IF

-- Perpare the main cursor
	LET this.sqlQueryHandle = base.SqlHandle.create()
	TRY
		GL_DBGMSG(2, SFMT("lookup: sql_getData = %1 Prepare", this.sql_getData))
		CALL this.sqlQueryHandle.prepare(this.sql_getData)
		CALL this.sqlQueryHandle.openScrollCursor()
	CATCH
		CALL lib.showError(SFMT(%"Failed to prepare:\n%1\n%2", this.sql_getData, SQLERRMESSAGE))
		RETURN NULL
	END TRY
	CALL this.fields.clear()
	FOR x = 1 TO this.sqlQueryHandle.getResultCount()
		LET this.fields[x].name      = this.sqlQueryHandle.getResultName(x)
		LET this.fields[x].type      = this.sqlQueryHandle.getResultType(x)
		LET this.dsp_fields[x].name  = "dsp_" || this.fields[x].name
		LET this.dsp_fields[x].type  = this.fields[x].type
		LET this.dsp_fields[x].width = this.getColumnLength(this.fields[x].type)
		GL_DBGMSG(2, SFMT("lookup: %1 Name: %2 Type: %3", x, this.fields[x].name, this.fields[x].type))
	END FOR
	LET this.totalFields = this.fields.getLength()
	GL_DBGMSG(2, "lookup: Cursor Okay.")

-- Open the window and define a table.
	GL_DBGMSG(2, "lookup: Opening Window.")
	OPEN WINDOW listv AT 1, 1 WITH 15 ROWS, 80 COLUMNS ATTRIBUTE(STYLE = "naked")
	CALL ui.Window.getCurrent().setText(this.windowTitle)
	LET l_frm =
			ui.Window.getCurrent().createForm(this.formName).getNode() -- ensures form name is specific for this lookup
	CALL l_frm.setAttribute("width", 100)

	LET l_grid = l_frm.createChild('Grid')
	CALL l_grid.setAttribute("width", 100)
	CALL l_grid.setAttribute("gridWidth", 100)
{
-- Create a centered window l_title.
	LET l_hbx = l_grid.createChild('HBox')
	CALL l_hbx.setAttribute("posY", "0")
	CALL l_hbx.setAttribute("width", 100)
	CALL l_hbx.setAttribute("gridWidth", 100)
	LET l_sp = l_hbx.createChild('SpacerItem')
	LET l_titl = l_hbx.createChild('Label')
	CALL l_titl.setAttribute("text", this.windowTitle)
	CALL l_titl.setAttribute("style", "tabtitl")
	LET l_sp = l_hbx.createChild('SpacerItem')
}
	GL_DBGMSG(2, "lookup: Generating Table...")
-- Create the table
	LET l_tabl = l_grid.createChild('Table')
	CALL l_tabl.setAttribute("width", 100)
	CALL l_tabl.setAttribute("gridWidth", 100)
	CALL l_tabl.setAttribute("tabName", "tablistv")
	CALL l_tabl.setAttribute("height", "10")
	CALL l_tabl.setAttribute("pageSize", "10")
	CALL l_tabl.setAttribute("posY", "1")
	CALL l_tabl.setAttribute("doubleClick", "accept")

-- Create Columns & Headings for the table.
	FOR x = 1 TO this.totalFields
		LET l_tabc = l_tabl.createChild('TableColumn')
		CALL l_tabc.setAttribute("colName", this.dsp_fields[x].name)
		LET l_edit = l_tabc.createChild('Edit')
		IF this.columnTitlesArr[x] IS NULL THEN
			LET this.columnTitlesArr[x] = this.dsp_fields[x].name
		END IF
		CALL l_tabc.setAttribute("text", this.columnTitlesArr[x])
		CALL l_edit.setAttribute("width", this.dsp_fields[x].width)
		IF this.columnTitlesArr[x].getCharAt(1) = "_" THEN -- if l_title starts with _ then it's a hidden column
			CALL l_tabc.setAttribute("hidden", "1")
		END IF
	END FOR

	GL_DBGMSG(2, "lookup: Adding Update/Insert area ...")
-- Create Lables & Fields for the update/insert area.
	LET this.inputVBox = l_grid.createChild('VBox')
	CALL this.inputVBox.setAttribute("posY", 2)
	CALL this.inputVBox.setAttribute("hidden", TRUE)
	LET l_hbx = this.inputVBox.createChild('Grid')
	CALL l_hbx.setAttribute("width", 100)
	CALL l_hbx.setAttribute("gridWidth", 100)
	CALL l_hbx.setAttribute("height", this.fields.getLength())
	CALL l_hbx.setAttribute("gridHeight", this.fields.getLength())
	FOR x = 1 TO this.totalFields
		LET l_curr = l_hbx.createChild('Label')
		CALL l_curr.setAttribute("text", this.columnTitlesArr[x])
		CALL l_curr.setAttribute("gridWidth", 20)
		CALL l_curr.setAttribute("width", 20)
		CALL l_curr.setAttribute("posY", x)
		CALL l_curr.setAttribute("posX", 1)
		LET l_curr = l_hbx.createChild('FormField')
		CALL l_curr.setAttribute("name", this.fields[x].name)
		CALL l_curr.setAttribute("colName", this.fields[x].name)
		LET l_titl = l_curr.createChild('Edit')
		CALL l_titl.setAttribute("gridWidth", this.dsp_fields[x].width)
		CALL l_titl.setAttribute("width", this.dsp_fields[x].width)
		CALL l_titl.setAttribute("posY", x)
		CALL l_titl.setAttribute("posX", 20)
	END FOR

	GL_DBGMSG(2, "lookup: Adding buttons...")
-- Create centered buttons.
	LET l_hbx = l_grid.createChild('HBox')
	CALL l_hbx.setAttribute("width", 100)
	CALL l_hbx.setAttribute("gridWidth", 100)
	CALL l_hbx.setAttribute("posY", 50 + x)
	LET l_curr = l_hbx.createChild('Label')
	CALL l_curr.setAttribute("text", "Row:")
	LET l_curr = l_hbx.createChild('Label')
	CALL l_curr.setAttribute("name", "cur_row")
	CALL l_curr.setAttribute("sizePolicy", "dynamic")
	LET l_sp   = l_hbx.createChild('SpacerItem')
	LET l_titl = l_hbx.createChild('Button')
	CALL l_titl.setAttribute("name", "firstrow")
	CALL l_titl.setAttribute("text", "")
	CALL l_titl.setAttribute("image", "fa-step-backward")
	LET l_titl = l_hbx.createChild('Button')
	CALL l_titl.setAttribute("name", "prevpage")
	CALL l_titl.setAttribute("text", "")
	CALL l_titl.setAttribute("image", "fa-backward")
	LET l_titl = l_hbx.createChild('Button')
	CALL l_titl.setAttribute("text", "Okay")
	CALL l_titl.setAttribute("name", "accept")
	CALL l_titl.setAttribute("image", "fa-check")
	CALL l_titl.setAttribute("width", "6")
	IF this.allowInsert THEN
		LET l_titl = l_hbx.createChild('Button')
		CALL l_titl.setAttribute("text", "Insert")
		CALL l_titl.setAttribute("name", "append")
		CALL l_titl.setAttribute("image", "fa-file")
		CALL l_titl.setAttribute("width", "6")
	END IF
	IF this.allowInsert THEN
		LET l_titl = l_hbx.createChild('Button')
		CALL l_titl.setAttribute("text", "Update")
		CALL l_titl.setAttribute("name", "update")
		CALL l_titl.setAttribute("image", "fa-pencil")
		CALL l_titl.setAttribute("width", "6")
	END IF
	IF this.allowDelete THEN
		LET l_titl = l_hbx.createChild('Button')
		CALL l_titl.setAttribute("text", "Delete")
		CALL l_titl.setAttribute("name", "delete")
		CALL l_titl.setAttribute("image", "fa-trash")
		CALL l_titl.setAttribute("width", "6")
	END IF
	LET l_titl = l_hbx.createChild('Button')
	CALL l_titl.setAttribute("name", "cancel")
	CALL l_titl.setAttribute("text", "Cancel")
	CALL l_titl.setAttribute("image", "fa-close")
	CALL l_titl.setAttribute("width", "6")
	LET l_titl = l_hbx.createChild('Button')
	CALL l_titl.setAttribute("name", "nextpage")
	CALL l_titl.setAttribute("text", "")
	CALL l_titl.setAttribute("image", "fa-forward")
	LET l_titl = l_hbx.createChild('Button')
	CALL l_titl.setAttribute("name", "lastrow")
	CALL l_titl.setAttribute("text", "")
	CALL l_titl.setAttribute("image", "fa-step-forward")
	LET l_sp   = l_hbx.createChild('SpacerItem')
	LET l_titl = l_hbx.createChild('Label')
	CALL l_titl.setAttribute("text", this.totalRecords USING "###,###,##&" || " Rows")
	CALL l_titl.setAttribute("sizePolicy", "dynamic")

-- Setup the dialog
	LET int_flag       = FALSE
	LET this.theDialog = ui.Dialog.createDisplayArrayTo(this.fields, "tablistv")
	CALL this.theDialog.addTrigger("ON ACTION close")
	CALL this.theDialog.addTrigger("ON ACTION accept")
	CALL this.theDialog.addTrigger("ON ACTION cancel")
	IF this.allowInsert THEN
		CALL this.theDialog.addTrigger("ON APPEND")
	END IF
	IF this.allowUpdate THEN
		CALL this.theDialog.addTrigger("ON UPDATE")
	END IF
	IF this.allowDelete THEN
		CALL this.theDialog.addTrigger("ON DELETE")
	END IF
	CALL this.refrestData()

	CALL this.theDialog.setCurrentRow("tablistv", 1) -- TODO: should be done by the runtime
-- Loop for events.
	WHILE TRUE
		LET l_event = this.theDialog.nextEvent()
		CASE l_event
			WHEN "BEFORE DISPLAY"
				IF this.totalRecords = 1 THEN
					EXIT WHILE
				END IF -- if only 1 row just select it!
			WHEN "ON ACTION close"
				LET int_flag = TRUE
				EXIT WHILE
			WHEN "ON ACTION cancel"
				LET int_flag = TRUE
				EXIT WHILE
			WHEN "ON ACTION accept"
				EXIT WHILE
			WHEN "ON UPDATE"
				LET int_flag = this.update(this.theDialog.getFieldValue(this.dsp_fields[1].name))

			WHEN "ON APPEND"
				LET int_flag = this.update(NULL)

			WHEN "ON DELETE"
				LET int_flag = this.delete(this.theDialog.getFieldValue(this.dsp_fields[1].name))

			WHEN "ON SORT"
				--MESSAGE "Use 'reset sort order' to reset to default."
				EXIT WHILE
			WHEN "ON ACTION tablistv.accept" -- doubleclick
				EXIT WHILE
			WHEN "BEFORE ROW"
				LET x               = this.theDialog.arrayToVisualIndex("tablistv", arr_curr())
				LET this.currentRow = arr_curr()
				CALL l_curr.setAttribute("text", SFMT("%1 (%2)", x USING "<<<,##&", arr_curr() USING "<<<,##&"))
			OTHERWISE
				GL_DBGMSG(2, "lookup: Unhandled Event:" || l_event)
		END CASE
	END WHILE
	LET this.selectedKey = this.theDialog.getFieldValue(this.dsp_fields[1].name) -- get the selected row first field.
	LET this.theDialog   = NULL                                                  -- Terminate the dialog
	CALL this.sqlQueryHandle.close()
	CLOSE WINDOW listv
	IF int_flag THEN
		GL_DBGMSG(2, "lookup: Window Closed, Cancelled.")
		RETURN NULL
	ELSE
		GL_DBGMSG(2, SFMT("lookup: Window Closed, returning row:%1 %2", arr_curr(), this.selectedKey.trim()))
		RETURN this.selectedKey.trim()
	END IF

	RETURN l_key
END FUNCTION
----------------------------------------------------------------------------------------------------
FUNCTION (this lookup) refrestData()
	DEFINE x, i INTEGER
-- Fetch the data
	CALL this.sqlQueryHandle.fetchFirst()
	LET x = 0
	WHILE sqlca.sqlcode = 0
		LET x = x + 1
		-- must set the current row before setting values
		CALL this.theDialog.setCurrentRow("tablistv", x)
		FOR i = 1 TO this.sqlQueryHandle.getResultCount()
			CALL this.theDialog.setFieldValue(this.dsp_fields[i].name, this.sqlQueryHandle.getResultValue(i))
		END FOR
		CALL this.sqlQueryHandle.fetch()
	END WHILE
	GL_DBGMSG(0, SFMT("Fetched %1 Rows.", x))
END FUNCTION
----------------------------------------------------------------------------------------------------
#+ Initialize helper function:
#+
#+ @param tabnam db table name
#+ @param cols	columns names ( comma seperated )
#+ @param colts columns l_titles ( comma seperated )
#+					can be NULL to use column names
#+					can be _ to have a hidden column - ie 1st col if it's a key
#+ @param wher	The WHERE clause, 1=1 means all, or use result of construct
#+ @param ordby The ORDER BY clause
FUNCTION (this lookup) init(tabnam STRING, cols STRING, colts STRING, wher STRING, ordby STRING) RETURNS()
	LET this.sql_count    = NULL
	LET this.sql_getData  = NULL
	LET this.tableName    = tabnam
	LET this.columnList   = cols
	LET this.columnTitles = colts
	LET this.whereClause  = wher
	LET this.orderBy      = ordby
END FUNCTION
----------------------------------------------------------------------------------------------------
FUNCTION (this lookup) countRows(l_where STRING) RETURNS INT
	DEFINE i INT

	GL_DBGMSG(2, "lookup: Declaring Count Cursor...")
	IF this.sql_count IS NULL THEN
		LET this.sql_count = SFMT("SELECT COUNT(*) FROM %1 WHERE %2", this.tableName, l_where)
	END IF
	TRY
		PREPARE listcntpre FROM this.sql_count
	CATCH
		CALL lib.showError(SFMT(%"Failed to prepare count cursor:\n%1\n%2", this.sql_count, SQLERRMESSAGE))
		RETURN 0
	END TRY
	DECLARE listcntcur CURSOR FOR listcntpre
	OPEN listcntcur
	FETCH listcntcur INTO i
	CLOSE listcntcur

	GL_DBGMSG(2, SFMT("lookup: Counted: %1", i))
	RETURN i
END FUNCTION
----------------------------------------------------------------------------------------------------
PRIVATE FUNCTION (this lookup) checkLookupParams() RETURNS BOOLEAN
	DEFINE l_err STRING
	DEFINE l_tok base.StringTokenizer

	IF this.maxColWidth = 0 THEN
		LET this.maxColWidth = 40
	END IF
	IF this.tableName IS NULL THEN
		IF this.sql_getData IS NULL THEN
			LET l_err = l_err.append("tableName ")
		END IF
		LET this.allowDelete = FALSE -- can't do this no table name!
		LET this.allowInsert = FALSE -- can't do this no table name!
		LET this.allowUpdate = FALSE -- can't do this no table name!
	END IF
	IF this.columnList IS NULL AND this.sql_getData IS NULL THEN
		LET l_err = l_err.append("columnList ")
	END IF
	IF this.columnTitles IS NULL AND this.columnList != "*" THEN
		LET this.columnTitles = this.columnList
	END IF
	IF this.whereClause IS NULL THEN
		LET this.whereClause = "1=1"
	END IF
	IF this.formName IS NULL THEN
		LET this.formName = "gl_" || this.tableName
	END IF
	IF this.windowTitle IS NULL THEN
		LET this.windowTitle = SFMT(%"Listing from %1", this.tableName)
	END IF

	LET l_tok = base.StringTokenizer.create(this.columnTitles, ",")
	CALL this.columnTitlesArr.clear() -- clear the defaults if l_title supplied.
	WHILE l_tok.hasMoreTokens()
		LET this.columnTitlesArr[this.columnTitlesArr.getLength() + 1] = l_tok.nextToken()
	END WHILE

	IF l_err IS NOT NULL THEN
		CALL lib.showError(SFMT(%"Lookup called by initiated correctly!\nThe following are not set:%1", l_err))
		RETURN FALSE
	END IF
	RETURN TRUE
END FUNCTION
----------------------------------------------------------------------------------------------------
PRIVATE FUNCTION (this lookup) delete(l_key STRING) RETURNS BOOLEAN
	DEFINE l_confirm CHAR(1)
	DEFINE l_sql     STRING
	LET l_confirm =
			fgldialog.fgl_winQuestion("Delete", SFMT("Delete this record?\nKey'%1'", l_key), "Yes", "Yes|No", "question", 0)
	IF l_confirm = "Y" THEN
		LET l_sql = SFMT("DELETE FROM %1 WHERE %2 = '%3'", this.tableName, this.fields[1].name, l_key)
		GL_DBGMSG(2, SFMT("lookup: l_sql=%1", l_sql))
		TRY
			EXECUTE IMMEDIATE l_sql
			RETURN FALSE
		CATCH
			GL_DBGMSG(0, SFMT("SQL Failed:%1 %2", status, SQLERRMESSAGE))
			CALL lib.showError(SFMT("Failed to delete!\n%1 %2", status, SQLERRMESSAGE))
		END TRY
	END IF
	RETURN TRUE
END FUNCTION
----------------------------------------------------------------------------------------------------
PRIVATE FUNCTION (this lookup) update(l_key STRING) RETURNS BOOLEAN
	DEFINE l_dia             ui.Dialog
	DEFINE l_event, l_newKey STRING
	DEFINE l_accept          BOOLEAN = FALSE
	DEFINE x, l_firstField   SMALLINT
	DEFINE l_sql             STRING
	CALL this.inputVBox.setAttribute("hidden", FALSE)
	CALL ui.Dialog.setDefaultUnbuffered(TRUE)
	LET l_dia        = ui.Dialog.createInputByName(this.fields)
	LET l_firstField = 1
	IF this.isKeySerial THEN
		LET l_firstField = 2
	END IF
	FOR x = 1 TO this.totalFields
		IF x = 1 AND (this.isKeySerial OR l_key IS NOT NULL) THEN
			CALL l_dia.setFieldActive(this.fields[x].name, FALSE)
			DISPLAY SFMT("Add field '%1' to input - disabled", this.fields[x].name)
		ELSE
			CALL l_dia.setFieldActive(this.fields[x].name, TRUE)
			DISPLAY SFMT("Add field '%1' to input - enabled", this.fields[x].name)
		END IF
		IF l_key IS NOT NULL THEN
			CALL l_dia.setFieldValue(this.fields[x].name, this.theDialog.getFieldValue(this.dsp_fields[x].name))
		END IF
	END FOR
	CALL l_dia.addTrigger("ON ACTION close")
	CALL l_dia.addTrigger("ON ACTION accept")
	CALL l_dia.addTrigger("ON ACTION cancel")
-- Loop for events.
	WHILE TRUE
		LET l_event = l_dia.nextEvent()
		DISPLAY "Event:", l_event
		CASE l_event
			WHEN "AFTER FIELD " || this.fields[1].name
				IF l_key IS NULL AND NOT this.isKeySerial THEN
					LET l_newKey = l_dia.getFieldValue(this.fields[1].name.trimRight())
					IF this.countRows(SFMT("%1 = '%2'", this.fields[1].name, l_newKey)) > 0 THEN
						CALL lib.showError(SFMT(%"Key '%1' already used!", l_newKey))
						CALL l_dia.nextField(this.fields[1].name)
					END IF
				END IF
			WHEN "ON ACTION close"
				EXIT WHILE
			WHEN "ON ACTION cancel"
				EXIT WHILE
			WHEN "ON ACTION accept"
				LET l_accept = TRUE
				EXIT WHILE
			OTHERWISE
				GL_DBGMSG(2, "lookup: Unhandled Event:" || l_event)
		END CASE
	END WHILE
	CALL this.inputVBox.setAttribute("hidden", TRUE)
	IF NOT l_accept THEN
		RETURN TRUE
	END IF

	IF l_key IS NULL THEN
		LET l_sql = SFMT("INSERT INTO %1 ( ", this.tableName)
	ELSE
		LET l_sql = SFMT("UPDATE %1 SET (", this.tableName)
	END IF

	FOR x = l_firstField TO this.totalFields
		LET l_sql = l_sql.append(this.fields[x].name.trimRight())
		IF x < this.fields.getLength() THEN
			LET l_sql = l_sql.append(",")
		END IF
	END FOR
	IF l_key IS NOT NULL THEN -- update
		LET l_sql = l_sql.append(") = ( ")
	ELSE -- insert
		LET l_sql = l_sql.append(") VALUES ( ")
	END IF
	FOR x = l_firstField TO this.totalFields
		LET l_sql = l_sql.append(SFMT("'%1'", l_dia.getFieldValue(this.fields[x].name.trimRight())))
		IF x < this.fields.getLength() THEN
			LET l_sql = l_sql.append(",")
		END IF
	END FOR
	LET l_sql = l_sql.append(")")

	IF l_key IS NOT NULL THEN -- update
		LET l_sql =
				l_sql.append(
						SFMT(" WHERE %1 = '%2'",
								this.fields[1].name.trimRight(), l_dia.getFieldValue(this.fields[1].name.trimRight())))
	END IF

	GL_DBGMSG(2, SFMT("lookup: l_sql=%1", l_sql))
	TRY
		EXECUTE IMMEDIATE l_sql
	CATCH
		--DISPLAY "SQLCode:",sqlca.sqlcode, " SQLERRD2:",sqlca.sqlerrd[2], " sqlawarn:",sqlca.sqlawarn
		IF sqlca.sqlerrd[2] != -1 THEN -- probably really 55000 so ignore ( PGS serial retrieve fail ! )
			GL_DBGMSG(0, SFMT("SQL Failed:%1 %2", status, SQLERRMESSAGE))
			CALL lib.showError(SFMT("Failed!\n%1 %2", status, SQLERRMESSAGE))
			RETURN TRUE -- int_flag
		END IF
	END TRY

	IF l_key IS NOT NULL THEN -- update
		CALL this.theDialog.setCurrentRow("tablistv", this.currentRow)
	ELSE
		LET this.totalRecords = this.totalRecords + 1
		CALL this.theDialog.setCurrentRow("tablistv", this.totalRecords)
		CALL l_dia.setFieldValue(this.fields[1].name, sqlca.sqlerrd[2])
	END IF
	FOR x = 1 TO this.totalFields
		DISPLAY SFMT("Updating Row %1 field %2 to %3",
				this.currentRow, this.dsp_fields[x].name, l_dia.getFieldValue(this.fields[x].name.trimRight()))
		CALL this.theDialog.setFieldValue(this.dsp_fields[x].name, l_dia.getFieldValue(this.fields[x].name.trimRight()))
	END FOR

	RETURN FALSE -- int_flag
END FUNCTION
----------------------------------------------------------------------------------------------------
#+ @param s_typ Type
#+ @return Length from type or defaults to 10
FUNCTION (this lookup) getColumnLength(l_type STRING) RETURNS SMALLINT
	DEFINE x, y, l_size SMALLINT
	LET l_size = 1 -- default
	CASE l_type
		WHEN "SMALLINT"
			LET l_size = 5
		WHEN "SERIAL"
			LET l_size = 10
		WHEN "INTEGER"
			LET l_size = 10
		WHEN "FLOAT"
			LET l_size = 12
		WHEN "DATE"
			LET l_size = 10
	END CASE
	LET x = l_type.getIndexOf("(", 1)
	IF x > 1 THEN
		LET y = l_type.getIndexOf(",", 1)
		IF y = 0 THEN
			LET y = l_type.getIndexOf(")", 1)
		END IF
		LET l_size = l_type.subString(x + 1, y - 1)
	END IF
	IF l_type.subString(1, 4) = "CHAR" OR l_type.subString(1, 7) = "VARCHAR" THEN
		LET l_size = l_size / 3 -- sqlite db seems to creates the column 3 x wider to allow for uniqcode chars!
	END IF
	IF this.maxColWidth > 0 AND l_size > this.maxColWidth THEN
		LET l_size = this.maxColWidth
	END IF
	DISPLAY SFMT("Type: %1 Size: %2", l_type, l_size)
	RETURN l_size
END FUNCTION
