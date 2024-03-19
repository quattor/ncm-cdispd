#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Test::NoWarnings;
use Test::Quattor qw(profile1 profile2);
use CDISPD::Utils;
use CDISPD::Application;
use Readonly;
use CAF::Object;

$CAF::Object::NoAction = 1;

our $this_app;

Test::NoWarnings::clear_warnings();

=pod

=head1 DESCRIPTION

This is a test suite for CDISPD::Utils::compare_profiles() function.
Note that compare_profiles is in fact using all the other utility functions so
these tests make no sense if all the others are not passed successfully.

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

# Keep @expected_components sorted
my @expected_components = ('dpmlfc', 'filecopy', 'ldconf', 'named');

# Check what must be run to move from initial to final configuration

compare_profiles();
my @iclist_sorted = sort  @{$this_app->{ICLIST}};
my $expected_length = @expected_components;
my $iclist_length = @{$this_app->{ICLIST}};
is($iclist_length, $expected_length, "ICLIST has $expected_length components");
for (my $i=0; $i<$iclist_length; $i++) {
    is($iclist_sorted[$i], $expected_components[$i], "ICLIST contains '$expected_components[$i]'");
}

# Same check starting with a non empty ICLIST containing 'dirperm' that is
# removed in final configuration

$this_app->{ICLIST} = [ 'ldconf', 'dirperm', 'filecopy' ];
compare_profiles();
@iclist_sorted = sort  @{$this_app->{ICLIST}};
$expected_length = @expected_components;
$iclist_length = @{$this_app->{ICLIST}};
is($iclist_length, $expected_length, "ICLIST has $expected_length components");
for (my $i=0; $i<$iclist_length; $i++) {
    is($iclist_sorted[$i], $expected_components[$i], "ICLIST contains '$expected_components[$i]'");
}


Test::NoWarnings::had_no_warnings();

done_testing();
