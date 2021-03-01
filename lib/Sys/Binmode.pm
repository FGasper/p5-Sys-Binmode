package Sys::Binmode;

use strict;
use warnings;

=encoding utf-8

=head1 NAME

Sys::Binmode - A fix for Perl’s system call encoding bug.

=head1 SYNOPSIS

    use Sys::Binmode;

    my $foo = "é";
    $foo .= "\x{100}";
    chop $foo;

    # Prints “é”:
    print $foo, $/;

    # In Perl 5.32 this may print mojibake,
    # but with Sys::Binmode it always prints “é”:
    exec 'echo', $foo;

=head1 DESCRIPTION

tl;dr: Use this module in B<all> new code. Seriously.

=head1 BACKGROUND

Ideally, a Perl application doesn’t need to know how the interpreter stores
a given string internally. Perl can thus store any Unicode code point while
still optimizing for size and speed when storing “bytes-compatible”
strings—i.e., strings whose code points all lie below 256. Perl’s
“optimized” string storage format is faster and less memory-hungry, but it
can only store code points 0-255. The “unoptimized” format, on the other
hand, can store any Unicode code point.

Of course, Perl doesn’t I<always> optimize “bytes-compatible” strings;
Perl can also, if
it wants, store such strings “unoptimized” (i.e., in Perl’s internal
“loose UTF-8” format), too. For code points 0-127 there’s actually no
difference between the two forms, but for 128-255 the formats differ. (cf.
L<perlunicode/The "Unicode Bug">) This means that anything that reads
Perl’s internals B<MUST> differentiate between the two forms in order to
use the string correctly.

Alas, that differentiation doesn’t always happen. Thus, Perl can
output a string that stores one or more 128-255 code points
differently depending on whether Perl has “optimized” that string or not.
Remember, though, that Perl applications I<should> I<not> I<care> about
Perl’s string storage internals. (This is why, for example, the L<bytes>
pragma is discouraged.) But without that knowledge, the application can’t
know what it actually says to the outside world! Thus we have unpredictable
behaviour, which is categorically bad.

=head1 HOW THIS MODULE (PARTLY) FIXES THE PROBLEM

This module provides predictable behaviour for Perl’s built-in functions by
downgrading all strings before giving them to the operating system. It’s
equivalent to—but faster than!—prefixing your system calls with
C<utf8::downgrade()> (cf. L<utf8>) on all arguments.

Predictable behaviour is B<always> a good thing; ergo, you should
use this module in B<all> new code.

=head1 CAVEATS

If you apply this module injudiciously to existing code you may see
exceptions thrown where previously things worked just fine. This can
happen if you’ve neglected to encode one or more strings before
sending them to the OS; if Perl has such a string stored upgraded then
Perl will, under default behaviour, send a UTF-8-encoded
version of that string to the OS. In essence, it’s an implicit
UTF-8 auto-encode.

The fix is to apply an explicit UTF-8 encode prior to the system call
that throws the error. This is what we should do I<anyway>;
Sys::Binmode just enforces that better.

=head1 WHERE ELSE THIS PROBLEM CAN APPEAR

This problem is widespread in XS modules due to rampant
use of L<the SvPV macro|https://perldoc.perl.org/perlapi#SvPV> and
variants. SvPV is like the L<bytes> pragma in C: it gives you the string’s
internal bytes with no regard for what those bytes represent. XS authors
I<generally> should B<avoid> B<SvPV> unless the C code in question ensures
that the string is in the intended format.
(If in doubt, prefer L<SvPVbyte|https://perldoc.perl.org/perlapi#SvPVbyte>
or L<SvPVutf8|https://perldoc.perl.org/perlapi#SvPVutf8>.)

Note in particular that, as of Perl 5.32, the default XS typemap converts
scalars to C C<char *> and C<const char *> via an SvPV variant. This means
that any module that uses that conversion logic also has this problem.
So XS authors should also avoid the default typemap for such conversions.

=head1 LIMITATIONS

=over

=item * This module will cause an exception to be thrown whenever
an application tries to send a string with a >255 code point to the operating
system. This exception is a B<GOOD> B<THING!> because it means you’ve
neglected to encode your string appropriately for output, and Perl now
points you to the bug.

=item * This module works by replacing the affected ops’ default handlers
with a wrapper function that downgrades the strings then calls the
default handler. If, though, an op’s default handler was I<already>
overwritten, we don’t want to clobber that. This will trigger a compile-time
exception. (It I<may> be possible to accommodate such cases, but currently
that doesn’t happen.)

=back

=head1 LEXICAL SCOPING

If, for some reason, you I<want> Perl’s unpredictable default behaviour,
you can disable this module for a given block via
C<no Sys::Binmode>, thus:

    use Sys::Binmode;

    system 'echo', $foo;        # predictable/sane/happy

    {
        no Sys::Binmode;

        system 'echo', $foo;    # nasal demons
    }

=head1 AFFECTED BUILT-INS

=over

=item * C<exec> and C<system>

=item * C<do> and C<require>

=item * File tests (e.g., C<-e>) and the following:
C<chdir>, C<chmod>, C<chown>, C<chroot>, C<fcntl>, C<glob>, C<ioctl>,
C<link>, C<lstat>, C<mkdir>, C<open>, C<opendir>, C<readlink>, C<rename>,
C<rmdir>, C<select>, C<stat>, C<symlink>, C<sysopen>, C<truncate>,
C<umask>, C<unlink>, C<utime>

=item * C<bind>, C<connect>, and C<setsockopt>

=item * C<gethostbyaddr> and C<getnetbyaddr>

=item * C<syscall>

=back

=head1 TODO

=over

=item * C<dbmopen> and the System V IPC functions aren’t covered here.
If you’d like them, ask.

=item * There’s room for optimization, if that’s gainful.

=item * Ideally this behaviour should be in Perl’s core distribution.

=item * Even more ideally, this behaviour should be Perl’s I<default>.
Maybe someday!

=back

=cut

#----------------------------------------------------------------------

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

#----------------------------------------------------------------------

=head1 ACKNOWLEDGEMENTS

Thanks to Leon Timmermans (LEONT) for some debugging help.

=head1 LICENSE & COPYRIGHT

Copyright 2021 Gasper Software Consulting. All rights reserved.

This library is licensed under the same license as Perl.

=cut

1;
