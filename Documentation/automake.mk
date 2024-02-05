DOC_SOURCE = \
	Documentation/group-selection-method-property.txt \
	Documentation/_static/logo.png \
	Documentation/conf.py \
	Documentation/index.rst \
	Documentation/contents.rst \
	Documentation/intro/index.rst \
	Documentation/intro/install/index.rst \
	Documentation/intro/install/debian.rst \
	Documentation/intro/install/documentation.rst \
	Documentation/intro/install/distributions.rst \
	Documentation/intro/install/fedora.rst \
	Documentation/intro/install/general.rst \
	Documentation/intro/install/ovn-upgrades.rst \
	Documentation/intro/install/rhel.rst \
	Documentation/intro/install/windows.rst \
	Documentation/tutorials/index.rst \
	Documentation/tutorials/ovn-openstack.rst \
	Documentation/tutorials/ovn-sandbox.rst \
	Documentation/tutorials/ovn-ipsec.rst \
	Documentation/tutorials/ovn-ovsdb-relay.rst \
	Documentation/tutorials/images/ovsdb-relay-1.png \
	Documentation/tutorials/images/ovsdb-relay-2.png \
	Documentation/tutorials/images/ovsdb-relay-3.png \
	Documentation/tutorials/ovn-rbac.rst \
	Documentation/tutorials/ovn-interconnection.rst \
	Documentation/topics/index.rst \
	Documentation/topics/testing.rst \
	Documentation/topics/high-availability.rst \
	Documentation/topics/integration.rst \
	Documentation/topics/ovn-news-2.8.rst \
	Documentation/topics/role-based-access-control.rst \
	Documentation/topics/vif-plug-providers/index.rst \
	Documentation/topics/vif-plug-providers/vif-plug-providers.rst \
	Documentation/howto/index.rst \
	Documentation/howto/docker.rst \
	Documentation/howto/firewalld.rst \
	Documentation/howto/ipsec.rst \
	Documentation/howto/ssl.rst \
	Documentation/howto/openstack-containers.rst \
	Documentation/ref/index.rst \
	Documentation/faq/index.rst \
	Documentation/faq/contributing.rst \
	Documentation/faq/general.rst \
	Documentation/internals/index.rst \
	Documentation/internals/authors.rst \
	Documentation/internals/bugs.rst \
	Documentation/internals/committer-emeritus-status.rst \
	Documentation/internals/committer-grant-revocation.rst \
	Documentation/internals/committer-responsibilities.rst \
	Documentation/internals/documentation.rst \
	Documentation/internals/mailing-lists.rst \
	Documentation/internals/maintainers.rst \
	Documentation/internals/ovs_submodule.rst \
	Documentation/internals/patchwork.rst \
	Documentation/internals/release-process.rst \
	Documentation/internals/security.rst \
	Documentation/internals/contributing/index.rst \
	Documentation/internals/contributing/backporting-patches.rst \
	Documentation/internals/contributing/coding-style.rst \
	Documentation/internals/contributing/documentation-style.rst \
	Documentation/internals/contributing/libopenvswitch-abi.rst \
	Documentation/internals/contributing/submitting-patches.rst \
	Documentation/requirements.txt \
	$(addprefix Documentation/ref/,$(RST_MANPAGES) $(RST_MANPAGES_NOINST))
FLAKE8_PYFILES += Documentation/conf.py
EXTRA_DIST += $(DOC_SOURCE)

# You can set these variables from the command line.
SPHINXOPTS =
SPHINXBUILD = sphinx-build
SPHINXSRCDIR = $(srcdir)/Documentation
SPHINXBUILDDIR = $(builddir)/Documentation/_build

# Internal variables.
ALLSPHINXOPTS = -W -n -d $(SPHINXBUILDDIR)/doctrees $(SPHINXOPTS) $(SPHINXSRCDIR)

sphinx_verbose = $(sphinx_verbose_@AM_V@)
sphinx_verbose_ = $(sphinx_verbose_@AM_DEFAULT_V@)
sphinx_verbose_0 = -q

