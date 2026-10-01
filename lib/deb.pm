# SPDX-License-Identifier: GPL-2.0-or-later
# thin wrapper around the Dpkg perl modules shipped with the dpkg rpm
package deb;
use strict; use warnings;
use Dpkg::Control;
use Dpkg::Control::Info;
use Dpkg::Deps;
use Dpkg::Index;
use Dpkg::Version;
use Exporter 'import';
our @EXPORT_OK = qw(read_index read_control dep_names debver2rpm debvercmp normalize_name norm_url);

# read_index("xzcat Sources.xz |", CTRL_INDEX_SRC) -> Dpkg::Index
sub read_index($$) {
    my ($src, $type) = @_;
    my $idx = Dpkg::Index->new(type => $type);
    open(my $fh, $src) or die "$src: $!";
    $idx->parse($fh, $src);
    close $fh;
    return $idx;
}

# read_control("debian/control") -> Dpkg::Control::Info
sub read_control($) { return Dpkg::Control::Info->new(filename => $_[0]) }

# dep_names($field, build => 1, nocheck => 1, prefer => {name => 1})
# -> package names after dropping substvars, foreign arches, build profiles,
#    versions; first alternative wins unless one of them is preferred
sub dep_names($%) {
    my ($str, %o) = @_;
    return () unless defined $str;
    $str =~ s/\$\{[^}]*\}//g;
    $str =~ s/^[\s,]+|[\s,]+$//g;
    $str =~ s/,[\s,]*,/,/g;
    return () unless length $str;
    my $deps = deps_parse($str, build_dep => $o{build} // 0, union => 0,
        reduce_arch => 1, host_arch => 'amd64', build_arch => 'amd64',
        reduce_profiles => 1, build_profiles => [$o{nocheck} // 1 ? 'nocheck' : ()]);
    return () unless $deps;
    my @names; my %seen;
    for my $dep (ref($deps) =~ /::(AND|OR)$/ ? $deps->get_deps : $deps) {
        my @alts = $dep->isa('Dpkg::Deps::OR') ? $dep->get_deps : ($dep);
        @alts = grep { defined $_->{package} } @alts or next;
        my ($pick) = grep { $o{prefer} && $o{prefer}{$_->{package}} } @alts;
        $pick //= $alts[0];
        push @names, $pick->{package} unless $seen{$pick->{package}}++;
    }
    return @names;
}

# "1:2.3~rc1+dfsg-2" -> (1, "2.3~rc1+dfsg", "2")
sub debver2rpm($) {
    my $v = Dpkg::Version->new($_[0]);
    my $up = $v->version;
    $up =~ s/[-:]/./g;
    return ($v->epoch, $up, $v->revision);
}

sub debvercmp($$) { return version_compare($_[0], $_[1]) }

# Debian source/binary name -> lowercase candidate openSUSE names
sub normalize_name($) {
    my $n = lc shift;
    my %c = ($n => 1);
    my @rules = (
        [qr/^lib(.*)-perl$/, 'perl-$1'],
        [qr/^ruby-(.*)/, 'rubygem-$1'],
        [qr/^node-(.*)/, 'nodejs-$1'],
        [qr/^fonts-(.*)/, '$1-fonts'],
        [qr/^php-(.*)/, 'php8-$1'],
        [qr/^elpa-(.*)/, 'emacs-$1'],
        [qr/^lib(.*)-java$/, '$1'],
        [qr/^(.*)-java$/, '$1'],
        [qr/^lib(.*)/, '$1'],
        [qr/^python-(.*)/, 'python3-$1'],
        [qr/^python3-(.*)/, 'python-$1'],
        [qr/^(.*)-opensource-src$/, '$1'],
        [qr/^(.*?)[0-9][0-9.]*$/, '$1'],
        [qr/^golang-github-[^-]+-(.*)/, '$1'],
        [qr/^lua-(.*)/, 'lua54-$1'],
        [qr/^ocaml-(.*)/, '$1'],
        [qr/^r-cran-(.*)/, 'r-$1'],
        [qr/^haskell-(.*)/, 'ghc-$1'],
        [qr/^rust-(.*)/, 'rust-$1'],
        [qr/^xfonts-(.*)/, 'xorg-x11-fonts'],
    );
    for my $r (@rules) {
        my ($re, $rep) = @$r;
        if ($n =~ $re) { my ($cap, $x) = ($1, $rep); $x =~ s/\$1/$cap/; $c{$x} = 1 }
    }
    return keys %c;
}

sub norm_url($) {
    my $u = lc shift // '';
    $u =~ s/\s+//g; $u =~ s{^https?://(www\.)?}{}; $u =~ s{/+$}{}; $u =~ s/\.git$//;
    return $u;
}
1;
