#!/usr/bin/perl

use strict;
use warnings;

package Bird;
use Exporter qw/import/;

our @EXPORT_OK = qw//;


#-----------------------------------------------------------------------------
# Bird command module

use IO::Socket::UNIX qw/SOCK_STREAM/;

use constant BIRDC_PATH => '/usr/sbin/birdc';
use constant VALID_SETTINGS => (
	'restrict',
	'socket',
);


sub new {
	my ($class, %args) = @_;

	my $self = {
		'settings'	=> {
			'restrict'	=> 0,
			'socket'	=> undef,
		},
	};

	# Import any /valid/ settings specified in the constructor
	map { $self->{'settings'}->{$_} = $args{$_} if defined($args{$_}) } &VALID_SETTINGS if %args;

	bless($self,$class);
	return $self;
}

sub long_cmd {
	my ($self, $command) = @_;

	my @arguments = ( BIRDC_PATH, '-v' );
	push( @arguments, '-r' ) if( $self->{'settings'}->{'restrict'} );
	push( @arguments, '-s'.$self->{'settings'}->{'socket'} ) if( defined $self->{'settings'}->{'socket'} );
	push( @arguments, $command );

	open( BIRD, "-|", @arguments ) || die "Connection failed: $@";
	my @result = <BIRD>;
	close( BIRD );
	chomp @result;

	# Check the header data
	die "Bad 'hello' received" unless( scalar @result > 0 );
	die "Bad 'hello' received" unless( shift(@result) =~ m/^0001 BIRD 1\.[\d\.]+ ready\.$/ );
	die "Bad 'hello' received" unless( $self->{'settings'}->{'restrict'} && shift(@result) =~ m/^0016 Access restricted$/ );

	return @result;
}

sub cmd {
	my ($self, $command) = @_;
	return pop @{$self->long_cmd($command)};
}


1;

#-----------------------------------------------------------------------------
# POD Documentation

__END__


=head1 NAME

Bird - Library for communicating with the BIRD routing daemon


=head1 DESCRIPTION

Bird provides a simple API to communicate with the BIRD routing daemon.

This module is intended as a drop-in replacement for the Birdctl module available at:
https://github.com/stephank/nagios-bird

Unlike Birdctl, this module uses the commandline tool birdc for interacting with BIRD.


=head1 TODO

Finish writing the POD documentation for this module


=head1 COPYRIGHT AND LICENSE

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.
