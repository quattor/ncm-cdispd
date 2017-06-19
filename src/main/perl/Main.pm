#${PMpre} CDISPD::Main${PMpost}

use parent qw(Exporter);
use POSIX qw(setsid);

use CAF::Object qw (throw_error);
use LC::Exception;
use EDG::WP4::CCM::CacheManager;
use CDISPD::Application;
use CDISPD::Utils qw(COMP_CONFIG_PATH compare_profiles add_component clean_ICList);
use CAF::FileReader;

use constant CONFIG_ROOT => "/";
use constant NCD_EXECUTABLE => "/usr/sbin/ncm-ncd";


our @EXPORT = qw(main);

our $this_app;
*this_app = \$main::this_app;

our $SIG;

=pod

=head1 NAME

CDISPD::Main: main ncm-cdispd functions, factored out in module to allow unittests.

=head1 FUNCTIONS

=over

=item delay_signals

Configure signal handling for delayed processing of some signals

No return value.

=cut

sub delay_signals
{

    $SIG{'INT'}  = \&signal_terminate;
    $SIG{'TERM'} = \&register_signal;
    $SIG{'QUIT'} = \&signal_terminate;
    $SIG{'HUP'}  = \&register_signal;

}

=item immediate_signals

Configure signal handling for immediate processing of all signals

No return value.

=cut

sub immediate_signals
{

    $SIG{'INT'}  = \&signal_terminate;
    $SIG{'TERM'} = \&signal_terminate;
    $SIG{'QUIT'} = \&signal_terminate;
    $SIG{'HUP'}  = \&signal_reinitialize;

}

=item register_signal

Keep track of the signal received but do not process it immediately.
This is used to postpone signal processing during the exeuction of
ncm-ncd.

No return value.

=cut

sub register_signal
{

    my $signal = shift;
    unless ( $signal ) {
        $this_app->error("register_signal(): missing argument");
        return;
    }

    $this_app->{WAITING_SIGNAL} = $signal;
    $this_app->info("Signal $signal registered for processing after ncm-ncd completion");

}

=item process_signal

Process a delayed signal.
This function does nothing if called when there is no delayed signal.

No return value.

=cut

sub process_signal
{

    unless ( $this_app->{WAITING_SIGNAL} ) {
        $this_app->debug(1,"process_signal(): no delayed signal to process");
        return;
    }

    $this_app->info("Processing delayed signal ".$this_app->{WAITING_SIGNAL});

    # Reset the delayed signal first
    my $signal = $this_app->{WAITING_SIGNAL};
    $this_app->{WAITING_SIGNAL} = undef;

    if ( $signal eq 'HUP' ) {
        signal_reinitialize($signal);
    } elsif ( $signal =~ /INT|TERM|QUIT/ ) {
        signal_terminate($signal);
    } else {
        $this_app->error("Unsupported delayed signal $signal");
    };

}

=item signal_terminate

Proccess signals INT, TERM and QUIT: terminate cdispd daemon

=cut

sub signal_terminate
{

    my $signal = shift;
    unless ( $signal ) {
        $this_app->error("signal_terminate(): missing argument");
        return;
    }

    $this_app->warn("signal handler: signal $signal received");
    $this_app->warn('terminating ncm-cdispd...');

    exit(-1);

}

=item signal_reinitialize

Proccess HUP signal: reinitialize cdispd daemon

=cut

sub signal_reinitialize
{

    my $signal = shift;
    unless ( $signal ) {
        $this_app->error("signal_reinitialize(): missing argument");
        return;
    }

    $this_app->warn("signal handler: received signal: $signal");
    $this_app->warn("reinitializing daemon...");

    # re-read config file
    $this_app->{CONFIG}->file($this_app->option('cfgfile'));
    $this_app->warn("... daemon options reset to those in ".$this_app->option('cfgfile'));

    my $cred = 0;
    my $cm   = EDG::WP4::CCM::CacheManager->new( $this_app->option('cache_root') );
    $this_app->{OLD_CFG}   = $cm->getLockedConfiguration($cred);
    $this_app->{OLD_CKSUM} = $this_app->{OLD_CFG}->getElement(CONFIG_ROOT)->getChecksum();
    $this_app->{OLD_CFID}  = $this_app->{OLD_CFG}->getConfigurationId();
    $this_app->warn("... previous profile set to last one");

    return;
}

=item exception_handler

Exception handling
Use of LC::Exception with CAF

=cut

