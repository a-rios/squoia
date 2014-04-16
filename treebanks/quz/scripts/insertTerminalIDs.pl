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
#my $counter = 1;

foreach my $sentence  ( $dom->getElementsByTagName('s'))
{
	my $count=1;
	my $sID = $sentence->getAttribute('id');
	# print "$sID\n";
	
	my @terminals = $sentence->findnodes('descendant::terminal');
	my @terminals_sorted = sort { $a->findvalue('child::order') <=> $b->findvalue('child::order') } @terminals ;
	#print $sID." ".scalar(@terminals)."\n";
	# print $terminals[0]->findvalue('child::order')."\n";
	
	foreach my $terminal (@terminals_sorted)
	{
	  my $ord = @{$terminal->findnodes('child::order') }[0];
	  #print $terminal->findvalue('child::order/text')."\n";
	  
	 # print "\t$ord\n";
	  my $id = $sID."_".$count;
	#  print $id."\n";
	  $terminal->setAttribute('id', $id);
	  $ord->removeChildNodes();
	  $ord->appendText($count);
	  $count++;
	}
}

my $corpus= @{$dom->getElementsByTagName('quechua_corpus')}[0];
$corpus->setAttribute('xmlns','http://ufal.mff.cuni.cz/pdt/pml/');

# print new xml to stdout
my $docstring = $dom->toString;
#$docstring=~ s/\n\s+\n/\n/g;

print STDOUT $docstring;