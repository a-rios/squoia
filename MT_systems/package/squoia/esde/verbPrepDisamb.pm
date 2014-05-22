#!/usr/bin/perl

# disambiguate prepositional complement of verb
# path to verb prep disambiguation file is expected to be included in the config file
# format of verb prep file, tab separated:
# SLverb	SLprep	TLverb		TLprep	TLcas
# examples for SL=Spanish and TL=German:
# ESverb	ESprep	DEverb		DEprep	DEcas
# 1) both sides have a preposition
# soñar		con	träumen		von	Dat
# 2) Spanish has a preposition, German has only case marking the complement/object
# acusar	de	an|klagen	-	Gen
# 3) Spanish has no preposition, German has a preposition
# esperar	-	warten		auf	Akk

package squoia::esde::verbPrepDisamb;

use strict;
use utf8;

sub main{
	my $dom = ${$_[0]};
	my %verbprep = %{$_[1]};

	# Language-specific (?) "constant values"
	my $PREP_FUNC = "creg";
	my $DOBJ_FUNC = "cd";	# TODO: cd-a?
	my $SL_PREP_CPOS = "SP";
	my $PREP_PHRASE = "PP";
	my $TL_PREP_POS = "APPR";


	# get all prepositional complement chunks
	foreach my $prepchunk ( $dom->findnodes('//CHUNK[@si="'.$PREP_FUNC.'"]') ) {
		my $prepnode = @{$prepchunk->findnodes('descendant::NODE[starts-with(@smi,"'.$SL_PREP_CPOS.'")]')}[0];
		next if not $prepnode;
		my $verbchunk = squoia::util::getParentChunk($prepchunk);
		my $verbnode = @{$verbchunk->findnodes('child::NODE')}[0];
		next if not $verbnode;

		my $SLverb = $verbnode->getAttribute('slem');
		my $SLprep = $prepnode->getAttribute('slem');
		my $TLverb = $verbnode->getAttribute('lem');

		my $verbkey = "$SLverb\t$SLprep\t$TLverb";
		if (exists($verbprep{$verbkey})) {
			my ($TLprep,$TLcase) = @{$verbprep{$verbkey}};
			print STDERR "$verbkey mapped to prep: $TLprep; case: $TLcase\n";
			# 1) both sides have prep => replace SL prep with TL prep (or at least disambiguate)
			if ($SLprep ne "-" and $TLprep ne "-") {
				print STDERR "both side have prep: set SL prep $SLprep to (disambiguated) TL prep $TLprep and TL case $TLcase\n";
				$prepnode->setAttribute('lem',$TLprep);
				$prepnode->setAttribute('cas',$TLcase);
			}
			# 2) SL prep, TL no prep => delete prep?
			elsif ($TLprep eq "-" and $SLprep ne "-") {
				print STDERR "SL prep, TL no prep: set SL prep $SLprep delete attribute to yes\n";
				$prepnode->setAttribute('delete','yes');
				$prepnode->setAttribute('cas',$TLcase);
			}
	# this is never the case if we get only the creg chunks!!!		# 3) SL no prep, TL prep => add prep?
			elsif ($SLprep eq "-" and $TLprep ne "-") {
				print STDERR "SL no prep, TL prep: add TL prep $TLprep and case $TLcase\n";
			}
			else {
				print STDERR "this should not be the case; check your verb_prep file!\n";
			}
		}
		else {
			print STDERR "no entry for $verbkey\n";
		}
	}
	# get all direct complement chunks
	foreach my $objchunk ( $dom->findnodes('//CHUNK[@si="'.$DOBJ_FUNC.'"]') ) {	# TODO : cd-a? starts-with(@si,
		my $verbchunk = squoia::util::getParentChunk($objchunk);
		my $verbnode = @{$verbchunk->findnodes('child::NODE')}[0];

		my $SLverb = $verbnode->getAttribute('slem');
		my $SLprep = "-";
		my $TLverb = $verbnode->getAttribute('lem');

		my $verbkey = "$SLverb\t$SLprep\t$TLverb";
		if (exists($verbprep{$verbkey})) {
			my ($TLprep,$TLcase) = @{$verbprep{$verbkey}};
			print STDERR "$verbkey mapped to prep: $TLprep; case: $TLcase\n";
			# 3) SL no prep, TL prep => add prep?
			if ($TLprep ne "-") {
				print STDERR "SL no prep, TL prep: add prepositional phrase chunk with TL prep $TLprep and case $TLcase\n";
				my $prepchunk = XML::LibXML::Element->new('CHUNK');
				$prepchunk->setAttribute('ref',"0");	# TODO get max ref?
				$prepchunk->setAttribute('type',$PREP_PHRASE);
				$prepchunk->setAttribute('si',$PREP_FUNC);
				$prepchunk->setAttribute('comment','prepositional object');
				my $prepnode = XML::LibXML::Element->new('NODE');
				$prepnode->setAttribute('slem', $SLprep);
				$prepnode->setAttribute('lem', $TLprep);
				$prepnode->setAttribute('pos',$TL_PREP_POS);
				$prepnode->setAttribute('cas',$TLcase);
				# add the chunk and node to the tree
				$verbchunk->addChild($prepchunk);
				$prepchunk->addChild($prepnode);
				$prepchunk->addChild($objchunk);
			}
			else {
				print STDERR "this should not be the case; check your verb_prep file!\n";
			}
		}
		else {
			print STDERR "no entry for $verbkey\n";
		}
	}
}

1;
