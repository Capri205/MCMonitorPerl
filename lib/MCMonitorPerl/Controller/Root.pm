package MCMonitorPerl::Controller::Root;

use strict;
use warnings;
use Moose;
use namespace::autoclean;
use Data::Dumper;
use JSON;
use LWP::UserAgent;
use Net::Ping;
use Hash::Ordered;
use Time::HiRes qw( usleep gettimeofday );
use POSIX qw( strftime );
use MCMonitorPerl::SocketConnection;
use Proc::ProcessTable;


# setup a global state tracker and some global limits
our %globalstate = (
    'sounds' => {
        'playjoinsound' => "false",
        'playleavesound' => "false",
        'playalarmsound' => "false"
    },
    'playertracker' => {},
    'eventtracker' => {},
    'jointrackerconcount' => {},
    'jointrackerdirection' => {},
    'statetracker' => {},
    'lasterror' => {}
);
our $MAXCHECKSB4ALARM = 3;
our $MAXPLAYERSTORE = 5;
our $MAXSTARTINGSTATECHECKS = 3;
our $MAXSTOPPINGSTATECHECKS = 1;


BEGIN { extends 'Catalyst::Controller' }

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config(namespace => '');

=encoding utf-8

=head1 NAME

MCMonitorPerl::Controller::Root - Root Controller for MCMonitorPerl

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=head2 index

