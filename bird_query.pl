#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;
use Switch;

use birdctl;

use constant NAGIOS_CODES => {
	'ok'       => { 'retcode' => 0, 'string' => 'OK',       'multi' => 'Up'      },
	'warning'  => { 'retcode' => 1, 'string' => 'WARNING',  'multi' => 'Warning' },
	'critical' => { 'retcode' => 2, 'string' => 'CRITICAL', 'multi' => 'Down'    },
	'unknown'  => { 'retcode' => 3, 'string' => 'UNKNOWN',  'multi' => 'Unknown' },
};


#-----------------------------------------------------------------------------
# Initialisation

use constant BIRD_SOCKET => '/var/run/bird.ctl';
use constant ROUTE_PREFIX => 'R_AS';

my $bird = new birdctl(
  socket => BIRD_SOCKET,
  restrict => 1,
);

# Get any commandline arguments
our( $opt_AS, $opt_showroutes, $opt_perfdata, $opt_nagios );
GetOptions(
	'AS=i',
	'showroutes',
	'perfdata',
	'nagios'
);


#-----------------------------------------------------------------------------
# Grab a list of peers

my $peers = {};
my $query = 'show protocols "'.ROUTE_PREFIX . ($opt_AS||'').'*"';
foreach my $result ( _query($bird,$query) ) {
	$result = _trim($result);
	$result =~ s/^1002-//g;	# dodgy hack to avoid section headers from barfing first peer, todo this right

	next unless( $result =~ m/^(\S*)\s*(\S*)\s*(\S*)\s*(\S*)\s*(\S* \S*)\s*(\S*)/ );
	my ($name,$proto,$table,$state,$since,$info) = ($1,$2,$3,$4,$5,$6);

	# Check this is an AS session we care about
	next unless( $name =~ m/^R_AS(\S+)x1/ );
	my $as_num = $1;	

	$peers->{$as_num} = {
		'as'               => $as_num,
		'session_name'     => $name,
		'table'            => $table,
		'routes'           => {},
		'filtered_routes'  => {},
		'state'		   => $info
	};
}

# Get list of accepted routes
foreach my $as ( keys $peers ) {
	my $peer = $peers->{$as};

	my $query = "show route protocol ".$peer->{'session_name'};
	$peers->{$as}->{'routes'} = extractRoutes( _query($bird,$query) );
}

# Get list of filtered routes
foreach my $as ( keys $peers ) {
	my $peer = $peers->{$as};

	my $query = "show route table ". $peer->{'table'} ." protocol ".$peer->{'session_name'};
	my $routes = extractRoutes( _query($bird,$query) );

	# List this as filtered if it wasnt in the list of accepted routes
	foreach my $route ( keys $routes ) {
		next if( exists $peer->{'routes'}->{$route} );
		$peer->{'filtered_routes'}->{$route} = $routes->{$route};
	}
}

#-----------------------------------------------------------------------------
# Output any peer information we have

my $nagios = {}; map { $nagios->{$_} = 0 } keys NAGIOS_CODES;
foreach my $as ( keys $peers ) {
	my $peer = $peers->{$as};

	if( defined $opt_AS && defined $opt_nagios ) {
		exit nagios_single($peer);
	} elsif( defined $opt_nagios ) {
		my $code = nagios_code($peer);
		$nagios->{$code}++;
	} elsif( defined $opt_perfdata ) {
		print perfdata($peer)."\n";
	} else {
		outputHuman($peer);
	}
}

if( defined $opt_nagios && !defined $opt_AS ) {
	exit nagios_multi( $nagios );
}


#-----------------------------------------------------------------------------
# Output methods

sub nagios_multi {
	my ($results) = @_;

	# What was the highest error code?
	my $nagios_code = 'unknown';
	$nagios_code = 'ok'       if( $results->{'ok'} > 0       );
	$nagios_code = 'warning'  if( $results->{'warning'} > 0  );
	$nagios_code = 'critical' if( $results->{'critical'} > 0 );

	# Generate keyvalue pairs for output
	my @stats = map { join('=',NAGIOS_CODES->{$_}->{'multi'},$results->{$_}) } keys $results;

	# Generate Nagios stdout
	my $retString = nagios_string(
		'SESSIONS',
		$nagios_code,
		join('; ', @stats),
		defined($opt_perfdata) ? join(' ', @stats) : undef
	);

	# Generate output
	print $retString."\n";
	return NAGIOS_CODES->{$nagios_code}->{'retcode'};
}

sub nagios_single {
	my ($peer) = @_;

	my $nagios_code = nagios_code($peer);

	# Generate Nagios stdout
	my $retString = nagios_string(
		'AS'.$peer->{'as'},
		$nagios_code,
		$peer->{'state'},
		defined($opt_perfdata) ? perfdata($peer) : undef
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

sub perfdata {
	my ($peer) = @_;

	my $num_routes = scalar keys $peer->{'routes'};
	my $num_filtered_routes = scalar keys $peer->{'filtered_routes'};
	my $total_routes = $num_routes + $num_filtered_routes;

	return join(' ',
		"as=$peer->{'as'}",
		"state=$peer->{'state'}",
		"route_tot=$total_routes",
		"route_accept=$num_routes",
		"route_filtered=$num_filtered_routes"
	);
}

sub outputHuman {
	my ($peer) = @_;

	my $num_routes = scalar keys $peer->{'routes'};
	my $num_filtered_routes = scalar keys $peer->{'filtered_routes'};
	my $total_routes = $num_routes + $num_filtered_routes;

	print "Autonomous System: $peer->{'as'}\n";
	print "\tSession name: $peer->{'session_name'}\n";
	print "\tSession state: $peer->{'state'}\n";
	print "\tRoute table name: $peer->{'table'}\n";
	print "\tTotal routes: $total_routes\n";
	print "\tAccepted routes: $num_routes\n";
	if( $opt_showroutes ) {
		foreach my $route ( keys $peer->{'routes'} ) {
			print "\t\t$route via $peer->{'routes'}->{$route}\n"
		}
	}
	print "\tFiltered routes: $num_filtered_routes\n";
	if( $opt_showroutes ) {
		foreach my $route ( keys $peer->{'filtered_routes'} ) {
			print "\t\t$route via $peer->{'filtered_routes'}->{$route}\n"
		}
	}
	print "\n"
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

	foreach my $line ( @input ) {
		$line = _trim( $line );
		$line =~ s/^1007-//g;

		next unless $line =~ m/(\S+)\s*via.*\[AS(\d+)i\]$/;
		my ($route,$origin_as) = ($1,$2);

		$routes->{$route} = $origin_as;
	}

	return $routes;
}


#-----------------------------------------------------------------------------
# Utility

sub _query {
	my ($bird,$query) = @_;
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

