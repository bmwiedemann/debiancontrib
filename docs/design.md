# Design

## Shim spec
`deb2spec` generates a static spec from `debian/control`: one `%package` per
Debian binary package, `Provides: deb(<name>)`, `Requires: deb(<dep>)` from
Depends, and `BuildRequires:` from Build-Depends (first alternative,
arch/profile filtered via Dpkg::Deps, versions dropped) — resolved through
`data/depmap`/`depmap.manual` to the openSUSE requires themselves, unless the
name is provided by one of our own packages. The body is only

    %prep     %debian_prep      dpkg-source -x of the .dsc (applies Debian patches)
    %build    %debian_build     debian/rules build; debian/rules binary
    %install  %debian_install   debian-install: copy debian/<pkg>/ into %buildroot

The macros live in `debian-rpm-macros` (from the debian-compat source package).
During the build `/usr/lib/debian-compat/bin` is first on PATH and holds no-op
stubs for the binary-stage helpers (dh_strip, dh_shlibdeps, dh_gencontrol,
dh_builddeb, ...), so `debian/rules binary` stops after populating
`debian/<pkg>/` and never needs a dpkg database. rpm's own find-requires,
debuginfo extraction and brp-compress replace what the stubs skip.

`DEB_RULES_REQUIRES_ROOT=no` (OBS builds as abuild), `DEB_BUILD_OPTIONS=nocheck`
by default, dpkg-architecture forced to amd64/x86_64-linux-gnu with
DEB_BUILD_* = DEB_HOST_* so nothing looks like a cross build; %optflags are
appended through DEB_CFLAGS_APPEND.

## Relocation
`debian-install` maps paths with `data/relocate.map` (first match wins):
multiarch `/usr/lib/x86_64-linux-gnu/` -> `/usr/lib64/`, perl -> vendor_perl,
`python3/dist-packages` -> site-packages (arch or noarch), ruby, nodejs,
`/usr/share/doc/<pkg>` -> `/usr/share/doc/packages/<pkg>`, `/bin /sbin /lib`
-> `/usr/...`; lintian/doc-base/.la/.packlist files are dropped. pkg-config,
cmake and *-config files get the multiarch string replaced. It writes
`rpmfiles/<pkg>` for `%files -f`: `%dir` for directories not owned by
`filesystem` or listed in `data/owned-dirs`, `%license` for copyright,
`%config(noreplace)` under /etc, man/info pages with a `*` suffix.

Debian maintainer scripts (postinst etc.) are ignored and logged; packages
relying on update-alternatives therefore lack the generic name (e.g. `nc`).

## debian-compat
Two OBS source packages, both generated/staged by `pushcompat`:

- `debian-compat` is the build environment and changes rarely:
  - `debian-rpm-macros`: macros, dh stubs, debian-install, relocate.map
  - `debian-compat-filesystem`: `/usr/lib/x86_64-linux-gnu -> ../lib64`,
    `/usr/lib/python3/dist-packages`, `/usr/share/perl5` symlinks and
    `x86_64-linux-gnu-gcc` style toolchain names
  - sensible-utils and init-system-helpers stubs
- `debian-compat-mappings` is one spec with a fileless
  `debian-compat-<name>` package per Debian name that is in
  `data/compat-seed` or referenced by a committed spec and not provided by one
  of our own packages, with `Provides: deb(<name>)` and `Requires:` the
  openSUSE provides (pkgconfig(), sonames, perl(), package names). `mkcompat`
  generates it from `data/depmap` (+ `depmap.manual`).

Build-Depends are resolved to the openSUSE requires themselves by `deb2spec`
(unless a name is provided by one of our own packages); `deb(...)` remains the
namespace of runtime `Requires:` and of dependencies between our packages,
served by the mappings package. The repositories use `rebuild="local"`
(`data/prj-meta.xml`): a commit only rebuilds the package whose source
changed, so compat and mapping updates leave consumers alone. After a
`depmap` change, regenerate specs with `regen=1 updatepkg` and push the compat
packages; after a macros/toolchain change, trigger the full rebuild
explicitly.

