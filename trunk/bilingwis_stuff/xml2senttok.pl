#!/usr/bin/perl

use strict;
use utf8;
#use open ':utf8';
binmode STDERR, ':utf8';
#binmode STDOUT, ':utf8';
#use Storable;
use XML::LibXML;

my $num_args = $#ARGV + 1;
if ($num_args > 1 ) {
  print "\nUsage: perl xml2senttok.pl -simple/-full (provide XML on STDIN) \n";
  print "\tonly relevant for Quechua: simple or full xml: with simple quechua token=morphemes\n";
  exit;
  }

my $mode =  $ARGV[0];
my $dom    = XML::LibXML->load_xml( IO => *STDIN );

## make xml for InterText
my $domnew = XML::LibXML->createDocument ('1.0', 'UTF-8');
my $book = $domnew->createElementNS( "", "book" );
$book->setAttribute('id', $dom->documentElement->getAttribute('id'));
$domnew->setDocumentElement( $book );

foreach my $s ($dom->getElementsByTagName('s') ){
	my $sentence = XML::LibXML::Element->new( 's' );
	$sentence->setAttribute('id', $s->getAttribute('Intertext_id'));
	$book->appendChild($sentence);
	if($mode eq '-full'){
		foreach my $w  ($s->findnodes('descendant::w')){
			#print $w->textContent()." ";
			$sentence->appendText($w->textContent()." ");
		}
	}
	else{
		foreach my $t  ($s->findnodes('descendant::t')){
			#print $t->textContent()." ";
			$sentence->appendText($t->textContent()." ");
		}
	}
	#print "\n";
}

my $docstring = $domnew->toString(3);
print STDOUT $docstring;