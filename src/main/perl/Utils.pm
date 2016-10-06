#${PMpre} CDISPD::Utils${PMpost}

=pod

=head1 NAME

CDISPD::Utils: utility functions used by ncm-cdispd to do the profile comparison

=head1 DESCRIPTION

This class provides functions used by ncm-cdispd to compare profiles and to identify
which components must be run.

=cut

####################################################################
# Note about debug level used in this package:
#    - level 1: reserved to ncm-cdispd itself
#    - level 2: compare_profiles(), is_active() and add_component()
#    - level 3: utility functions used to compare profiles
#               (very verbose!)
####################################################################

use POSIX qw(setsid);
require Exporter;
our @ISA = qw(Exporter);

use CAF::Object qw (SUCCESS throw_error);
use EDG::WP4::CCM::CacheManager;
use EDG::WP4::CCM::Path 16.8.0;

our @EXPORT = qw(COMP_CONFIG_PATH compare_profiles add_component clean_ICList);
our $this_app;

*this_app = \$main::this_app;

use constant COMP_CONFIG_PATH => '/software/components';


=pod

=head1 Available functions

=over

=item clean_ICList

Empty/initialise the list of invoked components << $this_app->{ICLIST} >>

=cut

sub clean_ICList
{
    $this_app->debug(3, "cleaning IC list");
    $this_app->{ICLIST} = [];
}

=pod

=item remove_component

Given name of component, remove the component from the list of invoked components if present.

Returns SUCCESS on success, undef on failure.

=cut

sub remove_component
{
    my $component = shift;
    unless ( $component ) {
        $this_app->error("remove_component(): missing argument");
        return;
    }

    $this_app->debug(3, "Removing component $component from ICLIST");
    @{$this_app->{ICLIST}} = grep ($_ ne $component, @{$this_app->{ICLIST}});

    return SUCCESS;
}

=pod

=item add_component

Add a new component to the list of components to be invoked by C<ncm-ncd> (C<<$this_app->{ICLIST}>>).
Components whose properties "dispatch" or "active" is false are ignored (inactive components
are never added).

Arguments are a hash reference with the contents of C</software/components> and the component name.

Return value: 0 if success, else a non-zero value.

=cut

sub add_component
{
    my ($comp_config, $component) = @_;
    unless ( $comp_config && $component ) {
        $this_app->error("add_component(): missing argument(s)");
        return 1;
    }

    # Do not add an inactive component.
    unless ( is_active($comp_config, $component)) {
        return 0;
    }

    unless ( defined($comp_config->{$component}->{dispatch}) ) {
        $this_app->warn("No dispatch flag defined for component $component, not added to list");
        return 0;
    }

    if ( $comp_config->{$component}->{dispatch} ) {
        if ( grep $component eq $_, @{ $this_app->{ICLIST} } ) {
            $this_app->verbose("component $component already in list");
        } else {
            $this_app->report("component $component, marked to dispatch, added to list");
            push( @{ $this_app->{ICLIST} }, $component );

            if ( $this_app->option('state') ) {
                # Touch the file to indicate the last time the component has been scheduled to run
                my $state_file = $this_app->option('state')."/$component";
                if ( open( TOUCH, ">$state_file" ) ) {
                    close(TOUCH);
                } else {
                    $this_app->warn("Cannot update state for component $component (state file=$state_file, status=$!)");
                }
            }
        }
    } else {
        $this_app->debug(2, "component $component, marked to not dispatch, NOT added to list" );
    }

    return 0;
}

=pod

=item changed_status

Check if the status (active/inactive) of a component has changed.

Arguments are a hashref containing the previous and new configuration
of components (C</software/components>) and the component name.

Return value: a boolean true if the status changed to active, false otherwise

=cut

