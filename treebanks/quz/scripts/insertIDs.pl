#!/usr/bin/perl

use utf8;                  # Source code is UTF-8
#binmode STDIN, ':utf8';
#binmode STDOUT, ':utf8';
use strict;
use XML::LibXML;

# IMPORTANT: delete xmlns="http://ufal.mff.cuni.cz/pdt/pml/" from pml before applying!!!
#     <s id="s1">
#       <saphi>
#         <nonterminal id="s1_VROOT">
#           <cat>VROOT</cat>
#read xml from STDIN
#my $parser = XML::LibXML->new({encoding => 'utf-8'});
my $dom    = XML::LibXML->load_xml( IO => *STDIN);
my $counter = 1;

foreach my $sentence  ( $dom->getElementsByTagName('s'))
{

	print STDERR "inserting IDs in sentence: $counter\n";
	my $nonterminal = @{$sentence->findnodes('child::saphi/nonterminal')}[0];
	#print $nonterminal;
	$sentence->setAttribute('id', 's'.$counter);
	$nonterminal->setAttribute('id', 's'.$counter."_VROOT");
	
	$counter++;
	

}

my $corpus= @{$dom->getElementsByTagName('quechua_corpus')}[0];
$corpus->setAttribute('xmlns','http://ufal.mff.cuni.cz/pdt/pml/');

# print new xml to stdout
my $docstring = $dom->toString;
#$docstring=~ s/\n\s+\n/\n/g;

print STDOUT $docstring;