#!/usr/bin/perl

use strict;
use warnings;

use Date::Parse;
use DateTime;
use DateTime::Format::Duration;
use Getopt::Long;
use Pod::Usage;
use Switch;

use Bird;

use constant NAGIOS_CODES => {
	'ok'       => { 'retcode' => 0, 'string' => 'OK',       'multi' => 'Up'      },
	'warning'  => { 'retcode' => 1, 'string' => 'WARNING',  'multi' => 'Warning' },
	'critical' => { 'retcode' => 2, 'string' => 'CRITICAL', 'multi' => 'Down'    },
	'unknown'  => { 'retcode' => 3, 'string' => 'UNKNOWN',  'multi' => 'Unknown' },
};


#-----------------------------------------------------------------------------
# Initialisation

use constant BIRD4_SOCKET => '/var/run/bird/bird.ctl';
use constant BIRD6_SOCKET => '/var/run/bird/bird6.ctl';
use constant ROUTE_PREFIX => 'R_AS';
use constant ROUTE_SUFFIX => 'x*';

# Get any commandline arguments
our( $opt_AS, $opt_showroutes, $opt_perfdata, $opt_nagios, $opt_6, $opt_help, $opt_x, $opt_l, $opt_j, $opt_o, $opt_f, $opt_yolo, $opt_debug );
GetOptions(
	'AS=i',
	'showroutes',
	'perfdata',
	'nagios',
	'6',
	'x',
	'l',
	'j', # j is for joe
	'o',
	'f',
	'yolo',
	'debug',
	'help|?'
);
pod2usage(1) if $opt_help;

my $bird = new Bird(
  socket => ( defined $opt_6 ? BIRD6_SOCKET : BIRD4_SOCKET),
  restrict => 1,
);


#-----------------------------------------------------------------------------
# Grab a list of peers

my $now = DateTime->now();

my $peers = {};
my $as_pattern = defined($opt_AS) ? $opt_AS.ROUTE_SUFFIX : '*';
my $query = 'show protocols "'.ROUTE_PREFIX.$as_pattern.'"';
foreach my $result ( _query($bird,$query) ) {
	$result = _trim($result);
	$result =~ s/^1002-//g;	# dodgy hack to avoid section headers from barfing first peer, todo this right

	next unless( $result =~ m/^(\S*)\s*(\S*)\s*(\S*)\s*(\S*)\s*(\S* \S*)\s*(\S*)/ );
	my ($name,$proto,$table,$state,$since,$info) = ($1,$2,$3,$4,$5,$6);

	# Check this is an AS session we care about
	next unless( $name =~ m/^R_AS(\S+)x\d+/ );
	my $as_num = $1;	

	# Calculate session uptime
	my $start = DateTime->from_epoch( epoch => str2time( $since ) );
	my $uptime = $now->subtract_datetime_absolute($start);

	$peers->{$name} = {
		'as'               => $as_num,
		'session_name'     => $name,
		'table'            => $table,
		'routes'           => {},
		'filtered_routes'  => {},
		'state'		   => $info,
		'uptime'           => $uptime
	};
}

# Don't grab prefixes unless needed
unless( $opt_nagios ) {
	# Get list of accepted routes
	foreach my $key ( keys %{$peers} ) {
		my $peer = $peers->{$key};
	
		my $query = "show route table master protocol ".$peer->{'session_name'}." all";
		$peers->{$key}->{'routes'} = extractRoutes( _query($bird,$query) );
	}
	
	# Get list of filtered routes
	foreach my $key ( keys %{$peers} ) {
		my $peer = $peers->{$key};
	
		my $query = "show route protocol ".$peer->{'session_name'};
		my $routes = extractRoutes( _query($bird,$query) );
	
		# List this as filtered if it wasnt in the list of accepted routes
		foreach my $route ( keys %{$routes} ) {
			next if( exists $peer->{'routes'}->{$route} );
			$peer->{'filtered_routes'}->{$route} = $routes->{$route};
		}
	}
}



#-----------------------------------------------------------------------------
# Output any peer information we have

