# Menu Examples

A working Genero demo of different ways to write a **menu program** — the
top-level navigation of an application.

One module, `src/menu.4gl`, reads the navigation from a `menus` database table
and builds the screen at runtime. Two command-line arguments select the
container style and the menu form. The child programs are real maintenance and
enquiry programs, so you see each menu style in use.

The demo was written in Genero V4 and updated for V5 and V6. Use it with GBC
5.01 or later.

## Menu styles

`src/menu.4gl` takes two arguments:

* **Argument 1** selects the container style.
* **Argument 2** selects the menu form. The value must start with `menu`. If
  you give no value, the program opens `menu`.

| Arg 1 | Container | Start menu | Menu list |
|-------|-----------|------------|-----------|
| `M`   | MDI, GBC sidebar | no | yes |
| `m`   | MDI, start menu | yes | yes |
| `t`   | MDI, tabbed windows | yes | yes |
| `n`   | MDI, not tabbed | yes | no |
| `S`   | SDI, one window per program | no | yes |
| none  | No style change | no | yes |

Mode `n` shows no menu list. The start menu is the only navigation. Use it with
the `menu_empty` form for an empty screen body.

`lib.switch_mdi()` does the container change. The stylesheet `etc/default.4st`
holds three styles — `UserInterface.mdi`, `UserInterface.sm` and
`UserInterface.sdi`. The function copies the attributes of the selected style
into the active `UserInterface` style, then refreshes the front end. This lets
one program supply all the container styles.

The four GAS application files in `etc/` start these combinations:

| File | Arguments | Result |
|------|-----------|--------|
| `etc/m1.xcf` | `M menu_sg` | MDI sidebar, scrollgrid menu |
| `etc/m2.xcf` | `m` | MDI with a classic start menu |
| `etc/m3.xcf` | `t` | MDI with tabbed windows |
| `etc/m4.xcf` | `S menu_sg` | SDI, scrollgrid menu |

## The menus table

`src/mk_db.4gl` creates the table and loads the test menu. `m_type` sets what a
row does:

| `m_type` | Action |
|----------|--------|
| `T` | Title row. Sets the window title and the form title. The row is not shown. |
| `M` | Sub menu. `m_child` names the menu to load. |
| `F` | Start a program in MDI. Runs `fglrun <m_cmd> c <m_args>`. |
| `f` | Start a program in SDI. Runs `fglrun mdiSwitch S <m_cmd> <m_args>`. |
| `Q` | Exit the application. Added at runtime to the main menu. |
| `B` | Go back to the previous menu. Added at runtime to a sub menu. |

The other columns are `m_text`, `m_desc` and `m_img` for the display, and
`m_cmd` and `m_args` for the command.

## Modules in src/

### Programs

| Module | Purpose |
|--------|---------|
| `menu.4gl` | The demo menu program. Reads the `menus` table, builds the menu or the start menu, and starts the child programs. |
| `mdiSwitch.4gl` | SDI launcher. Applies the SDI styles, then starts the target program with `RUN ... WITHOUT WAITING`. The child program gets its own window. |
| `menu_mnt.4gl` | Maintains the `menus` table. Shows a `DIALOG` with a `DISPLAY ARRAY` and an `INPUT` sub-dialog. |
| `cust_mnt.4gl` | Customer child program. Add, update, delete and query customers. Argument 2 `E` gives a read-only enquiry. |
| `stk_mnt.4gl` | Stock child program. Same pattern as `cust_mnt`, with a choice of reports. |
| `mk_db.4gl` | Creates the SQLite database, the tables and the test data. `lib.db_connect()` runs it if the database file is not found. |

### Libraries

| Module | Purpose |
|--------|---------|
| `lib.4gl` | Shared code for all programs: `init()`, `db_connect()`, `switch_mdi()`, `log()`, `about()`, `exit_program()` and the report setup functions. |
| `lookup.4gl` | A dynamic lookup class. It reads the column names and types from the prepared statement, then builds the form at runtime with the AUI tree. `cust_mnt` and `stk_mnt` use it. |
| `logging.4gl` | A single `logIt()` function. No module imports it. |

### Forms

| Form | Purpose |
|------|---------|
| `menu.per` | Menu as a `TABLE` with one image column. |
| `menu_flipped.per` | Menu as a `TABLE` with `FLIPPED`. Each row shows two label lines and an icon. |
| `menu_sg.per` | Menu as a `SCROLLGRID`. Each row shows a large icon and two label lines. |
| `menu_empty.per` | Title only. Use it with mode `n` for start-menu navigation. |
| `menu_mnt.per` | Form for `menu_mnt`. |
| `cust_mnt.per` | Form for `cust_mnt`. |
| `cust_mnt_arr.per` | An alternative customer list, with `FLIPPED@SMALL`. No module opens it. |
| `stk_mnt.per` | Form for `stk_mnt`. |
| `rpt_settings.per` | Report output options. `lib.rpt_outputAsk()` opens it. |

### Other files in src/

* `schema.inc` — holds the `SCHEMA training` statement. Every module that uses
  the database includes it.
* `*.rdd` — report data definitions. The Genero Report Writer generates them.

## Build and run

```bash
make                      # compile every module in src/ into bin600
make GENVER=501           # compile with the 5.01 toolchain into bin501
make run                  # compile, then start the menu
make clean                # delete the compiled files
```

`GENVER` selects the output directory and the toolchain. Use `RUNARGS` to
select a menu style:

```bash
make run RUNARGS="M menu_sg"    # MDI sidebar, scrollgrid menu
make run RUNARGS="m"            # MDI with a start menu
make run RUNARGS="t"            # MDI with tabbed windows
make run RUNARGS="S menu_sg"    # SDI
```

`etc/training.db` holds the test data and is in the repository. The schema file
is not, so `make` first extracts `etc/training.sch` from the database with
`fgldbsch`. The compiler needs the schema for `SCHEMA` and `DEFINE ... LIKE`.
Run `mk_db` if you want to rebuild the tables and the test data.

To build and deploy a GAS archive:

```bash
make gar                  # build menu.gar
make deploy               # deploy menu.gar to the application server
```

# TABLE with FLIPPED

## Desktop

Menu

![ss1](https://github.com/neilm-fourjs/MenuExamples/raw/main/pics/Menu_TableFlipped.png "SS1")

Sidebar expanded and child program loaded

![ss2](https://github.com/neilm-fourjs/MenuExamples/raw/main/pics/SideBarExanded_withChild.png "SS2")

## Smaller Screen

Menu

![ss3](https://github.com/neilm-fourjs/MenuExamples/raw/main/pics/Menu_SmallWidth.png "SS3")

Child program left screen section

![ss4](https://github.com/neilm-fourjs/MenuExamples/raw/main/pics/Child_Small_1.png "SS4")

Child program right screen section

![ss5](https://github.com/neilm-fourjs/MenuExamples/raw/main/pics/Child_Small_2.png "SS5")

A Classic StartMenu

![ss6](https://github.com/neilm-fourjs/MenuExamples/raw/main/pics/StartMenu_withChild.png "SS6")

A Tabbed Container with Buttons for a Menu

![ss7](https://github.com/neilm-fourjs/MenuExamples/raw/main/pics/Tabbed_ButtonMenu.png "SS7")
