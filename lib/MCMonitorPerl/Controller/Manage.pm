package MCMonitorPerl::Controller::Manage;
use Moose;
use namespace::autoclean;
use Net::OpenSSH;
use Net::OpenSSH::Constants qw( :error );
use Time::HiRes qw( usleep gettimeofday );
use POSIX qw( strftime );
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller'; }

=head1 IDENTIFIERS

=cut

my $identityfile = ( $ENV{HOME} . "/.ssh/id_rsa" );

my %sshparams = (
    port => 8105,
    user => 'mcadmin',
    key_path => $identityfile,
    master_opts => [-o => "StrictHostKeyChecking=no"],
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

    $c->stash( serverlist => [ $c->model( 'DB::Servers' )->all ] );

    $c->stash( handleupdates => "deactivate" );
    $c->stash( template => 'template/manage/index.tt2' );
}

=head2 start

=cut

sub start :Path('start') Args(1) {
    my ( $self, $c, $server ) = @_;

    my %p = %{$c->request->params};

    # get server data from database
    my $serverdata = $c->model( 'DB::Servers' )->find(
        { servername => $server },
    );
    if ( !defined( $serverdata ) or $serverdata eq '' ) {
        $c->response->body( "Something went terribly wrong.<br>" . $server . " - not found. Please check your server list" );
        return;
    }
    my $host = $serverdata->get_column( 'hostname' );

    # get our ssh connection
    my $sshcon = $self->getsshconnection( $c, $host );

    # execute command
    my $cmd = $self->buildcmd( $c, $server, "start" );
    my ( $stdout, $stderr, $rtncode ) = $sshcon->system( $cmd );
    #$c->log->debug("remote command status:");
    #$c->log->debug("stdout: " . $stdout);
    #$c->log->debug("stderr: " . $stderr);
    #$c->log->debug("rtncode: " . $rtncode);
    if ( $rtncode != 0 ) {
        $c->response->body( "Something went terribly wrong.<br>Error executing command: $cmd");
        return;
    }

    # update status in database as starting
    $serverdata->update(
        {
            state => "Starting"
        }
    );

    # redirect to our monitoring page
    $c->response->redirect( "/" );
}

=head2 stop

=cut

sub stop :Path('stop') Args(1) {
    my ( $self, $c, $server ) = @_;

    my %p = %{$c->request->params};

    # get server data from database
    my $serverdata = $c->model( 'DB::Servers' )->find(
        { servername => $server },
    );
    if ( !defined( $serverdata ) or $serverdata eq '' ) {
        $c->response->body( "Something went terribly wrong<br>" . $server . " - not found. Please check your server list" );
        return;
    }
    my $host = $serverdata->get_column( 'hostname' );

    # get our ssh connection
    my $sshcon = $self->getsshconnection( $c, $host );

    # execute command
    my $cmd = $self->buildcmd( $c, $server, "stop" );
    my ( $stdout, $stderr, $rtncode ) = $sshcon->system( $cmd );
    if ( $rtncode != 0 ) {
        $c->response->body( "Something went terribly wrong<br>Error executing command: $cmd");
        return;
    }

    # update status in database as stopping
    $serverdata->update(
        {
            state => "Stopping"
        }
    );

    # redirect to our monitoring page
    $c->response->redirect( "/" );
}

=head2 getsshconnection

=cut

sub getsshconnection {
    my ( $self, $c, $host ) = @_;

    BEGIN {
        $Net::OpenSSH::debug = -1;
#        $Net::OpenSSH::debug_fh = \*STDOUT;
#        $Net::OpenSSH::debug = ~0;
#        $Net::OpenSSH::debug |= 0x7f;
    }
    $c->log->debug("Identify file: " . $identityfile);

    # setup ssh object
    my $sshcon =  Net::OpenSSH->new( $host, %sshparams );
    if ( ( defined( $! ) and $! ne '' ) or ( defined( $sshcon->error ) and $sshcon->error != 0 ) ) {
        $c->log->debug( $! );
        $c->log->debug( $sshcon->error );
#        my $errorstr = "Unable to establish SSH connection to $host<br>" . $! . "<br>" . $sshcon->error;
#        $c->stash( sshfailerror  => $errorstr );
#        $c->detach( 'sshfail' );
    }
    $c->log->debug("SSH connection established to $host");

    return $sshcon;
}

=head2 buildcmd

=cut

sub buildcmd {
    my ( $self, $c, $server, $action ) = @_;

    my $rtncmd = "/mcserver.sh\ ";
    if ( $server eq "ob-traincraft" ) {
        $rtncmd = "ob-traincraft" . $rtncmd . $action;
    } elsif ( $server eq "ob-orespawn" ) {
        $rtncmd = "ob-orespawn" . $rtncmd . $action;
    } elsif ( $server eq "ob-twilight" ) {
        $rtncmd = "ob-twilight" . $rtncmd . $action;
    } elsif ( $server eq "ob-lobby" ) {
        $rtncmd = "ob-lobby" . $rtncmd . $action;
    } elsif ( $server eq "ob-build" ) {
        $rtncmd = "ob-build" . $rtncmd . $action;
    }

    return $rtncmd;
}

=head2 sshfail

=cut

sub sshfail :Private {
    my( $self, $c ) = @_;
    
    my %status = ( 'issue' => $c->stash->{ sshfailerror }, 'lastchecked' => gettimestamp() );
    $c->stash( status => \%status, template => 'template/manage/sshfail.tt2' );

}

=head2 get current timestamp
                         
=cut
                     
sub gettimestamp {
    my ($sec, $usec) = gettimeofday();
    return my $timestamp = sprintf( "%s.%03d", strftime( "%m/%d %H:%M:%S", localtime $sec ), $usec/10 );
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