The root page (/)

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    # setup web connection
    my $ua = LWP::UserAgent->new(
        timeout => 10,
        protocols_allowed => [ 'https' ]
    );

    # check our web server is up and redirect to an error page if not
    if ( !$self->checkwebserverstatus( $c, $ua ) ) {
        $c->log->error("Error: Web service not available.");
        $c->detach( 'webdown' );
    }

    # check the monitoring agent is running
    if ( !$self->checkagentstatus( $c ) ) {
        $c->log->error("Error: Monitoring Agent isn't running.");
        $c->detach( 'agentdown' );
    }
    $c->log->info("Monitoring Agent appears to be running.");

    # reset our sound prompts each check
    $globalstate{ 'sounds' }->{ 'playjoinsound' } = "false";
    $globalstate{ 'sounds' }->{ 'playleavesound' } = "false";
    $globalstate{ 'sounds' }->{ 'playalarmsound' } = "false";

    # get server list from database
    my $serverlist = [ $c->model( 'DB::Servers' )->search(
        { },
        { order_by => 'servername DESC' }
    ) ];

    # get player updates
    my $playerupdates = $self->getplayerupdates( $c, $ua );
    $c->log->debug("debug - playerupdates1: $playerupdates");
    $playerupdates =~ s/^\[\"//; $playerupdates =~ s/\"\]$//;
    $c->log->debug("debug - playerupdates2: $playerupdates");
    chomp( $playerupdates );
    my @playerupdates = split( ',', $playerupdates );
    $c->log->debug("debug - playerupdates3: $playerupdates");

    # loop through our servers setting up state for our view call
    for my $server ( @$serverlist ) {

        my $servername = $server->get_column( 'servername' );

        # set up a server entry in our state tracker if not there
        $self->setupstateentry( $c, $servername );

        # process server state based on whether the agent found the server up or down
        my $lasterror = $server->get_column( 'lasterror' );
        if ( defined( $lasterror ) and $lasterror ne '' ) {

	    # error processing
            if ( $server->get_column( 'state' ) eq "Starting" ) {
                # play the server starting animation for however many monitoring cycles
                $c->log->debug("Server $servername is starting state, but still cannot connect");
                $globalstate{ 'statetracker' }->{ $servername } += 1;
                $c->log->debug("statetracker for $servername is " . $globalstate{ 'statetracker' }->{ $servername } );

            } elsif ( $server->get_column( 'state' ) eq "Stopping" ) {
                # just play the stopping animation for however monitoring cycles
                if ( $globalstate{ 'statetracker' }->{ $servername } >= $MAXSTOPPINGSTATECHECKS ) {
                    $globalstate{ 'statetracker' }->{ $servername } = 0;
                } else {
                    $c->log->debug("Server $servername is stopping state transition");
                    $globalstate{ 'statetracker' }->{ $servername } += 1;
                    $c->log->debug("statetracker for $servername is " . $globalstate{ 'statetracker' }->{ $servername } );
                }
            } else {

                my $lastchecked = $server->get_column( 'lastchecked' );

                $globalstate{ 'statetracker' }->{ $servername } = 0;

                # trigger alarm sound if we've seen this condition for a number of consecutive checks
                if ( $server->get_column( 'maintenancemode' ) eq 0 ) {
                    if ( $globalstate{ 'eventtracker' }->{ $servername } < $MAXCHECKSB4ALARM ) {
                        $globalstate{ 'eventtracker' }->{ $servername } += 1;
                    } else {
                        $globalstate{ 'sounds' }->{ 'playalarmsound' } = "true";
                    }
                }
                # set states so that things dont persist - like blinking text etc
                $globalstate{ 'jointrackerdirection' }->{ $servername } = "NoChange";
            }
            
            $globalstate{ 'lasterror' }->{ $servername } = $lasterror;
            $c->log->debug("State for $servername is " . $server->get_column( 'state' ) . ", reason: " . $lasterror );            
            $c->log->debug("statetracker for $servername is " . $globalstate{ 'statetracker' }->{ $servername } );

        } else {

	    # success processing


            # get ping data and other things for the server
            my $numconnections = $server->get_column( 'numconnections' );
            my $pingdata = decode_json( $server->get_column( 'pingdata' ) );

            # reset some server and global states, just in case something was down and is now up
	    $globalstate{ 'eventtracker' }->{ $servername } = 0;
	    $globalstate{ 'lasterror' }->{ $servername } = "";

            # 
            #  MINECRAFT
            # 
            #  {"description": {"text":""},
            #   "players":{"max":10,"online":1,"sample":[{"id":"145d43e8-cc3e-433e-baa4-81e711c6880a","name":"botch"}]},
            #   "version":{"name":"Spigot 1.15.2","protocol":578},"favicon":"data:image/png;base64,..."}
    
            #  {"description":"",
            #   "players":{"max":10,"online":0},
            #   "version":{"name":"1.7.10","protocol":5},
            #   "modinfo":{"type":"FML",
            #              "modList":[{"modid":"mcp","version":"9.05"},
            #                         {"modid":"FML","version":"7.10.99.99"},
            #                         {"modid":"Forge","version":"10.13.4.1614"},
            #                         {"modid":"kimagine","version":"0.2"},
            #                         {"modid":"obmetaproducer","version":"0.1"},
            #                         {"modid":"OreSpawn","version":"1.7.10.20.2"},
            #                         {"modid":"worldedit","version":"6.1.1"}
            #                        ]
            #             }
            #  }

            # process player updates for server
            # update looks like this: ServerSwitchEvent#sean_ob#ob-lobby#10/29 18:10:26.1026
            for my $update ( @playerupdates ) {
                my @fields = split( '#', $update );
                if ( defined( $fields[2] ) and $fields[2] eq $servername ) {
                    if ( $fields[0] eq "ServerSwitchEvent" && $servername ne "BungeeCord" ) {
                        if ( scalar( $globalstate{ 'playertracker' }{ $servername }->keys ) == $MAXPLAYERSTORE ) {
                            $globalstate{ 'playertracker' }{ $servername }->pop;
                        }
                        # get timestamp of event or use current if not there
                        my $timestamp = gettimestamp();
                        if ( defined( $fields[3] ) and $fields[3] ne '' ) {
                            # clean up the timestamp we got from the web call
			    #
			    #   06\/29 09:04:50.450\n
                            #   06/29 09:04:5
			    #
			    #   06\/29 08:57:29.5729\n
                            #   06/29 08:57:29
			    $c->log->debug("debug - pre fix timestamp: " . $fields[3]);
                            $fields[3] =~ s/\\n//;
                            $fields[3] =~ s/\\//;
                            $timestamp = substr( $fields[3], 0, length( $fields[3] ) - ( length( $fields[3] ) - 14 ) );
			    $c->log->debug("debug - fix timestamp: $timestamp");
                        }
                        $globalstate{ 'playertracker' }{ $servername }->unshift( $timestamp => $fields[1] );
                    }
                }
            }

            # sync our player tracker - needed at startup of monitoring, or when thing's just go awry
            # note: we can't add them in the order they joined
            if ( $numconnections > 0 && scalar( $globalstate{ 'playertracker' }{ $servername }->keys ) == 0 && $servername ne "BungeeCord" ) {
                my $onlineplayers = $pingdata->{ 'players' }{ 'sample' };
                if ( scalar( @$onlineplayers ) > 0 ) {

                    # look through tracker and add any missing players
                    for my $onlineplayer ( @$onlineplayers ) {
                        my $player = $onlineplayer->{ 'name' };
                        my $found = 0;
                        my $iter = $globalstate{'playertracker'}{$servername}->iterator;
                        while( ( my $k, my $v ) = $iter->() ) {
                            if ( $v eq $player ) {
                                $found = 1;
                            }
                        }
                        if ( $found == 0 ) {
                            if ( scalar( $globalstate{ 'playertracker' }{ $servername }->keys ) == $MAXPLAYERSTORE ) {
                                $globalstate{ 'playertracker' }{ $servername }->pop;
                            }
                            my $timestamp = gettimestamp();
                            $globalstate{ 'playertracker' }{ $servername }->unshift( $timestamp => $player );
                        }
                    }
                }
            }

            # check number of connections and set state accordingly
            my $playercountchange = $self->checkplayercountchange( $c, $servername, $numconnections );

            # manage state - give starting or stopping a few monitoring cycles
            if ( $server->get_column( 'state' ) eq "Starting" ) {
                if ( $globalstate{ 'statetracker' }->{ $servername } >= $MAXSTARTINGSTATECHECKS ) {
                    $globalstate{ 'statetracker' }->{ $servername } = 0;
                    $server->update(
                        {
                            state => "Running"
                        }
                    );
                } else {
                    $globalstate{ 'statetracker' }->{ $servername } += 1;
                }
            }
            if ( $server->get_column( 'state' ) eq "Stopping" ) {
                if ( $globalstate{ 'statetracker' }->{ $servername } >= $MAXSTOPPINGSTATECHECKS ) {
                    $globalstate{ 'statetracker' }->{ $servername } = 0;
		    $server->update(
                        {
                            state => "Down"
                        }
                    );
                } else {
                    $globalstate{ 'statetracker' }->{ $servername } += 1;
                }
            }
        }
    }

    # prioritize sounds - can only play one - alarm highest, join next, leave lowest
    if ( $globalstate{ 'sounds' }{ 'playalarmsound' } eq "true" ) {
        $globalstate{ 'sounds' }{ 'playjoinsound' } = "false";
        $globalstate{ 'sounds' }{ 'playleavesound' } = "false";
    } elsif ( $globalstate{ 'sounds' }{ 'playjoinsound' } eq "true" ) {
        $globalstate{ 'sounds' }{ 'playalarmsound' } = "false";
        $globalstate{ 'sounds' }{ 'playleavesound' } = "false";
    } elsif ( $globalstate{ 'sounds' }{ 'playleavesound' } eq "true" ) {
        $globalstate{ 'sounds' }{ 'playalarmsound' } = "false";
        $globalstate{ 'sounds' }{ 'playjoinsound' } = "false";
    }

    # get current servers status

    $c->response->header( 'Cache-Control' => 'no-cache' ); 

    # refresh our data as it has changed
    $serverlist = [ $c->model( 'DB::Servers' )->search(
        { },
        { order_by => 'servername DESC' }
    ) ];

    # load up our template with our data
    $c->stash( 
        serverlist => $serverlist,
        globalstate => \%globalstate,
        template => 'template/root/index.tt2'
    );
}

