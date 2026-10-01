# SPDX-License-Identifier: GPL-2.0-or-later
package tsv;
use strict; use warnings;

sub read_tsv($;$) {
    my ($file, $cb) = @_;
    open(my $fh, '<', $file) or die "$file: $!";
    my @rows;
    while (<$fh>) {
        chomp; next if /^#/ || !length;
        my @f = split /\t/, $_, -1;
        $cb ? $cb->(@f) : push(@rows, \@f);
    }
    close $fh;
    return \@rows;
}

sub write_tsv($$) {
    my ($file, $rows) = @_;
    open(my $fh, '>', "$file.new") or die "$file.new: $!";
    print $fh join("\t", map { defined $_ ? $_ : '' } @$_), "\n" for @$rows;
    close $fh or die;
    rename "$file.new", $file or die "$file: $!";
}
1;
