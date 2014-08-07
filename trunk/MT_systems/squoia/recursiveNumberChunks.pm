#!/usr/bin/perl

package squoia::recursiveNumberChunks;			
use utf8;
use strict;
#binmode STDIN, ':utf8';

sub main{
	my $dom = ${$_[0]};
	my $verbose = $_[1];

	print STDERR "#VERBOSE ". (caller(0))[3]."\n" if $verbose;

	# get all SENTENCE chunks, iterate over childchunks
	foreach my $sentence  ( $dom->getElementsByTagName('SENTENCE'))
	{
		#print STDERR $sentence->toString if $verbose;
		#get all direct child CHUNKS within SENTENCE
		my @sentenceCHUNKS = $sentence->findnodes('child::CHUNK');
	
		foreach my $chunk (@sentenceCHUNKS)
		{
			&recursiveOrderChunk($chunk);
		}
	}
	
	# print new xml to stdout
	#my $docstring = $dom->toString;
	#print STDOUT $docstring;
}

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

1;


