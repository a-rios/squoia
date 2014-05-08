#!/usr/bin/perl

# The lexical transfer module does not allow to translate one lemma into 2
# or more lemmas in the target language. But there are cases, where this is necessary
# e.g. Spanish 'chismear' (to gossip) translates to Quechua
# as 'simi apaykachay' (lit. to bring the word). In the bilingual dictionary, the attribute
# 'split', is expected.
#The lemmas in the attribute 'lem' are expected to be separated by '_'
# (e.g. 'simi_apaykachay'). The morphology tags for the individual lemmas need to be indicated
# in an attribute 'complex_mi' and should be separated by '_' as well (e.g. 'Noun_Verb').
# Example entry with 'chismear' (Spanish/Quechua):
# <l>chismear</l><r>simi_apa<s n="split"/><s n="complex_mi"/>NRoot_VRoot+Intrup</r>
# Also, the attribute names for morphology is expected to be 'mi' and for lemmas 'lem'.
# Input: xml output from lexical transder module from Matxin/Apertium (LT)
# Output: same xml, but every node contains exactly one lemma

use utf8;
use open ':utf8';
#binmode STDIN, ':utf8';
#binmode STDOUT, ':utf8';
use XML::LibXML;
use File::Spec::Functions qw(rel2abs);
use File::Basename;
my $path = dirname(rel2abs($0));
require "$path/util.pl";
use strict;

my $parser = XML::LibXML->new("utf8");
my $dom    = XML::LibXML->load_xml( IO => *STDIN );

my $maxNodeRef = &getMaxNodeRef($dom);

foreach my $wordnode ( $dom->getElementsByTagName('NODE') ) {
	if ( $wordnode->hasAttribute('split') and $wordnode->getAttribute('split') eq "yes")      #if node has an attribute split=yes, append sibling node
	{
		my %attrvalues;
		$wordnode->removeAttribute('split');
		my @lemmas     = split( _, $wordnode->getAttribute('lem') );
		# how many new nodes have to be generated (=number of lemmas)
		my $numberOfNewNodes = @lemmas;
		print STDERR $wordnode->getAttribute('lem')." split into $numberOfNewNodes nodes\n";
		my @attributes = $wordnode->attributes();
		foreach my $attribute (@attributes) {
			my $attrName = $attribute->nodeName;
			if ($attrName =~ /^complex\_(.+)/) {
				my $attr = $1;
				my @values = split( _, $wordnode->getAttribute($attrName) );
				# check if number of lemmas and values of the complex attribute is the same
				my $test = @values;
				if ($numberOfNewNodes != $test)
				{
					my $sentenceNode = @{$wordnode->findnodes('ancestor::SENTENCE[1]')}[0];
					die "number of lemmas in ".$wordnode->getAttribute('lem')." does not correspond to number of $attrName tags ($test) in node "
					.$wordnode->getAttribute('ref')." in sentence "
					. $sentenceNode->getAttribute('ref')."\n";
				}
				# remove attributes that are not needed
				$wordnode->removeAttribute($attrName);

				# save the array of values for this attribute into a hash
				$attrvalues{$attr} = \@values;
			}
		}
		for ( my $i = 1 ; $i < $numberOfNewNodes ; $i++ ) {
			# make clones of the node to be split up
			my $newWord = $wordnode->cloneNode('0');
			$newWord->setAttribute( 'clone', $i );
#			$newWord->setAttribute( 'ref', "-".$i );
			$newWord->setAttribute( 'ref', $maxNodeRef+$i );
			$newWord->setAttribute( 'lem', $lemmas[$i] );
			$newWord->setAttribute( 'delete', 'no' );
			foreach my $attr (keys %attrvalues) {
				my $values = $attrvalues{$attr};
				$newWord->setAttribute( $attr, @{$values}[$i] );
			}
			#insert new node after actual node
			my $parentNode = $wordnode->parentNode;
			$parentNode->insertAfter( $newWord, $wordnode );
		}
		# correct attributes in original cloned node
		$wordnode->setAttribute( 'lem', $lemmas[0] );
		foreach my $attr (keys %attrvalues) {
			my $values = $attrvalues{$attr};
			$wordnode->setAttribute( $attr, @{$values}[0] );
		}
	}
}
# print new xml to stdout
my $docstring = $dom->toString(1);
print STDOUT $docstring;

