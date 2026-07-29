#
# MenuExamples - compile every module in $(SRCDIR) into bin$(GENVER)
#
GENVER=600
BASE=$(PWD)
SRCDIR=src
BINDIR=bin$(GENVER)
DB=../etc/training
SCH=etc/$(DB).sch
export DBNAME=$(BASE)/etc/$(DB).db
export DBTYPE=sqt

# GENVER selects both the output directory and the toolchain, so bin501
# always holds 5.01 bytecode and bin600 holds 6.00. Override FGLROOT,
# FGLDIR or GREDIR on the command line for a non-standard install.
FGLROOT=/opt/fourjs
export FGLDIR=$(FGLROOT)/fgl$(GENVER)
export GREDIR=$(FGLROOT)/gre$(GENVER)

# -o is an output DIRECTORY for fglcomp/fglform, so the rules add it.
# --implicit=none stops fglcomp from compiling imported modules itself;
# make owns the build order through $(DEPS).
FGLCOMP=$(FGLDIR)/bin/fglcomp -r --make -M -W all --implicit=none
FGLFORM=$(FGLDIR)/bin/fglform --make -M -W all
FGLDBSCH=$(FGLDIR)/bin/fgldbsch
FGLRUN=$(FGLDIR)/bin/fglrun
DEPLOYCMD=$(FGLASDIR)/bin/gasadmin gar  -E res.appdata.path=/opt/fourjs/gas$(GENVER)_appdata

# $(GREDIR)/lib holds greruntime, which src/lib.4gl imports. Keep the
# inherited FGLLDPATH on the end - := stops the reference recursing.
export FGLLDPATH := $(BASE)/$(BINDIR):$(BASE)/.fglpkg/webcomponents:$(GREDIR)/lib:$(FGLLDPATH)
export FGLIMAGEPATH=$(BASE)/pics:$(FGLDIR)/lib/image2font.txt:$(BASE)/.fglpkg:$(BASE)/.fglpkg/webcomponents
export FGLDBPATH=$(BASE)/etc
export FGLRESOURCEPATH=$(BASE)/etc:$(BASE)/$(BINDIR)

# Every source in $(SRCDIR) is a build target.
SOURCES=$(wildcard $(SRCDIR)/*.4gl)
FORMSRCS=$(wildcard $(SRCDIR)/*.per)
MODULES=$(SOURCES:$(SRCDIR)/%.4gl=$(BINDIR)/%.42m)
FORMS=$(FORMSRCS:$(SRCDIR)/%.per=$(BINDIR)/%.42f)
DEPS=$(BINDIR)/modules.mk

PROG=menu
RUNARGS=
DESC=MenuExamples
XCF=$(PROG).xcf
PKGFGL=
PKGWC=
#PKGDIR=.fglpkg/webcomponents/
#PKGSRC=.fglpkg/webcomponents/$(PKGFGL)
DIST=distbin

.PHONY: all modules forms deps run clean gar deploy
.SUFFIXES:

all: $(PKGSRC) $(FORMS) $(MODULES)

modules: $(MODULES)

forms: $(FORMS)

deps: $(DEPS)

$(BINDIR)/%.42m: $(SRCDIR)/%.4gl | $(BINDIR)
	$(FGLCOMP) -o $(BINDIR) $<

$(BINDIR)/%.42f: $(SRCDIR)/%.per | $(BINDIR)
	$(FGLFORM) -o $(BINDIR) $<

# fglcomp --dependencies writes the IMPORT FGL graph as make rules, so a
# change to lib.4gl rebuilds every module that imports it.
$(DEPS): $(SOURCES) $(SCH) | $(BINDIR)
	@$(FGLDIR)/bin/fglcomp --dependencies -M -o $(BINDIR) $(SOURCES) > $@.tmp \
		&& mv $@.tmp $@ || { rm -f $@.tmp; false; }

ifeq (,$(filter clean,$(MAKECMDGOALS)))
-include $(DEPS)
endif

# The compiler reads the schema for SCHEMA/DEFINE LIKE, so all modules
# depend on it. $(DEPS) declares the rest of the prerequisites.
$(MODULES): $(SCH)

#.fglpkg/webcomponents/$(PKGWC)
#	fglpkg install $(PKGWC)@1.1.1

$(SCH):
	cd etc && $(FGLDBSCH) -db $(DB).db  -dv dbm$(DBTYPE) -of $(DB)

$(BINDIR):
	mkdir -p $(BINDIR)

etc:
	mkdir etc

run: all
	cd $(BINDIR) && $(FGLRUN) $(PROG).42m $(RUNARGS)

clean:
	find . -name \*.42? -delete;
	rm -f $(DEPS) $(DEPS).tmp
	rm -rf $(DIST) $(PROG).gar

etc/MANIFEST: etc
	@printf '%s\n' \
		'<MANIFEST>' \
		'    <DESCRIPTION>$(DESC)</DESCRIPTION>' \
		'    <APPLICATION xcf="$(XCF)"/>' \
		'</MANIFEST>' > $@
	@echo "Generated $@"

etc/$(XCF):
	@printf '%s\n' \
		'<APPLICATION Parent="defaultgwc" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.4js.com/ns/gas/4.01/cfextwa.xsd">' \
		'    <EXECUTION>' \
		'        <ENVIRONMENT_VARIABLE Id="FGLRESOURCEPATH">.</ENVIRONMENT_VARIABLE>' \
		'        <ENVIRONMENT_VARIABLE Id="FGLIMAGEPATH">.</ENVIRONMENT_VARIABLE>' \
		'        <ENVIRONMENT_VARIABLE Id="FGLLDPATH">$(BINDIR):.</ENVIRONMENT_VARIABLE>' \
		'        <ENVIRONMENT_VARIABLE Id="DBTYPE">sqt</ENVIRONMENT_VARIABLE>' \
		'        <ENVIRONMENT_VARIABLE Id="DBNAME">$(DB).db</ENVIRONMENT_VARIABLE>' \
		'        <PATH>$$(res.deployment.path)</PATH>' \
		'        <MODULE>$(BINDIR)/$(PROG).42m</MODULE>' \
		'    </EXECUTION>' \
		'</APPLICATION>' > $@
	@echo "Generated $@"

# stage everything the archive needs into $(DIST) with MANIFEST + .xcf at the
# root, then zip from inside $(DIST) so the archive paths are relative to it.
$(PROG).gar: all etc/MANIFEST etc/$(XCF)
	@rm -rf $(DIST) $(PROG).gar
	mkdir -p $(DIST)/webcomponents/$(PKGWC)
	cp etc/MANIFEST etc/$(XCF) $(DBNAME) $(DIST)/
	cp -r $(BINDIR) $(DIST)/
#	cp -r $(PKGDIR)$(PKGWC) $(DIST)/webcomponents/
	cd $(DIST) && zip -r ../$(PROG).gar .

gar: $(PROG).gar

deploy: $(PROG).gar
	-$(DEPLOYCMD) --disable-archive $(PROG) && $(DEPLOYCMD) --undeploy-archive $(PROG)
	$(DEPLOYCMD) --deploy-archive $(PROG).gar
	$(DEPLOYCMD) --enable-archive $(PROG)
