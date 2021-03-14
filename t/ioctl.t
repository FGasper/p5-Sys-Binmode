#!/usr/bin/env perl

use strict;
use warnings;

use autodie;

use Test::More;
use Test::FailWarnings;

plan skip_all => "Only for Linux, not $^O" if $^O ne 'linux';

eval { require IO::Pty } or plan skip_all => "No IO::Pty ($@)";

# cf. ioctl_list(4)
use constant {
    TCGETS => 0x00005401,
    TCSETS => 0x00005402,
};

my $pty = IO::Pty->new();

my $val;
ioctl $pty, TCGETS, $val;

diag sprintf "PTY TCGETS: %v.02x\n", $val;

my $copy = $val;

utf8::upgrade($copy);
ioctl $pty, TCSETS, $copy;

my $val2;
ioctl $pty, TCGETS, $val2;

is(
    sprintf('%v.02x', $val2),
    sprintf('%v.02x', $val),
    'ioctl downgraded its argument',
);

done_testing();