sub exception_handler
{

    my ( $ec, $e ) = @_;
    unless ( $ec && $e ) {
        $this_app->error("exception_handler(): missing argument");
        return;
    }

    $this_app->error("fatal exception:");
    $this_app->error( $e->text );
    if ( $this_app->option('debug') ) {
        $e->throw;
    } else {
        $e->has_been_reported(1);
    }
    $this_app->error("exiting ncm-cdispd...");
    exit(-1);

}

=item daemonize

Become a daemon. Perform a couple of things to avoid
potential problems when running as a daemon.

=cut

sub daemonize
{

    my $logfile = $this_app->option('logfile');

    if ( !chdir('/') ) {
        $this_app->error("Can't chdir to /: $! : Exiting");
        exit(-1);
    }

    if ( !open(STDIN, '<', '/dev/null') ) {
        $this_app->error("Can't read /dev/null: $! : Exiting");
        exit(-1);
    }

    if ( !open(STDOUT, ">>", $logfile) ) {
        $this_app->error("Can't write to $logfile: $! : Exiting");
        exit(-1);
    }

    if ( !open(STDERR, ">>", $logfile ) ) {
        $this_app->error("Can't write to $logfile: $! : Exiting");
        exit(-1);
    }

    my $pid = fork();
    if ( !defined($pid) ) {
        $this_app->error("Can't fork: $! : Exiting");
        exit(-1);
    }
    exit if $pid;

    # Save the PID.
    if ( $this_app->option('pidfile') ) {

        if (open(my $PIDFILE, ">", $this_app->option('pidfile'))) {
            print $PIDFILE "$$";
            close $PIDFILE;
        } else {
            $this_app->error("Cannot write PID to file \""
                             . $this_app->option('pidfile')
                             . "\": $! : Exiting" );
            exit(-1);
        }
    }

    if ( $this_app->option('state') ) {
        my $dir = $this_app->option('state');
        if ( !-d $dir ) {
            mkdir( $dir, 0755 )
                or $this_app->warn("Cannot create state dir $dir: $!");
        }
    }

    if ( !setsid() ) {
        $this_app->error("Can't start a new session: $! : Exitting");
        exit(-1);
    }

    return;

}


=item init_components

Perform an initial call of all components with dispatch property = true

Returns on success, a non-zero value otherwise.

=cut

sub init_components
{

    # credentials are undefined
    my $cred = 0;

    my $cm = EDG::WP4::CCM::CacheManager->new($this_app->option('cache_root'));
    $this_app->{OLD_CFG} = $cm->getLockedConfiguration($cred);

    #
    # Call the list of components
    #

    my $status = 0;   # Assume success
    if ( $this_app->{OLD_CFG}->elementExists(COMP_CONFIG_PATH) ) {
        my $comp_config = $this_app->{OLD_CFG}->getElement(COMP_CONFIG_PATH)->getTree();

        foreach my $component (keys(%$comp_config)) {
            $this_app->debug(2, "Adding component $component if it is eligible to run");
            add_component($comp_config,$component);
        }
        $status = launch_ncd();
    } else {
        $status = 1;
        $this_app->status("Path ".COMP_CONFIG_PATH." is not defined: no components to configure");
    }

    # current configuration profile is this one
    $this_app->{OLD_CKSUM} = $this_app->{OLD_CFG}->getElement(CONFIG_ROOT)->getChecksum();
    $this_app->{OLD_CFID}  = $this_app->{OLD_CFG}->getConfigurationId();

    return $status;
}


=item launch_ncd

Launch the 'ncd' program, with the ncd arguments passed
to cdispd, and with the contents of @ICList as the component list.
Not that processing of some signals is delayed during ncm-ncd run.

Returns ncm-ncd exit status if run, else 0 (success) or 1 (ncm-ncd missing).

=cut

