#!/usr/bin/perl

# pml2treealigner.pl
#	to convert PML alignment files into TreeAligner XML files
# usage:
#	pml2treealigner.pl < PML_alignments.pml > TA_alignments.xml

use strict;
use XML::LibXML;

my $dom    = XML::LibXML->load_xml( IO => *STDIN );
# register namespace as "pml"
my $root = $dom->documentElement;
my $xc = XML::LibXML::XPathContext->new( $root );
$xc->registerNs("pml", "http://ufal.mff.cuni.cz/pdt/pml/");

my $author = "pml2treealigner";
my $date = `date +%Y-%m-%d`;
$date =~ s/\n//;
my $description = "TEST_ALIGNMENTS";
my $revision = "1";
my $size = 1;
#my $uuid = "e4b77b01-fbb6-48ea-8315-981d0abbecba";

print STDOUT <<HEAD;
<?xml version="1.0" encoding="UTF-8"?>
<treealign subversion="3" version="2">
  <head>
    <alignment-metadata>
      <author>$author</author>
      <date>$date</date>
      <description>$description</description>
      <history>
</history>
      <license>None</license>
      <revision>$revision</revision>
      <size>$size</size>
    </alignment-metadata>
    <treebanks>
HEAD
#      <uuid>$uuid</uuid>

my $refa = "de";
my $langa = "de_DE";
my $refb = "es";
my $langb = "es_ES";

#my @tbs = $dom->findnodes('/tree_alignment/head/references/reffile[@id="a"]');
my @tbs = $xc->findnodes('/pml:tree_alignment/pml:head/pml:references/pml:reffile[@id="a"]');
my $tb = $tbs[0];
#      <reffile id="a" name="document_a" href="FOCUS_SQUOIA_DE.pml" />
my $tbref = $tb->getAttribute('href');
$tbref =~ s/pml$/xml/;
print STDOUT <<TBREFA;
      <treebank id="$refa" language="$langa" filename="$tbref"/>
TBREFA
#my @tbs = $dom->findnodes('/tree_alignment/head/references/reffile[@id="b"]');
my @tbs = $xc->findnodes('/pml:tree_alignment/pml:head/pml:references/pml:reffile[@id="b"]');
my $tb = $tbs[0];
my $tbref = $tb->getAttribute('href');
$tbref =~ s/pml$/xml/;
print STDOUT <<TBREFB;
      <treebank id="$refb" language="$langb" filename="$tbref"/>
    </treebanks>
    <alignment-features>
      <alignment-feature color="#33e533" name="good">Exact alignment</alignment-feature>
      <alignment-feature color="#e53333" name="fuzzy">Fuzzy alignment</alignment-feature>
    </alignment-features>
    <consistency-checks>
</consistency-checks>
    <settings>
      <display-options>
        <top-treebank treebank-id=""/>
      </display-options>
      <auto-align active="True"/>
    </settings>
  </head>
  <alignments>
TBREFB

#  <body>
#    <LM>
#      <tree_a.rf>a#s1422</tree_a.rf>
#      <tree_b.rf>b#s1405</tree_b.rf>
# get the sentence alignments
#my @salignments = $dom->findnodes('/tree_alignment/body/LM');
my @salignments = $xc->findnodes('/pml:tree_alignment/pml:body/pml:LM');
foreach my $sal (@salignments) {
	# get the sentence alignment VROOT
	#my @nodes = $sal->findnodes('tree_a.rf');
	my @nodes = $xc->findnodes('pml:tree_a.rf',$sal);
	my $anode = $nodes[0];
	my $asent = $anode->textContent;
	$asent =~ s/a#(s\d+)/\1/;
	#my @nodes = $sal->findnodes('tree_b.rf');
	my @nodes = $xc->findnodes('pml:tree_b.rf',$sal);
	my $bnode = $nodes[0];
	my $bsent = $bnode->textContent;
	$bsent =~ s/b#(s\d+)/\1/;
	print STDOUT <<SENTALIGN;
    <sen-align>
      <node treebank_id="$refa" node_id="${asent}_VROOT"/>
      <node treebank_id="$refb" node_id="${bsent}_VROOT"/>
    </sen-align>
SENTALIGN

#      <node_alignments>
#        <LM>
#          <a.rf>a#s1422_501</a.rf>
#          <b.rf>b#s1405_504</b.rf>
#          <quality>exact</quality>
#        </LM>

	# get the node alignments for this aligned sentence pair	
	#my @nalignments = $sal->findnodes('node_alignments/LM');
	my @nalignments = $xc->findnodes('pml:node_alignments/pml:LM',$sal);
	foreach my $nal (@nalignments) {
		#my @nodes = $nal->findnodes('quality');
		my @nodes = $xc->findnodes('pml:quality',$nal);
		my $quality = $nodes[0]->textContent;
		$quality =~ s/exact/good/;
		#my @nodes = $nal->findnodes('a.rf');
		my @nodes = $xc->findnodes('pml:a.rf',$nal);
		my $anode = $nodes[0]->textContent;
		$anode =~ s/a#(s\d+_\d+)/\1/;		
		#my @nodes = $nal->findnodes('b.rf');
		my @nodes = $xc->findnodes('pml:b.rf',$nal);
		my $bnode = $nodes[0]->textContent;
		$bnode =~ s/b#(s\d+_\d+)/\1/;		
		print STDOUT <<NALIGN;
    <align type="$quality" last_change="$date" author="$author">
      <node treebank_id="$refa" node_id="$anode"/>
      <node treebank_id="$refb" node_id="$bnode"/>
    </align>
NALIGN
	}
}

print STDOUT <<ENDBODY;
  </alignments>
</treealign>
ENDBODY

print STDERR "Conversion from PML to TreeAligner XML done!\n"
