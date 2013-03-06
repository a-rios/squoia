#!/usr/bin/perl

# insert semantic information from semantic dictionary into xml
# path to semantic dictionary is expected to be included in the config file
# format of semantic dictionary, tab separated:
# lemma	semanticTag condition (where to insert semantic tag, can be a perl regular expression)
# example (English with Penn Treebank tagset, read: if lemma is 'woman', insert sem=[+Fem] if pos is NN):
# woman	[+Fem]	pos=NN
# run	[+Mov]	pos=V.+	


#use utf8; 
#use encoding 'utf8';

use utf8;                  # Source code is UTF-8
use open ':utf8';
use Storable; # to retrieve hash from disk
#binmode STDIN, ':utf8';
#binmode STDOUT, ':utf8';
use strict;
use XML::LibXML;
use File::Spec::Functions qw(rel2abs);
use File::Basename;
my $path = dirname(rel2abs($0));
require "$path/util.pl";


# retrieve hash with config parameters from disk, get path to file with semantic information
eval
{
	retrieve('parameters');

} or die "No parameters defined. Run readConfig.pl first!";

	my %hash = %{ retrieve("parameters") }; 
my $semanticDictFile= $hash{"SemFile"} or die "Semantic dictionary not specified in config!";
open SEMFILE, "< $semanticDictFile" or die "Can't open $semanticDictFile : $!";

my %semanticLexicon =();

 #read semantic information from file into a hash (lemma, semantic Tag,  condition)
 while(<SEMFILE>)
 {
 	chomp;
 	s/#.*//;     # no comments
	s/^\s+//;    # no leading white
	s/\s+$//;    # no trailing white
	my ($lemma, $semTag ,$condition ) = split( /\s*\t+\s*/, $_, 3 );
	my @value = ($semTag, $condition);
	$semanticLexicon{$lemma} = \@value;
	#print "$lemma:$semanticLexicon{$lemma}\n";
	
}
#read xml from STDIN
my $parser = XML::LibXML->new({encoding => 'utf-8'});
my $dom    = XML::LibXML->load_xml( IO => *STDIN);

foreach my $sentence  ( $dom->getElementsByTagName('SENTENCE'))
	{	
		my @NODES = $sentence->findnodes('descendant::NODE');
		push(@NODES,$sentence->findnodes('descendant::SYN'));
		foreach my $wordnode (@NODES) 
		{
			#print 'bla';
			if ( $wordnode->hasAttribute('lem'))      #if node has attribute lem, read lemma
			{
				my $lem  = $wordnode->getAttribute('lem');
				if (exists($semanticLexicon{$lem}))# if there's an entry in the semantic lexicon for this lemma
				{
					# get condition(s) for insertion, split, remove empty fields
					my $nodeCondition = @{$semanticLexicon{$lem}}[1]; 

					my @conditionsWithEmptyfields = split( /(\!|&&|\|\||\)|\()/, $nodeCondition);

					#remove empty fields resulted from split
					my @conditions = grep {$_} @conditionsWithEmptyfields; 

					my $result= &evalConditions(\@conditions,$wordnode);

					if ($result)
					{
						$wordnode->setAttribute('sem', @{$semanticLexicon{$lem}}[0]);
					}		
				} 
			}
		}
	}

# print new xml to stdout
my $docstring = $dom->toString(1);
#print $dom->actualEncoding();
print STDOUT $docstring;