`mkdepmap` builds the map from Debian Packages/Contents vs openSUSE
primary/filelists: identical names, case-only differences, normalized names
(lib*-perl -> perl-*, ruby- -> rubygem-, t64 suffixes, -dev -> -devel, ...),
pkgconfig files, sonames, perl modules, python modules, owners of /usr/bin
files. Unmapped names stay `deb(x)` and show up as unresolvable in OBS;
`showunresolvable` lists the most wanted ones.

## Finding candidates
`match` marks a Debian source as present in openSUSE if `exceptions/have`
lists it (hand-verified equivalents like kwallet-pam -> pam_kwallet6), or the
source name (also normalized), the Homepage, the orig tarball name, enough of
its binary package names (directly or via depmap; -dev/-common/-data binaries
do not count), its files or an AppStream component ID (DEP-11 vs repodata
appdata.xml, e.g. com.corsixth.corsixth -> CorsixTH; IDs that several Debian
sources share, like forks, are ignored) match Slowroll, Tumbleweed or any
Factory devel project. Files are compared as distro-neutral keys (`file_key` in
lib/deb.pm: command, font file, soname, .pc and header names, perl/python/lua
module paths), so google-caladea-fonts is found for fonts-crosextra-caladea by
its Caladea-*.ttf. Fonts also match by family name (at least 8 characters;
openSUSE's may add up to 3 more, NotoSansCJK -> NotoSansCJKjp, for .ttc vs
.otf). Half of the keys of one class must exist in openSUSE, and at least two
for commands, headers and .pc files, which are too generic alone, unless the
command is named like the package; headers and .pc files do not decide when
none of the commands exist. Metapackages and transitional packages (no files
outside /usr/share/{doc,lintian,bug}, from `cache/debian-nfiles.tsv`, not in
section doc) count as present when at least half of their dependencies are
(xfce4 -> xfwm4, thunar, ...). `exceptions/have` with `-` overrides a false
match. `match` warns about packages of our project that now look present.
`candidates` ranks the rest by popcon, drops `exceptions/blocklist`
(Debian infrastructure, kernel, firmware, patent-encumbered codecs) and the ecosystems in
`exceptions/ecosystems` (rust, go, haskell, R, ocaml unless `ecosystems=`
enables them) and counts build dependencies that neither depmap nor our own
packages provide.

## Versions
`Version` is the Debian upstream version (epoch -> Epoch, `-`/`:` -> `.`),
`Release: 0`; the full Debian version is kept in `%global debian_version` and
`Provides: deb(src:<name>) = <version>` for `updatepkg`.

## Build environment details learned the hard way
- Slowroll's %optflags carry `-Werror=return-type`; it is stripped before being appended to Debian's flags.
- `dh_autoreconf` needs autoconf/automake/libtool/gettext-tools, so `debian-rpm-macros` requires them.
- Debian-only build tools: `mawk` (symlink to gawk), `x86_64-linux-gnu-gcc` and friends (debian-compat-toolchain).
- `debian/*.install` files hard-code `usr/share/perl5` and `usr/lib/python3/dist-packages`; the `dh_install`
  wrapper in debian-compat links those names inside debian/tmp to where openSUSE's interpreters installed the files.
- `%dir` entries are emitted for every directory not owned by a package in the build root (`rpm -qf`),
  because OBS's post-build check rejects unowned directories.
- Build-Depends under `<!nocheck>` are dropped; a few packages (gem2deb) use such tools in their rules
  anyway, fixed with `extra_buildrequires` overrides.
- Dependencies that exist only in a devel project are listed in out/wanted-from-devel.txt by adddeps;
  they should be submitted to Factory/Slowroll rather than packaged here.
