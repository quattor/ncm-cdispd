#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 3;
use Test::NoWarnings;
use Test::Quattor;
use CDISPD::Utils;
use Readonly;
use CAF::Object;

$CAF::Object::NoAction = 1;

=pod

=head1 DESCRIPTION

This is a test suite for CDISPD::Utils::escape() function

=cut

my $str = 'this is, a-test!';
is(CDISPD::Utils::escape($str), 'this_20is_2c_20a_2dtest_21', "String '$str' successfully escape");


Test::NoWarnings::had_no_warnings();

