package MCMonitorPerl::Controller::Manage;
use Moose;
use namespace::autoclean;
use Net::SSH::Perl;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller'; }

=head1 IDENTIFIERS

=cut

my @identityfiles = ( $ENV{HOME} . "/.ssh/id_rsa" );
my %sshparams = (
    protocol => '2,1',
    port => 8105,
    user => 'mcadmin',
    identity_files => \@identityfiles,
    use_pty => 1,
    debug => 1
);

=head1 NAME

MCMonitorPerl::Controller::Manage - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->log->debug("debug - in Manage index");

    $c->stash( serverlist => [ $c->model( 'DB::Servers' )->all ] );

    $c->stash( template => 'template/manage/index.tt2' );
}

=head2 start

=cut

sub start :Path('start') Args(1) {
    my ( $self, $c, $server ) = @_;

    my %p = %{$c->request->params};
    $c->log->debug("------- %p -------");
    $c->log->debug(%p);
    $c->log->debug("------------------");
    $c->log->debug("server: $server");
    $c->log->debug("debug - in Manage start");

    # get server data from database
    my $serverdata = $c->model( 'DB::Servers' )->find(
        { servername => $server },
    );
    if ( !defined( $serverdata ) or $serverdata eq '' ) {
        $c->response->body( $server . " - not found. Please check your server list" );
        return;
    }
    my $host = $serverdata->get_column('hostname');
    $c->log->debug("hostname for $server is $host");

    # get our ssh connection
    my $sshcon = $self->getsshconnection( $c, $host );

    # execute command
    my $cmd = $self->buildcmd( $c, $server, "start" );
    my ( $stdout, $stderr, $rtncode ) = $sshcon->cmd( $cmd );
    if ( $rtncode != 0 ) {
        $c->response->body( "Error exectuing command: $cmd");
        return;
    } else {
        $c->log->debug("stdout: " . $stdout);
        $c->log->debug("stderr: " . $stderr);
        $c->log->debug("rtncode: " . $rtncode);
    }

    # update status in database as starting
    $serverdata->update({
        isup => 3
    });

    # redirect to our monitoring page
    $c->response->redirect( "/" );
}

=head2 stop

=cut

sub stop :Path('stop') Args(1) {
    my ( $self, $c, $server ) = @_;

    my %p = %{$c->request->params};
    $c->log->debug("------- %p -------");
    $c->log->debug(%p);
    $c->log->debug("------------------");
    $c->log->debug("server: $server");
    $c->log->debug("debug - in Manage stop");

    # get server data from database
    my $serverdata = $c->model( 'DB::Servers' )->find(
        { servername => $server },
    );
    if ( !defined( $serverdata ) or $serverdata eq '' ) {
        $c->response->body( $server . " - not found. Please check your server list" );
        return;
    }
    my $host = $serverdata->get_column('hostname');
    $c->log->debug("hostname for $server is $host");

    # get our ssh connection
    my $sshcon = $self->getsshconnection( $c, $host );

    # execute command
    my $cmd = $self->buildcmd( $c, $server, "stop" );
    my ( $stdout, $stderr, $rtncode ) = $sshcon->cmd( $cmd );
    if ( $rtncode != 0 ) {
        $c->response->body( "Error exectuing command: $cmd");
        return;
    } else {
        $c->log->debug("stdout: " . $stdout);
        $c->log->debug("stderr: " . $stderr);
        $c->log->debug("rtncode: " . $rtncode);
    }

    # update status in database as stopping
    $serverdata->update({
        isup => 4
    });

    # redirect to our monitoring page
    $c->response->redirect( "/" );
}

=head2 getsshconnection

=cut

sub getsshconnection {
    my ( $self, $c, $host ) = @_;

    # setup ssh object
    $c->log->debug("Identify file: " . $identityfiles[0]);
    my $sshcon = Net::SSH::Perl->new( $host, %sshparams );
    if ( !defined( $sshcon ) or $sshcon eq '' ) {
        $c->response->body( "Unable to establish SSH connection to $host" );
        return;
    }
    $c->log->debug("SSH connection established to $host");
    # attempt login
    $sshcon->login('mcadmin');

    return $sshcon;
}

=head2 buildcmd

=cut

sub buildcmd {
    my ( $self, $c, $server, $action ) = @_;

    my $rtncmd = "/Minecraft/mcserver.sh\ ";
    if ( $server eq "ob-traincraft" ) {
        $rtncmd = "ob-traincraft" . $rtncmd . $action;
    }
    return $rtncmd;
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
