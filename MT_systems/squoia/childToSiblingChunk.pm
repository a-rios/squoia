#!/usr/bin/perl

# Configuration: ChildToSiblingFile
# 	child chunks become siblings of head (parent) chunks (to be reordered independently among other chunks)
# Format:
#	1				2
#	childChunkCondition		targetChunkAttrVal
# Example:
# 	subjectOfRelativeClause		comment="oblique relative clause",flat=true
#
#
package squoia::childToSiblingChunk;
use strict;
use utf8;


sub main{
	my $dom = ${$_[0]};
	my %targetAttributes = %{$_[1]};
	my $verbose = $_[2];
	
	print STDERR "#VERBOSE ". (caller(0))[3]."\n" if $verbose;

	foreach my $chunk ( $dom->findnodes('//CHUNK/CHUNK/CHUNK') ) {	# the candidates child chunks must have a grandparent chunk to become sibling of their parent chunk
		my $grandparent = $chunk->parentNode->parentNode;
		foreach my $chunkCond (keys %targetAttributes) {
			#check chunk conditions
			my @chunkConditions = squoia::util::splitConditionsIntoArray($chunkCond);
			my $result = squoia::util::evalConditions(\@chunkConditions,$chunk);
			if ($result) {
				# "move" the CHUNK node to the grandparent CHUNK to become a sibling of the parent CHUNK
				$chunk->unbindNode();
				$grandparent->appendChild($chunk);
				my @attributes = split(/\s*,\s*/,$targetAttributes{$chunkCond});
				foreach my $attrVal (@attributes) {
					my ($newChunkAttr,$newChunkVal) = split("=", $attrVal);
					$newChunkVal =~ s/["]//g;
					print STDERR "setting attribute $newChunkAttr to $newChunkVal\n" if $verbose;
					$chunk->setAttribute($newChunkAttr,$newChunkVal);
				}
			}
		}
	}

	# print new xml to stdout
	#my $docstring = $dom->toString;
	#print STDOUT $docstring if $verbose;
}
1;


