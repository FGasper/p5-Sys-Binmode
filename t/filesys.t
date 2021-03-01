#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::FailWarnings;

use File::Temp;

my $dir = File::Temp::tempdir( CLEANUP => 1 );

my $e_down = "é";
utf8::downgrade($e_down);

my $e_up = $e_down;
utf8::upgrade($e_up);

open my $wfh, '>', "$dir/$e_down";

do {
    use Sys::Binmode;

    open my $rfh, '<', "$dir/$e_up";
    ok( fileno($rfh), 'open() with upgraded string' );
};

done_testing();

1;
