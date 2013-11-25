#!/usr/bin/perl

# use information in preposition dictionary to disambiguate the translation of preposition/case
# path to semantic disambiguation file is expected to be included in the config file
# format of preposition disambigution file, tab separated:
# source-preposition/case target-preposition/case	condition  default (+/-)
# example (Spanish preposition 'de' can be translated into Quechua as gentive or ablative. 
# Rule 1 takes genitive if the in the parent chunk has an attribute si=sp-mod and the chunk thats the 
# head of this chunk (chunkgrandparent) has an attribute headsmi=/NC/. In other words, if the
# noun that is the head of this chunk is a noun, take genitive (possessum), if it's a verb,
# ablative, e.g. [la casa [de Juan]], casa is the head of the 'chunkparent' (possessum).
# src   trgt    condition										default (+/-)
# de	+Gen	chunkparent.si=sp-mod&&chunkgrandparent.headsmi=/NC/	-  	
# de 	+Abl	chunkgrandparent.headpos=/V.+/							+


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
 my $prepFile = $hash{"PrepFile"}
  or die "Preposition disambiguation file not specified in config!";
open PREPFILE, "< $prepFile" or die "Can't open $prepFile : $!";

my %prepSel = ();


#read information from file into a hash (source-prep/case, target prep/case,  condition, probability)
while (<PREPFILE>) {
	chomp;
	s/#.*//;     # no comments
	s/^\s+//;    # no leading white
	s/\s+$//;    # no trailing white
	next if /^$/;	# skip if empty line
	my ( $srcprep, $trgtprep, $condition, $isDefault ) = split( /\s*\t+\s*/, $_, 4 );


	# read into hash, key is srcprep, for each key define a two-dimensional array of
	# translations, whose element are arrays of the values read in from the prep file
	my @value = ($trgtprep, $condition, $isDefault );

	if (!exists( $prepSel{$srcprep} )) 
	{
		my @translations=();
		push(@translations,\@value);	
		$prepSel{$srcprep} = \@translations;
	}
	else
	{
		push(@{ $prepSel{$srcprep} },\@value);	
		#print "@{ $prepSel{$srcprep} }[1]";
	}
}

	my $parser = XML::LibXML->new("utf8");
	my $dom    = XML::LibXML->load_xml( IO => *STDIN );

	# get all nodes (NODE) with prepositions on source side (prep=srcprep)
	foreach my $wordnode ( $dom->getElementsByTagName('NODE')) 
	{
		if ( $wordnode->hasAttribute('adpos')) 
			{
			#get value of prep, this is the key for prepSel to access its possible transations
			my $translationsref = $prepSel{$wordnode->getAttribute('adpos')};				
			
			foreach my $target (@$translationsref)
			{
		 	# @$target[0] = target preposition/case, @$target[1] = condition, "@$target[2] = default yes/no
#       					 	print "@$target[0]: @$target[1]\n";
#       					 	foreach $t (@$target)
#       					 	{
#       					 		print "$t\n";
#       					 	}

				# get condition for translation	
				my $translationCondition =  @$target[1];    		

				my @conditions = &splitConditionsIntoArray($translationCondition);
				print STDERR "@conditions\n";

				# evaluate condition(s) to true or false
				my $result= &evalConditions(\@conditions,$wordnode);
				#print STDERR "result: $result\n";
				
				# save result of evaluation as value of condition
				@$target[3] = $result;
				#print "$translationCondition  $result\n";

			}	
			
							
			# Sorted by condition value, then default
			my @FullSort = sort {$b->[3] cmp $a->[3]
 						 ||
 					 $a->[2] cmp $b->[2]
							} @$translationsref;				
			print STDERR "#############\n";
			for(my $j; $j<scalar(@FullSort);$j++){for(my $i;$i<4;$i++){print STDERR $FullSort[$j][$i]."\n";}}
			print STDERR "#############\n";
		
			#write specified attribute of the best translation into xml node
			my $trgt = $FullSort[0][0];
			my @pairs = split(',',$trgt);
			foreach my $pair (@pairs) {
				my ($trgtattr, $trgtprep) = split('=',$pair);
				print STDERR "preposition $trgtattr => $trgtprep\n";
				$wordnode->setAttribute($trgtattr, $trgtprep);
			}
		}
	}
# print new xml to stdout
my $docstring = $dom->toString;
print STDOUT $docstring;
