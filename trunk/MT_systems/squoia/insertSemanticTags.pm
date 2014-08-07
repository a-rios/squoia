#!/usr/bin/perl

# insert semantic information from semantic dictionary into xml
# path to semantic dictionary is expected to be included in the config file
# format of semantic dictionary, tab separated:
# lemma	semanticTag condition (where to insert semantic tag, can be a perl regular expression)
# example (English with Penn Treebank tagset, read: if lemma is 'woman', insert sem=[+Fem] if pos is NN):
# woman	[+Fem]	pos=NN
# run	[+Mov]	pos=V.+	

package squoia::insertSemanticTags;

use utf8;                  # Source code is UTF-8
use strict;

my %semanticLexicon =();


sub main{
	my $dom = ${$_[0]};
	%semanticLexicon = %{$_[1]};
	my $verbose = $_[2];

	print STDERR "#VERBOSE ". (caller(0))[3]."\n" if $verbose;
	
	foreach my $sentence  ( $dom->getElementsByTagName('SENTENCE'))
		{	
			#print STDERR "inserting semantic tags in sentence ".$sentence->getAttribute('ref')."\n" if $verbose;
			my @NODES = $sentence->findnodes('descendant::NODE');
			push(@NODES,$sentence->findnodes('descendant::SYN'));
			foreach my $wordnode (@NODES) 
			{
				#print 'bla';
				if ( $wordnode->hasAttribute('lem') ||$wordnode->hasAttribute('slem'))      #if node has attribute lem, read lemma
				{
					my $lem  = $wordnode->getAttribute('lem');
					my $slem = $wordnode->getAttribute('slem');
	
					if ( $wordnode->hasAttribute('lem') && exists($semanticLexicon{$lem})) # if there's an entry in the semantic lexicon for this lemma
					{
						# get condition(s) for insertion, split, remove empty fields
						my $nodeCondition = @{$semanticLexicon{$lem}}[1]; 
	
	#					my @conditionsWithEmptyfields = split( /(\!|&&|\|\||\)|\()/, $nodeCondition);
	#
	#					#remove empty fields resulted from split
	#					my @conditions = grep {$_} @conditionsWithEmptyfields; 
						my @conditions = squoia::util::splitConditionsIntoArray($nodeCondition);
	
						my $result= squoia::util::evalConditions(\@conditions,$wordnode);
	
						if ($result || (scalar(@conditions)==1 && $conditions[0] eq '-') )
						{
							$wordnode->setAttribute('sem', @{$semanticLexicon{$lem}}[0]);
						}		
					} 
					elsif( $wordnode->hasAttribute('slem') && exists($semanticLexicon{$slem}))
					{
						# get condition(s) for insertion, split, remove empty fields
						my $nodeCondition = @{$semanticLexicon{$slem}}[1]; 
	
						my @conditionsWithEmptyfields = split( /(\!|&&|\|\||\)|\()/, $nodeCondition);
	
						#remove empty fields resulted from split
						my @conditions = grep {$_} @conditionsWithEmptyfields; 
	
						my $result= squoia::util::evalConditions(\@conditions,$wordnode);
						if ($result || (scalar(@conditions)==1 && @conditions[0] eq '-') )
						{
							$wordnode->setAttribute('sem', @{$semanticLexicon{$slem}}[0]);
						}
					}
				}
			}
		}
	
	# print new xml to stdout
	#my $docstring = $dom->toString(1);
	#print $dom->actualEncoding();
	#print STDOUT $docstring;
}

1;
