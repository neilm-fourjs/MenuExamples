IMPORT FGL fgldialog
IMPORT FGL greruntime
IMPORT os

PUBLIC DEFINE m_debug_lev SMALLINT
PUBLIC DEFINE m_mdi       BOOLEAN = FALSE
PUBLIC DEFINE m_client    STRING
DEFINE m_log_file         STRING
DEFINE m_log              base.Channel

-- Report Settings
PUBLIC DEFINE m_report         STRING
PUBLIC DEFINE m_report_ask     BOOLEAN = TRUE
PUBLIC DEFINE m_report_preview BOOLEAN = TRUE
PUBLIC DEFINE m_report_output  STRING = "SVG"
PUBLIC DEFINE m_report_outFile STRING -- file name to use if preview = false

--------------------------------------------------------------------------------------------------------------
-- Connect to the default database.
FUNCTION db_connect() RETURNS()
	DEFINE l_db STRING

	LET l_db = fgl_getenv("DBNAME")
	IF l_db.getLength() < 1 THEN
		LET l_db = "training.db"
	END IF

	IF NOT os.Path.exists(l_db) THEN
		IF base.Application.getProgramName() != "mk_db" THEN
			RUN SFMT("fglrun mk_db %1", l_db)
		ELSE
			CALL showError(SFMT("Database doesnt exist %1", l_db))
			EXIT PROGRAM
		END IF
	END IF

	TRY
		CONNECT TO l_db || "+driver='dbmsqt'"
	CATCH
		CALL showError(SQLERRMESSAGE)
		EXIT PROGRAM
	END TRY
	CALL log(1, SFMT("Connected to %1", l_db))
END FUNCTION
--------------------------------------------------------------------------------------------------------------
-- Initialize the program environment
FUNCTION init() RETURNS()

	LET m_debug_lev = 2
	CALL log(1, SFMT("Program %1 Started - debug: %2", base.Application.getProgramName(), m_debug_lev))

-- don't bother switch MDI setting unless we are passed M or S
	IF base.Application.getArgument(1) = "M" THEN
		LET m_mdi = TRUE
		CALL switch_mdi("mdi")
	END IF
	IF base.Application.getArgument(1) = "m" THEN
		LET m_mdi = TRUE
		CALL switch_mdi("sm") -- startMenu
	END IF
	IF base.Application.getArgument(1) = "S" THEN
		LET m_mdi = FALSE
		CALL switch_mdi("sdi")
	END IF
	LET m_client = ui.Interface.getFrontEndName()
	CALL log(
			1,
			SFMT("Program %1 Started - debug: %2 mdi: %3 client: %4",
					base.Application.getProgramName(), m_debug_lev, m_mdi, m_client))

END FUNCTION
--------------------------------------------------------------------------------------------------------------
-- change the style name to handle MDI / SDI styles
FUNCTION switch_mdi(l_mdi STRING)
	DEFINE n, l_n_ui, n_sl om.DomNode
	DEFINE l_nl            om.NodeList
	DEFINE l_style         STRING

	LET n_sl = ui.Interface.getRootNode().selectByPath("//StyleList").item(1)
	IF n_sl IS NULL THEN
		CALL log(0, "Failed to find styleList")
		RETURN
	END IF
--	CALL n_sl.writeXml("sl_1.xml")

-- find the style attributes we need to copy
	LET l_style = SFMT("//Style[@name='UserInterface.%1']/StyleAttribute", l_mdi)
	LET l_nl    = ui.Interface.getRootNode().selectByPath(l_style)
	IF l_nl.getLength() = 0 THEN
		CALL log(0, SFMT("Failed to find style attributes for %1", l_style))
		RETURN
	ELSE
		CALL log(1, SFMT("Found %1 attributes on %2", l_nl.getLength(), l_style))
	END IF

