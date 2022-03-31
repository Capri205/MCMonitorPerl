use utf8;
package MCMonitorPerl::Schema::MCMonitorDB::Result::Servers;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

MCMonitorPerl::Schema::MCMonitorDB::Result::Servers

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 TABLE: C<servers>

=cut

__PACKAGE__->table("servers");

=head1 ACCESSORS

=head2 servername

  data_type: 'text'
  is_nullable: 0

=head2 description

  data_type: 'text'
  is_nullable: 1

=head2 enginetype

  data_type: 'text'
  is_nullable: 1

=head2 engineversion

  data_type: 'text'
  is_nullable: 1

=head2 serverversion

  data_type: 'text'
  is_nullable: 1

=head2 hostname

  data_type: 'text'
  is_nullable: 0

=head2 ipaddress

  data_type: 'text'
  is_nullable: 0

=head2 port

  data_type: 'integer'
  is_nullable: 0

=head2 maintenancemode

  data_type: 'integer'
  is_nullable: 1

=head2 isup

  data_type: 'integer'
  is_nullable: 1

=head2 numconnections

  data_type: 'integer'
  is_nullable: 1

=head2 lastchecked

  data_type: 'text'
  is_nullable: 1

=head2 state

  data_type: 'text'
  is_nullable: 1

=head2 rconport

  data_type: 'integer'
  is_nullable: 1

=head2 rconpassword

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "servername",
  { data_type => "text", is_nullable => 0 },
  "description",
  { data_type => "text", is_nullable => 1 },
  "enginetype",
  { data_type => "text", is_nullable => 1 },
  "engineversion",
  { data_type => "text", is_nullable => 1 },
  "serverversion",
  { data_type => "text", is_nullable => 1 },
  "hostname",
  { data_type => "text", is_nullable => 0 },
  "ipaddress",
  { data_type => "text", is_nullable => 0 },
  "port",
  { data_type => "integer", is_nullable => 0 },
  "maintenancemode",
  { data_type => "integer", is_nullable => 1 },
  "isup",
  { data_type => "integer", is_nullable => 1 },
  "numconnections",
  { data_type => "integer", is_nullable => 1 },
  "lastchecked",
  { data_type => "text", is_nullable => 1 },
  "state",
  { data_type => "text", is_nullable => 1 },
  "rconport",
  { data_type => "integer", is_nullable => 1 },
  "rconpassword",
  { data_type => "text", is_nullable => 1 }
);

=head1 PRIMARY KEY

=over 4

=item * L</servername>

=back

=cut

__PACKAGE__->set_primary_key("servername");


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2021-04-08 22:04:27
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:gtmM5B+0jFixJ8SRLb6mFw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
