package MCMonitorPerl::View::HOME;
use Moose;
use namespace::autoclean;

extends 'Catalyst::View::TT';

__PACKAGE__->config(
    TEMPLATE_EXTENSION => '.tt2',
    TIMER => 0,
    render_die => 1
);

=head1 NAME

MCMonitorPerl::View::HOME - TT View for MCMonitorPerl

=head1 DESCRIPTION

TT View for MCMonitorPerl.

=head1 SEE ALSO

L<MCMonitorPerl>

=head1 AUTHOR

sean,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;