if HAVE_SPHINX
docs-check: $(DOC_SOURCE)
	$(AM_V_GEN)$(SPHINXBUILD) $(sphinx_verbose) -b html $(ALLSPHINXOPTS) $(SPHINXBUILDDIR)/html && touch $@
	$(AM_V_GEN)$(SPHINXBUILD) $(sphinx_verbose) -b man $(ALLSPHINXOPTS) $(SPHINXBUILDDIR)/man && touch $@
ALL_LOCAL += docs-check
CLEANFILES += docs-check

check-docs:
	$(SPHINXBUILD) -b linkcheck $(ALLSPHINXOPTS) $(SPHINXBUILDDIR)/linkcheck

clean-docs:
	rm -rf $(SPHINXBUILDDIR)
	rm -f docs-check
CLEAN_LOCAL += clean-docs
endif
.PHONY: check-docs
.PHONY: clean-docs

# Installing manpages based on rST.
#
# The docs-check target converts the rST files listed in RST_MANPAGES
# into nroff manpages in Documentation/_build/man.  The easiest way to
# get these installed by "make install" is to write our own helper
# rules.

# rST formatted manpages under Documentation/ref.
RST_MANPAGES =

# rST formatted manpages that we don't want to install because they
# document stuff that only works with a build tree, not with an
# installed OVS.
RST_MANPAGES_NOINST = ovn-sim.1.rst

# The GNU standards say that these variables should control
# installation directories for manpages in each section.  Automake
# will define them for us only if it sees that a manpage in the
# appropriate section is to be installed through its built-in feature.
# Since we're working independently, for best safety, we need to
# define them ourselves.
man1dir = $(mandir)/man1
man2dir = $(mandir)/man2
man3dir = $(mandir)/man3
man4dir = $(mandir)/man4
man5dir = $(mandir)/man5
man6dir = $(mandir)/man6
man7dir = $(mandir)/man7
man8dir = $(mandir)/man8
man9dir = $(mandir)/man9

# Set a shell variable for each manpage directory.
set_mandirs = \
	man1dir='$(man1dir)' \
	man2dir='$(man2dir)' \
	man3dir='$(man3dir)' \
	man4dir='$(man4dir)' \
	man5dir='$(man5dir)' \
	man6dir='$(man6dir)' \
	man7dir='$(man7dir)' \
	man8dir='$(man8dir)' \
	man9dir='$(man9dir)'

# Given an $rst of "ovs-vlan-test.8.rst", sets $stem to
# "ovs-vlan-test", $section to "8", and $mandir to $man8dir.
extract_stem_and_section = \
	stem=`echo "$$rst" | sed -n 's/^\(.*\)\.\([0-9]\).rst$$/\1/p'`; \
	section=`echo "$$rst" | sed -n 's/^\(.*\)\.\([0-9]\).rst$$/\2/p'`; \
	test -n "$$section" || { echo "$$rst: cannot infer manpage section from filename" 2>&1; continue; }; \
	eval "mandir=\$$man$${section}dir"; \
	test -n "$$mandir" || { echo "unknown directory for manpage section $$section"; continue; }

INSTALL_DATA_LOCAL += install-man-rst
if HAVE_SPHINX
install-man-rst: docs-check
	@$(set_mandirs); \
	for rst in $(RST_MANPAGES) $(EXTRA_RST_MANPAGES); do \
	    $(extract_stem_and_section); \
	    echo " $(MKDIR_P) '$(DESTDIR)'\"$$mandir\""; \
	    $(MKDIR_P) '$(DESTDIR)'"$$mandir"; \
	    echo " $(INSTALL_DATA) $(SPHINXBUILDDIR)/man/$$stem.$$section '$(DESTDIR)'\"$$mandir/$$stem.$$section\""; \
	    $(INSTALL_DATA) $(SPHINXBUILDDIR)/man/$$stem.$$section '$(DESTDIR)'"$$mandir/$$stem.$$section"; \
	done
else
install-man-rst:
	@:
endif

UNINSTALL_LOCAL += uninstall-man-rst
uninstall-man-rst:
	@$(set_mandirs); \
	for rst in $(RST_MANPAGES); do \
	    $(extract_stem_and_section); \
	    echo "rm -f '$(DESTDIR)'\"$$mandir/$$stem.$$section\""; \
	    rm -f '$(DESTDIR)'"$$mandir/$$stem.$$section"; \
	done