sub launch_ncd
{

    my $result = 0;    # Assume success

    my $p = CAF::Process->new([NCD_EXECUTABLE, '--configure'] , log => $this_app );
    if ( defined( $this_app->{ICLIST} ) && scalar(@{$this_app->{ICLIST}}) ) {
        # At this point, ICLIST should contain only components present in the last profile received.
        # The only case where a component may be in the list without being part of the configuration
        # is the following:
        #   - Profile n is deployed succesfully (ncm-ncd returns a success)
        #   - Profile n+1 add a new component X that fails (reference config to compare next profile with remains n)
        #   - Profile n+2 remove component X but the profile comparison occurs between n and n+2 (because
        #     X failed with profile N+1) and thus X removal is not detected.
        # As a result, X remains on the list of component to run. This should be harmless as ncm-ncd will ignore it.
        # This is probably rare enough to avoid complex processing to handle this in ncm-dispd.
        $p->pushargs(@{$this_app->{ICLIST}});
    } else {
        $this_app->info("no components to be run by NCM - ncm-ncd won't be called");
        return (0);
    }

    # ncd options
    if ( $this_app->option('state') ) {
        $p->pushargs("--state", $this_app->option('state'));
    }
    if ( $this_app->option('ncd-retries') ) {
        $p->pushargs("--retries", $this_app->option('ncd-retries'));
    }
    if ( $this_app->option('ncd-timeout') ) {
        $p->pushargs("--timeout", $this_app->option('ncd-timeout'));
    }
    if ( $this_app->option('ncd-useprofile') ) {
        $p->pushargs("--useprofile", $this_app->option('ncd-useprofile'));
    }

    if ( $this_app->option('noaction') ) {
        $this_app->info( "would run (noaction mode): $p");
    } else {
        $this_app->info( "about to run: $p");
        if ( $p->is_executable() ) {
            # Delay processing of some signals
            delay_signals();

            # Execute ncm-ncd and report exit status
            my $act = sub {
                my ($logger, $message) = @_;
                $logger->verbose($message);
            };
            my $errormsg = $p->stream_output($act, mode => 'line', arguments => [$this_app]);

            my $ec = $?;
            my $msg = "ncm-ncd finished with status: ". ($ec >> 8) . " (ec $ec";
            my $log_level = 'info';
            if ( $ec ) {
                log_failed_components();
                $log_level = 'warn';
                $msg .= ", some configuration modules failed to run successfully)";
                $result = 1;
            } else {
                $msg .= ", all configuration modules ran successfully)";
            }
            $this_app->$log_level($msg);

            # Process delayed signal if any and reestablish
            # immediate processing of signals
            process_signal();
            immediate_signals();

        } else {
            $this_app->error("Command ". ${$p->get_command()}[0] . " not found or not executable");
            $result = 1;
        }
    }
    return $result;
}


=item log_failed_components

Scan the ncm-ncd component state directory and for each failed component
(component with an entry in the directory), print a line with the name of the
component and the failure reason.

No return value.

=cut

sub log_failed_components
{

    unless ( $this_app->option('state') ) {
        $this_app->debug(1,"No component state file defined: cannot list failed components");
        return;
    }

    my $comp_state_dir = $this_app->option('state');
    if ( opendir(my $dh, $comp_state_dir) ) {
        my @comps = grep { -f "$comp_state_dir/$_" } readdir($dh);
        $this_app->warn("No failed component found in the component state directory ($comp_state_dir)") if ( @comps == 0 );
        foreach my $component (sort(@comps)) {
            my $fh = CAF::FileReader->new("$comp_state_dir/$component");
            my $comp_msg = "$fh";
            chomp $comp_msg;
            $comp_msg = "(no message)" unless $comp_msg;
            $this_app->warn("Component $component failed with message: $comp_msg");
            $fh->close();
        }
        closedir $dh;
    } else {
        $this_app->error("Failed to open component state directory ($comp_state_dir)");
    }

}

=item main_loop

=cut

