# debiancontrib

Debian source packages rebuilt for openSUSE Slowroll with shim .spec files that
hand the work to Debian's own debhelper build, bridged by a `debian-compat`
package. OBS project: `home:bmwiedemannai:debiancontrib`.

Only Debian (testing) sources without an equivalent in openSUSE:Factory /
Slowroll or their devel projects are packaged (home: projects are ignored).

## Quick start

    source setup.sh        # puts the scripts on PATH; config via env vars, see lib.sh
    fetchindex             # download Debian + openSUSE indexes into cache/
    indexdebian; indexsuse # parse them into cache/*.tsv
    match                  # which Debian sources does openSUSE already have?
    mkdepmap               # Debian package name -> openSUSE provides (data/depmap)
    ready=1 top=30 candidates   # best next packages by popcon
    addpkg netcat          # stage obs/netcat (spec, sources, .changes)
    localbuild obs/netcat  # rpmbuild in the tumbleweed distrobox
    commit=1 addpkg netcat # commit to OBS
    pushcompat             # regenerate + stage debian-compat (commit=1 to send)
    status                 # build state of the whole project
    showunresolvable       # most wanted missing deb() mappings
    updatepkg              # refresh packages whose Debian version moved on

See docs/design.md for how it works and docs/workflow.md for the day-to-day loop.