if( defined $opt_o ) {
	outputOriginAs($peers);
} else {
	my $nagios = {}; map { $nagios->{$_} = { 'count' => 0, 'peers' => [] } } keys %{(NAGIOS_CODES)};
	my @optl = ();
	my @optx = ();
	foreach my $key ( keys %{$peers} ) {
		my $peer = $peers->{$key};

		if( defined $opt_f ) {
			next unless( scalar keys %{$peer->{'filtered_routes'}} > 0 );
		}
	
		if( defined $opt_l ) {
			push( @optl, $peer->{'as'} );
		} elsif( defined $opt_x ) {
			next if( defined($opt_AS) && $opt_AS ne $peer->{'as'} );
			push( @optx, outputPrefixes($peer, $opt_j) );
		} elsif( defined $opt_nagios ) {
			next if( defined($opt_AS) && $opt_AS ne $peer->{'as'} );

			my $code = nagios_code($peer);
			$nagios->{$code}->{'count'}++;
			push( @{$nagios->{$code}->{'peers'}}, $peer );
		} elsif( defined $opt_perfdata ) {
			print perfdata($peer)."\n";
		} else {
			outputHuman($peer);
		}
	}

	if( defined $opt_l ) {
		foreach my $as ( _uniq( @optl ) ) {
			print $as."\n";
		}
	} elsif( defined $opt_x ) {
		foreach my $line ( _uniq( @optx ) ) {
			print $line."\n";
		}
	}

	if( defined $opt_perfdata && ! defined $opt_AS ) {
			print globalperfdata()."\n";
	}

	if( defined $opt_nagios ) {
		exit nagios_multi( $nagios );
	}
}


#-----------------------------------------------------------------------------
# Output methods

sub outputOriginAs {
	my ($peers) = @_;

	my $as_list = {};
	foreach my $pKey ( keys %{$peers} ) {
		my $peer = $peers->{$pKey};

		$as_list->{$peer->{'as'}} = 1;

		foreach my $rKey ( keys %{$peer->{'routes'}} ) {
			my $route = $peer->{'routes'}->{$rKey};

			$as_list->{$route->{'origin_as'}} = 1;
		}
	}

	print join("\n", sort keys %{$as_list} )."\n";
}

sub nagios_multi {
	my ($results) = @_;

	# What was the highest error code?
	my $nagios_code = 'unknown';
	$nagios_code = 'ok'       if( $results->{'ok'}->{'count'} > 0       );
	$nagios_code = 'warning'  if( $results->{'warning'}->{'count'} > 0  );
	$nagios_code = 'critical' if( $results->{'critical'}->{'count'} > 0 );

	# Generate keyvalue pairs for output
	my @stats = map { join('=',NAGIOS_CODES->{$_}->{'multi'},$results->{$_}->{'count'}) } keys %{$results};
	my $statString = join('; ', @stats).'.';

	# List any busted AS by category
	foreach my $type ( keys %{$results} ) {
		next if( $type eq 'ok' );
		next unless( scalar @{$results->{$type}->{'peers'}} > 0 );

		my @peers = ();
		foreach my $peer ( @{$results->{$type}->{'peers'}} ) {
			push( @peers, $peer->{'session_name'} );
		}

		$statString .= ' '.NAGIOS_CODES->{$type}->{'multi'}.'('. join(',', @peers).')';
	}

	# Generate Nagios stdout
	my $retString = nagios_string(
		'SESSIONS',
		$nagios_code,
		$statString,
		defined($opt_perfdata) ? join(' ', @stats) : undef
	);

	# Generate output
	print $retString."\n";
	return NAGIOS_CODES->{$nagios_code}->{'retcode'};
}

sub nagios_string {
	my ($service, $code, $status, $perfdata) = @_;

	my $str = join(' ',
		$service,
		NAGIOS_CODES->{$code}->{'string'}.':',
		$status
	);

	if( defined $perfdata ) {
		$str .= ' | '.$perfdata;
	}

	return $str;
}

sub globalperfdata {
	my @all_routes_accept = ();
	my @all_routes_filtered = ();
	
	foreach ( keys %{$peers} ) {
		push( @all_routes_accept, keys %{$peers->{$_}->{'routes'}} );
		push( @all_routes_filtered, keys %{$peers->{$_}->{'filtered_routes'}} );
	}

	my $num_routes = scalar _uniq( @all_routes_accept );
	my $num_filtered_routes = scalar _uniq( @all_routes_filtered );
	my $total_routes = $num_routes + $num_filtered_routes;

	return join(' ',
		"as=ALL",
		"session=ALL",
		"route_tot=$total_routes",
		"route_accept=$num_routes",
		"route_filtered=$num_filtered_routes"
	);
}

sub perfdata {
	my ($peer) = @_;

	my $num_routes = scalar keys %{$peer->{'routes'}};
	my $num_filtered_routes = scalar keys %{$peer->{'filtered_routes'}};
	my $total_routes = $num_routes + $num_filtered_routes;
	my $uptime = $peer->{'uptime'}->in_units('seconds');

	return join(' ',
		"as=$peer->{'as'}",
		"session=$peer->{'session_name'}",
		"state=$peer->{'state'}",
		"route_tot=$total_routes",
		"route_accept=$num_routes",
		"route_filtered=$num_filtered_routes",
		"uptime=$uptime"
	);
}

