# This file doesn't force specific versions of re6stnet or slapos.
# It automatically clones missing repositories but doesn't automatically pull.
# You have to choose by using git manually.

# Run with SLAPOS_EPOCH=<N> (where <N> is an integer > 1)
# if rebuilding for new SlapOS version but same re6stnet.

# Non-obvious dependencies:
# - Debian: python-debian, python-docutils | python3-docutils
# We could avoid them by doing like for setuptools, but I'd rather go the
# opposite way: simplify the upload part by using the system setuptools and
# recent features from Make 4.

# This Makefile tries to be smart by only rebuilding the necessary parts after
# some change. But as always, it does not handle all cases, so once everything
# works, you should clean up everything before the final prepare+upload.

# TODO:
# - Arch probably needs clean up of *.py[co] files on uninstallation.
#   This is done already for DEB/RPM.
# - RPM: automatic deps to system libraries.
# - Each built package should have its own dist version (something like
#   -<dist-name><dist-version> suffix), at least to know which one is installed
#   after a dist upgrade.
#   On the other side, Debian should normally suggest to reinstall because
#   package metadata usually differ (e.g. installed size or dependencies), even
#   if there's nothing like checksum comparisons. Maybe other dists do as well.
# - Split tarball in several parts (for Debian, this is doable with
#   "debtransform" tag):
#   - 1 file for each one in download-cache
#   - 1 tarball with everything else
#   For faster release after re6st development, an intermediate split could be:
#   - re6stnet sdist
#   - a tarball of remaining download-cache
#   - 1 tarball with everything else
# - Make tarballs "reproducible". If the contents does not change, and we don't
#   really care about modification times, the result should always be the same.
#   It's really annoying that we can't rely on 'osc status' to know whether
#   there are real changes or not. 2 ways:
#   - This is doable with a very recent of tar (not even in Jessie), in order
#     to sort files by name (--sort option). Then there are timestamps:
#     see -n option of gzip, and --mtime option of tar.
#   - But the best one is probably to use Python instead of tar+gzip.
#     And in fact, such Python script should not be limited to that, since many
#     intermediate files like re6stnet.spec are so quick to generate that they
#     should be produced in RAM.
#
# Note that package don't contain *.py[co] files and they're not generated
# at installation. For this package, it's better like this because it minimizes
# disk usage without slowness (executables are either daemons or run as root).
# If this way of packaging is reused for other software, postinst scripts
# should be implemented.

BOOTSTRAP_URL = http://downloads.buildout.org/1/bootstrap.py
RE6STNET_URL = http://git.erp5.org/repos/re6stnet.git
SLAPOS_URL = http://git.erp5.org/repos/slapos.git

PACKAGE = re6st-node
BIN = re6st-conf re6st-registry re6stnet
NOPART = chrpath flex glib lunzip m4 patch perl popt site_perl xz-utils
TARGET = opt/re6st

ROOT = build
BUILD = $(ROOT)/$(TARGET)

BUILD_KEEP = buildout.cfg extends-cache download-cache

all: tarball debian.tar.gz re6stnet.spec PKGBUILD re6stnet.install

re6stnet:
	git clone $(RE6STNET_URL) $@

slapos:
	git clone $(SLAPOS_URL) $@

$(BUILD)/buildout.cfg: buildout.cfg.in
	mkdir -p $(@D)
	python2 -c 'import os; cfg = open("$<").read() % dict( \
		SLAPOS="$(CURDIR)/slapos", ROOT="$${buildout:directory}/" \
			+ os.path.relpath("$(ROOT)", "$(BUILD)"), \
		TARGET="/$(TARGET)"); open("$@", "w").write(cfg)'

$(BUILD)/bin/python: $(BUILD)/buildout.cfg slapos
	if [ -e $@ ]; then touch $@; else cd $(BUILD) \
	&& rm -rf extends-cache && mkdir -p download-cache extends-cache \
	&& wget -qO - $(BOOTSTRAP_URL) | python2 -S \
	&& bin/buildout buildout:parts=$(@F); fi

re6stnet/re6stnet.egg-info: $(BUILD)/bin/python re6stnet
	rm -f $(BUILD)/download-cache/dist/re6stnet-*
	cd re6stnet && ../$< setup.py sdist -d ../$(BUILD)/download-cache/dist
	# Touch target because the current directory is used as temporary
	# storage, and it is cleaned up after that setup.py runs egg_info.
	touch $@