=head2 default

Standard 404 error page

=cut

sub default :Path {
    my ( $self, $c ) = @_;
    $c->response->body( 'Page not found' );
    $c->response->status(404);
}

=head2 end

Attempt to render a view, if needed.

=cut

sub end : ActionClass('RenderView') {}

=head2 set up state entries for a server

=cut

sub setupstateentry :Private {
    my( $self, $c, $servername ) = @_;

    if ( !defined( $globalstate{ 'playertracker' }{ $servername } ) ) {
        $globalstate{ 'playertracker' }{ $servername } = new Hash::Ordered();
    }
    if ( !defined( $globalstate{ 'eventtracker' }{ $servername } ) ) {
        $globalstate{ 'eventtracker' }{ $servername } = 0;
    }
    if ( !defined( $globalstate{ 'jointrackerconcount' }{ $servername } ) ) {
     $globalstate{ 'jointrackerconcount' }{ $servername } = 0;
    }
    if ( !defined( $globalstate{ 'jointrackerdirection' }{ $servername } ) ) {
     $globalstate{ 'jointrackerdirection' }{ $servername } = 'NoChange';
    }

}

=head2 check if player count changed since last check

=cut

sub checkplayercountchange :Private {
    my( $self, $c, $servername, $numcons ) = @_;

    my $countchanged = 0;
    if ( defined( $globalstate{ 'jointrackerdirection' }{ $servername } ) ) {
        $globalstate{ 'jointrackerdirection' }{ $servername } = "NoChange";
    }

    # record changed connection count and the direction of the change, or
    # create a new tracker entry (eg. server or monitoring just started)
    if ( defined( $globalstate{ 'jointrackerconcount' }{ $servername } ) ) {

        if ( $numcons > $globalstate{ 'jointrackerconcount' }{ $servername } ) {
            $countchanged = 1;
            $globalstate{ 'jointrackerdirection' }{ $servername } = "Up";
            $globalstate{ 'sounds' }->{ 'playjoinsound' } = "true";
        } elsif ( $numcons < $globalstate{ 'jointrackerconcount' }{ $servername } ) {
            $countchanged = 1;
            $globalstate{ 'jointrackerdirection' }{ $servername } = "Down";
            $globalstate{ 'sounds' }->{ 'playleavesound' } = "true";
        }
        $globalstate{ 'jointrackerconcount' }{ $servername } = $numcons;

    } else {
       
        $self->setupstateentry( $c, $servername );
        $globalstate{ 'jointrackerconcount' }{ $servername } = $numcons;
        if ( $numcons > 0 ) {
            $countchanged = 1;
            $globalstate{ 'jointrackerdirection' }{ $servername } = "Up";
        }
    }

    return $countchanged;
}

