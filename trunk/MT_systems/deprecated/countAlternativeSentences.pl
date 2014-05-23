#!/usr/bin/perl

# count all alternative sentences after semantic disambiguation
# i.e. the synonyms that have not been explicitly disambiguated could represent true translation alternatives

use utf8;
use open ':utf8';
use XML::LibXML;
use strict;
require "util.pl";

my $dom    = XML::LibXML->load_xml( IO => *STDIN );

my @sentences = $dom->findnodes('//SENTENCE');
my $nofsent = int(@sentences);
print STDERR "$nofsent sentences before duplication\n";

my $totsent;

foreach my $sent (@sentences) {
	my $nofalt = 1;		# number of alternatives for this sentence
	# get all nodes (NODE) of a sentence with ambigous translations (SYN)
	foreach my $node ( $sent->findnodes('descendant::NODE[SYN]')) {
		
		# count the number of alternatives (SYN) for this node
		my $nofsyn = int(@{$node->findnodes('SYN')});

		# combinatorial multiplication of alternatives
		$nofalt = $nofalt * $nofsyn;
	}
	my $sref = $sent->getAttribute('ref');
	print STDERR "$nofalt alternatives for sentence $sref\n";
	$totsent = $totsent + $nofalt;
}

print STDERR "$totsent sentences after duplication\n";

# print new xml to stdout
my $docstring = $dom->toString;
print STDOUT $docstring;
