#!/usr/bin/perl

use utf8;                  # Source code is UTF-8
#binmode STDIN, ':utf8';
#binmode STDOUT, ':utf8';
use strict;
use XML::LibXML;


#     <s id="s1">
#       <saphi>
#         <nonterminal id="s1_VROOT">
#           <cat>VROOT</cat>
#read xml from STDIN
#my $parser = XML::LibXML->new({encoding => 'utf-8'});
my $dom    = XML::LibXML->load_xml( IO => *STDIN);
$dom->documentElement()->setAttribute( 'xmlns' , '' );
my $counter = 1;


foreach my $sentence  ( $dom->getElementsByTagName('s'))
{
	print STDERR "inserting IDs in sentence: $counter\n";
	#print STDERR $sentence->toString."\n";
	my $nonterminal = @{$sentence->findnodes('child::saphi/nonterminal')}[0];
	#print $nonterminal;
	$sentence->setAttribute('id', 's'.$counter);
	$nonterminal->setAttribute('id', 's'.$counter."_VROOT");

	# insert Ids of terminal nodes
	# note: ord attribute might not be reliable, sort nodes and set ord and id accordingly
	my @terminals = $sentence->findnodes('descendant::terminal');
	my @terminals_sorted = sort { $a->findvalue('child::order') <=> $b->findvalue('child::order') } @terminals ;
	my $wcount = 1;
	foreach my $terminal (@terminals_sorted)
	{
	    my $ord = @{$terminal->findnodes('child::order') }[0];
	    #print $terminal->findvalue('child::order/text')."\n";
	    # print "\t$ord\n";
	    my $id = "s".$counter."_".$wcount;
	    #  print $id."\n";
	    $terminal->setAttribute('id', $id);
	    $ord->removeChildNodes();
	    $ord->appendText($wcount);
	    $wcount++;
	}
	
    	$counter++;
}


$dom->documentElement()->setAttribute('xmlns: ','http://ufal.mff.cuni.cz/pdt/pml/');

# print new xml to stdout
my $docstring = $dom->toString;
#$docstring=~ s/\n\s+\n/\n/g;

print STDOUT $docstring;
