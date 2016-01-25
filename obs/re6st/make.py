# This file doesn't force specific versions of re6stnet or slapos.
# It automatically clones missing repositories but doesn't automatically pull.
# You have to choose by using git manually.

# Run with SLAPOS_EPOCH=<N> environment variable (where <N> is an integer > 1)
# if rebuilding for new SlapOS version but same re6stnet.

# Non-obvious dependencies:
# - Debian: python-debian, python-docutils | python3-docutils
# We could avoid them by doing like for setuptools, but I'd rather go the
# opposite way: simplify the upload part by using the system setuptools.

# This "makefile" is quite smart at only rebuilding the necessary parts after
# some change. The main exception concerns the download-cache & extends-cache,
# because the 'buildout' step is really long. In doubt, and once everything
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
#
# Note that package don't contain *.py[co] files and they're not generated
# at installation. For this package, it's better like this because it minimizes
# disk usage without slowness (executables are either daemons or run as root).
# If this way of packaging is reused for other software, postinst scripts
# should be implemented.

import os, rfc822, shutil, time, urllib
from glob import glob
from cStringIO import StringIO
from subprocess import check_call
from make import *
from debian.changelog import Changelog
from debian.deb822 import Deb822

BOOTSTRAP_URL = "http://downloads.buildout.org/1/bootstrap.py"
PACKAGE = "re6st-node"

BIN = "re6st-conf re6st-registry re6stnet".split()
BUILD_KEEP = "buildout.cfg", "extends-cache", "download-cache"
NOPART = "chrpath flex glib lunzip m4 patch perl popt site_perl xz-utils".split()
TARGET = "opt/re6st"

ROOT = "build"
BUILD = ROOT + "/" + TARGET
DIST = "dist"
OSC = "osc" # usually a symlink to the destination osc folder

re6stnet = git("re6stnet", "https://lab.nexedi.com/nexedi/re6stnet.git",
               "docs".__eq__)
slapos = git("slapos", "http://git.erp5.org/repos/slapos.git",
             ctime=False) # ignore ctime due to hardlinks to *-cache

os.environ["TZ"] = "UTC"; time.tzset()

@task("buildout.cfg.in", BUILD + "/buildout.cfg")
def cfg(task):
    cfg = open(task.input).read() % dict(
        SLAPOS=os.path.abspath("slapos"),
        ROOT="${buildout:directory}/" + os.path.relpath(ROOT, BUILD),
        TARGET="/"+TARGET)
    mkdir(BUILD)
    open(task.output, "w").write(cfg)

@task((cfg, slapos), (BUILD + "/bin/buildout", BUILD + "/bin/python"))
def bootstrap(task):
    try:
        os.utime(task.outputs[1], None)
    except OSError:
        bootstrap = urllib.urlopen(BOOTSTRAP_URL).read()
        mkdir(BUILD + "/download-cache")
        with cwd(BUILD):
            rmtree("extends-cache")
            os.mkdir("extends-cache")
            check_output((sys.executable, "-S"), input=bootstrap)
            check_call(("bin/buildout", "buildout:parts=python"))

def sdist_version(egg):
    global MTIME, VERSION
    MTIME = os.stat(egg).st_mtime
    VERSION = "%s+slapos%s.g%s" % (
        egg.rsplit("-", 1)[1].split(".tar.")[0],
        os.getenv("SLAPOS_EPOCH", ""),
        check_output(("git", "rev-parse", "--short", "HEAD"),
                     cwd="slapos").strip())
    tarball.provides = "%s/%s_%s.tar.gz" % (DIST, PACKAGE, VERSION),
    deb.provides = deb.provides[0], "%s/%s_%s.dsc" % (DIST, PACKAGE, VERSION)
    mkdir(DIST)
    return egg

def sdist(task):
    o = glob(BUILD + "/download-cache/dist/re6stnet-*")
    try:
        return sdist_version(*o),
    except TypeError:
        return None,

@task((bootstrap, re6stnet), ("re6stnet/re6stnet.egg-info", sdist))
def sdist(task):
    # XXX: We'd like to produce a reproducible tarball, so that 'make_tar_gz'
    #      is really useful for the main tarball.
    d = BUILD + "/download-cache/dist"
    g = d + "/re6stnet-*"
    map(os.remove, glob(g))
    check_call((os.path.abspath(task.inputs[1]), "setup.py", "sdist",
                "-d", os.path.abspath(d)), cwd="re6stnet")
    task.outputs[1] = sdist_version(*glob(g))
    # Touch target because the current directory is used as temporary
    # storage, and it is cleaned up after that setup.py runs egg_info.
    os.utime(task.outputs[0], None)

@task(sdist, BUILD + "/.installed.cfg")
def buildout(task):
    check_call(("bin/buildout",), cwd=BUILD)
    # Touch target in case that buildout had nothing to do.
    os.utime(task.output, None)

def tarfile_addfileobj(tarobj, name, dataobj, statobj):
    tarinfo = tarobj.gettarinfo(arcname=name, fileobj=statobj)
    dataobj.seek(0, 2)
    tarinfo.size = dataobj.tell()
    dataobj.reset()
    tarobj.addfile(tarinfo, dataobj)

