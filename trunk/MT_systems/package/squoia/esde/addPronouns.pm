#!/usr/bin/perl

# addPronounChunk: add/guess the pronouns needed for German but absent in Spanish (pro-drop language)
#
# Input: xml output from lexical transfer module from Matxin/Apertium (LT) after splitNodes.pl
# Output: 

package squoia::esde::addPronouns;

use strict;
use utf8;

sub main{
	my $dom = ${$_[0]};

	my $maxChunkRef = squoia::util::getMaxChunkRef($dom);
	my $subject = "suj";

	# get the nodes of VP chunks with no dependent "subject" chunks
	my $xpathexpr = '//CHUNK[(@type="VP" or @type="CVP") and count(CHUNK[starts-with(@si,"'.$subject.'")])=0]/NODE';

	my @specialnodes = $dom->findnodes($xpathexpr);
	foreach my $node (@specialnodes) {
		my $parentChunk = squoia::util::getParentChunk($node);	# VP chunk
		if ($parentChunk->getAttribute('si') =~ /^S|sn/) {	# TODO other possibilities?
			# do not add any pronoun in a relative clause TODO if it is the subject, but it could be the object!!!
			print STDERR "relative clause does not need any extra pronoun\n";
			# get person of finite verb
			my $finverb = @{$node->findnodes('descendant-or-self::NODE[contains(@pos,"FIN") or contains(@spos,"FIN")]')}[0];
			if ($finverb and $finverb->getAttribute('mi') =~ /^3\./) {
				# TODO: the verb is in 3rd person; relative could be the object...
				print STDERR "verb in 3rd person; relpronoun could still be the object...\n";
				next;
			} # else the finite verb has no explicit subject but has the form of a 1st or 2nd person => add pronoun
			print STDERR "add subject pronoun anyway!\n";
		}
		my $pronounChunk = XML::LibXML::Element->new('CHUNK');
		$maxChunkRef++;
		$pronounChunk->setAttribute('ref',"$maxChunkRef");
		$pronounChunk->setAttribute('type','NP');
		$pronounChunk->setAttribute('si',$subject);
		$pronounChunk->setAttribute('comment','added pronoun');
		my $pronounNode = XML::LibXML::Element->new('NODE');
		$pronounNode->setAttribute('pos','PPER');
		$pronounNode->setAttribute('cas','Nom');
		my $finVerb;
		if ($node->getAttribute('pos') =~ m/FIN/) {
			$finVerb = $node;
		}
		else {
			my @children = $node->findnodes('descendant::NODE');
			foreach my $child (@children) {
				if ($child->getAttribute('pos') =~ m/V.FIN/ or $child->getAttribute('spos') =~ m/V.FIN/) {
				# "spos" for verbs from periphrase whose pos tag has been switched; example: seguir|estar +gerund, where seguir|estar becomes an adverb
					$finVerb = $child;
					last;
				}
			}
		}
		if ($finVerb) {
			print STDERR "finite verb form " . $finVerb->getAttribute('sform') ."\n";
			my $verbMorph = "3.Sg.Pres.Ind";		# arbitrary default value
			if ($finVerb->hasAttribute('mi')) {
				$verbMorph = $finVerb->getAttribute('mi');
			}
			else {
				print STDERR $finVerb->serialize."Finite verb node has no morphological information (mi attribute)...
						this shouldn't be the case! Please check your diccionary and transfer rules\n";
			}
			my ($pers,$num) = split(/\./,$verbMorph);
			my $pronounMorph = $pers . "." . $num;
			$pronounNode->setAttribute('mi',$pronounMorph);
			$node->parentNode->addChild($pronounChunk);
			$pronounChunk->addChild($pronounNode);
		}
	}
}

1;
