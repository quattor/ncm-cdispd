#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 21;
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

This is a test suite for CDISPD::Utils::add_component() function and
the other related utility functions (remove_component(), clean_ICList())

=cut

# Initialize CAF::Application options
unless ( $this_app = CDISPD::Application->new($0,[]) ) {
    throw_error("Failed to initialize CAF::Application");
}

# Initialize ICLIST (used by utility functions)
$this_app->{ICLIST} = ();

my $config = get_config_for_profile("profile1");
my $comp_config = $config->getElement(COMP_CONFIG_PATH)->getTree();

# Add one component
my $component1 = 'named';
add_component($comp_config,$component1);
my $iclist_length = scalar(@{$this_app->{ICLIST}});
is($iclist_length, 1, "ICLIST still has $iclist_length component");
is($this_app->{ICLIST}[0], $component1, "ICLIST contains '$component1'");

# Add another component: check there is 2 components on the list and
# that they are the right ones
my $component2 = 'spma';
add_component($comp_config,$component2);
$iclist_length = scalar(@{$this_app->{ICLIST}});
is($iclist_length, 2, "ICLIST has $iclist_length component");
is($this_app->{ICLIST}[0], $component1, "ICLIST contains '$component1'");
is($this_app->{ICLIST}[1], $component2, "ICLIST contains '$component2'");

# Readd the first component: check there is no duplicate
add_component($comp_config,$component1);
$iclist_length = scalar(@{$this_app->{ICLIST}});
is($iclist_length, 2, "ICLIST has $iclist_length component");
is($this_app->{ICLIST}[0], $component1, "ICLIST contains '$component1'");
is($this_app->{ICLIST}[1], $component2, "ICLIST contains '$component2'");

# Add a component with dispatch=false: check that it is not added
my $component3 = 'ccm';
add_component($comp_config,$component3);
$iclist_length = scalar(@{$this_app->{ICLIST}});
is($iclist_length, 2, "ICLIST has $iclist_length component");
is($this_app->{ICLIST}[0], $component1, "ICLIST contains '$component1'");
is($this_app->{ICLIST}[1], $component2, "ICLIST contains '$component2'");

# Attempt to add a non existing component: check that it is not added
my $component4 = 'nonexistent';
add_component($comp_config,$component4);
$iclist_length = scalar(@{$this_app->{ICLIST}});
is($iclist_length, 2, "ICLIST has $iclist_length component");

# Add a component with active=false: check that it is not added
my $component5 = 'ldconf';
add_component($comp_config,$component5);
$iclist_length = scalar(@{$this_app->{ICLIST}});
is($iclist_length, 2, "ICLIST has $iclist_length component");
is($this_app->{ICLIST}[0], $component1, "ICLIST contains '$component1'");
is($this_app->{ICLIST}[1], $component2, "ICLIST contains '$component2'");

# Remove first component: check there is one component left and that
# this is component2
CDISPD::Utils::remove_component($component1);
$iclist_length = scalar(@{$this_app->{ICLIST}});
is($iclist_length, 1, "ICLIST has $iclist_length component");
is($this_app->{ICLIST}[0], $component2, "ICLIST contains '$component2'");

# Clear ICLIST and check there is nothing left
clean_ICList();
is($this_app->{ICLIST}, undef, "ICLIST is empty");

# Attempt to add a broken component (dispatch property missing):
# Check that nothing is added.
$config = get_config_for_profile("broken_profile");
$comp_config = $config->getElement(COMP_CONFIG_PATH)->getTree();
$component1 = 'spma';
add_component($comp_config,$component1);
is($this_app->{ICLIST}, undef, "ICLIST is empty");


Test::NoWarnings::had_no_warnings();


