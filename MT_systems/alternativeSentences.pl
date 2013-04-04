#!/usr/bin/perl

# output all alternative sentences after semantic disambiguation
# i.e. the synonyms that have not been explicitly disambiguated could represent true translation alternatives
# in this case, the sentence is duplicated
# no configuration necessary (or is it?)

use utf8;
use Storable;    # to retrieve hash from disk
use open ':utf8';
binmode STDIN, ':utf8';
use XML::LibXML;
use strict;
require "util.pl";


sub getParentSentence{
	my $node = $_[0];

	my $sentparent = @{$node->findnodes('ancestor-or-self::SENTENCE')}[0];
	return $sentparent;
}

sub getSentMaxAlt{
	my $node = $_[0];

	my $maxAlt = 0;
	my $sentnode = &getParentSentence($node);
	my $sentNo = $sentnode->getAttribute('ref');
	my $sentAlt = $sentnode->getAttribute('alt');
	if ($sentAlt) {	# the sentence has already alternatives
		#get the max number of alternatives
		$maxAlt = $sentAlt;
		foreach my $alt ($node->findnodes('//SENTENCE[@ref="'.$sentNo.'"]')) {
			my $altNo = int($alt->getAttribute('alt'));
			if ( $maxAlt <  $altNo) {
				$maxAlt = $altNo;
			}
		}
	}
	else {		# there are no alternatives yet
		# $maxAlt = 0;
	}
	
	return $maxAlt;
}

sub addClonedSentence{
	my $sentnode = $_[0];
	my $sentAlt = $_[1];

	my $newSent = $sentnode->cloneNode(1); # deep=true=1
	$newSent->setAttribute('alt',$sentAlt);
	$sentnode->addSibling($newSent);
	return $newSent;
}


my $dom    = XML::LibXML->load_xml( IO => *STDIN );

my $nofsent = int(@{$dom->findnodes('//SENTENCE')});
print STDERR "$nofsent sentences before duplication\n";

while ($dom->findnodes('//SYN')) {
# get all nodes (NODE) with ambigous translations (SYN)
#foreach my $node ( $dom->findnodes('//NODE[SYN]')) {
	my $node = @{$dom->findnodes('//NODE[SYN]')}[0];
		
	my $nodepath = $node->nodePath();
	#print STDERR "$nodepath\n";

	# delete the attributes of the first SYN child that have been "copied" into the parent NODE
	my $firstsyn = @{$node->getChildrenByLocalName('SYN')}[0];
	my @synattrlist = $firstsyn->attributes();
	foreach my $synattr (@synattrlist)
	{
		$node->removeAttribute($synattr->nodeName);
	}

	my $cloneNode = $node->cloneNode(1);
	# delete the synonyms from the original node
	foreach my $syn ($node->getChildrenByLocalName('SYN')) {
		$node->removeChild($syn);
	}
	

	my $sentnode = &getParentSentence($node);
	my $maxAlt = &getSentMaxAlt($sentnode);

	if ($maxAlt == 0) {	# there are no alternatives yet
		# set sentence attribute "alt"
		$sentnode->setAttribute('alt',"original");
	}
	my @synonyms = $cloneNode->getChildrenByLocalName('SYN');
	# duplicate sentence for all synonyms
	foreach my $syn (@synonyms) {
		$maxAlt++;
		print STDERR "synonym ". $syn->toString() ."\n\n";
		# copy whole sentence
		my $newSent = &addClonedSentence($sentnode,$maxAlt);
		my $newpath = $nodepath;
		$newpath =~ s/^.*SENTENCE(\[\d+\])?\///;
		#print STDERR "new path $newpath\n";
		my $newnode = @{$newSent->findnodes($newpath)}[0];
		# set the right attributes
		my @attributelist = $syn->attributes();
		foreach my $attribute (@attributelist) {
			my $val = $attribute->getValue();
			my $attr = $attribute->nodeName;
			$newnode->setAttribute($attr,$val);
		}
	}
	$node->replaceNode($cloneNode);
	my $nodepath = $node->nodePath();
	#print STDERR "node path after duplication\n$nodepath\n\n";
	my $corpus = $sentnode->parentNode;
	$corpus->removeChild($sentnode);
	#last;
#}
}

my $newnofsent = int(@{$dom->findnodes('//SENTENCE')});
print STDERR "$newnofsent sentences after duplication\n";

# number alternative sentences
for (my $index=1;$index le $nofsent;$index++) {
	my $nofalt=0;
	foreach my $sent ($dom->findnodes('//SENTENCE[@ref="'.$index.'"]')) {
		$sent->setAttribute('alt',++$nofalt);
	}
	print STDERR "sentence $index has $nofalt alternatives\n";
}

# print new xml to stdout
my $docstring = $dom->toString;
print STDOUT $docstring;
