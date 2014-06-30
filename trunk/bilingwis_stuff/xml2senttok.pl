#!/usr/bin/perl

use strict;
use utf8;
#use open ':utf8';
binmode STDERR, ':utf8';
binmode STDOUT, ':utf8';
#use Storable;
use XML::LibXML;

my $dom    = XML::LibXML->load_xml( IO => *STDIN );

my $num_args = $#ARGV + 1;
if ($num_args > 1) {
  print "\nUsage: perl xml2senttok.pl -simple/-full (only relevant for Quechua, simple or full xml: with simple quechua token=morphemes)\n";
  exit;
  }

my $mode =  $ARGV[0];

foreach my $s ($dom->getElementsByTagName('s') ){
	if($mode eq '-full'){
		foreach my $w  ($s->findnodes('descendant::w')){
			print $w->textContent()." ";
		}
	}
	else{
		foreach my $t  ($s->findnodes('descendant::t')){
			print $t->textContent()." ";
		}
	}
	print "\n";
}