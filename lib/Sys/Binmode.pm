package Sys::Binmode;

use strict;
use warnings;

our $VERSION = '0.01_01';

require XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

use constant _HINT_KEY => __PACKAGE__ . '/enabled';

sub import {
    $^H{ _HINT_KEY() } = 1;

    return;
}

sub unimport {
    delete $^H{ _HINT_KEY() };
}

1;
