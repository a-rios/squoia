#!/usr/bin/perl

use strict;
use utf8;
use Storable;    # to retrieve hash from disk
use open ':utf8';
binmode STDIN, ':utf8';
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");


my %lemmas;
my @forms;

# new version (new config), lemma/tag pairs
while(<>){
	if(/^\s*$/){
		print "\n";
	}
	else
	{
		
		my ($form, @entries) = split(/\s/);
	   
		print lc($form)."\t";
		if($form eq lc($form)){
				print "lc\t";
			}
			else{
				print "uc\t";
			}
	 
	   my $nbrOfEntries =0;
	
	   my @morfos;
	   for (my $i=0; $i<scalar(@entries); $i=$i+3)
	   {
			my $lemma = @entries[$i];
			my $tag = @entries[$i+1];
			my $analyisis = $lemma."##".$tag;
			push(@morfos, $analyisis);
			$nbrOfEntries++;
		}
		
		
		# check if number of tags > 8: -> in this case, unknown word, set all to ZZZ
		if(scalar(@morfos)>8)
		{ 
			my $morfcount=0;
			while($morfcount<16){
				print "ZZZ\t";
				$morfcount++;
			}
			# need to disambiuate: yes
			print "1\n";
		}
		
		
		else
		{
			my $morfcount = 0;
			foreach my $analysis (@morfos){
				my ($lem, $tag) = split('##', $analysis);
				print "$lem\t$tag\t";
				$morfcount+=2;
			}
			
			
		
			# if only one tag set disamb to 0, else 1
			my $needToDisamb=0;
			if($morfcount>2){
				$needToDisamb=1;
			}
			
			while($morfcount<16){
				print "ZZZ\t";
				$morfcount++;
			}
			print "$needToDisamb";
			# if only one tag and it's NOT Z -> already print label
			if($needToDisamb == 0){
				my ($lem, $tag) = split('##', @morfos[0]); 
				unless($tag eq 'Z' or $tag =~/^NP/){
					print "\t$tag"
				}
			}
			# TODO!
			# if this is a locucion: let freeling decide!
			print "\n";
		}
	

	}
}

# old config
#while (<>) 
#{
#	if(/^\s*$/){
#		print "\n";
#	}
#	else
#	{
#	   	my ($form, @entries) = split(/\s/);
#	   
#		print lc($form)."\t";
#		if($form eq lc($form)){
#				print "lc\t";
#			}
#			else{
#				print "uc\t";
#			}
#	 
#	   my $nbrOfEntries =0;
#	
#	   my @morfos;
#	   for (my $i=0; $i<scalar(@entries); $i=$i+3)
#	   {
#			my $lemma = @entries[$i];
#			my $tag = @entries[$i+1];
#			my $analyisis = $lemma."##".$tag;
#			push(@morfos, $analyisis);
#			$nbrOfEntries++;
#		}
#	
#	  #  print "@entries, $nbrOfEntries, ".scalar(@morfos)."\n";
#		my $printedLems="";
#		my $printedTags="";
#		my $lemcount = 0;
#		my $tagcount =0;
#		
#		
#		# check if number of tags > 8: -> in this case, unknown word, set all to ZZZ
#		if(scalar(@morfos)>8)
#		{ 
#			my $morfcount=0;
#			while($morfcount<13){
#				print "ZZZ\t";
#				$morfcount++;
#			}
#			# need to disambiuate: yes
#			print "1\n";
#		}
#		else
#		{
#			# print Lems
#			foreach my $analysis (@morfos)
#			{
#		   		 my ($lem, $tag) = split('##', $analysis);
#				 unless($printedLems =~ /\Q#$lem#\E/){
#				 	print "$lem\t";
#				 	$printedLems = $printedLems."#$lem#";
#				 	$lemcount++;
#				 }
#				
#			}
#			while($lemcount<5){
#				print "ZZZ\t";
#				$lemcount++;
#			}
#			# print Tags
#			my $needToDisamb=0;
#			foreach my $analysis (@morfos)
#			{
#		   		 my ($lem, $tag) = split('##', $analysis);
#				 unless($printedTags =~ /\Q#$tag#\E/){
#				 	print "$tag\t";
#				 	$printedTags = $printedTags."#$tag#";
#				 	$tagcount++;
#				 }
#				if($tagcount>1){
#					$needToDisamb=1;
#				}
#			}
#			while($tagcount<8)
#			{
#				print "ZZZ\t";
#				$tagcount++;
#			}
#			print $needToDisamb."\n";
#		}
#	}
#}