sub outputHuman {
	my ($peer) = @_;

	my $num_routes = scalar keys %{$peer->{'routes'}};
	my $num_filtered_routes = scalar keys %{$peer->{'filtered_routes'}};
	my $total_routes = $num_routes + $num_filtered_routes;

	print "Autonomous System: $peer->{'as'}\n";
	print "\tSession name: $peer->{'session_name'}\n";
	print "\tSession state: $peer->{'state'}\n";
	print "\tUptime: "._fmtDuration($peer->{'uptime'})."\n";
	print "\tRoute table name: $peer->{'table'}\n";
	print "\tTotal routes: $total_routes\n";
	print "\tAccepted routes: $num_routes\n";
	if( $opt_showroutes && ! $opt_yolo ) {
		foreach my $route ( keys %{$peer->{'routes'}} ) {
			print "\t\t$route via $peer->{'routes'}->{$route}->{'origin_as'}\n"
		}
	}
	print "\tFiltered routes: $num_filtered_routes\n";
	if( $opt_showroutes ) {
		foreach my $route ( keys %{$peer->{'filtered_routes'}} ) {
			print "\t\t$route via $peer->{'filtered_routes'}->{$route}->{'origin_as'}\n"
		}
	}
	print "\n"
}

sub outputPrefixes {
	my ($peer, $opt_j) = @_;

	my @prefixes = ();
	foreach my $route ( keys %{$peer->{'routes'}} ) {
		my $str = $route;

		if( defined $opt_j ) {
			$str .= "\t".($peer->{'routes'}->{$route}->{'path'} || "");
		}

		push(@prefixes, $str);
	}

	return @prefixes;
}

#-----------------------------------------------------------------------------
# Common methods

sub nagios_code {
	my ($peer) = @_;

	my $nagios_code = 'unknown';
	switch( $peer->{'state'} ) {
		case 'Established' { $nagios_code = 'ok'       }
		case 'Active'      { $nagios_code = 'warning'  }
		case 'Connect'     { $nagios_code = 'warning'  }
		case 'Idle'        { $nagios_code = 'warning'  }
		case 'OpenConfirm' { $nagios_code = 'warning'  }
		case 'OpenSent'    { $nagios_code = 'warning'  }
		else               { $nagios_code = 'critical' }
	}

	return $nagios_code;
}

sub extractRoutes {
	my (@input) = @_;
	my $routes = {};

	my $r = undef;
	foreach my $line ( @input ) {
		$line = _trim( $line );
		$line =~ s/^1007-//g;

		if( $line =~ m/(\S+)\s*via.*\[AS(\d+)[i\?]\]$/ ) {
			my ($route,$origin_as) = ($1,$2);
			$r = {
				'route'		=> $route,
				'origin_as'	=> $origin_as,
				'path'		=> undef
			};
			$routes->{$route} = $r;
		} elsif( $line =~ m/BGP.as_path: (.*)$/ ) {
			my ($as_path) = ($1);
			$r->{'path'} = $as_path;
		}
	}

	return $routes;
}


#-----------------------------------------------------------------------------
# Utility

sub _uniq {
        return keys %{{ map { $_ => 1 } @_ }};
}

sub _query {
	my ($bird,$query) = @_;

	if( defined $opt_debug ) {
		print "DEBUG: ".$query."\n";
	}

	my @result = $bird->long_cmd($query);
	chomp @result;
	return @result;
}

sub _trim {
	my ($input) = @_;
	$input =~ s/^\s*//g;	
	$input =~ s/\s*$//g;	
	return $input;
}

sub _fmtDuration {
	my ($duration) = @_;

	my $f = DateTime::Format::Duration->new(
		pattern => '%Yy, %mm, %ed, %kh, %Mm, %Ss',
		normalize => 'ISO'
	);

	return $f->format_duration($duration);
}

#-----------------------------------------------------------------------------
# POD Documentation


__END__

=head1 NAME

query_bird - Script to show peer and prefix information for configured sessions in BIRD

=head1 SYNOPSIS

query_bird.pl [options]

=head1 OPTIONS

=item B<-help>

Print a brief help message and exits.


=item B<-a> AS_NUM

Only query session information for the specified AS Number

=item B<-s>

Show filtered/accepted prefixes, not compatible with -n or -p

=item B<-p>

Output data in perfdata format for graphing

=item B<-n>

Runs as a NAGIOS check, can be combined with -p and -a

=item B<-6>

Query on the socket for IPv6 BIRD

=item B<-x>

Output a list of accepted prefixes, one per line. Not compatible with -s, -n or -p

=item B<-j>

Joe mode, includes the AS Path in the output of -x.

=item B<-l>

Output a list of peered ASNs, one per line. Only compatible with -f.

=item B<-o>

Like -l but includes originating AS systems for which BIRD has accepted one or more prefixes on

=item B<-f>

Only show peers with one or more filtered routes. Compatible with everything except -o

=item B<-y>

Yolo mode. Only compatible with -s, doesn't show accepted prefixes because life's too short.

=item B<-d>

Debug mode. Show the commands being executed against birdc.
