#!/usr/bin/perl

use strict;
use warnings;

use Net::IP;
use Template;

use Term::UI;
use Term::ReadLine;

use constant TEMPLATE_FILE => 'config_template.tt';

#-----------------------------------------------------------------------------
# Get input from the user

my $args = {};
my $term = Term::ReadLine->new('brand');

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

print "\n\n";


#-----------------------------------------------------------------------------
# Generate and output the configuration fragment

my $tt = Template->new();
$tt->process(TEMPLATE_FILE, $args );


#-----------------------------------------------------------------------------
# Support methods

sub validate_nestring {
	my ($input) = @_;
	return (defined $input && $input =~ /^\w+$/);
}

sub validate_numeric {
	my ($input) = @_;
	return (defined $input && $input =~ /^\d+$/);
}

sub validate_ip {
	my ($input) = @_;
	my $ip = new Net::IP($input) || return 0;
	return 1;
}
