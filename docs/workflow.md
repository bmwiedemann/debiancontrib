# Workflow

All scripts read defaults from `lib.sh` (`prj`, `repo`, `arch`, `cache`,
`obs`, `mirror`, `dist`, `components`, `nonfree=1`, `author`). Nothing is sent
to OBS unless `commit=1`.

## Refresh indexes (daily)

    fetchindex && indexdebian && indexsuse && match && mkdepmap

## Pick and add packages

    ready=1 limit=40 candidates          # zero unresolved build deps, by popcon
    showunresolvable local             # which mappings would unblock most
    addpkg foo bar                     # stage obs/foo, obs/bar
    localbuild obs/foo                 # optional local test (distrobox tumbleweed)
    commit=1 addpkg foo bar
    commit=1 pushcompat                # new deb() names referenced -> compat grows

`addpkg` refuses sources that `match` found in openSUSE (`force=1` overrides).
Per-package knobs go to `overrides/<src>.conf` (nocheck, extra_buildrequires,
drop_buildrequires, drop_requires, extra_requires_<bin>, build_options, prefer_alt,
skip_binaries, needsroot) and patches to `overrides/<src>/*.patch`; they are
applied on every regeneration.

## Watch OBS

    status                             # table + exit code 0/1/2
    showunresolvable                   # nothing provides deb(x) counts
    (cd obs/foo && osc r -w)           # wait for one package
    osc rbl $prj foo openSUSE_Slowroll x86_64

Fix mappings in `data/depmap.manual` (wins over generated `data/depmap`),
Debian-only names in `data/depmap.ignore`, then `commit=1 pushcompat`.

## Update

    updatepkg                          # all packages of the project
    list=1 updatepkg                   # only report
    commit=1 updatepkg foo

## Local build environment
`localbuild` runs rpmbuild inside the `tumbleweed` distrobox, with `out/rpms`
registered as a plaindir repo so debian-compat resolves; `install=1` installs
the results there (needed once for debian-compat).
