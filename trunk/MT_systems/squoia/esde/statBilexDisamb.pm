#!/usr/bin/perl

# statistical lexical disambiguation:
# select the most probable lexical alternatives after semantic disambiguation
# using a given language model and a maximum of alternatives (s. configuration)

package squoia::esde::statBilexDisamb;

use utf8;
use strict;

sub main{
	my $dom = ${$_[0]};
	my %bilexProb = %{$_[1]};
	my $lm = $_[2];		# filename of the language model
	my $maxalt = $_[3];	# maximum number of selected lexical alternatives
	my $verbose = $_[4];

	print STDERR "#VERBOSE ". (caller(0))[3]."\n" if $verbose;

	my $lempos = 0;		# boolean: language model with both lemmas and pos

	my @sentences = $dom->findnodes('//SENTENCE');
	my $nofsent = int(@sentences);
	print STDERR "$nofsent sentences before duplication\n" if $verbose;

	my $totsent;

	foreach my $sent (@sentences) {
		my $nofalt = 1;		# number of alternatives for this sentence
		# get all nodes (NODE) of a sentence with ambigous translations (SYN)
		foreach my $node ( $sent->findnodes('descendant::NODE[SYN]')) {
		
			# count the number of alternatives (SYN) for this node
			my $nofsyn = int(@{$node->findnodes('SYN')});

			# combinatorial multiplication of alternatives
			$nofalt = $nofalt * $nofsyn;

			my $slem = $node->getAttribute('slem');
			# select the best alternative from the bilingual lexical probabilities
			my @synonyms = $node->findnodes('SYN');
			my $bestprob = 0;
			my $seltarget = "";
			my $selsynnode = $node;
			foreach my $syn (@synonyms) {
				my $tlem = $syn->getAttribute('lem');
				$tlem =~ s/\|//;		# get rid of the "|" in the verbs with separable prefix
				my $stlem = "$slem\t$tlem";
				my $prob = $bilexProb{$stlem};
				if ($prob and $prob > $bestprob) {
					$bestprob = $prob;
					$seltarget = $tlem;
					$selsynnode = $syn;
				}
			}
			print STDERR "selected translation for source $slem is $seltarget with probability $bestprob\n" if $verbose;
			if (not $node->isSameNode($selsynnode)) {
				# correct the number of alternatives
				$nofalt = $nofalt / $nofsyn;
				# delete the attributes of the first SYN child that have been "copied" into the parent NODE
				my $firstsyn = $synonyms[0];
				my @synattrlist = $firstsyn->attributes();
				foreach my $synattr (@synattrlist)
				{
					$node->removeAttribute($synattr->nodeName);
				}
				# remove the other synonyms
				foreach my $syn (@synonyms) {
					if ($syn->isSameNode($selsynnode)) {
						# set the node to the selected synonym
						my @attributelist = $syn->attributes();
						foreach my $attribute (@attributelist)
						{
							my $val = $attribute->getValue();
							my $attr = $attribute->nodeName;
							$node->setAttribute($attr,$val);
						}						
					}
					else {
						my $lem = $syn->getAttribute('lem');
						print STDERR "syn $lem with prob ". $bilexProb{"$slem\t$lem"}." removed\n" if $verbose;
						$node->removeChild($syn);
					}
				}
		
		}
		else {
			# if more alternatives than max then select the best
			if ($nofsyn > $maxalt) {
				# correct the number of alternatives
				$nofalt = $nofalt * $maxalt / $nofsyn;

				print STDERR "there are $nofsyn alternatives for the node $slem\n" if $verbose;
				my $inputalts;
				my @synonyms = $node->findnodes('SYN');
				foreach my $syn (@synonyms) {
					my $lem = $syn->getAttribute('lem');
					$lem =~ s/\|//;		# get rid of the "|" in the verbs with separable prefix
					$inputalts .= $lem;
					if ($lempos) {
						my $pos = $syn->getAttribute('pos');
						$inputalts .= "_$pos";
					}
					$inputalts .= "\n";
				}
				print STDERR "input alternatives:\n$inputalts" if $verbose;
				# get the scores
				my $returnstring = `echo '$inputalts' | query $lm null 2>/dev/null | grep "OOV: 0" | sort -k5 | cut -d"=" -f1 | head -$nofalt`;
				print STDERR "returned string:\n$returnstring" if $verbose;
				my @selectedalts = split /\n/, $returnstring;
				my $index;
				#foreach my $alter (@selectedalts) {
				#	$index++;
				#	print STDERR "$index $alter\n";
				#}
				# select the first "maxalt" alternatives
				my %selsyn = ();
				if (scalar(@selectedalts)) {
					print STDERR "keep only the selected alternatives\n" if $verbose;
					for (my $i;$i<$maxalt;$i++) {
						print STDERR $i+1 ." $selectedalts[$i]\n" if $verbose;
						$selsyn{$selectedalts[$i]} = $i+1;
					}
					# delete the attributes of the first SYN child that have been "copied" into the parent NODE
					my $firstsyn = $synonyms[0];
					my @synattrlist = $firstsyn->attributes();
					foreach my $synattr (@synattrlist)
					{
						$node->removeAttribute($synattr->nodeName);
					}
					# remove the other synonyms
					foreach my $syn (@synonyms) {
						my $lem = $syn->getAttribute('lem');
						$lem =~ s/\|//;
						if (exists($selsyn{$lem})) {
							print STDERR "+ $lem\n" if $verbose;
							# set the node to the first choice
							if ($lem eq $selectedalts[0]) {
								print STDERR "************\n" if $verbose;
								my @attributelist = $syn->attributes();
								foreach my $attribute (@attributelist)
								{
									my $val = $attribute->getValue();
									my $attr = $attribute->nodeName;
									$node->setAttribute($attr,$val);
								}						
							}
						}
						else {
							print STDERR "- $lem\n" if $verbose;
							$node->removeChild($syn);
						}
					}
				}
				else {
					# back-off: take the first "random" synonyms
					print STDERR "back-off: take the first random synonyms\n" if $verbose;
					for (my $i;$i<$maxalt;$i++) {
						print STDERR "++ " . $i+1 ." " . $synonyms[$i]->getAttribute('lem') ."\n" if $verbose;
						$selsyn{$synonyms[$i]} = $i+1;
					}
					# remove the other synonyms
					for (my $i=$maxalt;$i<scalar(@synonyms);$i++) {
						print STDERR "- ".$synonyms[$i]->getAttribute('lem')."\n" if $verbose;
						$node->removeChild($synonyms[$i]);
					}			
				}
			}
		}
		}
		my $sref = $sent->getAttribute('ref');
		print STDERR "$nofalt alternatives for sentence $sref\n" if $verbose;
		$totsent = $totsent + $nofalt;
	}
	print STDERR "$totsent sentences after duplication\n" if $verbose;
}

1;
