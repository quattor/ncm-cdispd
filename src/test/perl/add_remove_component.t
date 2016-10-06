#!/usr/bin/perl
use strict;
use warnings;

use Test::More;
use Test::Quattor qw(profile1 broken_profile);
use CDISPD::Utils;
use CDISPD::Application qw(CDISPD_CONFIG_FILE);
use Readonly;
use CAF::Object;
use File::Path qw(mkpath rmtree);
use Cwd qw(getcwd);
use File::Basename qw(basename);

$CAF::Object::NoAction = 1;

our $this_app;

=pod

=head1 DESCRIPTION

This is a test suite for CDISPD::Utils::add_component() function and
the other related utility functions (remove_component(), clean_ICList())

=cut



# Initialize CAF::Application options
# Configure state directory as in the default configuration (unfortunately doesn't work
# as the config file is not open with CAF::FileEditor... file location cannot be mocked)
#set_file_contents(CDISPD_CONFIG_FILE, 'state = /var/run/quattor-components');
my $statedir = getcwd."/target/state/add_remove_component";
rmtree($statedir) if -d $statedir;
mkpath($statedir);
ok(-d $statedir, "new/empty statedir created");

unless ( $this_app = CDISPD::Application->new($0,['--state', $statedir]) ) {
    throw_error("Failed to initialize CAF::Application");
}

# Initialize ICLIST (used by utility functions)
$this_app->{ICLIST} = [];

my $config = get_config_for_profile("profile1");
my $comp_config = $config->getElement(COMP_CONFIG_PATH)->getTree();

# Test that the statefiles are equal to the components in the ICLIST
sub statefiles_equal_ICLIST
{
    my ($comps, $msg) = @_;

    my $cmpsmsg = join(", ", @$comps);

    my $statefiles = [sort(map{basename($_)} grep {-f $_} glob("$statedir/*"))];
    my $stfmsg = join(", ", @$statefiles);

    is_deeply($this_app->{ICLIST}, $comps, "ICLIST contains $cmpsmsg $msg");
    is_deeply([sort(@{$this_app->{ICLIST}})], $statefiles, "statefiles $stfmsg equal to components $cmpsmsg: $msg");
}

my $iclist_length;

# Add one component
my $component1 = 'named';
add_component($comp_config, $component1);
statefiles_equal_ICLIST([$component1], "first component $component1 added");

# Add another component: check there is 2 components on the list and
# that they are the right ones
my $component2 = 'spma';
add_component($comp_config, $component2);
statefiles_equal_ICLIST([$component1, $component2], "2nd component $component2 added");

# Readd the first component: check there is no duplicate
add_component($comp_config, $component1);
$iclist_length = scalar(@{$this_app->{ICLIST}});
statefiles_equal_ICLIST([$component1, $component2], "$component1 not readded");

# Add a component with dispatch=false: check that it is not added
my $component3 = 'ccm';
add_component($comp_config, $component3);
statefiles_equal_ICLIST([$component1, $component2], "$component3 not added (no dispatch)");

# Attempt to add a non existing component: check that it is not added
my $component4 = 'nonexistent';
add_component($comp_config, $component4);
statefiles_equal_ICLIST([$component1, $component2], "$component4 not added (does not exist)");

# Add a component with active=false: check that it is not added
my $component5 = 'ldconf';
add_component($comp_config, $component5);
statefiles_equal_ICLIST([$component1, $component2], "$component5 not added (not active)");

# Remove first component: check there is one component left and that
# this is component2
CDISPD::Utils::remove_component($component1);
is_deeply($this_app->{ICLIST}, [$component2],
          "ICLIST contains '$component2' ($component1 removed)");

# Clear ICLIST and check there is nothing left
clean_ICList();
is_deeply($this_app->{ICLIST}, [], "ICLIST is empty");

# Attempt to add a broken component (dispatch property missing):
# Check that nothing is added.
$config = get_config_for_profile("broken_profile");
$comp_config = $config->getElement(COMP_CONFIG_PATH)->getTree();
$component1 = 'spma';
add_component($comp_config,$component1);
is_deeply($this_app->{ICLIST}, [], "ICLIST is empty");

done_testing();

