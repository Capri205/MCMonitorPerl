package MCMonitorPerl::RCONConnection;

use strict;
use warnings;

use Data::Dumper;
use Net::RCON::Minecraft;

sub new {
    my ( $class ) = @_;

    my $self = {
        ip => $_[2],
        port => $_[3], 
	    password => $_[4],
	    isconnected => 0,
	    isauthorized => 0,
        status => "",
        response => "",
	    socket => undef
    };

    bless $self, $class;
    return $self;
}

sub connect {
    my ( $self ) = shift;
 
    # establish a socket to the target server
    $self->{socket} = new Net::RCON::Minecraft (
        host => $self->{ip},
        port => $self->{port},
        password => $self->{password},
        Timeout => 2,
    );
    if ( $self->{socket} ) {
        $self->{isconnected} = 1;
        return 1;
    } else {
	    $self->{isconnected} = 0;
        return 0;
    }
}

# disconnect our socket if connected
sub disconnect {
    my ( $self ) = shift;

    if ( $self->{isconnected} ) {
        $self->{socket}->disconnect();
    }
}

sub isconnected {
    my ( $self ) = shift;

    #return $self->{socket}->connected();
    return $self->{isconnected};
}

sub exec {
    my ( $self ) = shift;
    my ( $cmd ) = @_;

    my $response = eval {
        $self->{socket}->command( $cmd );
    };
    if ( $@ ) {
        $self->{status} = $@;
    } else {
        $self->{response}  = $response;
    }
}

sub status {
    my ( $self ) = shift;

    return $self->{status};
}

sub response {
    my ( $self ) =  shift;

    return $self->{response};
}

1;
