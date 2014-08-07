#!/usr/bin/perl

# Configuration: NodeChunkFile
# 	nodes to be upgraded to chunks (to be reordered independently among other chunks)
# Format:
#	targetAttributes									sourceChunkAttrVal	targetChunkAttrVal
# Example:
# 	my.pos=/VMFIN/ && parent.pos=VV && chunkparent.type=/VP.*/ && !(chunkparent.si=subj)	nodechunk=finVerb	type=modalV
#
#
# Input: xml output from lexical transfer module from Matxin/Apertium (LT) after splitNodes.pl
#	example: <CHUNK type="VP" si="top"><NODE ... pos="VV"><NODE ... lem="müssen" pos="VMFIN" mi="3.Sg.Pres.Ind"></NODE></NODE></CHUNK>
# Output: TODO: update description!
# 	example: <CHUNK type="VP" si="top"><NODE ... pos="VV"/><CHUNK ... lem="müssen" pos="VMFIN" mi="3.Sg.Pres.Ind" type="modalV"></CHUNK></CHUNK>

package squoia::nodesToChunks;
use strict;
use utf8;



sub main{
	my $dom = ${$_[0]};
	my @nodes2chunksRules = @{$_[1]};
	my $verbose = $_[2];
	
	print STDERR "#VERBOSE ". (caller(0))[3]."\n" if $verbose;

	my %targetAttributes = %{@nodes2chunksRules[0]};
	my %sourceAttributes = %{@nodes2chunksRules[1]};
	my $maxChunkRef = squoia::util::getMaxChunkRef($dom);

	foreach my $node ( $dom->getElementsByTagName('NODE') ) {
		#get parent chunk
		my $parentChunk = squoia::util::getParentChunk($node); 	#@{$node->findnodes('ancestor::CHUNK[1]')}[0]; # nearest ancestor chunk of node
		my $headNode = @{$parentChunk->findnodes('child::NODE')}[0];
		if (not $headNode->isSameNode($node)) { # is the head node equal the node to upgrade to a chunk?
			foreach my $nodeCond (keys %targetAttributes) {
				#check node conditions
				my @nodeConditions = squoia::util::splitConditionsIntoArray($nodeCond);
				my $result = squoia::util::evalConditions(\@nodeConditions,$node);
				if ($result) {
					# "upgrade" the NODE node to a CHUNK node
					print STDERR "upgrade " . $node->nodePath() . "(" . $node->getAttribute('slem') .") to a CHUNK\n" if $verbose;
					$node->unbindNode();
					my $newChunk = XML::LibXML::Element->new('CHUNK');
					$newChunk->appendChild($node);
					$parentChunk->appendChild($newChunk);
					my @sourceAttrs = split(",",$sourceAttributes{$nodeCond});
					foreach my $attrVal (@sourceAttrs) {
						my ($srcChunkAttr,$srcChunkVal) = split("=",$attrVal);
						$srcChunkVal =~ s/["]//g;
						$parentChunk->setAttribute($srcChunkAttr,$srcChunkVal);
					}
					my @attributes = split(",",$targetAttributes{$nodeCond});
					foreach my $attrVal (@attributes) {
						my ($newChunkAttr,$newChunkVal) = split("=", $attrVal);
						$newChunkVal =~ s/["]//g;
						$newChunk->setAttribute($newChunkAttr,$newChunkVal);
					}
					$maxChunkRef++;
					$newChunk->setAttribute('ref',"$maxChunkRef");
					$node->setAttribute('noderef',$node->getAttribute('ref'));	
				}
			}
		}
		#else {
		#	print STDERR "should the head node really be upgraded to a chunk?\n" if $verbose;
		#}
	}

	# print new xml to stdout
	#my $docstring = $dom->toString;
	#print STDOUT $docstring if $verbose;
}

1;