$(BUILD)/.installed.cfg: re6stnet/re6stnet.egg-info
	cd $(BUILD) && bin/buildout
	# Touch target in case that buildout had nothing to do.
	touch $@

$(ROOT)/Makefile: Makefile.in Makefile
	($(foreach x,BIN NOPART BUILD_KEEP TARGET, \
	echo $(x) = $($(x)) &&) cat $<) > $@

prepare: $(BUILD)/.installed.cfg $(ROOT)/Makefile
	$(eval VERSION = $(shell cd $(BUILD)/download-cache/dist \
	&& set re6stnet-* && set $${1#*-} \
	&& echo -n $${1%.tar.*}+slapos$(SLAPOS_EPOCH).g \
	&& cd $(CURDIR)/slapos && git rev-parse --short HEAD))
	make -C re6stnet

upstream.mk: re6stnet Makefile
	(echo 'override PYTHON = /$(TARGET)/parts/python2.7/bin/python' \
	&& cat $</Makefile) > $@

tarball: upstream.mk prepare
	tar -caf $(PACKAGE)_$(VERSION).tar.gz \
		--xform s,^re6stnet/,, \
		--xform s,^,$(PACKAGE)-$(VERSION)/, \
		cleanup install-eggs rebootstrap $< \
		re6stnet/daemon re6stnet/docs/*.1 re6stnet/docs/*.8 \
		-C $(ROOT) Makefile $(patsubst %,$(TARGET)/%,$(BUILD_KEEP))

debian/changelog: prepare
	cd re6stnet && sed s,$@,../$@, debian/common.mk | \
	make -f - PACKAGE=$(PACKAGE) VERSION=$(VERSION) ../$@

debian/control: debian/source/format prepare Makefile
	$(eval DSC = $(PACKAGE)_$(VERSION).dsc)
	python2 -c 'from debian.deb822 import Deb822; d = Deb822(); \
		b = open("re6stnet/$@"); s = Deb822(b); b = Deb822(b); \
		d["Format"] = open("$<").read().strip(); \
		d["Source"] = s["Source"] = b["Package"] = "$(PACKAGE)"; \
		d["Version"] = "$(VERSION)"; \
		d["Architecture"] = b["Architecture"] = "any"; \
		d["Build-Depends"] = s["Build-Depends"] = \
		"python (>= 2.6), debhelper (>= 8)"; \
		b["Depends"] = "$${shlibs:Depends}, iproute2 | iproute"; \
		b["Conflicts"] = b["Provides"] = b["Replaces"] = "re6stnet"; \
		open("$@", "w").write("%s\n%s" % (s, b)); \
		open("$(DSC)", "w").write(str(d))'

debian.tar.gz: $(patsubst %,debian/%,changelog control prerm postinst rules source/*)
# Unfortunately, OBS does not support symlinks.
	set -e; cd re6stnet; [ ! -e debian/postinst ]; \
	x=`find debian ! -type d $(patsubst %,! -path %,$^))`; \
	tar -chaf ../$@ $$x -C .. $^

define SED_SPEC
	# https://fedoraproject.org/wiki/Packaging:Python_Appendix#Manual_byte_compilation
	1i%global __os_install_post %(echo '%{__os_install_post}' |grep -v brp-python-bytecompile)
	/^%define (_builddir|ver)/d
	s/^(Name:\s*).*/\1$(PACKAGE)/
	s/^(Version:\s*).*/\1$(VERSION)/
	s/^(Release:\s*).*/\11/
	/^BuildArch:/cAutoReqProv: no\nBuildRequires: gcc-c++, make, python\n#!BuildIgnore: rpmlint-Factory\nSource: %{name}_%{version}.tar.gz
	/^Requires:/{/iproute/!d}
	/^Recommends:/d
	s/^(Conflicts:\s*).*/\1re6stnet/
	/^%description$$/a%prep\n%setup -q
	/^%preun$$/,/^$$/{/^$$/ifind /$(TARGET) -type f -name '*.py[co]' -delete
	}
endef

re6stnet.spec: prepare
	$(eval export SED_SPEC)
	sed -r "$$SED_SPEC" re6stnet/$@ > $@

PKGBUILD: PKGBUILD.in prepare
	sed 's/%VERSION%/$(VERSION)/' $< > $@

clean:
	rm -rf "$(ROOT)" *.dsc *.tar.gz re6stnet.spec \
		upstream.mk debian/control debian/changelog
