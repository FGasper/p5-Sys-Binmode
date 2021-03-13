#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::FailWarnings;

use Socket;

use Sys::Binmode;

socket my $ls, AF_INET, SOCK_DGRAM, 0;
setsockopt $ls, SOL_SOCKET, SO_REUSEADDR, 1;

socket my $ss, AF_INET, SOCK_DGRAM, 0;

my $addr = Socket::pack_sockaddr_in( 2000, Socket::inet_aton("244.0.0.0") );
utf8::upgrade $addr;

my $ok = send $ss, $addr, 0, $addr;
my $errs = "$!, $^E";

ok( $ok, 'send() succeeded' ) or diag $errs;

done_testing();

1;
