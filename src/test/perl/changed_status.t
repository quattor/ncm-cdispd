#!/usr/bin/perl
use strict;
use warnings;

use Test::More;
use Test::Quattor qw(profile1 profile2 broken_profile);
use CDISPD::Utils;
use CDISPD::Application;
use Readonly;
use CAF::Object;
use CAF::Reporter qw($VERBOSE_LOGFILE);

$CAF::Object::NoAction = 1;

our $this_app;

=pod

=head1 DESCRIPTION

This is a test suite for CDISPD::Utils::change_status() function

=cut

# Initialize CAF::Application options
unless ( $this_app = CDISPD::Application->new($0,[]) ) {
    throw_error("Failed to initialize CAF::Application");
}

# ugly, but no other way
is($this_app->_rep_setup()->{$VERBOSE_LOGFILE}, 1, "verbose_logfile is enabled");

my $config_initial = get_config_for_profile("profile1");
my $comp_config_initial = $config_initial->getElement(COMP_CONFIG_PATH)->getTree();
my $config_final = get_config_for_profile("profile2");
my $comp_config_final = $config_final->getElement(COMP_CONFIG_PATH)->getTree();
my $config_broken = get_config_for_profile("profile2");
my $comp_config_broken = $config_broken->getElement(COMP_CONFIG_PATH)->getTree();

# Check 'named' component: no status change (active)
my $component = 'named';
ok(!CDISPD::Utils::changed_status($comp_config_initial,$comp_config_final,$component), "$component: no status change");

# Check 'ldconf' component: status changed from inactive to active
$component = 'ldconf';
ok(CDISPD::Utils::changed_status($comp_config_initial,$comp_config_final,$component), "$component: status changed");

# Check 'grub' component: no status change (active)
$component = 'grub';
ok(!CDISPD::Utils::changed_status($comp_config_initial,$comp_config_final,$component), "$component: no status change");

# Check 'ccm' component: status changed from active to inactive
$component = 'ccm';
ok(CDISPD::Utils::changed_status($comp_config_initial,$comp_config_final,$component), "$component: status changed");


# Check 'named' component with a broken profile (missing active property) either
# as the initial or the final profile.
$component = 'named';
ok(!CDISPD::Utils::changed_status($comp_config_broken,$comp_config_final,$component), "$component: active property missing in initial profile");
ok(!CDISPD::Utils::changed_status($comp_config_initial,$comp_config_broken,$component), "$component: active property missing in final profile");

done_testing();
