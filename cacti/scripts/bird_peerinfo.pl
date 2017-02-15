#!/usr/bin/perl

use strict;
use warnings;

use File::Spec;
use Getopt::Long;


#-----------------------------------------------------------------------------
# Parse the commandline

our( $opt_6, $opt_pre, $opt_path, $opt_host, $opt_index, $opt_query, @opt_get );
GetOptions(
	'6',
	'pre=s',
	'path=s',
	'host=s',
	'index',
	'query=s',
	'get=s{2}' => \@opt_get
);

# If the user has nominated to run a script first
if( defined $opt_pre ) {
	die "Pre-run file does not exist or is not executable" unless( -x $opt_pre );
	system($opt_pre);
	die "Pre-run executable did not run cleanly" unless( ($? >> 8) == 0 );
}

# Generate filename for this datafile
die "No path specified" unless defined $opt_path;
die "No hostname specified" unless defined $opt_host;
my $fname = File::Spec->catfile( $opt_path, $opt_host.($opt_6 ? '_v6' : ''));

# Read in the peer data
my $peer_data = get_host_data($fname);

# Fire the appropriate command
if( defined $opt_index ) {
	cmd_index( $peer_data );
} elsif( defined $opt_query ) {
	cmd_query( $peer_data, $opt_query );
} elsif( scalar @opt_get == 2 ) {
	cmd_get( $peer_data, $opt_get[0], $opt_get[1] );
} else {
	die "Invalid usage";
}


#-----------------------------------------------------------------------------
# Some kind of cheesewhip

sub cmd_index {
	my ($peer_data) = @_;
	foreach my $key ( keys %{$peer_data} ) {
		print $peer_data->{$key}->{'session'}."\n";
	}
}

sub cmd_query {
	my ($peer_data, $type) = @_;

	foreach my $key ( keys %{$peer_data} ) {
		my $peer = $peer_data->{$key};

		my $value = $peer->{$type} || '0';
		print join( '!', $peer->{'session'}, $value )."\n";
	}
}

sub cmd_get {
	my ($peer_data,$type,$session) = @_;
	die "Invalid Session" unless( defined $peer_data->{$session} );

	# Validation
	die "Peer not found" unless defined( $peer_data->{$session} );
	die "Value not found for peer" unless defined( $peer_data->{$session}->{$type} );
	
	# Show the field we want
	print $peer_data->{$session}->{$type};
}

#-----------------------------------------------------------------------------
# Support functions

sub get_host_data {
	my ($file) = @_;
	my $data;

	# Read in data
	open( FH, $file ) or die "Could not open data for reading";
	foreach my $line ( <FH> ) {
		my $peer = {};
		foreach my $token ( split( /\s/, $line ) ) {
			my ($key,$value) = split('=', $token);
			$peer->{$key} = $value;
		}

		die "Peer data missing 'session' property" unless defined $peer->{'session'};
		$data->{$peer->{'session'}} = $peer;
	}
	close( FH );

	return $data;
}
