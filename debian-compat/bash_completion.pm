# SPDX-License-Identifier: GPL-2.0-or-later
# debian-compat stand-in for bash-completion's debhelper sequence (dh $@ --with bash-completion)
use strict;
use Debian::Debhelper::Dh_Lib;
insert_before('dh_installdeb', 'dh_bash-completion');
1;
