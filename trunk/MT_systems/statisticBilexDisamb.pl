#!/usr/bin/perl

# statistical lexical disambiguation:
# select the most probable lexical alternatives after semantic disambiguation
# using a given language model and a maximum of alternatives (s. configuration)
# TODO: config

use utf8;
use Storable;    # to retrieve hash from disk
use open ':utf8';
#binmode STDIN, ':utf8';
use XML::LibXML;
use strict;

use File::Spec::Functions qw(rel2abs);
use File::Basename;
my $path = dirname(rel2abs($0));
require "$path/util.pl";

# retrieve hash with config parameters from disk, get path to file with semantic information
eval {
	retrieve('parameters');
	
} or die "No parameters defined. Run readConfig.pl first!";

# BilexProbFile=$LEXICON_DIR/jem.bilexprob.dat
my %hash    = %{ retrieve("parameters") };
my $bilexProbFile = $hash{"BilexProbFile"}
  or die "Bilingual lexical probability file not specified in config!";
open BILEXPROBFILE, "< $bilexProbFile" or die "Can't open $bilexProbFile : $!";

my %bilexProb = ();
#read bilingual lexical probabilities from file into a hash (slem, tlem, prob)
while (<BILEXPROBFILE>) {
	chomp;
	s/#.*//;     # no comments
	s/^\s+//;    # no leading white
	s/\s+$//;    # no trailing white
	next if /^$/;	# skip if empty line
	my ( $slem, $tlem, $prob ) = split( /\s*\t+\s*/, $_, 3 );
	# assure key is unique, use slem:tlem as key
	my $key = "$slem\t$tlem";
	$bilexProb{$key} = $prob;
}
print STDERR "bilingual lexical probabilities\n";
foreach my $stlem (keys %bilexProb) {
	print STDERR "$stlem has prob ".$bilexProb{$stlem}."\n";
}
#exit;

my $lm = $ARGV[0];	# "dewac10M_3g_lemma.bin.lm";	# name of the model
my $maxalt = $ARGV[1];	# 3;		# maximum number of selected lexical alternatives
my $lempos = 0;		# boolean: language model with both lemmas and pos

my $dom    = XML::LibXML->load_xml( IO => *STDIN );

my @sentences = $dom->findnodes('//SENTENCE');
my $nofsent = int(@sentences);
print STDERR "$nofsent sentences before duplication\n";

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
			my $stlem = "$slem\t$tlem";
			my $prob = $bilexProb{$stlem};
			if ($prob and $prob > $bestprob) {
				$bestprob = $prob;
				$seltarget = $tlem;
				$selsynnode = $syn;
			}
		}
		print STDERR "selected translation for source $slem is $seltarget with probability $bestprob\n";
		if (not $node->isSameNode($selsynnode)) {
			# correct the number of alternatives
			$nofalt = $nofalt / $nofsyn;
			# remove the other syns
			#&removeUnusedSynonyms($node,\@synonyms,??);
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
					print STDERR "syn $lem removed\n";
					$node->removeChild($syn);
				}
			}
		
	}
	else {
		# if more alternatives than max then select the best
		if ($nofsyn > $maxalt) {
			# correct the number of alternatives
			$nofalt = $nofalt * $maxalt / $nofsyn;

			print STDERR "there are $nofsyn alternatives for the node $slem\n";
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
			print STDERR "input alternatives:\n$inputalts";
			# get the scores
			my $returnstring = `echo '$inputalts' | query $lm null 2>/dev/null | grep "OOV: 0" | sort -k5 | cut -d"=" -f1 | head -$nofalt`;
			print STDERR "returned string:\n$returnstring";
			my @selectedalts = split /\n/, $returnstring;
			my $index;
			#foreach my $alter (@selectedalts) {
			#	$index++;
			#	print STDERR "$index $alter\n";
			#}
			# select the first "maxalt" alternatives
			my %selsyn = ();
			for (my $i;$i<$maxalt;$i++) {
				print STDERR $i+1 ." $selectedalts[$i]\n";
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
					print STDERR "+ $lem\n";
					# set the node to the first choice
					if ($lem eq $selectedalts[0]) {
						print STDERR "************\n";
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
					print STDERR "- $lem\n";
					$node->removeChild($syn);
				}
			}
		}
	}
	}
	my $sref = $sent->getAttribute('ref');
	print STDERR "$nofalt alternatives for sentence $sref\n";
	$totsent = $totsent + $nofalt;
}

print STDERR "$totsent sentences after duplication\n";

# print new xml to stdout
my $docstring = $dom->toString;
print STDOUT $docstring;

sub removeUnusedSynonyms {
	my $node	= $_[0];
	my $synonyms	= $_[1];
	my $selsyn	= $_[2];
	my $selalts	= $_[3];

	# remove the other synonyms
	foreach my $syn (@{$synonyms}) {
		my $lem = $syn->getAttribute('lem');
		$lem =~ s/\|//;
		if (exists($selsyn->{$lem})) {
			print STDERR "+ $lem\n";
			# set the node to the first choice
			if ($lem eq @{$selalts}[0]) {
				print STDERR "************\n";
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
			print STDERR "- $lem\n";
			$node->removeChild($syn);
		}
	}
	print STDERR "unused synonyms removed\n";
}
