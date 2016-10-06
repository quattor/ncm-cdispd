#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Test::Quattor qw(profile1 profile2 profile2_missing_package);
use CDISPD::Utils;
use CDISPD::Application;
use Readonly;
use CAF::Object;

$CAF::Object::NoAction = 1;

our $this_app;

=pod

=head1 DESCRIPTION

This is a test suite for CDISPD::Utils::change_CPE() function and
related get_CPE() function.

=cut

# Initialize CAF::Application options
unless ( $this_app = CDISPD::Application->new($0,[]) ) {
    throw_error("Failed to initialize CAF::Application");
}

my $config_initial = get_config_for_profile("profile1");
my $comp_config_initial = $config_initial->getElement(COMP_CONFIG_PATH)->getTree();
my $config_final = get_config_for_profile("profile2");
my $comp_config_final = $config_final->getElement(COMP_CONFIG_PATH)->getTree();


$this_app->{OLD_CFG} = $config_initial;
$this_app->{NEW_CFG} = $config_final;

# named: get its CPE list and check if configuration module configuration change is detected
my $component = 'named';
my @CPE = CDISPD::Utils::get_CPE($comp_config_initial, $component);
is_deeply(\@CPE, [COMP_CONFIG_PATH."/$component", "/software/packages/{ncm-$component}"],
          "'$component': CPE correct");
ok(CDISPD::Utils::changed_CPE($comp_config_initial, $comp_config_final, $component),
   "$component: configuration change detected");

# ccm: get its CPE list and check if its CPE list modification is detected
# (subscribed path removed)
$component = 'ccm';
@CPE = CDISPD::Utils::get_CPE($comp_config_initial, $component);
is_deeply(\@CPE, [COMP_CONFIG_PATH."/$component", "/software/packages/{ncm-$component}", "/system/kernel"],
          "'$component': CPE correct");
ok(CDISPD::Utils::changed_CPE($comp_config_initial, $comp_config_final, $component),
   "$component: CPE list change detected (CPE entry removed)");

# ldconf: get its CPE list and check if its CPE list modification is detected
# (subscribed path changed)
$component = 'ldconf';
@CPE = CDISPD::Utils::get_CPE($comp_config_initial, $component);
is_deeply(\@CPE, [COMP_CONFIG_PATH."/$component", "/software/packages/{ncm-$component}", "/system/kernel"],
          "'$component': CPE correct");
ok(CDISPD::Utils::changed_CPE($comp_config_initial, $comp_config_final, $component),
   "$component: CPE list change detected (CPE entry modified)");

# grub: get its CPE list and verify that no change is detected
# (identical CPE list, no configuration change)
$component = 'grub';
@CPE = CDISPD::Utils::get_CPE($comp_config_initial, $component);
is_deeply(\@CPE, [COMP_CONFIG_PATH."/$component", "/software/packages/{ncm-$component}", "/system/kernel"],
          "'$component': CPE correct");
ok(!CDISPD::Utils::changed_CPE($comp_config_initial, $comp_config_final, $component),
   "$component: no CPE list or configuration change detected");

# spma: get its CPE list and verify that no change is detected
# (subscribed path missing in new configuration)
$component = 'spma';
@CPE = CDISPD::Utils::get_CPE($comp_config_initial, $component);
is_deeply(\@CPE, [COMP_CONFIG_PATH."/$component", "/software/packages/{ncm-$component}", "/software/repositories", "/software/packages"],
          "'$component': CPE correct");
ok(!CDISPD::Utils::changed_CPE($comp_config_initial, $comp_config_final, $component),
   "$component: no CPE list or configuration change detected");

# filecopy: get its CPE list and check if change is detected
# (subscribed path missing in old configuration)
$component = 'filecopy';
@CPE = CDISPD::Utils::get_CPE($comp_config_initial, $component);
is_deeply(\@CPE, [COMP_CONFIG_PATH."/$component", "/software/packages/{ncm-$component}", "/software/repositories"],
          "'$component': CPE correct");
ok(CDISPD::Utils::changed_CPE($comp_config_initial, $comp_config_final, $component),
   "$component: configuration change (new CPE in current profile)");

# same profile with filecopy with missing CPE (non-existing autoregpkg CPE)
my $config_final_missing_package = get_config_for_profile("profile2_missing_package");
my $comp_config_final_missing_package = $config_final_missing_package->getElement(COMP_CONFIG_PATH)->getTree();
$this_app->{NEW_CFG} = $config_final_missing_package;
ok(! CDISPD::Utils::changed_CPE($comp_config_initial, $comp_config_final_missing_package, $component),
   "$component: no configuration change (new CPE has non-existing entry from missing package)");


done_testing();
