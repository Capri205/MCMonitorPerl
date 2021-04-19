use strict;
use warnings;
use Test::More;


use Catalyst::Test 'MCMonitorPerl';
use MCMonitorPerl::Controller::Servers;

ok( request('/servers')->is_success, 'Request should succeed' );
done_testing();
