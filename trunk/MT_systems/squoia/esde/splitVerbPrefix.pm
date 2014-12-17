#!/usr/bin/perl

# Split separable verb prefix from root lemma
# only finite forms (VVFIN) need to be split
# example: lem="an|fangen" pos="VVFIN" => lem="an" pos="PTKVZ" + lem="fangen" pos="VVFIN"
#
# Input: xml output from lexical transder module from Matxin/Apertium (LT)
# Output: same xml, with additional chunk for separable verb prefix if verb is finite or imperative

package squoia::esde::splitVerbPrefix;

use strict;
use utf8;

sub main{
	my $dom = ${$_[0]};
	my $verbose = $_[1];

	print STDERR "#VERBOSE ". (caller(0))[3]."\n" if $verbose;

	my $maxChunkRef = squoia::util::getMaxChunkRef($dom);
	my $xpathexpr = '//CHUNK[@type="VP" or @type="CVP"]/descendant-or-self::NODE[contains(@lem,"|") and (@pos="VVFIN" or @pos="VVIMP" or (@pos="VV" and (@spos="VVFIN" or @spos="VVIMP" ) ))]';
	my @verbPrefNodes = $dom->findnodes($xpathexpr);
	foreach my $node (@verbPrefNodes) {
		my $lemma = $node->getAttribute('lem');
		my ($vpref,$vlem) = split(/\|/,$lemma);
		print STDERR "$lemma:\tverb prefix \"$vpref\" split from verb base \"$vlem\"\n" if $verbose;
		# replace complete verb lemma with root lemma only 
		$node->setAttribute('lem',$vlem);
		# create a new chunk (with embedded node) for separable verb prefix
		my $vprefChunk = XML::LibXML::Element->new('CHUNK');
		$maxChunkRef++;
		$vprefChunk->setAttribute('ref',"$maxChunkRef");
		$vprefChunk->setAttribute('type','VerbPrefix');
		$vprefChunk->setAttribute('comment','separable verb prefix');
		my $vprefNode = XML::LibXML::Element->new('NODE');
		$vprefNode->setAttribute('lem', $vpref);
		$vprefNode->setAttribute('pos','PTKVZ');
		# add the chunk and node to the tree
		my $parentChunk = squoia::util::getParentChunk($node);
		$parentChunk->addChild($vprefChunk);
		$vprefChunk->addChild($vprefNode);
	}
}

1;
