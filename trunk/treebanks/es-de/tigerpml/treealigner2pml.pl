#!/usr/bin/perl

# treealigner2pml.pl
#	to convert TreeAligner XML files into PML files
# usage:
#	treealigner2pml.pl < TA_alignments.xml > PML_alignments.pml

use strict;
use XML::LibXML;

my $dom    = XML::LibXML->load_xml( IO => *STDIN );

print STDOUT <<HEAD;
<?xml version="1.0" encoding="UTF-8"?>
<tree_alignment xmlns="http://ufal.mff.cuni.cz/pdt/pml/">
  <head>
    <schema href="sample_align_schema.xml" />
    <references>
HEAD
my $refa = "de";
my $refb = "es";

my @tbs = $dom->findnodes('/treealign/head/treebanks/treebank[@id="'.$refa.'"]');
my $tb = $tbs[0];
#      <treebank id="de" language="de_DE" filename="FOCUS_SQUOIA_DE.xml"/>
my $tbref = $tb->getAttribute('filename');
$tbref =~ s/xml$/pml/;
print STDOUT <<TBREFA;
      <reffile id="a" name="document_a" href="$tbref" />
TBREFA

@tbs = $dom->findnodes('/treealign/head/treebanks/treebank[@id="'.$refb.'"]');
my $tb = $tbs[0];
#      <treebank id="de" language="de_DE" filename="FOCUS_SQUOIA_DE.xml"/>
my $tbref = $tb->getAttribute('filename');
$tbref =~ s/xml$/pml/;
print STDOUT <<TBREFB;
      <reffile id="b" name="document_b" href="$tbref" />
TBREFB

print STDOUT <<HEADBODY;
    </references>
  </head>
  <body>
HEADBODY

#  <alignments>
#    <sen-align>
#      <node treebank_id="de" node_id="s1_VROOT"/>
#      <node treebank_id="es" node_id="s1_VROOT"/>
#    </sen-align>
my @salignments = $dom->findnodes('/treealign/alignments/sen-align');
foreach my $sal (@salignments) {
	# get the sentence alignment VROOT
	my @nodes = $sal->findnodes('node[@treebank_id="'.$refa.'"]');
	my $anode = $nodes[0];
	my $asent = $anode->getAttribute('node_id');
	$asent =~ s/_VROOT//;
	@nodes = $sal->findnodes('node[@treebank_id="'.$refb.'"]');
	my $bnode = $nodes[0];
	my $bsent = $bnode->getAttribute('node_id');
	$bsent =~ s/_VROOT//;
	#print STDERR "sent pair: $asent -- $bsent\n";
	print STDOUT <<SENTALIGN;
    <LM>
      <tree_a.rf>a#$asent</tree_a.rf>
      <tree_b.rf>b#$bsent</tree_b.rf>
      <node_alignments>
SENTALIGN
	
#    <align type="good" last_change="2012-01-17" author="norahollenstein">
#      <node treebank_id="de" node_id="s1_500"/>
#      <node treebank_id="es" node_id="s1_503"/>
#    </align>
	# get the node alignments for this aligned sentence pair
	my @nalignments = $dom->findnodes('/treealign/alignments/align[node[@treebank_id="'.$refa.'" and starts-with(@node_id,"'.$asent.'_")] and node[@treebank_id="'.$refb.'" and starts-with(@node_id,"'.$bsent.'_")]]');
	print STDERR scalar(@nalignments) . " node alignments for sentence pair $asent -- $bsent\n";
	foreach my $nal (@nalignments) {
		#print STDERR $nal->toString() . "\n";
		my $quality = $nal->getAttribute('type');
		$quality =~ s/good/exact/;
		my @nodes = $nal->findnodes('node[@treebank_id="'.$refa.'"]');
		my $anode = $nodes[0];
		my $anid = $anode->getAttribute('node_id');		
		my @nodes = $nal->findnodes('node[@treebank_id="'.$refb.'"]');
		my $bnode = $nodes[0];
		my $bnid = $bnode->getAttribute('node_id');
		print STDOUT <<NALIGN;
        <LM>
          <a.rf>a#$anid</a.rf>
          <b.rf>b#$bnid</b.rf>
          <quality>$quality</quality>
        </LM>
NALIGN
	}
	print STDOUT <<SENTEND;
      </node_alignments>
    </LM>
SENTEND
}

print STDOUT <<ENDBODY;
  </body>
</tree_alignment>
ENDBODY

print STDERR "Conversion from TreeAligner XML to PML done!\n"
