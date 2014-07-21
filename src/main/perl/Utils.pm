# ${license-info}
# ${developer-info
# ${author-info}
# ${build-info}
#
#
# CDISPD::Utils class
#
# Utility functions used by ncm-cdispd.
#
# Initial version written by German Cancio <German.Cancio@cern.ch>
# (C) 2003 German Cancio & EU DataGrid http://www.edg.org
#

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

package CDISPD::Utils;

use strict;
use POSIX qw(setsid);
require Exporter;
our @ISA = qw(Exporter);

use LC::Exception qw ( throw_error);
use EDG::WP4::CCM::CacheManager;
use EDG::WP4::CCM::Path;

our @EXPORT = qw(COMP_CONFIG_PATH compare_profiles add_component);
our $this_app;

*this_app = \$main::this_app;

use constant COMP_CONFIG_PATH => '/software/components';


=pod

=head1 Available functions

=over 4


=item escape ($string):string

 This function replaces non alphanumeric characters by an underscore followed
 by the character hexadecimal code (2 digits).

 Arguments
    - $string: a string whose non alphanumeric characters must be escaped

 Return value: the escaped string

 Note: this function could be replaced by a generic one if one is made available

=cut

sub escape($)
{
    my $str = shift;
    my @str = split //, $str;
    my @e_str;

    for my $c (@str) {
      if ( $c !~ /\w/ ) {
        $c = sprintf("_%2x",ord($c));
      }
      push @e_str, $c;
    }

    return join('',@e_str);
}


=pod 

=item clean_ICList ()

 Empty the list of invoked components ($this_app->{ICLIST})

 Arguments: none

 Return value: none

=cut

sub clean_ICList() {

    $this_app->debug(3, "cleaning IC list");
    $this_app->{ICLIST} = ();

    return;

}

=pod

=item remove_component ($component)

 Remove a component from the list of invoked components if present.

 Arguments
    - $component: name of the component to remove

 Return value: none

=cut

sub remove_component($) {
    my $component = shift;
    
    $this_app->debug(3, "Removing component $component from ICLIST");
    @{$this_app->{ICLIST}} = grep ($_ ne $component, @{$this_app->{ICLIST}});
    
    return;
}

=pod

=item add_component ($comp_config, $component):int

 Add a new component to the list of components to be invoked by ncm-ncd ($this_app->{ICLIST}).
 Components whose property "dispatch" is false are ignored.

 Arguments
    - $comp_config: a hash reference with the contents of /software/components
    - $component: a string representing a component name (key in the previous hash)

 Return value: 0 if success, else a non-zero value.

=cut

sub add_component($$) {

    my ($comp_config, $component) = @_;

    if ( $this_app->option('state') ) {
        my $state_file = $this_app->option('state')."/$component";
        if ( open( TOUCH, ">$state_file" ) ) {
            close(TOUCH);
        } else {
            $this_app->warn("Cannot update state for component $component (state file=$state_file, status=$!)");
        }
    }

    # Do no add an inactive component.
    unless ( is_active($comp_config,$component)) {
        return (0);
    }

    unless ( defined($comp_config->{$component}->{dispatch}) ) {
        $this_app->warn("No dispatch flag defined for component $component, not added to list");
        return (0);
    }

    if ( $comp_config->{$component}->{dispatch} ) {
        unless ( grep $component eq $_, @{ $this_app->{ICLIST} } ) {
            $this_app->report("component $component, marked to dispatch, added to list");
            push( @{ $this_app->{ICLIST} }, $component );
        } else {
            $this_app->report("component $component already in list");
        }
    } else {
        $this_app->debug(2, "component $component, marked to not dispatch, NOT added to list" );
    }

    return 0;

}

=pod

=item changed_status (%old_comp_config, %new_comp_config, $component):boolean

 Check if the status (active/inactive) of a component has changed.

 Arguments:
    - $old_cfg: a hash containing the previous configuration of components (/software/components)
    - $new_hash: a has containing the new configuration of components (/software/components)
    - $component: component name

 Return value: a boolean true if the status changed to active, false otherwise

=cut

sub changed_status($$$) {

    my ($old_comp_config, $new_comp_config, $component) = @_;

    unless ( defined($old_comp_config->{$component}->{active}) ) {
        # this component is misconfigured, we do not want it to be called
        $this_app->warn("component $component has no 'active' property defined in its old profile, status assumed unchanged");
        return (0);
    }

    unless ( defined($new_comp_config->{$component}->{active}) ) {
        # this component is misconfigured, we do not want it to be called
        $this_app->warn("component $component has no 'active' property defined in its new profile, status assumed unchanged");
        return (0);
    }

    if ( $new_comp_config->{$component}->{active} == $old_comp_config->{$component}->{active} ) {
        $this_app->debug(3, "component $component has not changed its status");
        return (0);
    };

    if ( $new_comp_config->{$component}->{active} && !$old_comp_config->{$component}->{active} ) {
        $this_app->debug(3, "component $component has changed its status from inactive to active");
    } else {
        $this_app->debug(3, "component $component has changed its status from active to inactive");
    }

    return (1);

}

=pod

=item is_active ($comp_config, $component):boolean

 Check if the status of the component is Active

 Arguments
    - $comp_config: a hash reference with the contents of /software/components
    - $component: a string representing a component name (key in the previous hash)

 Return value: a boolean true when the component is active

=cut

sub is_active($$) {
    my ($comp_config, $component)  = @_;

    unless ( defined($comp_config->{$component}->{active}) ) {
        # this component is misconfigured, we do not want it to be called
        $this_app->warn("component $component has no 'active' property defined in the profile, assumed inactive");
        return (0);
    }

    if ( $comp_config->{$component}->{active} ) {
        $this_app->debug(2, "component $component is active" );
    } else {
        $this_app->debug(2, "component $component is NOT active" );    
    }

    return $comp_config->{$component}->{active};
}

