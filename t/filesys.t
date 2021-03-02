#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::FailWarnings;

use File::Temp;
use Errno;
use Fcntl;

my $dir = File::Temp::tempdir( CLEANUP => 1 );

my $e_down = "é";
utf8::downgrade($e_down);

my $e_up = $e_down;
utf8::upgrade($e_up);

open my $wfh, '>', "$dir/$e_down";

sub _get_path_up { "$dir/$e_up" }

do {
    use Sys::Binmode;

    open my $rfh, '<', _get_path_up();
    ok( fileno($rfh), 'open() with upgraded string' );
};

if ($^O =~ m<linux|darwin|bsd>i) {
    use Sys::Binmode;

    ok( (-e _get_path_up()), '-e with upgraded string' );

    ok(
        chmod( 0644, _get_path_up()),
        'chmod with upgraded string',
    );

    ok(
        chown( -1, -1, _get_path_up()),
        'chown with upgraded string',
    );

    ok(
        link( _get_path_up(), _get_path_up() . '-link' ),
        'link with upgraded string',
    );

    ok( (lstat _get_path_up())[0], 'lstat with upgraded string' );

    mkdir( _get_path_up() . '-dir' ),

    ok(
        (-e "$dir/$e_down-dir"),
        'mkdir with upgraded string',
    );

    ok(
        opendir( my $dh, _get_path_up() . '-dir' ),
        'opendir with upgraded string',
    );

    () = readlink _get_path_up();
    is( 0 + $!, Errno::EINVAL, 'readlink with upgraded string' );

    ok(
        rename( _get_path_up() . '-link', _get_path_up() . '-link2' ),
        'rename with upgraded string',
    );

    ok(
        rmdir( _get_path_up() . '-dir' ),
        'rmdir with upgraded string',
    );

    ok( (stat _get_path_up())[0], 'stat with upgraded string' );

    symlink 'haha', _get_path_up() . '-symlink';
    is(
        (readlink "$dir/$e_down-symlink"),
        'haha',
        'symlink with upgraded string',
    );

    ok(
        sysopen( my $rfh, _get_path_up(), Fcntl::O_RDONLY),
        'sysopen with upgraded string',
    );

    ok(
        truncate(_get_path_up(), 0),
        'truncate with upgraded string',
    );

    ok(
        utime(undef, undef, _get_path_up()),
        'utime with upgraded string',
    );

    ok(
        unlink( _get_path_up() ),
        'unlink with upgraded string',
    );
}
else {
    diag "Skipping most tests on this OS ($^O).";
}

done_testing();

1;
