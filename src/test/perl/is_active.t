#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 5;
use Test::NoWarnings;
use Test::Quattor qw(profile1 broken_profile);
use CDISPD::Utils;
use CDISPD::Application;
use Readonly;
use CAF::Object;

$CAF::Object::NoAction = 1;

our $this_app;

=pod

=head1 DESCRIPTION

This is a test suite for CDISPD::Utils::is_active() function

=cut

# Initialize CAF::Application options
unless ( $this_app = CDISPD::Application->new($0,[]) ) {
    throw_error("Failed to initialize CAF::Application");
}

my $config = get_config_for_profile("profile1");
my $comp_config = $config->getElement(COMP_CONFIG_PATH)->getTree();
my $component = 'named';
is(CDISPD::Utils::is_active($comp_config,$component), 1, "Configuration module $component is active");
$component = 'ldconf';
is(CDISPD::Utils::is_active($comp_config,$component), 0, "Configuration module $component is not active");

$config = get_config_for_profile("broken_profile");
$comp_config = $config->getElement(COMP_CONFIG_PATH)->getTree();
$component = 'named';
is(CDISPD::Utils::is_active($comp_config,$component), 0, "Configuration module $component is not active");

Test::NoWarnings::had_no_warnings();

