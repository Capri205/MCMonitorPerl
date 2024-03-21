package SocketConnection;

use strict;   
use warnings;
use IO::Socket;
use Data::Dumper;

# minecraft ping
sub mcping {
    my ( $ip, $port ) = @_;
    
    my $retdata;
    
    # establish a socket to the target server
    my $socket = new IO::Socket::INET (
        PeerAddr => "$ip",
        PeerPort => "$port",
        Proto => 'tcp',
        Reuse => 1,
        Timeout => 1,
    );
    if ( $socket ) {
#        print "Socket connection established to $ip : $port\n";
        
        # build basic minecraft server ping
        my $senddata = "\x00"; # packet id (varint)
        $senddata .= "\x04"; # protocol version (varint)
        $senddata .= pack( 'c', length( $ip ) ) . $ip; # server (varint len + UTF-8 addr)
        $senddata .= pack( 'n', $port ); # server port (unsigned short)
        $senddata .= "\x01"; # next state: status (varint)
        $senddata = pack( 'c', length( $senddata ) ) . $senddata; # prepend length of packet ID + data
        $senddata .= "\x01\x00";
        $socket->send( $senddata );

        # get back packet length, type and length of data
        my $plength = read_var_int( $socket );
        my $ptype = read_var_int( $socket );
        my $dlength = read_var_int( $socket );
        $retdata = ""; my $datablock = ""; my $remainder = 0;
        while ( length( $retdata ) < $dlength ) {
            $remainder = $dlength - length( $retdata );
            $socket->recv( $datablock, $remainder, $ptype );
            $retdata .= $datablock;
        }
        
        
    } else {
#        print "Failed to make socket connection to $ip : $port\n";
        $retdata = $@;
        $socket = undef;
    }
    
    # close the socket if open
    if ( $socket ) {
        $socket->close();
    }

    return $retdata;
}

# read a series of bytes from socket to decode packet length, packet type, and data length (subsequent calls to this subroutine)
sub read_var_int {
    my ( $socket ) = @_;
    my $i = 0; my $j = 0; my $k = 0;
    while ( 1 ) {
        $socket->recv( $k, 1 );
        if ( !defined( $k ) or $k eq '' ) {
            return 0;
        }
        $k = ord( $k );
        $i |= ( $k & 0x7F ) << $j++ * 7;
        if ( ( $k & 0x80 ) != 128 ) {
            last;
        }
    }
    return $i;
}

1;
