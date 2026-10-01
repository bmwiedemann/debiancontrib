# SPDX-License-Identifier: GPL-2.0-or-later
# shared defaults and helpers, sourced by every bash script here
top=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
: ${prj:=home:bmwiedemannai:debiancontrib}
: ${repo:=openSUSE_Slowroll}
: ${arch:=x86_64}
: ${cache:=$top/cache}
: ${obs:=$top/obs}
: ${out:=$top/out}
: ${mirror:=http://ftp.gwdg.de/pub/linux/debian/debian}
: ${dist:=testing}
: ${components:=main contrib}
: ${nonfree:=0}
: ${author:=Bernhard Wiedemann <bwiedemann@suse.de>}
: ${commit:=0} # commit=1 lets scripts write to OBS
: ${oscsh:=$HOME/git/slowroll-tools/tools/osc.sh}
[ "$nonfree" = 1 ] && components="$components non-free"
export sloguard=${sloguard-$prj} # osc.sh refuses writes outside this project
verbose=-s . "$oscsh"
export PERL5LIB=$top/lib${PERL5LIB:+:$PERL5LIB}
export PATH=$top:$PATH
mkdir -p "$cache" "$obs" "$out"

die() { echo "${0##*/}: $*" >&2; exit 1; }
log() { echo "$(date +%T) $*" >&2; }

# tsvget FILE KEY [FIELD]: rows (or one field) whose first column is exactly KEY; fails if none
# (grep -P "^$name\t" breaks on names like libsigc++-2.0)
tsvget() { awk -F'\t' -v k="$2" -v f="${3:-0}" '$1 "" == k { print (f ? $f : $0); n++ } END { exit !n }' "$1"; }

verify_sha256() { echo "$2  $1" | sha256sum -c --quiet - ; }
