#!/usr/bin/perl

# use semantic information in xml to disambiguate synonyms
# path to semantic disambiguation file is expected to be included in the config file
# format of semantic disambigution file, tab separated:
# source-lemma target-lemma	condition (optional) probability (between 0-1, in case condition is not met or not given)
# example (Spanish lemma 'viejo' can be translated into Quechua as 'mawk'a' (things), 'machu' (male person) or 'paya' (female person))
# viejo	paya	my.smi=AQ0F.+&&parent.sem=[+Fem]	0.2
# viejo	machu	my.smi=AQ0M.+&&parent.sem=[+Masc]	0.3
# viejo	mawk'a	-	0.5

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

my %hash    = %{ retrieve("parameters") };
my $lexSelFile = $hash{"LexSelFile"}
  or die "Lexical selection file not specified in config!";
open LEXSELFILE, "< $lexSelFile" or die "Can't open $lexSelFile : $!";

my %lexSel = ();

#read semantic information from file into a hash (lemma, semantic Tag,  condition)
while (<LEXSELFILE>) {
	chomp;
	s/#.*//;     # no comments
	s/^\s+//;    # no leading white
	s/\s+$//;    # no trailing white
	next if /^$/;	# skip if empty line
	my ( $srclem, $trgtlem, $condition, $prob ) = split( /\s*\t+\s*/, $_, 4 );

	$condition =~ s/\s//g;	# no whitespace within condition
	# assure key is unique, use srclemma:trgtlemma as key
	my $key = "$srclem:$trgtlem";  
	my @value = ( $condition, $prob );
	$lexSel{$key} = \@value;

}

	my $parser = XML::LibXML->new("utf8");
	my $dom    = XML::LibXML->load_xml( IO => *STDIN );

	# get all nodes (NODE) with ambigous translations (SYN)
	foreach my $parentnode ( $dom->getElementsByTagName('NODE')) 
	{
		my @childnodes = $parentnode->getChildrenByLocalName('SYN');
		
		# create hash to store values of synonyms of this particular node
		my %nodehash =();
		
		
		# get all ambigous translations
		foreach my $synnode (@childnodes) 
		{
					
				#if node has attribute slem, read source lemma
				if ( $parentnode->hasAttribute('slem'))  
				{
					my $slem = $parentnode->getAttribute('slem');
					my $lem  = $synnode->getAttribute('lem');
					my $key  = "$slem:$lem";
					
			
					# get entry in the lexical disambiguation file for this lemma
					if (exists( $lexSel{$key} )) 
					{
					# get condition for selection	
					my $nodeCondition = @{ $lexSel{$key} }[0];    		

					my @conditions = &splitConditionsIntoArray($nodeCondition);

					# evaluate condition(s) to true or false
					my $result= &evalConditions(\@conditions,$parentnode);
				
					# keep results for all synonyms in a hash for the node, key = target lemma
					my @synvalue = ( $result,  @{ $lexSel{$key} }[1]);
						$nodehash{$lem} = \@synvalue;
					
					}
				}	
				else
				{last;}			
		}
		
		# if this is a NODE with SYN children (synonyms)	
		if (%nodehash)
		{
			# sort hash by probabilities 
			my @keys = sort {$nodehash{$b}[1] <=> $nodehash{$a}[1]} keys %nodehash;
		
			# take the first translation with a true condition, if no translation has a condition that
			# evaluated to true, take the translation with the highest probability value
			my $bestTranslation = @keys[0];
			foreach my $key(@keys)
			{
				if($nodehash{$key}[0]==1)
				{
					$bestTranslation = $key;
					last;
				}
			}
			
			# delete the attributes of the first SYN child that have been "copied" into the parent NODE
			my $firstsyn = $childnodes[0];
			my @synattrlist = $firstsyn->attributes();
			foreach my $synattr (@synattrlist)
			{
				$parentnode->removeAttribute($synattr->nodeName);
			}
			# delete all SYN childs of NODE that do not contain the lem=bestTranslation
			# in case there is more than one SYN with this lemma: copy values of the first to node, 
			# but keep other SYN's, don't delete them
			my $bestTranslationIsSetInNode=0;
			foreach my $synnode (@childnodes) 
			{
				#print $synnode->getAttribute('lem');
				if($synnode->getAttribute('lem') eq $bestTranslation && !$bestTranslationIsSetInNode)
				{
					$bestTranslationIsSetInNode =1;
					my @attributelist = $synnode->attributes();
					foreach my $attribute (@attributelist)
					{
						my $val = $attribute->getValue();
						my $attr = $attribute->nodeName;
						$parentnode->setAttribute($attr,$val);
						$parentnode->removeChild( $synnode );
					}
				}
				elsif($synnode->getAttribute('lem') ne $bestTranslation )
				{
					$parentnode->removeChild( $synnode );
				}
			}
		}	
	}

# print new xml to stdout
my $docstring = $dom->toString;
print STDOUT $docstring;