=head2 get player updates

=cut

sub getplayerupdates :Private {
    my( $self, $c, $ua ) = @_;

    my $url = 'https://ob-mc.net/serverquery/puquery.php';
    my $req = $ua->post( $url,
        {
            'id' => 'MCMonitor',
            'Content-type' => 'application/json'
        }
    );
    my $response = $req->decoded_content();

    if ( $response eq "[]" ) {
        $response = "";
    } else {
        $response =~ s/^\[\"//;
        $response =~ s/\\n\"\]//;
        $response =~ s/"//g;
    }

    $c->log->debug("puquery: " . $response);
    return $response;
}

=head2 get current timestamp

=cut

sub gettimestamp {
    my ($sec, $usec) = gettimeofday();
    return my $timestamp = sprintf( "%s.%03d", strftime( "%m/%d %H:%M:%S", localtime $sec ), $usec/10 );
}

=head2 check web server is available

=cut

sub checkwebserverstatus {
    my( $self, $c, $ua ) = @_;

    my $status = 0;
    my $pinger = Net::Ping->new( 'tcp' );
    $pinger->port_number(443);
    foreach my $line ( $pinger->ping('ob-mc.net') ) {
        if ( $line =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ ) {
            $c->log->info("Web server address reported as " . $line );
        } elsif ( $line =~ /^\d\.\d+$/ ) {
            chomp( $line );
            $c->log->info("Web server ping took " . $line . "ms");
        } elsif ( $line == 0 || $line == 1 ) {
            $c->log->info("Web server ping result was " . $line);
            $status = $line;
        }
    }
    
    return $status;
}

=head2 check monitoring agent is running

=cut

sub checkagentstatus {
    my( $self, $c ) = @_;

    my $status = 0;
    my $t = Proc::ProcessTable->new;
    # look for perl or shell processes of the monitoring agent
    foreach my $p (@{$t->table}) {
    if ( defined( $p->{ cwd } ) and $p->{ cwd } =~ /MCMonitorPerl\/Agent/ ) {
        if ( grep $_ =~ /MCMonitorAgent.sh/, $p->{ cmdline } or grep $_ =~ /MCMonitorAgent.pl/, $p->{ cmdline } ) {
        $status++;
        }
        if ( $p->{ cmndline } =~ /MCMonitorAgent.sh/ or $p->{ cmndline } =~ /MCMonitorAgent.pl/ ) {
            $status++;
        }
    }
    }

    return $status;
    
}

=head2 web service unavailable

=cut

sub webdown :Private {
    my( $self, $c ) = @_;

    my %status = ( 'issue' => 'Web service unavailable! Please check!', 'lastchecked' => gettimestamp() );
    $c->stash( status => \%status, template => 'template/root/webdown.tt2' );
}

=head2 monitoring agent unavailable

=cut

sub agentdown :Private {
    my( $self, $c ) = @_;

    my %status = ( 'issue' => 'Monitoring agent unavailable! Please check!', 'lastchecked' => gettimestamp() );
    $c->stash( status => \%status, template => 'template/root/agentdown.tt2' );
}

=head1 AUTHOR

sean,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