=pod

=item get_CPE ($comp_config, $component):array

 Return the list of configuration paths (Configuration Path Entries) whose changes
 have been subscribe by the current component.

 Arguments
    - $comp_config: a hash reference with the contents of /software/components
    - $component: a string representing a component name (key in the previous hash)

 Return value: an array containing:
    - the component configuration path (except if --noautoregcomp has been specified)
    - the component package path (except if --noautoregpkg has been specified)
    - each path whose change has been explicitely subscribed (register_change property) 

=cut

sub get_CPE($$) {

    my @list = ();
    my ($comp_config, $component)  = @_;

    #
    # add component path to @list, except if component auto-registration
    # of components has been disabled
    #
    unless ( $this_app->option('noautoregcomp') ) {
        my $path = COMP_CONFIG_PATH."/$component";
        $this_app->debug(3, "add $path to CPE list");
        push @list, $path;
    }

    #
    # add the component package to @list, except if auto-registration 
    # of packages has been disabled
    #
    unless ( $this_app->option('noautoregpkg') ) {
        my $path = "/software/packages/".escape("ncm_$component");
        $this_app->debug(3, "add $path to CPE list");
        push @list, $path;
    }

    #
    # add the list of registered changes
    #
    if ( $comp_config->{$component}->{register_change} ) {
        foreach my $path (@{$comp_config->{$component}->{register_change}}) {
            $this_app->debug(3, "add $path to CPE list");
            push @list, $path;            
        }
    }

    return (@list);

}

=pod

=item changed_CPE ($old_comp_config, $new_comp_config, $component):boolean

 Check if one of the CPE (Configuration Path Entries) subscribed had its configuration changed
 between previous and current profile.

 Arguments:
    - $old_cfg: a hash containing the previous configuration of components (/software/components)
    - $new_hash: a has containing the new configuration of components (/software/components)
    - $component: component name

 Return value: a boolean true if a CPE has changed, false otherwise

=cut

sub changed_CPE($$$) {

    my ($old_comp_config, $new_comp_config, $component) = @_;

    $this_app->debug(3, "Check CPE configuration changes for $component");

    foreach my $config_path (get_CPE($new_comp_config, $component)) {
        unless ( defined($new_comp_config->{$config_path}) ) {
            $this_app->error("$config_path doesn't exist in new profile: component $component has subscribed a non existent path");
            return (0);
        }

        unless ( defined($old_comp_config->{$config_path}) ) {
            $this_app->debug(3 ,"$config_path doesn't exist in previous profile: assume it is new and CPE has changed");
            return (1);
        }

        if ( $this_app->{OLDCFG}->getElement($config_path)->getChecksum() ne $this_app->{NEWCFG}->getElement($config_path)->getChecksum() ) {
            $this_app->debug(3, "Configuration path $config_path subbscribed by component $component has changed" );
            return (1);
        }
    }

    return (0);
}

=pod

=item compare_profiles ()

 Compare two profiles and fill the list of invoked components with those whose
 configuration has changed. Most of the comparison work is done by utility functions.

 Arguments: none

 Return value: none

=cut

sub compare_profiles() {

    # does the path exist at all - avoid crash cdispd in weird configuration 
    # situations this should never happen of course...
    my $old_comp_config;
    if ( $this_app->{OLD_CFG}->elementExists(COMP_CONFIG_PATH) ) {
        $old_comp_config  = $this_app->{OLD_CFG}->getElement(COMP_CONFIG_PATH)->getTree();
    } else {
        $old_comp_config = ();
    }

    my $new_comp_config;
    if ( $this_app->{NEW_CFG}->elementExists(COMP_CONFIG_PATH) ) {
        $new_comp_config  = $this_app->{NEW_CFG}->getElement(COMP_CONFIG_PATH)->getTree();
    } else {
        $this_app->error("new configuration has no ".COMP_CONFIG_PATH." path defined");
        $new_comp_config = ();
    }

    # Remove from ICLIST those components that have been removed
    foreach my $component (keys(%$old_comp_config)) {
        unless ( exists($new_comp_config->{$component}) ) {
            remove_component($component);
        }
    }

    # add to ICList those components that are new and active
    foreach my $component (keys(%$new_comp_config)) {
        # Only add if component is active
        if ( !exists($old_comp_config->{$component}) && is_active($new_comp_config,$component) ) {
            $this_app->debug(2, "component $component: new and active" );
            add_component($new_comp_config,$component);
        }
    }

    # add to ICList those components whose status or
    # whose interested CPE's checksums have changed
    foreach my $component (keys(%$old_comp_config)) {
        next unless exists($new_comp_config->{$component});

        if ( changed_status($old_comp_config, $new_comp_config, $component) ) {
            # Only add if active
            if ( is_active($new_comp_config, $component) ) {
                $this_app->debug(2, "component $component: status changed" );
                add_component($new_comp_config,$component);
            }
            next;
        }

        if ( !is_active($new_comp_config, $component ) ) {
            if ( $this_app->option('state') ) {
                my $file = "$this_app->option('state')/$component";
                unlink($file)
                  or $this_app->warn("Cannot remove state $file: $!");
            }
            $this_app->debug(2, "component $component is NOT active, skipping" );
            next;
        }
        
        $this_app->debug(2, "component $component is active checking CPE");
        if ( changed_CPE($old_comp_config, $new_comp_config, $component) ) {
            $this_app->debug(2, "component $component: CPE changed");
            add_component($new_comp_config,$component);
        } else {
            $this_app->debug( 2, "component $component has not changed its CPE" );
        }
    }

    return;
}

