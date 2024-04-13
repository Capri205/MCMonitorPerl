package MCMonitorPerl::Controller::Root;

use strict;
use warnings;
use Moose;
use namespace::autoclean;
use Data::Dumper;
use JSON;
use LWP::UserAgent;
use Net::Ping;
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
our $MAXSTARTINGSTATECHECKS = 12;
our $MAXSTOPPINGSTATECHECKS = 3;

my $offsetplayertrackeronstart = 'true';


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

}

=head2 index

The root page (/)

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    # check web connection
    if ( !$self->checkwebserverstatus( $c ) ) {
        $c->log->error("Error: Web service not available.");
        $c->detach( 'webdown' );
    }
    $c->log->info("Web service appears to be running.");

    # check the monitoring agent is running
    if ( !$self->checkagentstatus( $c ) ) {
        $c->log->error("Error: Monitoring Agent isn't running.");
        $c->detach( 'agentdown' );
    }
    $c->log->info("Monitoring Agent appears to be running.");

    # load up web page where update js will refresh data via ajax call
    # to getserverupdates subroutine 
    $c->stash( handleupdates => "activate" );
    $c->stash( template => 'template/root/index.tt2' );
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
        $globalstate{ 'playertracker' }{ $servername } = ();
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

=head2 get server updates

=cut

