#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;
use Net::IP;
use Template;

use Term::UI;
use Term::ReadLine;

use constant TEMPLATE_FILE => 'config_template.tt';


#-----------------------------------------------------------------------------
# Read in commandline options

our( $opt_template );
GetOptions( 'template=s' );

# See if a template was specified
$opt_template = $opt_template || TEMPLATE_FILE;
die "Template does not exist or is not readable" unless( -e $opt_template && -R $opt_template );


#-----------------------------------------------------------------------------
# Get input from the user

my $term = Term::ReadLine->new('brand');
my $args = {
	'as_path' => [],
	'allowed_prefixes' => []
};

$args->{'peer_name'} = $term->get_reply(
	'prompt' => 'Peer Name: ',
	'allow'  => \&validate_nestring
);

$args->{'peer_asn'} = $term->get_reply(
	'prompt' => 'ASN: ',
	'allow'  => \&validate_numeric
);

$args->{'peer_ip'} = $term->get_reply(
	'prompt' => 'IP: ',
	'allow'  => \&validate_ip
);

$args->{'ixp_template'} = $term->get_reply(
	'prompt' => 'IXP Template Name: ',
	'allow'  => \&validate_nestring,
	'default' => 'WAIX'
);


while( 1 ) {
	my $next_as = $term->get_reply(
		'prompt' => 'Next AS in Path (or enter to finish): ',
		'allow'  => \&validate_numericornull
	);
	last if( !defined( $next_as ) );
	push( @{$args->{'as_path'}}, $next_as );
}

$args->{'filter_prefixes'} = $term->ask_yn(
	'prompt'  => 'Filter prefixes?',
	'default' => 'n'
);
if( $args->{'filter_prefixes'} ) {
	while( 1 ) {
		my $prefix = $term->get_reply(
			'prompt' => 'Allow prefix (or enter to finish): ',
			'allow'  => \&validate_prefixornull
		);
		last unless( defined $prefix );

		push( @{$args->{'allowed_prefixes'}}, $prefix );
	}
}

print "\n\n";


#-----------------------------------------------------------------------------
# Generate and output the configuration fragment

my $tt = Template->new( RELATIVE => 1, ABSOLUTE => 1 );
$tt->process($opt_template, $args ) || die $tt->error();


#-----------------------------------------------------------------------------
# Support methods

sub validate_nestring {
	my ($input) = @_;
	return (defined $input && $input =~ /^[\w\-]+$/);
}

sub validate_numeric {
	my ($input) = @_;
	return (defined $input && $input =~ /^\d+$/);
}

sub validate_numericornull {
	my ($input) = @_;
	return (!defined $input || $input =~ /^\d+$/);
}

sub validate_prefixornull {
	my ($input) = @_;
	return 1;
}

sub validate_ip {
	my ($input) = @_;
	my $ip = new Net::IP($input) || return 0;
	return 1;
}
