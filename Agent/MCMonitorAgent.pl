use strict;
use warnings;
use DBI;
use JSON;
use SocketConnection 'mcping';
use Time::HiRes qw( usleep gettimeofday );
use POSIX qw( strftime );
use Log::Log4perl;
use Data::Dumper;


my $driver = "SQLite";
my $user = "";
my $password = "";
my $database = "/home/mcmonitor/MCMonitorPerl/root/db/mcmonitor.db";
my $dsn = "DBI:$driver:dbname=$database";
my $dbh = DBI->connect( $dsn, $user, $password, { RaiseError => 1 } ) or die $DBI::errstr;
print "Opened mcmonitor database\n";

my $interval = 10;
my $stopmonitoring = 0;

print "Starting monitoring @ " . localtime() . "\n";
my $iteration = 0;
while ( $stopmonitoring == 0 ) {
    
    ++$iteration;
    print $iteration . "\n";

    # get server list from database
    my $serverlist = $dbh->selectcol_arrayref( "select servername from servers", { Columns => [1] } );


    # mc ping each server to determine state, player count etc
    foreach my $servername ( @$serverlist ) {

        my $isup = 0; my $numconnections = 0; my $state = 'Down'; my $lasterror = "";

        print "Checking $servername\n";

        # get server data
        my $sql = "select * from servers where servername = ?";
        my $srv_hdl = $dbh->prepare( $sql );
        $srv_hdl->execute( $servername );
        my $server = $srv_hdl->fetchrow_hashref();
    
        # don't check servers that are in a transition state 
	my $serverstate = $server->{ state };
	print "Server state is " . $serverstate . "\n";
	if ( $serverstate eq "Starting" or $serverstate eq "Stopping" ) {
	    print "Skipping this server\n";
	    next;
        }

        # ping the server to see if it's alive and get some basic ping data back
        my $pingjson; my $pingdata;
        my $serverengine = $server->{ enginetype };
        if ( lc $serverengine eq "spigot" or lc $serverengine eq "fml" or
         lc $serverengine eq "forge" or lc $serverengine eq "paper" ) {
            $pingjson = SocketConnection::mcping( $server->{ ipaddress }, $server->{ port } );
        }
    
        my $lastchecked = substr( gettimestamp(), 1, length( gettimestamp() ) - 7 );
    
        # parse data result from server or socket connection attempt
        my $goterror = 0;
        eval {
            $pingdata = decode_json( $pingjson );
        } or do {
            $goterror = 1;
        };
    
        if ( $goterror ) {
            # parse error - strip out this text to get actual error and post state to database
            $pingjson =~ s/^IO::Socket::INET: connect: //;
	    
	    print "debug - server: $servername, isup: $isup, state: $state\n";
    
            $dbh->do("
                update servers set numconnections=$numconnections, isup=$isup, state='$state',
                                   lasterror='$pingjson', lastchecked = '$lastchecked', pingdata = '{}'
                where servername = '$servername'
            ") or die "Failed to update servers table: " . DBI->errstr;
    
            next;
        }
    
        if ( defined( $pingdata->{ version} ) ) {
            print Dumper( $pingdata->{ version } );
        }
        if ( defined( $pingdata->{ modinfo} ) ) {
            print Dumper( $pingdata->{ modinfo } );
        }
        if ( defined( $pingdata->{ players } ) ) {
            print Dumper( $pingdata->{ players } );
        }

        # parse mc ping data based on engine type
        $isup = 1; $state = 'Running'; $lasterror = ""; 
    
        #
        # MINECRAFT
        #
        # {"description": {"text":""},
        #  "players":{"max":10,"online":1,"sample":[{"id":"145d43e8-cc3e-433e-baa4-81e711c6880a","name":"botch"}]},
        #  "version":{"name":"Spigot 1.15.2","protocol":578},"favicon":"data:image/png;base64,..."}
    
        # {"description":"",
        #  "players":{"max":10,"online":0},
        #  "version":{"name":"1.7.10","protocol":5},
        #  "modinfo":{"type":"FML",
        #             "modList":[{"modid":"mcp","version":"9.05"},
        #                        {"modid":"FML","version":"7.10.99.99"},
        #                        {"modid":"Forge","version":"10.13.4.1614"},
        #                        {"modid":"kimagine","version":"0.2"},
        #                        {"modid":"obmetaproducer","version":"0.1"},
        #                        {"modid":"OreSpawn","version":"1.7.10.20.2"},
        #                        {"modid":"worldedit","version":"6.1.1"}
        #                       ]
        #            }
        # }
    
        # retrieve current number of connections from server
        if ( defined( $pingdata->{ players } ) ) {
            if ( defined( $pingdata->{ players }{ online } ) ) {
                $numconnections = $pingdata->{ players }{ online };
            }
        }

        # check for engine version change
        my $versionupd = "";
        if ( defined( $pingdata->{ 'version' }{ 'name' } ) ) {
            my $versionstring = $pingdata->{ 'version'}{ 'name' };
            my %replacements = ( "thermos" => "", "cauldron" => "", "craftbukkit" => "", "mcpc" => "",
                                 "kcauldron" => "", "forge " => "", "Forge " => "", "Spigot " => "",
                                 "BungeeCord " => "", "spigot " => "", "Paper " => "" );
            $versionstring =~ s/(@{[join "|", keys %replacements]})/$replacements{$1}/g;
            if ( $server->{ engineversion } ne $versionstring ) {
                $versionupd = ", engineversion='$versionstring'";
            }
        }

        $dbh->do("
            update servers set numconnections=$numconnections, isup=$isup, state='$state',
                               lasterror='$lasterror', lastchecked = '$lastchecked', pingdata = '$pingjson'
			       $versionupd
            where servername = '$servername'
        ") or die "Failed to update servers table: " . DBI->errstr;
    }
    
    sleep $interval;
}

$dbh->disconnect();

print "Stopped monitoring @ " . localtime() . "\n";
exit 0;
    
# return a custom format timestamp
sub gettimestamp {
    my ($sec, $usec) = gettimeofday();
    return my $timestamp = sprintf( "%s.%03d", strftime( "%m/%d %H:%M:%S", localtime $sec ), $usec/10 );
}

