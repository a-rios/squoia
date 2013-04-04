#!/usr/bin/perl
						
use utf8;
use strict;
binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';
use XML::LibXML;
require "util.pl";
require "esde/outputGerman.pl";
our $OUT_LANG;

sub genQuechua
{
	print "Annette is working on it!\n";
}

my %langGeneration =
	(
		'de'	=> \&genGerman,
		'qu'	=> \&genQuechua
	);

my $parser = XML::LibXML->new("utf8");
my $dom    = XML::LibXML->load_xml( IO => *STDIN );
# get all SENTENCE chunks, iterate over childchunks
foreach my $sentence  ( $dom->getElementsByTagName('SENTENCE'))
{
	#print STDERR $sentence->toString;
	#get all direct child CHUNKS within SENTENCE
	my @sentenceCHUNKS = $sentence->findnodes('descendant::CHUNK');

	my %orderhash;
	foreach my $chunk (@sentenceCHUNKS)
	{
		my $ord = $chunk->getAttribute('ord');
		$orderhash{$ord} = $chunk;
	}
	foreach my $ord (sort { $a <=> $b } keys %orderhash) {
		my $chunk = $orderhash{$ord};
		#print STDERR "ref: ".$chunk->getAttribute('ref')."\tord: ".$chunk->getAttribute('ord')."\ttype: ".$chunk->getAttribute('type')."\n";
		my @childnodes = &getNodesOfSingleChunk($chunk);
		my %nodeorder;
		foreach my $child (@childnodes) {
			my $ord;
			if ($child->hasAttribute('ord')) {
				$ord = $child->getAttribute('ord');
			}
			else {
				$ord = $child->getAttribute('ref');
			}
			$nodeorder{$ord} = $child;
		}
		foreach my $ord (sort { $a <=> $b } keys %nodeorder) {
			my $node = $nodeorder{$ord};
			#print STDERR "\tnode ref: ".$node->getAttribute('ref')."\tnode ord: ".$node->getAttribute('ord')."\tnode lemma: ".$node->getAttribute('lem')."\n";
			# TODO: call whatever subroutines to output the node information you want, e.g. the lemma
			if ($node->hasAttribute('delete')) {
				print STDERR "[".$node->getAttribute('slem')."]\n";
			}
			# unknown word
			# i.e. the word is not in the bilingual dictionary and could not be lexically transfered
			# and there is no "pos" attribute
			elsif ($node->hasAttribute('unknown') and $node->getAttribute('smi') !~ /^(Z|AO)/) {
				my $unknownStr = "*".$node->getAttribute('slem');
				if ($node->hasAttribute('sform')) {
					$unknownStr = "*".$node->getAttribute('sform');
				}
				print STDERR "unknown $unknownStr\n";
				print STDOUT "$unknownStr\n";
			}
			else {
				print STDERR $node->getAttribute('lem')." ";
				my $generation_ref = $langGeneration{$OUT_LANG};
				#my $morphstring = &genMolifInput($node);
				my $morphstring = $generation_ref->($node);
				print STDOUT "$morphstring\n";
			}
		}
	}
	print STDOUT "\n";	# empty line between sentences
}