sub changed_status
{
    my ($old_tree, $new_tree, $component) = @_;
    unless ( $old_tree && $new_tree && $component ) {
        $this_app->error("changed_status(): missing argument(s)");
        return 0;
    }

    unless ( defined($new_tree->{$component}->{active}) ) {
        # In the current profile, component is misconfigured ('active' property is required):
        # status assumed unchanged as the current profile is suspect.
        $this_app->warn("component $component has no 'active' property defined in its new profile, status assumed unchanged");
        return 0;
    }

    unless ( defined($old_tree->{$component}->{active}) ) {
        # In the old profile, component is misconfigured ('active' property is required):
        # assume status has changed to give an opportunity to fix the problem with current profile.
        $this_app->warn("component $component has no 'active' property defined in its old profile, assume status has changed");
        return 1;
    }

    if ( $new_tree->{$component}->{active} == $old_tree->{$component}->{active} ) {
        $this_app->debug(3, "component $component: status unchanged");
        return 0;
    };

    if ( $new_tree->{$component}->{active} && !$old_tree->{$component}->{active} ) {
        $this_app->debug(3, "component $component has changed its status from inactive to active");
    } else {
        $this_app->debug(3, "component $component has changed its status from active to inactive");
    }

    return 1;
}

=pod

=item is_active

Check if the status of the component is active

Arguments are a hash reference with the contents of C</software/components>
and the component name.

Return value: a boolean true when the component is active

=cut

sub is_active
{
    my ($comp_config, $component)  = @_;
    unless ( $comp_config && $component ) {
        $this_app->error("is_active(): missing argument(s)");
        return;
    }

    unless ( defined($comp_config->{$component}->{active}) ) {
        # this component is misconfigured, we do not want it to be called
        $this_app->warn("component $component has no 'active' property defined in the profile, ",
                        "assumed inactive (bug in profile?)");
        return 0;
    }

    my $active = $comp_config->{$component}->{active};
    $this_app->debug(2, "component $component is ".($active ? '' : 'in')."active" );
    return $active;
}

=pod

=item get_CPE

Return the list of configuration paths (Configuration Path Entries) whose changes
have been subscribed by the component.

Following paths are (possibly) added

=over

=item the component configuration path (except if C<--noautoregcomp> option has been specified)

=item the component package path (except if C<--noautoregpkg> option has been specified)

=item each path whose change has been explicitly subscribed (using the C<register_change> property)

=back

Arguments are a hash reference with the contents of C</software/components>
and the component name.

=cut

sub get_CPE
{
    my ($comp_config, $component)  = @_;

    my @list = ();
    unless ( $comp_config && $component ) {
        $this_app->error("get_CPE(): missing argument(s)");
        return (@list);
    }

    # add component path to @list, except if component auto-registration
    # of components has been disabled
    my $comp_path = COMP_CONFIG_PATH."/$component";
    if ( $this_app->option('noautoregcomp') ) {
        $this_app->verbose("noautoregcomp option set, not adding component path $comp_path to CPE list");
    } else {
        $this_app->debug(3, "add component path $comp_path to CPE list");
        push @list, $comp_path;
    }

    # add the component package to @list, except if auto-registration
    # of packages has been disabled
    my $pkg_path = "/software/packages/{ncm-$component}";
    if ( $this_app->option('noautoregpkg') ) {
        $this_app->verbose("noautoregpkg option set, not adding component package path $pkg_path to CPE list");
    } else {
        $this_app->debug(3, "add component package path $pkg_path to CPE list");
        push @list, $pkg_path;
    }

    # add the list of registered changes
    if ( $comp_config->{$component}->{register_change} ) {
        my @paths = @{$comp_config->{$component}->{register_change}};
        $this_app->debug(3, "add register_change paths ", join(",", @paths), " to CPE list");
        push @list, @paths;
    }

    return (@list);
}

=pod

=item changed_CPE

Check if one of the CPE (Configuration Path Entry) had its configuration changed
between previous and current profile or if the CPE list was changed.

