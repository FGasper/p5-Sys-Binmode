#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::FailWarnings;

use FindBin;
push @INC, "$FindBin::Bin/assets";

my $e_up = "é";
utf8::upgrade($e_up);

do {
    use Sys::Binmode;

    eval { do "do-$e_up.pl" };
    is( $@, q<>, 'do with upgraded string' );
};

do {
    use Sys::Binmode;

    eval { require "require-$e_up.pl" };
    is( $@, q<>, 'require with upgraded string' );
};

done_testing;

1;
