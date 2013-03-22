#!/usr/bin/perl
						
use utf8;
use strict;
binmode STDIN, ':utf8';
use XML::LibXML;

sub recursiveOrderChunk{
	my $parentChunk = $_[0];

	# put parent and children chunks into a hash with the original reference attribute as key
	my %orderhash;
	my $origRef = $parentChunk->getAttribute('ref');
	$orderhash{$origRef} = $parentChunk;

	my @childrenChunks = $parentChunk->findnodes('child::CHUNK');
	foreach my $childChunk (@childrenChunks) {
		&recursiveOrderChunk($childChunk);
		$origRef = $childChunk->getAttribute('ref');
		$orderhash{$origRef} = $childChunk;
	}
	# sort the hash by key and set new attribute p_ord resp. c_ord
	my $ord = 0;
	foreach my $ref (sort {$a <=> $b} keys %orderhash) {
		my $chunk = $orderhash{$ref};
		if ($chunk->isSameNode($parentChunk)) {
			$chunk->setAttribute('p_ord',$ord);
		}
		else {
			$chunk->setAttribute('c_ord',$ord);
		}
		$ord++;
	}
}


my $parser = XML::LibXML->new("utf8");
my $dom    = XML::LibXML->load_xml( IO => *STDIN );
# get all SENTENCE chunks, iterate over childchunks
foreach my $sentence  ( $dom->getElementsByTagName('SENTENCE'))
{
	#print STDERR $sentence->toString;
	#get all direct child CHUNKS within SENTENCE
	my @sentenceCHUNKS = $sentence->findnodes('child::CHUNK');

	foreach my $chunk (@sentenceCHUNKS)
	{
		&recursiveOrderChunk($chunk);
	}
}

# print new xml to stdout
my $docstring = $dom->toString;
print STDOUT $docstring;