sub main_loop
{
    my ($cm, $last_ncd_status, $ref_cid) = @_;

    # Wait for a new profile
    $this_app->debug( 1, "checking for new profiles ..." );
    $this_app->debug( 3, "CID of last profile processed: " . $this_app->{OLD_CFID} );

    while ( $cm->getCurrentCid() == $this_app->{OLD_CFID} ) {
        $this_app->debug(1, "no new profile found, sleep for " . $this_app->option('interval') . " seconds" );
        sleep( $this_app->option('interval') );
    }
    $this_app->info("new profile arrived, examining...");

    # credentials are undefined
    my $cred = 0;

    $this_app->{NEW_CFG}   = $cm->getLockedConfiguration($cred);
    $this_app->{NEW_CKSUM} = $this_app->{NEW_CFG}->getElement(CONFIG_ROOT)->getChecksum();
    $this_app->{NEW_CFID}  = $this_app->{NEW_CFG}->getConfigurationId();
    $this_app->debug( 3, "new profile cid=" . $this_app->{NEW_CFID} );

    # check if the profile is different
    my $ncd_status = 0;
    $this_app->debug( 3, "old profile checksum: " . $this_app->{OLD_CKSUM} );
    $this_app->debug( 3, "new profile checksum: " . $this_app->{NEW_CKSUM} );
    if ( $this_app->{OLD_CFID} ne $this_app->{NEW_CFID} ) {
        $this_app->verbose( "new profile detected: cid=" . $this_app->{NEW_CFID} );
        if (   ( $this_app->{OLD_CKSUM} ne $this_app->{NEW_CKSUM} )
            || ( $last_ncd_status != 0 ) )
        {

            # make a copy of the old ICLIST

            # Log the occurence of this rare issue
            # Once understood, use '$this_app->{ICLIST} || []' in line below
            if (! defined($this_app->{ICLIST})) {
                $this_app->{ICLIST} = [];
                $this_app->info("Undefined ICLIST encountered. ",
                            "Report this to the developers ",
                            "(including the templates under /var/lib/ccm and any logs): ",
                            "old cid $this_app->{OLD_CFID} new cid $this_app->{NEW_CFID}");
            }
            my $old_iclist = [ @{ $this_app->{ICLIST} } ];
            $this_app->debug(2, "Current ICLIST ".join(',', sort @$old_iclist));

            if ( $this_app->{OLD_CKSUM} ne $this_app->{NEW_CKSUM} ) {
                $this_app->info("new (and changed) profile detected");
                # Clear the list of component to run only if last execution of
                # ncm-ncd was successful
                if ($last_ncd_status == 0) {
                    $this_app->debug(2, "Cleaning ICLIST");
                    clean_ICList();
                };
            } else {
                $this_app->info( "new profile identical but re-running ncm-ncd since last execution reported errors");
            }

            # Not really needed when re-running after a previous run error
            # (as ICList is not cleared) but harmless
            compare_profiles();

            # Run ncm-ncd and check status.
            # If ncm-ncd returned an error, do not update the reference configuration to be used
            # next time: this will force any component with errors to run again.
            $ncd_status = launch_ncd();
            $this_app->debug( 1, "launch_ncd() exit status = $ncd_status" );
            unless ($ncd_status) {
                $ref_cid = $this_app->{NEW_CFID};
                $this_app->debug( 1, "ncm-ncd executed successfully: update base configuration to CID $ref_cid");
                $this_app->{OLD_CFG}   = $this_app->{NEW_CFG};
                $this_app->{OLD_CKSUM} = $this_app->{NEW_CKSUM};
                $last_ncd_status       = 0;
            } else {
                $this_app->debug( 1, "ncm-ncd reported errors: base configuration kept at CID $ref_cid");
                $last_ncd_status = $ncd_status;
                # restore the ICLIST
                $this_app->debug(2, "Restoring ICLIST to previous list: ".join(',', sort @$old_iclist));
                $this_app->{ICLIST} = $old_iclist;
            }

        } else {
            $this_app->info( "new profile has same checksum as old one, no NCM run");
        }
    } else {
        $this_app->verbose("no new profile found");
    }

    $this_app->{OLD_CFID} = $this_app->{NEW_CFID};
}


=item main

The main ncm-cdispd code.

=cut

sub main
{
    # ncm-cdispd main()
    # Minimal path
    $ENV{PATH} = "/bin:/sbin:/usr/bin:/usr/sbin";

    umask(022);

    # initialize the CAF::Application
    unless ( $this_app = CDISPD::Application->new( $0, @ARGV ) ) {
        throw_error("cannot start application");
    }

    # Set Exception handler
    ( LC::Exception::Context->new )->error_handler( \&exception_handler );

    # become a daemon if --D
    if ( $this_app->option('quiet') ) {
        $this_app->debug( 1, "quiet option enabled, become a daemon" );
        daemonize();    # become a daemon
    } else {
        $this_app->debug( 1, "no quiet option, do not become a daemon" );
    }

    $this_app->debug( 1, "initializing program" );

    # Configure signal handling
    immediate_signals();

    # list of components to be invoked
    $this_app->debug(2, "Initialising ICLIST");
    clean_ICList();

    my $cm = EDG::WP4::CCM::CacheManager->new( $this_app->option('cache_root') );

    # perform an initial call of all components
    $this_app->info( 'ncm-cdispd version '
                     . $this_app->version()
                     . ' started by '
                     . $this_app->username() . ' at: '
                     . scalar(localtime)
                     . ' pid: '
                     . $$ );
    $this_app->info('Dry run, no changes will be performed (--noaction flag set)')
        if ( $this_app->option('noaction') );

    $this_app->info("initalization of components");
    # $last_ncd_status keeps track of the previous execution of ncm-ncd. It is a
    # usual exit code, with 0=success.
    my $last_ncd_status = init_components();
    $this_app->debug( 1, "Initializing \$last_ncd_status to init_components status ($last_ncd_status)");
    my $ref_cid = $this_app->{OLD_CFID};
    $this_app->debug( 1, "CID of reference configuration set to $ref_cid" );

    # wait for a new configuration profile

    while (1) {
        main_loop($cm, $last_ncd_status, $ref_cid);
    }

}

=pod

=back

=cut

1;
