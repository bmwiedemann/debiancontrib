# debiancontrib: Debian packages for openSUSE Slowroll via shim specs

## Context
Slowroll users miss many packages that Debian has. Goal (task.txt): for Debian testing source packages with no equivalent in openSUSE:Factory/Slowroll or their devel projects (home: ignored), generate openSUSE packages whose .spec is only a shim around Debian's own debhelper build, bridged by a `debian-compat` package (Provides/Requires + symlinks). Packages go to OBS `home:bmwiedemannai:debiancontrib` (exists, empty; repo `openSUSE_Slowroll` → `openSUSE:Slowroll/standard`, currently x86_64+i586); tooling/docs are git-committed in `~/git/debiancontrib` (empty repo, branch master).

User decisions: generated **static** spec; **relocate** files to openSUSE paths + compat symlinks; first scope = generic C/C++ + Perl/Python + Ruby/Node/Lua/elpa/Java (Rust/Go/Haskell/R/OCaml behind a flag); **Bash + Perl**; OBS API via `~/git/slowroll-tools/tools/osc.sh` (`osc_api`/`osc_post`/`osc_put`, `sloguard=home:bmwiedemannai:debiancontrib`; `~/.netrc` auth verified working).

Verified facts:
- Slowroll ships debhelper 14.3, dpkg 1.22.22 (dpkg-source, dpkg-architecture, dpkg-buildflags, dpkg-parsechangelog), dpkg-devel, devscripts, fakeroot, quilt, dh-autoreconf, strip-nondeterminism, debianutils, lsb-release; rpm 4.20. NOT in openSUSE: dh-python/pybuild, gem2deb, dh-elpa, dh-lua, javahelper, dh-exec, po-debconf, cdbs, dh-nodejs/pkg-js-tools → package them from Debian with the same pipeline (bootstrap batch).
- **OBS builds as user `abuild`** (`~/git/obs-build/build:1548`), so `dh_testroot` needs `DEB_RULES_REQUIRES_ROOT=no` (+ stub). No fakeroot needed; rpm owns file ownership.
- Host perl: GDBM_File, XML::Parser, XML::Bare, JSON::XS, DB_File available; dpkg 1.22.22 is installed on the host and its `Dpkg::{Control,Deps,Version,Index,Source::Package,Changelog::Debian,Arch}` load and parse (`deps_parse` verified) → `lib/deb.pm` is a thin wrapper around Dpkg::*, no own deb822/deps/version parser. The `perl-Dpkg` (CPAN 1.23.9) package currently in the project is dropped (user decision): it fails `t/taint.t` only because the test lacks `-Ilib`, but 88 of its 93 modules collide with the paths the dpkg rpm owns. `xzcat`/`zstd -dc` pipes for indexes.
- Debian testing: 40210 main + 143 contrib + 251 non-free sources; openSUSE src indexes ~17.2k each (slowroll, tumbleweed); 243 distinct devel projects (Factory `/search/package`, ~90 s, cached; `osc_api source/<prj>` ≈3 s each). Quick prototype: ~29.7k Debian sources unmatched by name/url (~1540 in popcon top-5000), dominated by ecosystem packages; better matching (binary names, provides, orig tarball) is part of the work.
- Index sizes: Contents-amd64.gz 13 MB, Packages.xz 10 MB, Slowroll filelists 39 MB — fine for a local cache.
- Macro values on Slowroll: `%python3_sitelib`=/usr/lib/python3.13/site-packages, `%python3_sitearch`=/usr/lib64/python3.13/site-packages, `%perl_vendorlib`=/usr/lib/perl5/vendor_perl/5.44.0, `%perl_vendorarch`=…/x86_64-linux-thread-multi, `%_rpmmacrodir`=/usr/lib/rpm/macros.d; `rpm -ql filesystem` ≈ 919 dirs.

Conventions (user memory/skill): flat dir of small executables without extension, `: ${var:=default}` env params, one-line SPDX header, minimal comments, short imperative commit subjects (body only when needed); `.changes` author `Bernhard Wiedemann <bwiedemann@suse.de>` written by us (not `osc vc`); `osc ci --skip-local-service-run -m`; `osc r -w` in background for waiting; after `osc co -l` never `osc addremove`.