-- find and create/recreate the UserInterface style
	LET l_n_ui = ui.Interface.getRootNode().selectByPath("//Style[@name='UserInterface']").item(1)
	IF l_n_ui IS NOT NULL THEN
		CALL log(1, "Remove style 'UserInterface'")
		CALL n_sl.removeChild(l_n_ui)
	END IF
	CALL log(1, "Create style 'UserInterface'")
	LET l_n_ui = n_sl.createChild("Style")
	CALL l_n_ui.setAttribute("name", "UserInterface")

-- add the style attributes to the UserInterface style
	VAR x INT
	FOR x = 1 TO l_nl.getLength()
		CALL log(1, SFMT("Add styleAttribute %1=%2", l_nl.item(x).getAttributeValue(1), l_nl.item(x).getAttributeValue(2)))
		LET n = l_n_ui.createChild("StyleAttribute")
		CALL n.setAttribute(l_nl.item(x).getAttributeName(1), l_nl.item(x).getAttributeValue(1)) -- name
		CALL n.setAttribute(l_nl.item(x).getAttributeName(2), l_nl.item(x).getAttributeValue(2)) -- value
	END FOR
	CALL ui.Interface.refresh()
--	CALL n_sl.writeXml("sl_2.xml")
END FUNCTION
--------------------------------------------------------------------------------------------------------------
-- Exit the program and log the exit
FUNCTION exit_program(l_stat SMALLINT, l_msg STRING) RETURNS()
	CALL log(1, l_msg)
	CALL m_log.close()
	EXIT PROGRAM l_stat
END FUNCTION
--------------------------------------------------------------------------------------------------------------
-- A log a timestamped message.
FUNCTION about() RETURNS()
	DEFINE l_about STRING
	LET l_about = SFMT("Program: %1\n", base.Application.getProgramName())
	LET l_about = l_about.append(SFMT("Current Dir: %1\n", base.Application.getProgramDir()))
	LET l_about =
			l_about.append(
					SFMT("Client: %1 %2\n%3 %4\n",
							ui.Interface.getFrontEndName(), ui.Interface.getFrontEndVersion(), ui.Interface.getUniversalClientName(),
							ui.Interface.getUniversalClientVersion()))
	CALL fgldialog.fgl_winMessage("About", l_about, "information")
END FUNCTION
--------------------------------------------------------------------------------------------------------------
-- A log a timestamped message.
FUNCTION log(l_lev SMALLINT, l_msg STRING) RETURNS()
	IF m_log IS NULL THEN
		LET m_log_file = os.Path.join("..", "logs")
		IF NOT os.Path.exists(m_log_file) THEN
			IF NOT os.Path.mkdir(m_log_file) THEN
				CALL fgldialog.fgl_winMessage("Error", SFMT("Failed to mkdir %1", m_log_file), "exclamation")
				LET m_log_file = "." -- fall back to current dir!
			END IF
		END IF
		LET m_log_file = os.Path.join(m_log_file, SFMT("%1.log", base.Application.getProgramName()))
		LET m_log      = base.Channel.create()
		CALL m_log.openFile(m_log_file, "a+")
	END IF
	LET l_msg = SFMT("%1: %2", CURRENT, l_msg)
	IF m_debug_lev >= l_lev THEN
		CALL m_log.writeLine(l_msg)
		DISPLAY SFMT("%1:%2", base.Application.getProgramName(), l_msg)
	END IF
END FUNCTION
--------------------------------------------------------------------------------------------------------------
-- Show an error message and log that message.
FUNCTION showError(l_err STRING) RETURNS()
	CALL log(0, l_err)
	CALL fgldialog.fgl_winMessage("Error", l_err, "exclamation")
END FUNCTION
--------------------------------------------------------------------------------------------------------------
--
FUNCTION pop_combo(l_cb ui.ComboBox)
	CASE l_cb.getColumnName()
		WHEN "disc_code"
			CALL l_cb.addItem("AA", "This is item 'AA'")
			CALL l_cb.addItem("BB", "This is item 'BB'")
			CALL l_cb.addItem("CC", "This is item 'CC'")
	END CASE
