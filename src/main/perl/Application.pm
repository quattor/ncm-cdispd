# ${license-info}
# ${developer-info
# ${author-info}
# ${build-info}
#
#
# CDISPD::Application class
#
# Provide a class to initialize the CAF::Application used by ncm-cdispd
#
# Initial version written by German Cancio <German.Cancio@cern.ch>
# (C) 2003 German Cancio & EU DataGrid http://www.edg.org
#

=pod

=head1 NAME

CDISPD::Application: ncm-cdispd support class for initializing the CAF::Application

=head1 DESCRIPTION

This class provides the ncm-cdispd specific methods used to initialize the CAF::Application.

=cut

package CDISPD::Application;

use CAF::Application;
use CAF::Reporter;
use CAF::Process;
use CAF::Object;
use LC::Exception qw (SUCCESS throw_error);

use strict;

our @ISA = qw(CAF::Application CAF::Reporter);


#
# Public Methods/Functions for CAF
#

sub app_options() {

    my $self = shift;

    # these options complement the ones defined in CAF::Application
    push(
        my @array,

        # cdispd specific options

        {
            NAME => 'interval=i',
            HELP => 'time (in seconds) between checks for new'
              . ' configuration profiles',
            DEFAULT => 60
        },

        {
            NAME    => 'cache_root=s',
            HELP    => 'cache root directory',
            DEFAULT => undef
        },

        {
            NAME    => 'ncd-retries=i',
            HELP    => 'number of retries if ncd is locked',
            DEFAULT => undef
        },

        {
            NAME    => 'ncd-timeout=i',
            HELP    => 'time in seconds between retries',
            DEFAULT => undef
        },

        {
            NAME    => 'ncd-useprofile=s',
            HELP    => 'profile to use as configuration profile',
            DEFAULT => undef
        },

        # cdispd and ncd common options

        {
            NAME    => 'state=s',
            HELP    => 'directory in which to place state files',
            DEFAULT => undef
        },

        {
            NAME    => 'logfile=s',
            HELP    => 'path/filename to use for cdispd logs',
            # Do not define logfile if NoAction is set to allow unit testing to work
            DEFAULT => $CAF::Object::NoAction ? undef:'/var/log/ncm-cdispd.log'
        },

        {
            NAME    => 'cfgfile=s',
            HELP    => 'configuration file for cdispd defaults',
            DEFAULT => '/etc/ncm-cdispd.conf'
        },

        {
            NAME    => 'noaction',
            HELP    => 'do not actually perform operations',
            DEFAULT => undef
        },

        {
            NAME    => 'facility=s',
            HELP    => 'facility name for syslog',
            DEFAULT => 'local1'
        },

        # become a daemon option

        {
            NAME    => 'quiet|D',
            HELP    => 'becomes a daemon and suppress application outputs',
            DEFAULT => 0
        },

        # write process id to file

        {
            NAME    => 'pidfile=s',
            HELP    => 'write PID to this file path',
            DEFAULT => '/var/run/ncm-cdispd.pid'
        },

        # do not autoregister the paths of components

        {
            NAME    => 'noautoregcomp',
            HELP    => 'do not autoregister the paths  of components',
            DEFAULT => 0
        },

        # do not autoregister the paths of component package

        {
            NAME    => 'noautoregpkg',
            HELP    => 'do not autoregister the paths of component package',
            DEFAULT => 0
        }
    );

    return \@array;

}

sub _initialize {

    my $self = shift;

    #
    # define application specific data.
    #

    # external version number
    $self->{'VERSION'} = '${project.version}';

    # show setup text
    $self->{'USAGE'} = "Usage: cdispd [options]\n";

    #
    # log file policies
    #

    # append to logfile, do not truncate
    $self->{'LOG_APPEND'} = 1;

    # add time stamp before every entry in log
    $self->{'LOG_TSTAMP'} = 1;

    #
    # start initialization of CAF::Application
    #
    unless ( $self->SUPER::_initialize(@_) ) {
        return undef;
    }

    # start using log file
    $self->set_report_logfile( $self->{'LOG'} );

    return SUCCESS;

}

1;