## Repository layout (`~/git/debiancontrib`)
```
README.md  docs/design.md  docs/workflow.md
setup                 # `source setup` → PATH, default env
lib.sh                # bash: defaults (prj, repo=openSUSE_Slowroll, arch=x86_64, cache, obs, mirror=http://ftp.gwdg.de/pub/linux/debian/debian, dist=testing, components="main contrib", author), die/log, sources osc.sh with sloguard, debfetch, verify_sha256
lib/deb.pm            # perl: parse_deb822, parse_deps (alternatives, [arch] qualifiers, <profiles>), debvercmp, debver2rpm, normalize_name
lib/tsv.pm            # read/write TSV caches (replaces susepkginfo dblib/DB_File)
fetchindex            # Debian Sources/Packages/Contents + popcon; suse src+bin primary + filelists (slowroll, tumbleweed src); Factory search → devel project lists (cache/devel/<prj>.list)
indexdebian           # → cache/debian-sources.tsv, cache/debian-binaries.tsv
indexsuse             # → cache/suse-sources.tsv (name, version, url, origin), suse-provides.tsv, suse-files.tsv (bin/, lib64/*.so*, pkgconfig, include, perl/python dirs only)
match                 # → cache/match.tsv (source, status ∈ have-name|have-norm|have-url|have-tarball|have-binary|have-devel|missing, evidence) + out/match-audit.tsv
mkdepmap              # heuristics + file matching + data/depmap.manual → data/depmap (sorted, committed, can integrate+re-use some of /etc/zypp/apt-packagemap.d/)
candidates            # rank missing by popcon, apply exceptions, ecosystem classes, unresolved build-deps → out/candidates.tsv; --ready
showunresolvable      # obs mode (OBS _result unresolvable details → "nothing provides deb(x)" counts) / local mode
debget                # download .dsc + Files from pool, sha256 verify → cache/pool/<src>/
deb2spec              # extracted debian/ + .dsc (+ overrides) → spec (+ changes text, rpmlintrc)
addpkg                # debget → extract debian/ via tar → deb2spec → osc mkpac/co, add/rm sources → changesadd → osc ci (dry=1 stops before ci)
updatepkg             # compare %global debian_version vs index (debvercmp) → addpkg update mode; reports packages now available in openSUSE (out/obsolete.txt)
mkcompat              # regenerate debian-compat/debian-compat.spec from depmap ∩ (seed ∪ names referenced by obs/*/*.spec) + compat-extras; date-based Version
changesadd            # prepend canonical .changes entry (67 dashes, LC_ALL=C date -u, $author)
status / waitbuild / buildlog / localbuild / installcheck / batch
data/depmap  data/depmap.manual  data/depmap.ignore  data/compat-seed  data/compat-extras  data/relocate.map  data/licensemap  data/extraprojects  data/prj-meta.xml  data/prjconf
exceptions/blocklist  exceptions/ecosystems  exceptions/notes
overrides/<src>.conf  overrides/<src>/*.patch
debian-compat/        # hand-maintained parts: debian-compat.spec.in, macros.debian, debian-install, dh-stubs/, rpmlintrc
cache/ obs/ out/      # gitignored (obs/ = osc checkouts of $prj)
```

## Design

### 1. debian-compat source package (noarch, `Version: <date>`, built first)
- **debian-rpm-macros**: `%{_rpmmacrodir}/macros.debian`; `/usr/lib/debian-compat/bin/` no-op stubs (`dh_testroot dh_shlibdeps dh_makeshlibs dh_gencontrol dh_md5sums dh_builddeb dh_strip dh_dwz dh_compress dh_installdeb dh_strip_nondeterminism dh_buildinfo`, each logs "debian-compat: skipping …" and exits 0); `/usr/lib/debian-compat/debian-install` (perl worker for %debian_install); `relocate.map`; `owned-dirs`. Requires: debhelper dpkg dh-autoreconf patch rpm-build python3-base perl.
- **debian-compat-filesystem**: symlinks `/usr/lib/x86_64-linux-gnu → ../lib64`, `/usr/lib/python3/dist-packages → ../python3.13/site-packages` (from `%python3_sitelib` at build time), `/usr/share/perl5 → ../lib/perl5/vendor_perl/5.44.0`. Safety net for hard-coded leftovers.
- **Stub-script subpackages** from `data/compat-extras`: `debian-compat-sensible-utils` (sensible-editor/pager/browser wrappers), `-debianutils` (only commands missing on openSUSE: tempfile, savelog, ischroot, add-shell, remove-shell; Requires which), `-init-system-helpers` (deb-systemd-helper, invoke-rc.d, update-rc.d no-ops), `-lsb-release` (Requires lsb-release). Each `Provides: deb(<debname>)`.
- **Mapping subpackages** (fileless, one per needed depmap entry): `debian-compat-<debname>`: `Provides: deb(<debname>)`, `Requires: <suse provides>`; Debian virtual names mapping to the same target are collapsed as extra Provides. "Needed set" = `data/compat-seed` (toolchain: debhelper, debhelper-compat, dpkg-dev, build-essential→gcc gcc-c++ make glibc-devel, libc6-dev, pkg-config/pkgconf, cmake, meson, ninja-build, gettext, xsltproc, docbook-xsl/xml, python3-all(-dev), python3-setuptools, perl, ruby, default-jdk, nodejs, lua5.4, quilt, help2man, texinfo, bison, flex, libtool, …) ∪ every `deb(x)` referenced in committed specs, minus names provided by our own packages (conflict → die; fix via depmap.ignore). Expect ~100 at bootstrap, hundreds later; if >~1500 add a `--split` by prefix (plan only).