sub getserverupdates :Path( "/getserverstatus" ) Chained( . ) Args( 0 ) {
    my( $self, $c ) = @_;
    
    $c->log->debug("GETSERVERUPDATES");
    
    my $json = JSON::XS->new();
    $json->allow_nonref();

    # check web connection
    if ( !$self->checkwebserverstatus( $c ) ) {
        $c->log->error("Error: Web service not available.");
        my %status = ( 'issue' => 'Web service unavailable! Please check!', 'lastchecked' => gettimestamp() );
        $c->stash( status => \%status );
        return; 
    }
    $c->log->info("Web service appears to be running.");

    # check the monitoring agent is running
    if ( !$self->checkagentstatus( $c ) ) {
        $c->log->error("Error: Monitoring Agent isn't running.");
        $c->detach( 'agentdown' );
        return;
    }
    $c->log->info("Monitoring Agent appears to be running.");

    # get server list from database - state updated by the monitoring agent
    my $serverlist = [ $c->model( 'DB::Servers' )->search(
        { },
        { order_by => 'servername DESC' }
    ) ];

    # reset our sound prompts each check
    $globalstate{ 'sounds' }->{ 'playjoinsound' } = "false";
    $globalstate{ 'sounds' }->{ 'playleavesound' } = "false";
    $globalstate{ 'sounds' }->{ 'playalarmsound' } = "false";

    # get player updates
    my $playerupdates = $self->getplayerupdates( $c );
    $playerupdates =~ s/^\[\"//; $playerupdates =~ s/\"\]$//;
    chomp( $playerupdates );
    my @playerupdates = split( ',', $playerupdates );

    my %serverdata;
    for my $server ( @$serverlist ) {

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

        my $servername = $server->get_column( 'servername');

        # set up a server entry for the server in our state tracker if not there
        $self->setupstateentry( $c, $servername );

        # get raw ping data for server as we need some values from it
        my $pingdata = $json->decode( $server->get_column( 'pingdata' ) );

        # pull in server data from database
        my %data = ();
        $data{ enginetype } = $server->get_column( 'enginetype' );
        $data{ maintenancemode } = $server->get_column( 'maintenancemode' );
        $data{ isup } = $server->get_column( 'isup' );
        $data{ lastchecked } = $server->get_column( 'lastchecked' );
        $data{ lasterror } = $server->get_column( 'lasterror' );
        $data{ state } = $server->get_column( 'state' );
        $data{ numconnections } = $server->get_column( 'numconnections' );

        # process player updates for server - regardless of up or down
        # update looks like this: ServerSwitchEvent#sean_ob#ob-lobby#10/29 18:10:26.1026
        for my $update ( @playerupdates ) {
            
            my @fields = split( '#', $update );
            if ( defined( $fields[2] ) and $fields[2] eq $servername ) {
                if ( $fields[0] eq "ServerSwitchEvent" and $servername ne "BungeeCord" ) {

                    if ( defined( $globalstate{ 'playertracker' }{ $servername } ) and scalar( @{$globalstate{ 'playertracker' }{ $servername }} ) == $MAXPLAYERSTORE ) {
                        pop @{ $globalstate{ 'playertracker' }{ $servername } };
                    }
                    # get timestamp of event or use current if not there
                    my $timestamp = substr( gettimestamp(), 0, 14 );
                    if ( defined( $fields[3] ) and $fields[3] ne '' ) {
                        $timestamp = $fields[3];
                        $timestamp =~ s/\\n//;
                        $timestamp =~ s/\\//;
                        $timestamp = substr( $timestamp, 0, 14 );
                    }
                    unshift @{ $globalstate{ 'playertracker' }{ $servername } }, $timestamp . "#" . $fields[1];
                }
            }
        }

        # more finely process server state for globalstate
        my $lasterror = $server->get_column( 'lasterror' );
        if ( defined( $lasterror ) and $lasterror ne '' ) {

            # process errors
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

            # process success

            # get ping data and other things for the server
            my $numconnections = $server->get_column( 'numconnections' );

            # reset some server and global states, just in case something was down and is now up
            $globalstate{ 'eventtracker' }->{ $servername } = 0;
            $globalstate{ 'lasterror' }->{ $servername } = "";

            # sync our player tracker for up servers
            # needed at startup of monitoring, or when thing's just go awry
            # note: we can't add them in the order they joined
            if ( $numconnections > 0 and scalar( $globalstate{ 'playertracker' }{ $servername } ) == 0 and $servername ne "BungeeCord" ) {
                my $onlineplayers = $pingdata->{ 'players' }{ 'sample' };
                if ( scalar( @$onlineplayers ) > 0 ) {

                    # look through tracker and add any missing players
                    for my $onlineplayer ( @$onlineplayers ) {
                        my $player = $onlineplayer->{ 'name' };
                        my $found = 0;
                        for my $row ( @{ $globalstate{ 'playertracker' }{ $servername } } ) {
                            my @rowparts = split( "#", $row );
                            if ( $rowparts[1] eq $player ) {
                                $found = 1;
                            }
                        }
                        if ( $found == 0 ) {
                            if ( scalar( $globalstate{ 'playertracker' }{ $servername }->keys ) == $MAXPLAYERSTORE ) {
                                pop @{ $globalstate{ 'playertracker' }{ $servername } };
                            }
                            my $timestamp = gettimestamp();
                            unshift @{ $globalstate{ 'playertracker' }{ $servername } }, $timestamp . "#" . $player;
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
                    $server->update( { state => "Running" } );
                } else {
                    $globalstate{ 'statetracker' }->{ $servername } += 1;
                }
            }
            if ( $server->get_column( 'state' ) eq "Stopping" ) {
                if ( $globalstate{ 'statetracker' }->{ $servername } >= $MAXSTOPPINGSTATECHECKS ) {
                    $globalstate{ 'statetracker' }->{ $servername } = 0;
                    $server->update( { state => "Down" } );
                } else {
                    $globalstate{ 'statetracker' }->{ $servername } += 1;
                }
            }
        }

        # manage state - give starting or stopping a few monitoring cycles
        if ( $server->get_column( 'state' ) eq "Starting" ) {
            if ( $globalstate{ 'statetracker' }->{ $servername } >= $MAXSTARTINGSTATECHECKS ) {
                $globalstate{ 'statetracker' }->{ $servername } = 0;
                $server->update( { state => "Running" } );
            } else {
                $globalstate{ 'statetracker' }->{ $servername } += 1;
            }
        }
        if ( $server->get_column( 'state' ) eq "Stopping" ) {
            if ( $globalstate{ 'statetracker' }->{ $servername } >= $MAXSTOPPINGSTATECHECKS ) {
                $globalstate{ 'statetracker' }->{ $servername } = 0;
               $server->update( { state => "Down" } );
            } else {
                $globalstate{ 'statetracker' }->{ $servername } += 1;
            }
        }

        # put server state data into our hash
        $serverdata{ $server->get_column( 'servername') } =  \%data;
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

    # tag on globalstate hash to server state hash - extract in update js
    $serverdata{ globalstate } = \%globalstate;
    my $serverdata_json = $json->encode( \%serverdata );
   
    # return our json to the ajax call from update js
    $c->res->header( 'Cache-Control' => 'no-cache' );
    $c->res->content_type( "application/json" );
    $c->res->body( $serverdata_json );
    $c->detach();
}

=head2 get player updates

=cut

sub getplayerupdates :Private {
    my( $self, $c ) = @_;

    my $ua = LWP::UserAgent->new(
    timeout => 10,
        protocols_allowed => [ 'https' ]
    );

    my $url = 'https://ob-mc.net/serverquery/puquery.php';
    my $req = $ua->post( $url,
        {
            'id' => 'MCMonitor',
            'Content-type' => 'application/json',
            'offset' => $offsetplayertrackeronstart
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

    $offsetplayertrackeronstart = 'false';

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
    my( $self, $c ) = @_;

    my $ua = LWP::UserAgent->new(
    timeout => 10,
        protocols_allowed => [ 'https' ]
    );

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
        if ( defined( $p->{ cmndline } ) and
             ( $p->{ cmndline } =~ /MCMonitorAgent.sh/ or $p->{ cmndline } =~ /MCMonitorAgent.pl/ ) ) {
            $status++;
        }
        if ( defined( $p->{ cmdline } ) and ( grep $_ =~ /MCMonitorAgent.sh/, $p->{ cmdline } or grep $_ =~ /MCMonitorAgent.pl/
, $p->{ cmdline } ) ) {
            $status++;
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
