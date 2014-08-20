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

package squoia::prepositionDisamb;
use utf8;
use strict;

sub main{
	my $dom = ${$_[0]};
	my %prepSel = %{$_[1]};
	my $verbose = $_[2];

	print STDERR "#VERBOSE ". (caller(0))[3]."\n" if $verbose;
	
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

				my @conditions = squoia::util::splitConditionsIntoArray($translationCondition);
				#print STDERR "@conditions\n" if $verbose;

				# evaluate condition(s) to true or false
				my $result= squoia::util::evalConditions(\@conditions,$wordnode);
				#print STDERR "result: $result\n" if $verbose;
				
				# save result of evaluation as value of condition
				@$target[3] = $result;
				#print "$translationCondition  $result\n";

			}	
			
							
			# Sorted by condition value, then default
			my @FullSort = sort {$b->[3] cmp $a->[3]
 						 ||
 					 $a->[2] cmp $b->[2]
							} @$translationsref;
			#for(my $j; $j<scalar(@FullSort);$j++){for(my $i;$i<4;$i++){print STDERR $FullSort[$j][$i]."\n" if $verbose;}}
		
			#write specified attribute of the best translation into xml node
			my $trgt = $FullSort[0][0];
			if ($verbose){
				print STDERR "prepdisamb rule: ";
				for (my $i;$i<4;$i++) {
					print STDERR $FullSort[0][$i]." ";
				}
				print STDERR "\n";
			}
			my @pairs = split(',',$trgt);
			foreach my $pair (@pairs) {
				my ($trgtattr, $trgtprep) = split('=',$pair);
				print STDERR "preposition " . $wordnode->getAttribute('adpos') . " $trgtattr => $trgtprep\n" if $verbose;
				$wordnode->setAttribute($trgtattr, $trgtprep);
			}
		}
	}
#	# print new xml to stdout
#	my $docstring = $dom->toString;
#	print STDOUT $docstring;
}

1;
