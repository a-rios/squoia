#!/usr/bin/perl

package squoia::linearOrderChunk;					
use utf8;
use strict;

sub main{
	my $dom = ${$_[0]};

	foreach my $sentence  ( $dom->getElementsByTagName('SENTENCE'))
	{
		#print STDERR $sentence->toString;
		#get all direct child CHUNKS within SENTENCE
		my @sentenceCHUNKS = $sentence->findnodes('child::CHUNK');
	
		foreach my $chunk (@sentenceCHUNKS)
		{
			#print STDERR "ordered chunks\n";
			my $orderedChunks = &linearOrderChunk($chunk);
			my $index = 0;
			foreach my $chunk (@$orderedChunks) {
				$chunk->setAttribute('ord',$index);
			#	print STDERR "ref:".$chunk->getAttribute('ref')."\tord:".$chunk->getAttribute('ord')."\tc_ord:".$chunk->getAttribute('c_ord')."\tp_ord:".$chunk->getAttribute('p_ord')."\n";
				$index++;
			}
		}
	}
	
	# print new xml to stdout
#	my $docstring = $dom->toString;
#	print STDOUT $docstring;
}

sub linearOrderChunk{
	my $parentChunk = $_[0];

	my @orderedChunks;
	my %orderhash;
	my $ord = $parentChunk->getAttribute('p_ord');
	$orderhash{$ord} = $parentChunk;
	my @childrenChunks = $parentChunk->findnodes('child::CHUNK');
	foreach my $childChunk (@childrenChunks) {
		$ord = $childChunk->getAttribute('c_ord');
		$orderhash{$ord} = $childChunk;
	}
	#print STDERR "ordered chunks under parent chunk with ref:" .$parentChunk->getAttribute('ref')."\n";
	foreach my $ord (sort {$a <=> $b} keys %orderhash) {
		my $chunk = $orderhash{$ord};
		if ($chunk->isSameNode($parentChunk)) {
			# do no call the recursive subroutine again!!!
			# just push the parent chunk into the ordered array
			push(@orderedChunks, $chunk);
		}
		else {
			# recursively call the ordering subroutine on the children of the current child chunk
			my $slice = &linearOrderChunk($chunk);
			push(@orderedChunks, @$slice);
		}
	}
	return \@orderedChunks;
}


1;

