#!/usr/bin/env perl

use strict;
use warnings;

use autodie;

use Socket;

use Sys::Binmode;

socket my $ls, AF_INET, SOCK_DGRAM, 0;
setsockopt $ls, SOL_SOCKET, SO_REUSEADDR, 1;

my $addr = Socket::pack_sockaddr_in( 0, Socket::inet_aton('224.0.0.12') );

bind $ls, $addr;

utf8::upgrade $addr;

socket my $ss, AF_INET, SOCK_DGRAM, 0;
send $ss, $addr, 0, $addr;
close $ss;

alarm 5;
my $from = recv $ls, my $buf, 512, 0;

printf "buf: %v.02x\n", $buf;
printf "from: %v.02x\n", $from;

1;