### 2. Build contract (`macros.debian`)
```
%debian_prep:    %setup -q -c -T; dpkg-source --no-check -x %{_sourcedir}/%{debian_dsc} src; cd src; for p in %{?debian_patches}: patch -p1
%debian_env:     PATH=/usr/lib/debian-compat/bin:$PATH; DEB_RULES_REQUIRES_ROOT=no;
                 DEB_BUILD_OPTIONS="%{?debian_nocheck:nocheck }parallel=%{?jobs}%{!?jobs:1} %{?debian_build_options}";
                 SOURCE_DATE_EPOCH=$(dpkg-parsechangelog -STimestamp); eval "$(dpkg-architecture -a amd64 -t x86_64-linux-gnu -f -s)";
                 DEB_CFLAGS_APPEND/DEB_CXXFLAGS_APPEND="%{optflags}"; HOME=$PWD/.home
%debian_build:   cd src; %debian_env; debian/rules build; debian/rules binary   (stubs end the binary stage after dh_install*; works with override_* targets since the real debian/rules runs; no dpkg-buildpackage → no dpkg-checkbuilddeps)
%debian_install: cd src; %debian_env; /usr/lib/debian-compat/debian-install %{buildroot}
%debian_check:   optional, only when overrides set check=1
```
`dpkg-source -x` handles 1.0 / 3.0 (native) / 3.0 (quilt) and applies the quilt series; extra `overrides/<src>/*.patch` listed as `PatchN:` and applied afterwards.

