package MCMonitorPerl::Model::DB;

use strict;
use base 'Catalyst::Model::DBIC::Schema';

__PACKAGE__->config(
    schema_class => 'MCMonitorPerl::Schema::MCMonitorDB',
    
    connect_info => {
        dsn => 'dbi:SQLite:/home/mcmonitor/MCMonitorPerl/root/db/mcmonitor.db',
        user => '',
        password => '',
        on_connect_do => q{PRAGMA foreign_keys = ON},
    }
);

=head1 NAME

MCMonitorPerl::Model::DB - Catalyst DBIC Schema Model

=head1 SYNOPSIS

See L<MCMonitorPerl>

=head1 DESCRIPTION

L<Catalyst::Model::DBIC::Schema> Model using schema L<MCMonitorPerl::Schema::MCMonitorDB>

=head1 GENERATED BY

Catalyst::Helper::Model::DBIC::Schema - 0.65

=head1 AUTHOR

Sean OBrien

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
