#!/usr/bin/perl

# get the ambiguous subordinated verbs together with main verb and possible linker
# input: xml after synTransferIntra
#	<CHUNK ref="16" type="grup-verb" si="S" verbform="ambiguous" lem="lograr" verbmi="VRoot+IPst+1.Sg.Subj">
#	<NODE ref="16" alloc="" slem="lograr" smi="VMIS1S0" sform="logré" UpCase="none" lem="unspecified" mi="indirectpast" verbmi="VRoot+IPst+1.Sg.Subj">
#	<SYN lem="unspecified" mi="indirectpast" verbmi="VRoot+IPst+1.Sg.Subj"/>
#	<SYN lem="unspecified" mi="directpast" verbmi="VRoot+NPst+1.Sg.Subj"/>
#	<SYN lem="unspecified" mi="perfect" verbmi="VRoot+Perf+1.Sg.Poss"/>
#	<SYN lem="unspecified" mi="DS" verbmi="VRoot+DS+1.Sg.Poss"/>
#	<SYN lem="unspecified" mi="agentive" verbmi="VRoot+Ag"/>
#	<SYN lem="unspecified" mi="SS" verbmi="VRoot+SS"/>
#	</NODE>
# output: test file to pass to the ML classifier
#	class, main_es_verb, subord_es_verb, linker
#

use utf8;
use Storable;    # to retrieve hash from disk
use open ':utf8';
binmode STDIN, ':utf8';
binmode(STDOUT, ":utf8");
use XML::LibXML;
use strict;
use File::Spec::Functions qw(rel2abs);
use File::Basename;
my $path = dirname(rel2abs($0));
require "$path/util.pl";

sub isPossibleMainVerb{
	my $node = $_[0];

	#my $parentChunk = &getParentChunk($node);
	my $parent = $node->parentNode;
	if ($parent->nodeName eq "CHUNK") {
		return ($parent->hasAttribute('verbform'));
	}
	else {
		return 0;
	}
}

sub isMainVerb{
	my $node = $_[0];

	#my $parentChunk = &getParentChunk($node);
	my $parent = $node->parentNode;
	if ($parent->nodeName eq "CHUNK") {
		return ($parent->getAttribute('verbform') =~ /main/);
	}
	else {
		return 0;
	}
}

sub isRelPronoun{
	my $node = $_[0];
	# slem="que" smi="PR00N000"
	return ($node->getAttribute('smi') =~ /^PR/);
}

sub isLinker{
	my $node = $_[0];

	my $pos = $node->getAttribute('smi');
	my $lem = $node->getAttribute('slem');
	return ($pos =~ /CS|CC/ and $lem =~ /pero|cuando|si/);
}



my $dom    = XML::LibXML->load_xml( IO => *STDIN );

my $sno;
foreach my $sentence  ( $dom->getElementsByTagName('SENTENCE'))
{
	$sno = $sentence->getAttribute('ref');
	print STDERR "SENT $sno\n";
	#get all NODES within SENTENCE
	my @sentenceNodes = $sentence->findnodes('descendant::NODE');

	my %nodereforder;
	foreach my $node (@sentenceNodes) {
		my $ref = $node->getAttribute('ref');
		$nodereforder{$ref} = $node;
	}
	# search for ambiguous verb form, from left to right (ascending ref order)
	foreach my $ref (sort { $a <=> $b } keys %nodereforder) {
		my $node = $nodereforder{$ref};
		my $subordverb = $node->getAttribute('slem');
		print STDERR "NODE ref: ".$node->getAttribute('ref')."\tnode lemma: ".$node->getAttribute('slem')."\n";			
		#my $parentChunk = &getParentChunk($node);
		my $parentChunk = $node->parentNode;	# head verb, no auxiliary or other dependent element; head verb is directly under verb chunk
		if ($parentChunk->nodeName eq "CHUNK" and $parentChunk->getAttribute('verbform') =~ /ambiguous/ ) {
			print STDERR "AMBIGUOUS verb form ".$parentChunk->getAttribute('lem')."\n";
			my $prevnode;
			my $linker="0.0";
			my $linkref=0;
			my $mainverb;
			my $mainref=0;
			# search for possible main verb and linker left from ambiguous verb, from right to left (descending ref order)
			for (my $i=$ref-1;$i>0;$i--) {
				if (exists($nodereforder{$i})) {
					$prevnode = $nodereforder{$i};
					if (&isPossibleMainVerb($prevnode)) {
						$mainverb = $prevnode->getAttribute('slem');
						$mainref = $i;
						print STDERR "\tprevious node ($i) $mainverb is a MAIN verb\n";
						if ($linker =~ /0\.0/) {
							my $prevmain;
							my $possmainref=$i;
							my $linkerref=$i;
							my $relref = $i;
							for (my $j=$i-1; $j>0;$j--) {
								if (exists($nodereforder{$j})) {
									$prevmain = $nodereforder{$j};
									if (&isRelPronoun($prevmain)) {
										$relref = $j;
										print STDERR "relative pronoun found ($relref) $mainverb is in relative clause\n";
										last;
									}
									#elsif (&isPossibleMainVerb($prevmain)) {
									#	$possmainref = $j;
									#	print STDERR "possible main verb ".$nodereforder{$possmainref}->getAttribute('slem')."\n";
									#}
									elsif (&isLinker($prevmain)) {
										$linkerref = $j;
										print STDERR "main verb has a previous linker...";
										print STDERR $prevnode->getAttribute('slem')." is a subordinated verb?\n";
										print STDERR "set $subordverb to main\n";
										$parentChunk->setAttribute('verbform','main');
									}
								}
							}
							if ($relref == $i) { #no relative pronoun found
								if ($linkerref == $i) { #no linker
									print STDERR "$sno: $mainverb coordinated with $subordverb\n";
									my $vform = $prevnode->parentNode->getAttribute('verbform');
									print STDERR "set verb form to $vform\n";
									$parentChunk->setAttribute('verbform',$vform);
								}
								last;
							}
							else {
								$i = $relref; # search "main" verb of relative clause
								print STDERR "verb in RELATIVE clause; search for main verb...\n";
							}
						}
						else {
							print STDOUT "$sno\t?,$mainverb,$subordverb,$linker\n";
							last;
						}
					}
					elsif (&isLinker($prevnode)) {
						$linker = $prevnode->getAttribute('slem');
						$linkref = $i;
						print STDERR "\tprevious node ($i) ".$prevnode->getAttribute('slem')." is a LINKER\n";
					}
				}
			}
		}
	}
	
	print STDERR "\n";	# empty line between sentences
}


# print new xml to stdout
my $docstring = $dom->toString;
print STDOUT $docstring;
