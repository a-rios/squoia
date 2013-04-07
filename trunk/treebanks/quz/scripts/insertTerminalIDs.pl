#!/usr/bin/perl

use utf8;                  # Source code is UTF-8
#binmode STDIN, ':utf8';
#binmode STDOUT, ':utf8';
use strict;
use XML::LibXML;

# IMPORTANT: delete xmlns="http://ufal.mff.cuni.cz/pdt/pml/" from pml before applying!!!
#     <s id="s1">
#       <root>
#         <nonterminal id="s1_VROOT">
#           <cat>VROOT</cat>
#read xml from STDIN
#my $parser = XML::LibXML->new({encoding => 'utf-8'});
my $dom    = XML::LibXML->load_xml( IO => *STDIN);
#my $counter = 1;

foreach my $sentence  ( $dom->getElementsByTagName('s'))
{

	my $sID = $sentence->getAttribute('id');
	my @terminals = $sentence->findnodes('descendant::terminal');
	#print $nonterminal;
	
	foreach my $terminal (@terminals)
	{
	  my $ord = @{$terminal->findnodes('child::order/text()')}[0];
	#  print $ord;
	  my $id = $sID."_".$ord;
	  $terminal->setAttribute('id', $id);
	}
}

my $corpus= @{$dom->getElementsByTagName('corpus')}[0];
$corpus->setAttribute('xmlns','http://ufal.mff.cuni.cz/pdt/pml/');

# print new xml to stdout
my $docstring = $dom->toString;
#$docstring=~ s/\n\s+\n/\n/g;

print STDOUT $docstring;