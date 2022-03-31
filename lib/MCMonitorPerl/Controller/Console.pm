package MCMonitorPerl::Controller::Console;
use Moose;
use namespace::autoclean;
use Data::Dumper;
use URI::http;

use MCMonitorPerl::RCONConnection;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

MCMonitorPerl::Controller::Console - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index : Path Args() {
    
    my ( $self, $c, $server ) = @_;
    
    if ( defined( $server ) and $server ne '' ) {
        $c->log->debug("debug - server defined: $server");
    }
    my $params = $c->request->parameters;
    $c->log->debug("----$params----");
    $c->log->debug(Dumper($params));
    $c->log->debug("----------");
    my $command = $params->{command};
    
    $c->log->debug("debug - in console with server $server");
    
    if ( defined( $command ) and $command ne "" ) {
        $c->log->debug("command provided: " . $params->{command} );
        my $response = $self->process_command( $c, $server, $command );
        $response = $response->raw;
        $response = $self->process_response( $c, $response );
        $c->log->debug($response);
        $c->stash( response => $response );
    }
    
    #TODO: get log entries and put into a log window
    
    $c->stash( server => $c->model( 'DB::Servers' )->search( { servername => $server } ) );

    $c->stash( template => 'template/console/index.tt2' );
}

sub process_command {
    my ( $self, $c, $server, $command) = @_;

    $c->log->debug("debug - in process_command for server $server, command: $command");

    # get server from database so we can get rcon details    
    my $serverdata = $c->model( 'DB::Servers' )->find(
        { servername => $server },
        { }
    );
    if ( !defined( $serverdata ) or $serverdata eq '' ) {
        $c->log->debug("Unable to find '" . $server ."' in the database");
        $c->detach();
    }

    # establish rcon connection to server and submit command
    my $rcon = MCMonitorPerl::RCONConnection->new(
        "rcon-${server}", $serverdata->get_column('ipaddress'), $serverdata->get_column('rconport'), $serverdata->get_column('rconpassword')
    );
    $rcon->connect();
    
    if ( $rcon->isconnected() ) {
        $rcon->exec( $command );
        $c->log->debug($rcon->response());
    }
    return $rcon->response();
}

sub process_response {
    my ( $self, $c, $response ) = @_;

    $c->log->debug("debug - in process_response");
    
    chomp( $response );
    
    #TODO: color stripping or implement colors?

    return $response;
}

=encoding utf8

=head1 AUTHOR

Sean OBrien

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
