#!/usr/bin/perl

# Split separable verb prefix from root lemma
# only finite forms (VVFIN) need to be split
# example: lem="an|fangen" pos="VVFIN" => lem="an" pos="PTKVZ" + lem="fangen" pos="VVFIN"
#
# Input: xml output from lexical transder module from Matxin/Apertium (LT)
# Output: same xml, with additional chunk for separable verb prefix if verb is finite

use strict;
use XML::LibXML;
require "util.pl";

my $dom    = XML::LibXML->load_xml(location => "-");

my $maxChunkRef = &getMaxChunkRef($dom);
 
#my $xpathexpr = '//CHUNK[@type="VP" or @type="CVP"]/descendant-or-self::NODE[contains(@lem,"|") and (starts-with(@pos,"VVFIN") or starts-with(@pos,"VVPP"))]';
my $xpathexpr = '//CHUNK[@type="VP" or @type="CVP"]/descendant-or-self::NODE[contains(@lem,"|") and @pos="VVFIN"]';

my @verbPrefNodes = $dom->findnodes($xpathexpr);
foreach my $node (@verbPrefNodes) {
	my $lemma = $node->getAttribute('lem');
	my ($vpref,$vlem) = split(/\|/,$lemma);
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
	my $parentChunk = &getParentChunk($node);
	$parentChunk->addChild($vprefChunk);
	$vprefChunk->addChild($vprefNode);
}

# print new xml to stdout
my $docstring = $dom->toString(1);
print STDOUT $docstring;

