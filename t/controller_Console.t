use strict;
use warnings;
use Test::More;


use Catalyst::Test 'MCMonitorPerl';
use MCMonitorPerl::Controller::Console;

ok( request('/console')->is_success, 'Request should succeed' );
done_testing();
