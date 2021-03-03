#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::FailWarnings;

use File::Temp;

my $e_down = "é";

my $dir = File::Temp::tempdir();

do { open my $w, '>', "$dir/do-$e_down.pl" };
do { open my $w, '>', "$dir/require-$e_down.pl"; print {$w} 1 };

my $e_up = $e_down;
utf8::upgrade($e_up);

do {
    use Sys::Binmode;

    eval { do "$dir/do-$e_up.pl" };
    is( $@, q<>, 'do with upgraded string' );
};

TODO: {

    # In testing, mark was 0x234f1cb98 and sp was 0x20e3010.
    # This causes our wrapper function to think there are no args,
    # so nothing gets downgraded.
    #
    # Only seen on Windows.
    local $TODO = 'Windows MARK/SP bug?' if $^O =~ m<mswin>i;

    use Sys::Binmode;

    eval { require "$dir/require-$e_up.pl" };
    is( $@, q<>, 'require with upgraded string' );
};

done_testing;

1;