END FUNCTION
--------------------------------------------------------------------------------------------------------------
-- Set the First / Last / Next / Prev actions
FUNCTION setActions(d ui.Dialog, l_cnt INT, l_row INT, l_rowActions STRING) RETURNS()
	DEFINE l_st base.StringTokenizer
	LET l_st = base.StringTokenizer.create(l_rowActions, "|")
	WHILE l_st.hasMoreTokens()
		IF l_row > 0 THEN
			CALL d.setActionActive(l_st.nextToken(), TRUE)
		ELSE
			CALL d.setActionActive(l_st.nextToken(), FALSE)
		END IF
	END WHILE
	CALL d.setActionActive("first", FALSE)
	CALL d.setActionActive("last", FALSE)
	CALL d.setActionActive("next", FALSE)
	CALL d.setActionActive("previous", FALSE)
	IF l_cnt = 0 THEN
		RETURN
	END IF

	CALL d.setActionActive("next", (l_cnt > l_row))
	CALL d.setActionActive("last", (l_cnt > l_row))

	CALL d.setActionActive("previous", (l_row > 1))
	CALL d.setActionActive("first", (l_row > 1))

END FUNCTION
--------------------------------------------------------------------------------------------------------------
--
FUNCTION report_setup(l_rptName STRING) RETURNS(om.SaxDocumentHandler)
	DEFINE l_handler om.SaxDocumentHandler

--    	CALL greruntime.fgl_report_configureDistributedProcessing("localhost", 6299)
--	RUN "fglWrt -a info"
	LET m_report = l_rptName
	IF m_report_ask OR l_rptName.getIndexOf(",", 1) > 0 THEN
		IF NOT rpt_outputAsk(l_rptName: l_rptName) THEN
			RETURN NULL
		END IF
	END IF
	IF NOT greruntime.fgl_report_loadCurrentSettings(SFMT("%1.4rp", m_report)) THEN
		EXIT PROGRAM
	END IF
	CALL greruntime.fgl_report_selectDevice(m_report_output)
	CALL greruntime.fgl_report_selectPreview(m_report_preview)

	IF m_report_output = "PDF" THEN
		CALL fgl_report_configurePDFDevice(
				fontDirectory: "~/.fonts", antialiasFonts: TRUE, antialiasShapes: TRUE, monochrome: FALSE, fromPage: NULL,
				toPage: NULL)
		CALL fgl_report_configurePDFFontEmbedding( preferUnicodeEncoding: TRUE )
	END IF
	IF m_report_output = "XLS" THEN
		CALL fgl_report_configureXLSDevice(
				fromPage: NULL, toPage: NULL, removeWhitespace: TRUE, ignoreRowAlignment: TRUE, ignoreColumnAlignment: FALSE,
				removeBackgroundImages: TRUE, mergePages: TRUE)
	END IF

	IF NOT m_report_preview AND m_report_outFile IS NOT NULL THEN
		CALL greruntime.fgl_report_setOutputFileName(m_report_outFile)
	END IF

	IF m_report_output = "XML" THEN
		LET l_handler = greruntime.fgl_report_createProcessLevelDataFile(SFMT("%1.xml", m_report))
	ELSE
		LET l_handler = greruntime.fgl_report_commitCurrentSettings()
	END IF
	IF l_handler IS NULL THEN
		CALL fgl_winMessage("Error", SFMT("Report Initialization for '%1' failed!", l_rptName), "exclamation")
		EXIT PROGRAM 1
	END IF
	CALL log(1, SFMT("Report Started, preview=%1 output=%2 file=%3", m_report_preview, m_report_output, m_report_outFile))
	RETURN l_handler
