package MCMonitorPerl::Controller::Servers;

use strict;
use warnings;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

MCMonitorPerl::Controller::Servers - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index : Path('/servers') Args(0) {
    my ( $self, $c ) = @_;

    $c->stash( serverlist => [ $c->model( 'DB::Servers' )->all ] );

    $c->stash( template => 'template/servers/index.tt2' );
}

=head2 create new server configuration

=cut

sub create :Path('create') Args(0) {
    my ( $self, $c ) = @_;

    my %p = %{$c->request->params};
    $c->log->debug("------- %p -------");
    $c->log->debug(%p);
    $c->log->debug("------------------");

    if ( defined( $p{servername} ) ) {
        my $server = $c->model( 'DB::Servers' )->create(
            {
                servername => $p{servername},
                description => $p{description},
                enginetype => $p{enginetype},
                engineversion => $p{engineversion},
                serverversion => $p{serverversion},
                hostname => $p{hostname},
                ipaddress => $p{ipaddress},
                port => $p{port},
                maintenancemode => $p{maintenancemode}
            }
        );
        $c->response->redirect( $c->uri_for( $self->action_for( 'servers' ) ) );
    }

    $c->stash( template => 'template/servers/create.tt2' );
}

sub edit :Path('edit') Args(1) {
    my ( $self, $c, $servername ) = @_;

    my %p = %{$c->request->params};
    $c->log->debug("------- %p -------");
    $c->log->debug(%p);
    $c->log->debug("------------------");

    # retrieve server
    my $server = $c->model( 'DB::Servers' )->find(
        {
            servername => $servername
        }
    );

    # process updates to server details, or display edit screen for server
    if ( scalar( %p ) > 0 ) {

        # adjust readable values (Yes, No, True False etc) to 1's & 0's for db
        $p{maintenancemode} = $self->translateState( $c, $p{maintenancemode} );

        # look for changed fields and update database row if they have
        if ( $server->get_column('servername') ne $p{servername} ||
             $server->get_column('description') ne $p{description} ||
             $server->get_column('enginetype') ne $p{enginetype} ||
             $server->get_column('engineversion') ne $p{engineversion} ||
             $server->get_column('serverversion') ne $p{serverversion} ||
             $server->get_column('hostname') ne $p{hostname} ||
             $server->get_column('ipaddress') ne $p{ipaddress} ||
             $server->get_column('port') ne $p{port} ||
             $server->get_column('maintenancemode') ne $p{maintenancemode} ) {

            $server->update(
                {
                    servername => $p{servername},
                    description => $p{description},
                    enginetype => $p{enginetype},
                    engineversion => $p{engineversion},
                    serverversion => $p{serverversion},
                    hostname => $p{hostname},
                    ipaddress => $p{ipaddress},
                    port => $p{port},
                    maintenancemode => $p{maintenancemode},
                }
            );
        }
        $c->response->redirect( $c->uri_for( $self->action_for( 'servers' ) ) );

    } else {

        $c->stash( server => $server );
        $c->stash( template => 'template/servers/edit.tt2' );
    }
}

sub details :Path('details') Args(1) {
    my ( $self, $c, $servername ) = @_;

    my %p = %{$c->request->params};
    $c->log->debug("------- %p -------");
    $c->log->debug(%p);
    $c->log->debug("------------------");

    # retrieve server
    my $server = $c->model( 'DB::Servers' )->find(
        {
            servername => $servername
        }
    );

    $c->stash( server => $server );

    $c->stash( template => 'template/servers/details.tt2' );
}

sub delete :Path('delete') Args(1) {
    my ( $self, $c, $servername ) = @_;

    my %p = %{$c->request->params};
    $c->log->debug("------- %p -------");
    $c->log->debug(%p);
    $c->log->debug("------------------");

    # retrieve server
    my $server = $c->model( 'DB::Servers' )->find(
        {
            servername => $servername
        }
    );

    if ( scalar( %p ) > 0 ) {

	$server->delete();

        $c->response->redirect( $c->uri_for( $self->action_for( 'servers' ) ) );

    } else {
        $c->stash( server => $server );

        $c->stash( template => 'template/servers/delete.tt2' );
    }
}

sub translateState :Private {
    my( $self, $c, $state ) = @_;

    if ( $state eq "True" || $state eq "Yes" ) {
        return "1";
    }
    return "0";
}

=encoding utf8

=head1 AUTHOR

sean,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