Arguments are a hashref containing the previous and new configuration
of components (C</software/components>) and the component name.

Return value: a boolean true if a CPE has changed, false otherwise

=cut

sub changed_CPE
{

    my ($old_tree, $new_tree, $component) = @_;

    unless ( $old_tree && $new_tree && $component ) {
        $this_app->error("changed_CPE(): missing argument(s)");
        return 0;
    }

    $this_app->debug(3, "Check CPE configuration changes for $component");

    my @old_CPE = get_CPE($old_tree, $component);
    my @new_CPE = get_CPE($new_tree, $component);

    foreach my $cpe (@new_CPE) {
        unless ( $this_app->{NEW_CFG}->elementExists($cpe) ) {
            # should be checked in the component type
            $this_app->error("$cpe doesn't exist in new profile: component $component has subscribed a non existent path. ",
                             "Returning CPE not changed (bug in profile?).");
            return 0;
        }
    }

    # Check that both lists are different size
    if ( @new_CPE != @old_CPE ) {
        $this_app->debug(3, "CPE list changed between previous and current profiles (different number of element)");
        return 1;
    }

    foreach my $cpe (@old_CPE) {
        unless ( grep($_ eq $cpe, @new_CPE) ) {
            $this_app->debug(3, "CPE list changed between previous and current profiles (entry '$cpe' removed)");
            return 1;
        }
    }

    foreach my $cpe (@new_CPE) {
        unless ( $this_app->{OLD_CFG}->elementExists($cpe) ) {
            $this_app->debug(3, "$cpe doesn't exist in previous profile: assume it is new and CPE has changed");
            return 1;
        }

        if ( $this_app->{OLD_CFG}->getElement($cpe)->getChecksum() ne $this_app->{NEW_CFG}->getElement($cpe)->getChecksum() ) {
            $this_app->debug(3, "Configuration path $cpe subscribed by component $component has changed" );
            return 1;
        }
    }

    return 0;
}

=pod

=item compare_profiles

Compare two profile configuration instances (attributes C<OLD_CFG> and C<NEW_CFG>)
and fill the list of invoked components (C<ICLIST> attribute)
with those whose configuration has changed
(and if they are active and to be dispatched).

Most of the comparison work is done by utility functions.

=cut

sub compare_profiles
{

    # Does the path exist at all? Avoid crashing cdispd in weird configuration.
    my $old_tree = $this_app->{OLD_CFG}->getTree(COMP_CONFIG_PATH);
    unless ($old_tree) {
        $this_app->error(COMP_CONFIG_PATH." missing in previous configuration: assume an empty previous configuration");
    }

    my $new_tree = $this_app->{NEW_CFG}->getTree(COMP_CONFIG_PATH);
    unless ($new_tree) {
        $this_app->error("new configuration has no ".COMP_CONFIG_PATH." path defined");
    }

    # Remove from ICLIST those components that have been removed
    foreach my $component (sort keys %$old_tree) {
        unless ( exists($new_tree->{$component}) ) {
            remove_component($component);
        }
    }

    # add to ICList those components that are new and active
    foreach my $component (sort keys %$new_tree) {
        unless ( exists($old_tree->{$component}) ) {
            $this_app->debug(2, "component $component: new, to be added if active" );
            add_component($new_tree, $component);
        }
    }

    # add to ICList those components whose status or CPEs have changed
    foreach my $component (keys(%$new_tree)) {
        if ( changed_status($old_tree, $new_tree, $component) ) {
            $this_app->debug(2, "component $component: status changed" );
            add_component($new_tree, $component);
            next;
        }

        if ( changed_CPE($old_tree, $new_tree, $component) ) {
            $this_app->debug(2, "component $component: CPE list or configuration changed");
            add_component($new_tree,$component);
        } else {
            $this_app->debug(2, "component $component: no change in CPE list or CPE configuration" );
        }
    }
}

=pod

=back

=cut

1;
