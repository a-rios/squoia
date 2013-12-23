#!/usr/bin/perl

use strict;
use utf8;
use Storable;    # to retrieve hash from disk
use open ':utf8';
binmode STDIN, ':utf8';
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

my %FLdix = %{retrieve('../FLdix')};
my %Morfodix = %{retrieve('../Morfodix')};
# columns:
# 0:word form 1: lc/uc 2-6: lemmas, 7-14: tags, 15: class

## wapiti format, version 1
#while(<>){
#	if(/^\s*$/){
#		print "\n";
#	}
#	else
#	{
#		my @rows = split('\t');
#		print lc(@rows[0])."\t";
#		
#		if(@rows[0] eq lc(@rows[0])){
#			print "lc\t";
#		}
#		else{
#			print "uc\t";
#		}
#		# get lemmas & tags
#		my $entry = $FLdix{lc(@rows[0])};
#		if(!$entry){
#			print STDERR "looked in morfo dix for ".lc(@rows[0])."\n";
#			$entry = $Morfodix{lc(@rows[0])};
#		}
#		
#		my $tagcount =0;
#		# check if number of tags > 8 (from FL): -> in this case, unknown word, set all to ZZZ
#		if(scalar(keys %{$entry})>8)
#		{ 
#			my $morfcount=0;
#			while($morfcount<14){
#				print "ZZZ\t";
#				$morfcount++;
#			}
#			# need to disambiuate: yes
#			print "1\t";
#		}
#		
#		else
#		{
#			my $lemcount = 0;
#			my %tags;
#			my %lems;
#			foreach my $analysis (keys %{$entry}){
#				my ($lem, $tag) = split('##', $analysis);
#				$tags{$tag}=1;
#				$lems{$lem}=1;
#			}
#			
#			foreach my $lem (keys %lems){
#				print "$lem\t";
#				$lemcount++;
#			}
#			
#			while($lemcount<5){
#				print "ZZZ\t";
#				$lemcount++;
#			}
#		
#			foreach my $tag (keys %tags){
#				print "$tag\t";
#				$tagcount++;
#			}
#			# if only one tag set disamb to 0, else 1
#			my $needToDisamb=0;
#			if($tagcount>1){
#				$needToDisamb=1;
#			}
#			
#			while($tagcount<8){
#				print "ZZZ\t";
#				$tagcount++;
#			}
#			
#			print "$needToDisamb\t";
#		}
#		print "@rows[-1]";
#		#print "\n";
#		
#	}
#}

# wapiti format, version 2
while(<>){
	if(/^\s*$/){
		print "\n";
	}
	else
	{
		my @rows = split('\t');
		print lc(@rows[0])."\t";
		
		if(@rows[0] eq lc(@rows[0])){
			print "lc\t";
		}
		else{
			print "uc\t";
		}
		# get lemmas & tags
		my $entry = $FLdix{lc(@rows[0])};
		if(!$entry){
			#print STDERR "looked in morfo dix for ".lc(@rows[0])."\n";
			$entry = $Morfodix{lc(@rows[0])};
		}
		
		# check if number of tags > 8 (from FL): -> in this case, unknown word, set all to ZZZ
		if(scalar(keys %{$entry})>8)
		{ 
			my $morfcount=0;
			while($morfcount<16){
				print "ZZZ\t";
				$morfcount++;
			}
			# need to disambiuate: yes
			print "1\t";
		}
		
		else
		{
			my $morfcount = 0;
			foreach my $analysis (keys %{$entry}){
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
			print "$needToDisamb\t";
		}
		print "@rows[-1]";
		#print "\n";

	}
}


#crfsuite format
#while(<>){
#	if(/^\s*$/){
#		print "\n";
#	}
#	else
#	{	
#		my @rows = split('\t');
#		
#		# print label first
#		print "@rows[-1]";
#		
#		print "word[0]=".lc(@rows[0])."\t";
#		
#		if(@rows[0] eq lc(@rows[0])){
#			print "Upcase=0\t";
#		}
#		else{
#			print "Upcase=1\t";
#		}
#		# get lemmas & tags
#		my $entry = $FLdix{lc(@rows[0])};
#	
#		my $lemcount = 0;
#		my %tags;
#		my %lems;
#		foreach my $analysis (keys %{$entry}){
#			my ($lem, $tag) = split('##', $analysis);
#			$tags{$tag}=1;
#			$lems{$lem}=1;
#		}
#		
#		my @lems = keys %lems;
#		for(my $i=0;$i<scalar(@lems);$i++ )
#		{
#			my $lem = @lems[$i];
#			print "lem[$i]=$lem\t";
#			$lemcount++;
#		}
#		
#		while($lemcount<5){
#			print "lem[$lemcount-1]=ZZZ\t";
#			$lemcount++;
#		}
#		
#		my $tagcount =0;
#		my @tags = keys %tags;
#		for(my $i=0;$i<scalar(@tags);$i++ ){
#			my $tag = @tags[$i];
#			print "tag[$i]=$tag\t";
#			$tagcount++;
#		}
#		# if only one tag set disamb to 0, else 1
#		my $needToDisamb=0;
#		if($tagcount>1){
#			$needToDisamb=1;
#		}
#		
#		while($tagcount<8){
#			print "tag[$tagcount-1]=ZZZ\t";
#			$tagcount++;
#		}
#		
#		print "disamb=$needToDisamb\t";
#		#print "\n";
#	}
#}