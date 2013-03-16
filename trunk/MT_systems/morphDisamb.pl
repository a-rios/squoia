#!/usr/bin/perl

# disambiguate morphologically ambigous translations
# path to morphologic/pos disambiguation file is expected to be included in the config file
# format of morphologic disambigution file, tab separated:
# source-lemma target-morph/pos	condition (optional) probability (between 0-1, in case condition is not met or not given)
# example (Spanish lemma 'ebrio' can be translated into Quechua as 'machaq' (a drinker) or 'machasqa' (drunk))
# ebrio	my.mi=VRoot+Ag	my.smi=/NC/	0.3
# ebrio	my.mi=VRoot+Perf	my.smi=/AQ/ 0.7

use utf8;
use Storable;    # to retrieve hash from disk
use open ':utf8';
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
my $morphSelFile = $hash{"MorphSelFile"}
  or die "Morphological selection file not specified in config!";
open MORPHSELFILE, "< $morphSelFile" or die "Can't open $morphSelFile : $!";

my %morphSel = ();

#read semantic information from file into a hash (lemma, semantic Tag,  condition)
while (<MORPHSELFILE>) {
	chomp;
	s/#.*//;     # no comments
	s/^\s+//;    # no leading white
	s/\s+$//;    # no trailing white
	next if /^$/;	# skip if empty line
	my ( $srcNodeConds, $keepOrDelete, $trgtMI, $conditions, $prob ) = split( /\s*\t+\s*/, $_, 5 );

	$conditions =~ s/\s//g;	# no whitespace within condition
	# assure key is unique, use srclemma:trgtlemma as key
	my $key = "$srcNodeConds---$trgtMI";
	my @value = ( $conditions, $keepOrDelete, $prob );
	$morphSel{$key} = \@value;

}
my @allNodeConditions = keys(%morphSel);
my $parser = XML::LibXML->new("utf8");
my $dom    = XML::LibXML->load_xml( IO => *STDIN );

	# get all nodes (NODE) with ambigous translations (SYN)
	foreach my $node ( $dom->getElementsByTagName('NODE')) 
	{
		my @SYNnodes = $node->getChildrenByLocalName('SYN');
		
		# create hash to store values of synonyms of this particular node
		my %nodehash =();
		
		# if this node has SYN nodes,
		# check if one of the node conditions apply to this node
		if(scalar(@SYNnodes)>0)
		{
			print STDERR "Disambiguating morphological translation options in sentence: ".$node->findvalue('ancestor::SENTENCE/@ref')."\n";
			foreach my $ruleskey (@allNodeConditions)
				{				
					my ($nodeCond, $trgtMI) = split('---',$ruleskey);		  
					my @nodeConditions = &splitConditionsIntoArray($nodeCond);

					# evaluate all head condition(s), if true for this node, check if the childnode conditions apply
					if(&evalConditions(\@nodeConditions,$node))
					{
							# check for each target conditions if one of the matching rules applies
							# if yes, check if k=keep or d=delete 
							# -> if keep, we're done, delete all other nodes and make this the only translation option
							# -> if delete, delete and look at next SYN node
							
							# get target conditions
							my $trgtConds = @{ $morphSel{$ruleskey}}[0];
							my @trgtConditions = &splitConditionsIntoArray($trgtConds);
							
							if(&evalConditions(\@trgtConditions,$node))
							{
								#keep or delete?
								my $keepOrDelete = @{ $morphSel{$ruleskey}}[1];
								my @targetMIs = split(',',$trgtMI);
								#if more than one target mi, can only be delete, not keep
								if(scalar(@targetMIs)>1 && $keepOrDelete eq 'k')
								{
									print STDERR "error: more than one translation option with target mi=$trgtMI!\n Something's wrong here, won't disambiguate.";
								}
								# else, only one target mi with k or d, or more than one with d
								else
								{
									foreach my $trgt (@targetMIs)
									{
										my $xpathstring= 'child::SYN[@mi="'.$trgt.'"]';
										# find synnode with this 'mi', should only be one!
										my @matchingSyns = $node->findnodes($xpathstring);
										if(scalar(@matchingSyns)>1)
										{
											print STDERR "error: more than one translation option with target mi $trgtMI!\n Something's wrong here, won't disambiguate.";
										}
										elsif(scalar(@matchingSyns) ==1)
										{
											my $matchingtranslation = @matchingSyns[0];
											my @matchingtranslationAttributes = $matchingtranslation->attributes();
									
								 		   	if($keepOrDelete eq 'k')
								   			{
								    			# delete the attributes of the first SYN child that have been "copied" into the parent NODE
												my $firstsyn = $SYNnodes[0];
												my @synattrlist = $firstsyn->attributes();
												foreach my $synattr (@synattrlist)
												{
													unless($synattr =~ /ref|slem|smi|sform|UpCase|complex_mi/)
													{
													$node->removeAttribute($synattr->nodeName);
													}
												}
												# fill in attributes of best translation
								    			foreach my $bestattr (@matchingtranslationAttributes)
								    			{
								    				my ($attr,$value) = split('=',$bestattr);
								    				$value =~ s/"//g;
								    				$attr =~ s/\s//g;
								    				$node->setAttribute($attr, $value);
								    			}
								    			#delete all SYN nodes
								    			foreach my $syn (@SYNnodes)
								    			{
								    				$node->removeChild($syn);
								    			}
								   			}
								   			elsif($keepOrDelete eq 'd')
								   			{
								    			$node->removeChild($matchingtranslation);
								    		}
								   			else
								   			{
								    			print STDERR "error: invalid option $keepOrDelete! Valid options are: k (keep) or d (delete). Won't disambiguate.";
								   			 }
										}
									}
								}
							}
						}
					}
			}
	}

# print new xml to stdout
my $docstring = $dom->toString;
print STDOUT $docstring;