@task(re6stnet)
def upstream(task):
    check_call(("make", "-C", "re6stnet"))
    task.outputs = glob("re6stnet/docs/*.[1-9]")

@task((upstream, buildout, __file__,
       "Makefile.in", "cleanup", "install-eggs", "rebootstrap"))
def tarball(task):
    prefix = "%s-%s/" % (PACKAGE, VERSION)
    def xform(path):
        for p in "re6stnet/", "build/", "":
            if path.startswith(p):
                return prefix + path[len(p):]
    with make_tar_gz(task.output, MTIME, xform) as t:
        s = StringIO()
        for k in "BIN", "NOPART", "BUILD_KEEP", "TARGET":
            v = globals()[k]
            s.write("%s = %s\n" % (k, v if type(v) is str else " ".join(v)))
        with open(task.inputs[-4]) as x:
            s.write(x.read())
            tarfile_addfileobj(t, "Makefile", s, x)
        s.truncate(0)
        s.write("override PYTHON = /%s/parts/python2.7/bin/python\n" % TARGET)
        with open("re6stnet/Makefile") as x:
            s.write(x.read())
            tarfile_addfileobj(t, "upstream.mk", s, x)
        for x in task.inputs[-3:]:
            t.add(x)
        t.add("re6stnet/daemon")
        for x in upstream.outputs:
            t.add(x)
        for x in BUILD_KEEP:
            t.add(BUILD + "/" + x)

@task(sdist, "debian/changelog")
def dch(task):
    with cwd("re6stnet") as p:
        p += "/" + task.output
        check_output(("make", "-f", "-", p,
                      "PACKAGE=" + PACKAGE, "VERSION=" + VERSION),
            input=open("debian/common.mk").read().replace(task.output, p))

@task((dch, tree("debian")), DIST + "/debian.tar.gz")
def deb(task):
    control = open("re6stnet/debian/control")
    d = Deb822(); s = Deb822(control); b = Deb822(control)
    d["Format"] = open("debian/source/format").read().strip()
    d["Source"] = s["Source"] = b["Package"] = PACKAGE
    d["Version"] = VERSION
    d["Architecture"] = b["Architecture"] = "any"
    d["Build-Depends"] = s["Build-Depends"] = \
        "python (>= 2.6), debhelper (>= 8)"
    b["Depends"] = "${shlibs:Depends}, iproute2 | iproute"
    b["Conflicts"] = b["Provides"] = b["Replaces"] = "re6stnet"
    patched_control = StringIO(str("%s\n%s" % (s, b))) # BBB: cast to str for Python 2.6
    open(task.outputs[1], "w").write(str(d))
    date = rfc822.parsedate_tz(Changelog(open(dch.output)).date)
    mtime = time.mktime(date[:9]) - date[9]
    # Unfortunately, OBS does not support symlinks.
    with make_tar_gz(task.outputs[0], mtime, dereference=True) as t:
        added = glob("debian/*")
        t.add("debian")
        x = "debian/control"
        tarfile_addfileobj(t, x, patched_control, control)
        added.append(x)
        with cwd("re6stnet"):
            upstream = set(glob("debian/*"))
            upstream.difference_update((x, "debian/rules", "debian/source"))
            # check we are aware of any upstream file we override
            assert upstream.isdisjoint(added), upstream.intersection(added)
            map(t.add, sorted(upstream))

@task((sdist, __file__), DIST + "/re6stnet.spec")
def rpm(task):
    check_call(("sed", "-r", r"""
# https://fedoraproject.org/wiki/Packaging:Python_Appendix#Manual_byte_compilation
1i%%global __os_install_post %%(echo '%%{__os_install_post}' |grep -v brp-python-bytecompile)
/^%%define (_builddir|ver)/d
s/^(Name:\s*).*/\1%s/
s/^(Version:\s*).*/\1%s/
s/^(Release:\s*).*/\11/
/^BuildArch:/cAutoReqProv: no\
BuildRequires: gcc-c++, make, python\
#!BuildIgnore: rpmlint-Factory\
Source: %%{name}_%%{version}.tar.gz
/^Requires:/{
    /iproute/!d
}
/^Recommends:/d
s/^(Conflicts:\s*).*/\1re6stnet/
/^%%description$/a%%prep\n%%setup -q
/^%%preun$/,/^$/{
    /^$/ifind /%s -type f -name '*.py[co]' -delete
}
""" % (PACKAGE, VERSION, TARGET), "re6stnet/re6stnet.spec"),
    stdout=open(task.output, "w"))

@task((sdist, "PKGBUILD.in"), DIST + "/PKGBUILD")
def arch(task):
    pkgbuild = open(task.inputs[-1]).read().replace("%VERSION%", VERSION)
    open(task.output, "w").write(pkgbuild)

@task((tarball, deb, rpm, arch, "re6stnet.install"))
def build(task):
    pass

@task(build)
def osc(task):
    check_call(("osc", "up"), cwd=OSC)
    old = set(glob(OSC + "/re6st-node_*"))
    for path in build.inputs:
        shutil.copy2(path, OSC)
        old.discard(OSC + "/" + os.path.basename(path))
    for path in old:
        os.remove(path)
    check_call(("osc", "addremove"), cwd=OSC)
