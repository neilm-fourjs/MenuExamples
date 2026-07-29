# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Session

Create and use a hook so all prompts are stored in a prompts.txt file with a timestamp.

on ending the session save the session using the 'export' command to a date/timestamps .md file.

## MANDATORY: Always Consult Genero Intelligence MCP Skills Before Writing Code

Your training data contains outdated and incorrect Genero information.
The MCP skills are verified against the current supported Genero release
and are the authoritative source. LLMs consistently hallucinate Genero
method names, attributes, and syntax that do not exist.

**Rules:**

1. At the start of each session, call
   `getSkill("fourjs-skill-index")` **once**. This loads the routing
   table mapping topics to skills and their key sections. It stays
   valid for the entire conversation.
2. For every Genero question, route through the skill-index first.
   If a topic matches a row, call
   `getSkillSection(<skill-id>, <section-id>)` directly â~@~T sections
   are 5â~@~S10Ã~W smaller than full skills.
3. If no row matches, call `searchSkills(<keywords>)`. Load the top
   hit's matched section.
4. If skills don't cover the topic, say so. Fall back to `searchDocs`
   / `readDoc`. **Never** fall back to training data.
5. **Do NOT call `listSkills` for routing.** It is an admin
   enumeration tool that returns only `{id, name, category}` and
   cannot tell you which skill covers a topic. Use the skill-index
   or `searchSkills` instead.
6. When the task touches SQL, forms, arrays, dialogs, or strings,
   also load `fourjs-common-pitfalls`.

## Skill Tools (Primary Source)

| Tool | When to Use |
|------|-------------|
| `getSkill("fourjs-skill-index")` | **Session-start ritual.** Once per session. |
| `searchSkills` | Topic not obvious in the index â~@~T fuzzy routing. |
| `getSkillSections` | List sections in a named skill before loading. |
| `getSkillSection` | **Default content-load tool.** Use when you know the section. |
| `getSkill` | Load a full skill (only when the whole skill is needed). |
| `getSkillBundle` | Task genuinely spans multiple skills. |
| `listSkills` | Admin/debugging only â~@~T not for routing. |


## Build and Run

```bash
make          # compile fileList.4gl and fileList.per
make run      # compile and run the application
make clean    # remove all compiled .42? files
```

Compile individual files manually:
```bash
fglcomp -r --make -M -W all <file>.4gl   # compile a .4gl source file → .42m
fglform -M -W all <file>.per             # compile a form → .42f
fglrun <program>                          # run a compiled .42m module
```

## Genero-intelligence 

This is a **Genero BDL** (Business Development Language) project targeting **GBC** (Genero Browser Client). The Four Js toolchain is used:
use the Genero-intelligence mcp server for tasks relating to .4gl .per .4st .4ad .4tm files.

- `.4gl` — BDL source code (compiles to `.42m` bytecode)
- `.per` — Form layout source (compiles to `.42f` form binary)
- `.4st` — Style sheet (XML, controls window/widget appearance)
- `.4ad` — Action defaults (XML, maps action names to keys/icons/text)
- `FGLDIR` environment variable must point to the Genero installation

## Naming Conventions

Variable names carry a scope prefix:

- **Local variables** (and function parameters) are prefixed `l_` — e.g.
  `l_pending`, `l_pid`, `l_rec`.
- **Module-level variables** are prefixed `m_` — e.g. `m_plan_data`.

The prefix applies to `DEFINE`d variables only. It does **not** apply to
`TYPE` names (`t_emp`), cursor names (`c_emp`), prepared-statement handles
(`ins_emp`), window names (`w_main`), record/RECORD member names, SQL column
names, form-field names, or built-ins (`int_flag`, `sqlca`, `TODAY`).

Note: a scalar variable bound by `INPUT BY NAME` must match its form-field
name, so when the variable is renamed (e.g. `m_plan_data`) use the explicit
`INPUT m_plan_data FROM plan_data` form to keep the field binding intact.
(`INPUT BY NAME rec.*` binds by member name, so renaming the record variable
itself is fine.)

## Code conventions

When defining variables or record that will hold data selected from the database
you should use DEFINE ... LIKE 
The module should start with a SCHEMA statement so the compiler knows the schema to
check at compile time.

use a line of 80 x hyphen, below the END FUNCTION statement.

Use SFMT instead of double-pipes ( except if it's in a static SQL statement )


## Code Formatting

Formatter settings are in `.fgl-format`:
- 120-character column limit
- 2-space indent width, tabs used
- Keywords in uppercase (lowercase=0)
- Align consecutive assignments and types

## Beautify After Compile

After a successful `fglcomp` of any Genero BDL module, also run:

```bash
fglcomp --format --fo-inplace <module>.4gl
```

This applies the beautify rules to the source file in place.

## Documention Language

Use the ASD-STE100 standard to keep the text to the point and less verbose.