### 3. debian-install (relocation + filelists), per binary P with `debian/P/` tree
1. Walk `debian/P`; DROP `usr/share/lintian`, `usr/share/bug`, `usr/share/doc-base`, `DEBIAN/`, `*.la`, `usr/share/doc/P/changelog.Debian*`.
2. Map via ordered regex table `data/relocate.map` (first match wins): `usr/lib/x86_64-linux-gnu/perl5/5.x/ → %perl_vendorarch`, `usr/share/perl5/ → %perl_vendorlib`, `usr/lib/python3/dist-packages/ → %python3_sitearch` (arch pkg) / `%python3_sitelib` (all), ruby vendor dirs → `%rb_vendorarchdir`/`%rb_vendorlibdir`, `usr/share/nodejs/ → /usr/lib/node_modules/`, `usr/lib/x86_64-linux-gnu/ → /usr/lib64/`, `usr/share/doc/P/ → /usr/share/doc/packages/P/`, `/(bin|sbin|lib)/ → /usr/…`.
3. Copy preserving modes; rewrite absolute symlink targets through the same table; `sed s,/usr/lib/x86_64-linux-gnu,/usr/lib64,g` on text files under lib64/pkgconfig, lib64/cmake, share/pkgconfig, bin/*-config.
4. Write `%{_builddir}/rpmfiles/P`: `%config(noreplace)` for /etc, `%license` for doc/packages/P/copyright, `%doc` for other docdir files, man/info paths with `*` suffix (brp-compress), `%dir` for created dirs not in `rpm -ql filesystem` and not in `owned-dirs` (language roots, pkgconfig, cmake, applications …), parents first. Spec: `%files -n P -f %{_builddir}/rpmfiles/P`.
5. Log ignored maintainer scripts (`DEBIAN/postinst` …) and count leftover `x86_64-linux-gnu` strings in relocated ELF/text files; die if any dst still starts with `/usr/lib/x86_64-linux-gnu/`.

### 4. deb2spec
Input: `cache/pool/<src>/x/debian/` (extracted with tar from `.debian.tar.*` or the native tarball), the `.dsc` (Format, Files), `overrides/<src>.conf`. Output: spec, changes text, optional `<src>-rpmlintrc`.
- `%global debian_source`, `%global debian_version <full>` (authoritative for updatepkg); `debver2rpm`: `N:` → Epoch, strip `-rev`, remaining `-`/`:` → `.`; keep `~`, `+dfsg`. `Release: 0`.
- Header: Name = Debian source; Summary from first non -dev/-doc binary; License from DEP-5 `debian/copyright` short names via `data/licensemap` joined with AND (else `SEE debian/copyright`); URL = Homepage; `Source0..N` = .dsc + tarballs (no `_service`; sources committed); `BuildRequires: debian-rpm-macros` + translated Build-Depends(-Indep/-Arch).
- Dependency translation: parse_deps → drop arch-excluded, `<!nocheck>` (nocheck default on), `<cross>`/`<pkg.*>` profiles; first alternative (override `prefer_alt=`); drop versions, `${…}` substvars, `depmap.ignore` names; emit `deb(name)`; sibling binaries → `deb(name) = %{version}`.
- Per binary: `%package -n <bin>` (skip udeb, -dbgsym, Section debug), `BuildArch: noarch` if `Architecture: all`, `Provides: deb(<bin>) = %{version}` + `deb(<virtual>)` for Debian Provides, `Requires:` from Depends/Pre-Depends, Recommends/Suggests mapped 1:1, Conflicts/Breaks only for names we build, `%description -n`, `%files -n … -f`. Binary named like the source = main package; first binary carries `Provides: deb(src:<src>) = <debian_version>`.
- Body: `%prep %debian_prep / %build %debian_build / %install %debian_install` (+ `%check %debian_check` if check=1).
- Overrides keys: nocheck, extra_buildrequires, drop_buildrequires, extra_requires_<bin>, build_options, prefer_alt, skip_binaries, needsroot (emits `# needsrootforbuild`), patches auto-listed. Refuse (unless force=1) if a binary name is a real openSUSE package name (`suse-provides.tsv`) or license unmappable for non-free.
- `.changes`: `changesadd` with "- Initial package of Debian <src> <ver>" / "- Update to Debian version <ver>"; same text as `osc ci -m`.

### 5. Candidate pipeline
- `match` says "openSUSE has it" if any: source name in slowroll/tumbleweed src or any devel-project list (`data/extraprojects` adds e.g. openSUSE:Factory:NonFree); normalized name (`lib*-perl→perl-*`, `python-/python3-`, `ruby-→rubygem-`, `node-→nodejs-`, `fonts-→*-fonts`, `php-→php8-`, `elpa-→emacs-`, `lib(.*)-java→\1`, strip `lib`, strip version suffix like `pango1.0`, `-opensource-src`; case-insensitive); Homepage ≈ rpm `<url>`; orig tarball basename; any Debian binary name ∈ suse binary names/provides; ≥50% of its `/usr/bin` files (Contents) in `suse-files.tsv`. Evidence column + `out/match-audit.tsv` for the risky categories (binary/url).
- `mkdepmap` per Debian binary name (from Packages): identical name; `lib*-dev` → `.pc` files from Contents → `pkgconfig(x)` provides, else header owners; `libfooN` → `libfoo.so.N()(64bit)` provides; `libfoo-perl` → `perl(Foo::Bar)` from `.pm` paths; `python3-foo` → `python3dist(foo)`/site-packages owner; `ruby-foo` → `rubygem(foo)`; `node-foo` → `npm(foo)`; `/usr/bin/x` owner majority; `data/depmap.manual` wins; column 3 = method.
- `candidates`: missing ∩ popcon rank, drop `exceptions/blocklist` (`^apt$ ^dpkg$ ^debian- -keyring$ ^initramfs-tools ^linux$ -dkms$ ^firmware- ^base-files$ ^tasksel …`), classify ecosystem via `exceptions/ecosystems` (cargo/dh-cargo/rustc → rust; dh-golang → go; ghc/haskell-devscripts → haskell; dh-r/r-base-dev → r; dh-ocaml → ocaml; `ecosystems=` enables), compute unresolved = builddeps − depmap − deb() provided by packaged sources − ignore; columns rank, inst, source, version, origsize, nunresolved, unresolved list, section. `--ready`, `maxsize=`.
- `showunresolvable obs` → most-wanted mappings → `depmap.manual`/heuristics → `mkcompat` → commit → repeat.

### 6. Bootstrap order
1. git skeleton: README, docs, setup, lib.sh, lib/*.pm (deb.pm uses `Dpkg::Control`/`Dpkg::Deps` with `reduce_arch`/`reduce_profiles`, `Dpkg::Version` for `debvercmp`), .gitignore; `osc rdelete home:bmwiedemannai:debiancontrib perl-Dpkg` (superseded by dpkg's modules); `data/prj-meta.xml` (drop i586; it was also unresolvable: nothing provides suse-reproducible-builds) + `data/prjconf` (rpmlint off during iteration: `Support: !rpmlint-Factory !rpmlint-mini`; `Macros: %debian_nocheck 1`), applied with `osc meta prj -F` / `osc meta prjconf -F`.
2. `fetchindex`, `indexdebian`, `indexsuse`, `match`, `mkdepmap`, `candidates` — run, commit tooling + a summary of counts in docs.
3. `debian-compat` v1 (macros, stubs, debian-install, filesystem, seed mappings, extras) → `mkcompat`, commit, build.
4. Mechanism validation locally (not committed): `hello` (autotools), `libconfig-tiny-perl` (arch all, perl relocation), a cmake/autotools shared lib with -dev split (lib64 relocation, .pc sed, %dir), a meson package. Check file lists, soname auto-requires + `deb()` names, no `x86_64-linux-gnu` paths, `%license`, noarch stanzas.
5. First batch (~10) from `candidates --ready` restricted to seed-only build-deps, plus `dh-exec` and `po-debconf` (they unblock many). Iterate with `showunresolvable`.
6. Ecosystem bootstrap: `dh-python` (+pybuild-plugin-pyproject), `gem2deb`, `dh-elpa`, `pkg-js-tools`/`dh-nodejs`, `dh-lua`, `pkg-kde-tools`, `javahelper`/`maven-*-helper` last. Their `dh-sequence-*` Provides come automatically from debian/control.
7. Scale: `batch N` by popcon, `status` + `showunresolvable` per batch; `exceptions/notes` for structural failures; `updatepkg` runs (cron-able) for Debian version bumps.

## Verification
- `localbuild <pkg>`: `osc build --noservice --vm-type=kvm -j9 openSUSE_Slowroll x86_64 [--prefer-pkgs=out/rpms]`, rpms copied to `out/rpms/`; `checkrpm`: `rpm -qlpv`, `--provides/--requires` (soname deps + `deb(...)`), `--scripts` empty, no `x86_64-linux-gnu` paths, BUILDARCH noarch where expected, rpmlint (in distrobox if absent on host).
- `installcheck`: `distrobox enter tumbleweed -- sudo zypper -n --no-gpg-checks in out/rpms/debian-compat-*.rpm out/rpms/<pkg>*.rpm`, then run `<bin> --version` / `perl -MFoo -e1` / `python3 -c 'import foo'`; later `zypper --root out/root` against Slowroll oss + the published project repo for whole-set runtime resolution.
- OBS: `waitbuild` (`osc r -w` in background), `buildlog` for failures, `status` exit codes (0 green / 1 in flight / 2 failures), `showunresolvable obs` must reach 0 for a batch before scaling.
- `match` spot-check: 20 previously "missing" names (pango1.0, qtbase-opensource-src, python3.13, libsoup3, requests, setuptools …) must now be `have-*`; audit `out/match-audit.tsv`.
- `updatepkg` dry run on a package with a pinned older version shows the bump and regenerates identically otherwise (deterministic spec output → empty diff when nothing changed).

## Risks / mitigations (short)
- Missing dh add-ons → packaged from Debian first; `candidates` marks dependents unresolved until then.
- `gcc -dumpmachine` = x86_64-suse-linux → `dpkg-architecture -a amd64 -t x86_64-linux-gnu -f`; verify `--libdir` in step 4.
- Maintainer scripts ignored (alternatives, pycompile, systemd enable): openSUSE file triggers cover ldconfig/icons/desktop db; `post_<bin>=` override knob if ever needed.
- rpmlint/post-build-checks: off initially; `owned-dirs` grows as seen.
- False "missing" → duplicates: `addpkg` refuses binary-name collisions; audit file; `updatepkg` reports packages now in openSUSE.
- Build-dep cycles: nocheck profile, `drop_buildrequires=`; OBS handles the rest.
- Large tarballs: `maxsize` filter; `_service` only if needed later.
- Non-free: off by default (`nonfree=1`), license must map to SPDX unless `force=1`.