END FUNCTION
--------------------------------------------------------------------------------------------------------------
--
FUNCTION rpt_outputAsk(l_rptName STRING) RETURNS BOOLEAN
	DEFINE l_report  STRING
	DEFINE l_reports base.StringTokenizer
	DEFINE l_cb      ui.ComboBox
	LET l_reports = base.StringTokenizer.create(l_rptName, ",")
	LET m_report  = NULL
	OPEN WINDOW rpt_output WITH FORM "rpt_settings"
	LET l_cb = ui.ComboBox.forName("m_report")
	WHILE l_reports.hasMoreTokens()
		LET l_report = l_reports.nextToken().trim()
		IF m_report IS NULL THEN
			LET m_report = l_report
		END IF
		CALL l_cb.addItem(l_report, l_report)
	END WHILE

	INPUT BY NAME m_report, m_report_output, m_report_preview, m_report_outFile ATTRIBUTES(UNBUFFERED, WITHOUT DEFAULTS)
		BEFORE INPUT
			CALL DIALOG.setFieldActive("m_report_outfile", NOT m_report_preview)
		ON CHANGE m_report_output
			IF m_report_output = "SVG" THEN
				LET m_report_preview = TRUE
				CALL DIALOG.setFieldActive("m_report_outfile", NOT m_report_preview)
			END IF
			LET m_report_outFile = report_fileName(m_report_outFile)
		ON CHANGE m_report_preview
			CALL DIALOG.setFieldActive("m_report_outfile", NOT m_report_preview)
	END INPUT
	CLOSE WINDOW rpt_output
	IF int_flag THEN
		RETURN FALSE
	END IF
	RETURN TRUE
END FUNCTION
--------------------------------------------------------------------------------------------------------------
--
FUNCTION report_fileName(l_name STRING) RETURNS STRING
	DEFINE l_newName STRING
	IF l_name IS NOT NULL THEN
		LET l_newName = os.Path.rootName(l_name)
	ELSE
		LET l_newName = m_report
	END IF
	LET l_newName = SFMT("%1.%2", l_newName, m_report_output.toLowerCase())
	RETURN l_newName
END FUNCTION
--------------------------------------------------------------------------------------------------------------
--
FUNCTION report_finish()
	DEFINE l_rptName    STRING
	DEFINE l_remoteFile STRING
	DEFINE l_remoteDir  STRING
	IF NOT m_report_preview AND m_report_outFile IS NOT NULL THEN
		LET l_rptName = os.Path.baseName(m_report_outFile)
		IF os.Path.exists(m_report_outFile) THEN
			CALL ui.Interface.frontCall("standard", "getenv", ["TEMP"], [l_remoteDir])
			IF l_remoteDir IS NULL THEN
				LET l_remoteDir = "."
			END IF
			IF l_remoteDir.getIndexOf("\\", 1) > 0 THEN
				LET l_remoteFile = SFMT("%1\\%2", l_remoteDir, l_rptName)
			ELSE
				LET l_remoteFile = os.Path.join("/tmp", l_rptName)
			END IF
			TRY
				CALL log(1, SFMT("putFile %1 to %2", m_report_outFile, l_remoteFile))
				CALL fgl_putfile(m_report_outFile, l_remoteFile)
			CATCH
				CALL log(0, SFMT("Failed %1 %2", STATUS, err_get(STATUS)))
			END TRY
		END IF
	END IF
	CALL log(1, "Report Finished")
END FUNCTION
--------------------------------------------------------------------------------------------------------------
--
FUNCTION setCombo(l_cb ui.ComboBox)
	DEFINE l_key   STRING
	DEFINE l_value STRING
	CASE l_cb.getColumnName()
		WHEN "stock_cat"
			DECLARE stk_cat_cur CURSOR FOR SELECT catid, cat_name FROM stock_cat
			FOREACH stk_cat_cur INTO l_key, l_value
				CALL l_cb.addItem(l_key.trim(), l_value.trim())
			END FOREACH
	END CASE
END FUNCTION
