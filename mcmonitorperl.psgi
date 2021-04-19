use strict;
use warnings;

use MCMonitorPerl;

my $app = MCMonitorPerl->apply_default_middlewares(MCMonitorPerl->psgi_app);
$app;

