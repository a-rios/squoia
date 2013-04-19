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
#binmode(STDOUT, ":utf8");
#binmode(STDERR, ":utf8");
use XML::LibXML;
use strict;
use File::Spec::Functions qw(rel2abs);
use File::Basename;
my $path = dirname(rel2abs($0));
require "$path/util.pl";

my $dom    = XML::LibXML->load_xml( IO => *STDIN );

my $sno;
foreach my $sentence  ( $dom->getElementsByTagName('SENTENCE'))
{
	$sno = $sentence->getAttribute('ref');
	print STDERR "SENT $sno\n";
	#get all interesting NODES within SENTENCE
	my @sentenceNodes = $sentence->findnodes('descendant::NODE[parent::CHUNK[@verbform] or starts-with(@smi,"PR") or @smi="CS"]'); #head verb, relative pronoun, or subordinating conjunction

	my %nodereforder;
	foreach my $node (@sentenceNodes) {
		my $ref = $node->getAttribute('ref');
		$nodereforder{$ref} = $node;
	}
	my @nodes;
	foreach my $ref (sort { $a <=> $b } keys %nodereforder) {
		my $node = $nodereforder{$ref};
		push(@nodes,$node);
	}
	for (my $i=0;$i<scalar(@nodes);$i++) {
		my $node = $nodes[$i];
		my $subordverb = $node->getAttribute('slem');
		print STDERR "NODE ref: ".$node->getAttribute('ref')."\tnode lemma: ".$node->getAttribute('slem')."\t";
		my $smi = $node->getAttribute('smi');
		if ($smi =~ /^PR/) {
			print STDERR "RELPRONOUN\t";
			my $nextverbnode = $nodes[$i+1];
			my $nextverb = $nextverbnode->getAttribute('slem');
			my $nextverbform = $nextverbnode->parentNode->getAttribute('verbform');
			if ($nextverbform =~ /^rel/) {
				print STDERR "OK: relative pronoun before relative verb form\n";
			}
			else {
				print STDERR "NOK?: verb form $nextverbform after relative pronoun\n";
				#print STDERR "\n***ERROR: verb form $nextverbform after relative pronoun\n";
				#$nextverbnode->parentNode->setAttribute('verbform','rel:');
				#print STDERR "verb form '$nextverbform' of following verb $nextverb set to 'rel:'\n";
			}
			
		}
		elsif ($smi =~ /^CS/) {
			print STDERR "LINKER\n";
		}
		else {
			my $verbform = $node->parentNode->getAttribute('verbform');
			if ($verbform =~ /ambiguous/) {
				print STDERR "\n---AMBIGUOUS ";
				# search left for linker or relative pronoun
				if ($i > 0) {
					my $prevnode = $nodes[$i-1];
					my $prevsmi = $prevnode->getAttribute('smi');
					my $newverbform = "main"; # default?
					if ($prevsmi =~/^CS/) {
						my $linker = $prevnode->getAttribute('slem');
						$newverbform = "MLdisamb";
						#print STDOUT "FOUND an example in sentence $sno\n";
						print STDERR "linked with $linker\n";
						# search main verb left or right of this one
						my $found=0;
						for (my $j=$i-2; $j>=0; $j--) { # left
							my $cand = $nodes[$j];
							if ($cand->parentNode->hasAttribute('verbform')) {
								print STDERR "found candidate main verb left of subordinated verb\n";
								my $candverb = $cand->getAttribute('slem');
								print STDERR "$candverb,$subordverb,$linker\n";
								print STDOUT "$candverb,$subordverb,$linker\n";
								$found = 1;
								last;
							}
							else {
								print STDERR "WEIRD left $cand ....\n";
							}
						}
						if (not $found) {
							for (my $j=$i+1; $j<scalar(@nodes); $j++) { # search right for the next verb; 
								my $cand = $nodes[$j];
								if ($cand->parentNode->hasAttribute('verbform')) {
									print STDERR "found candidate main verb right of subordinated verb\n";
									if ($nodes[$j-1]->getAttribute('smi') =~ /^CS|^PR/ ) {
										print STDERR "candidate is rather subordinated with ".$nodes[$j-1]->getAttribute('slem')."... continue searching\n";
										next; 
									}
									my $candverb = $cand->getAttribute('slem');
									print STDERR "$candverb,$subordverb,$linker\n";
									print STDOUT "$candverb,$subordverb,$linker\n";
									$found = 1;
									last;
								}
							}
						
						}
					}
					elsif ($prevsmi =~ /^PR/) {
						print STDERR "relative clause\n";
						$newverbform = "rel:";
						$node->parentNode->setAttribute('verbform',$newverbform);
						print STDERR "verb form of $subordverb set to 'rel:'\n";
					}
					else {
						print STDERR "no linker, not in relative clause\n";
						my $headverb = $prevnode->getAttribute('slem');
						$newverbform = $prevnode->parentNode->getAttribute('verbform');
	#					print STDERR "verb form of $subordverb set to $newverbform\n";
	#					$node->parentNode->setAttribute('verbform',$newverbform);
						print STDERR "verb form of $subordverb set to 'main' (coordination would be $newverbform)\n";
						$node->parentNode->setAttribute('verbform','main');
					}
				}
				else {
					print STDERR "no previous verb, no linker, not in relative clause\n";
					print STDERR "verb form of $subordverb set to 'main'\n";
					$node->parentNode->setAttribute('verbform','main');
				}
			}
			else {
				print STDERR "VERB form: $verbform\n";
			}
		}
	}
	
	print STDERR "\n";	# empty line between sentences
}


# print new xml to stdout
#my $docstring = $dom->toString;
#print STDOUT $docstring;
