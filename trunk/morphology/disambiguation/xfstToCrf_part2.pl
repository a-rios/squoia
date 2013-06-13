#!/usr/bin/perl

use strict;
use open ':utf8';
binmode STDIN, ':utf8';
binmode STDERR, ':utf8';
binmode STDOUT, ':utf8';

# check if paramenter was given, either:
# -train (disambiguated input, add class in last row)
# -test (input to be disambiguated, leave last row empty)

my $num_args = $#ARGV + 1;
if ($num_args > 1) {
  print STDERR "\nUsage:  perl xfstToCrf.pl -test/-train\n";	
  print STDERR "-test/-train is optional, default is -test\n";	
  exit;
}

my $mode = $ARGV[0];
unless($mode eq '-test' or $mode eq '-train' or !$mode){
	print STDERR "\nUsage:  perl xfstToCrf.pl -test/-train\n";	
  	print STDERR "-test/-train is optional, default is -test\n";	
  	exit;
}

my @words;
my $newWord=1;
my $index=0;

my @words;
my $newWord=1;
my $index=0;

while(<STDIN>){
	
	if (/^$/)
	{
		$newWord=1;
	}
	else
	{	
		my ($form, $analysis) = split(/\t/);
	
		my ($pos) = $analysis =~ m/(ALFS|CARD|NP|NRoot|Part|VRoot|PrnDem|PrnInterr|PrnPers|SP|\$)/ ;
		
		my ($root) = $analysis =~ m/^([^\[]+?)\[/ ;
		#print "$root\n";
		
		if($pos eq ''){
			if($form eq '#EOS'){
				$pos = '#EOS';
			}
			else{
				$pos = "ZZZ";
			}
		}
		
		my @morphtags =  $analysis =~ m/(\+.+?)\]/g ;
	
		#print "$form: $root morphs: @morphtags\n";
		my %hashAnalysis;
		$hashAnalysis{'pos'} = $pos;
		$hashAnalysis{'morph'} = \@morphtags;
		$hashAnalysis{'string'} = $_;
		$hashAnalysis{'root'} = $root;
    
		if($newWord)
		{
			my @analyses = ( \%hashAnalysis ) ;
			my @word = ($form, \@analyses);
			push(@words,\@word);
			$index++;
		}
		else
		{
			my $thisword = @words[-1];
			my $analyses = @$thisword[1];
			push(@$analyses, \%hashAnalysis);
		}
		$newWord=0;	
 }
	
}

# if a word has more than one analysis that differ only in length of the root by 1, and last letter is -q/-y/-n 
# delete the one with the shorter root (e.g. millay -> milla -y/millay, qapaq-> qapa-q/qapaq, allin -> alli -n/ allin)
foreach my $word (@words){
	my $analyses = @$word[1];
	my $form = @$word[0];
	
	if(scalar(@$analyses)>1)
	{
		for(my $j=0;$j<scalar(@$analyses);$j++) 
		{
			my $analysis = @$analyses[$j];
			my $root = $analysis->{'root'};
			#print "$root ";
			#check if contained in following roots
			for(my $k=$j+1;$j<$k;$k--) 
			{
				my $analysis = @$analyses[$k];
				my $postroot = $analysis->{'root'};
				#print "$postroot ";
				if($postroot =~ /\Q$root\E[yqn]$/)
				{
					splice (@{$analyses},$j,1);	
					$j--;
					#print "1 to delete $root, compared with $postroot\n";
					last;	
				}
				elsif($root eq 'u' && $postroot eq 'o')
				{
					splice (@{$analyses},$j,1);	
					$j--;
					#print "1 to delete $root, compared with $postroot\n";
					last;	
				}
				else
				{
					#check if contained in preceding roots
					for(my $k=0;$k<$j;$k++) 
					{
						my $analysis = @$analyses[$k];
						my $preroot = $analysis->{'root'};
						#print "2 $root vs. $preroot \n";
						if($preroot =~ /\Q$root\E[yqn]$/)
						{
							splice (@{$analyses},$j,1);	
							$j--;
							#print "2 to delete $root, compared with $preroot\n";
						}
						elsif($root eq 'u' && $preroot eq 'o')
						{
							splice (@{$analyses},$j,1);	
							$j--;
							#print "2 to delete $root, compared with $postroot\n";
							last;	
						}
					}
				}
			}
			
			#print "\n";
		}
	}	
}

my $lastlineEmpty=0;

#foreach my $word (@words){
#	my $analyses = @$word[1];
#	#my $analysis = @$analyses[0];
#	#print "pos:".$analysis->{'pos'}."\n";
#	#my $analysis2 = @$analyses[1];
#	#print $analysis2->{'pos'}."\n";
#	my $form = @$word[0];
#	
#	if($form eq '#EOS' ){
#		unless($lastlineEmpty == 1){
#			print "\n";
#			$lastlineEmpty =1;
#			next;
#		}
#	}
#	else
#	{
#		print "$form\t";
#		$lastlineEmpty =0;
#		# uppercase/lowercase?
#		#punctuation (punctuation has never more than one analysis, so we can just take @$analyses[0])
#		if(@$analyses[0]->{'pos'} eq '$'){
#			print "n\t";
#		}
#		elsif(substr($form,0,1) eq uc(substr($form,0,1))){
#			print "uc\t";
#		}
#		# lowercase
#		else{
#			print "lc\t";
#		}
#	
#		# root pos (only one at this point)
#		my $pos = @$analyses[0]->{'pos'};
#		print "$pos\t";
#
#		#possible morph tags: take ALL morph tags into account 
#		my $printedmorphs='';
#		my $nbrOfMorph =0;
#		foreach my $analysis (@$analyses){
#			my $morphsref = $analysis->{'morph'};
#			#print $morphsref;
#			foreach my $morph (@$morphsref){
#			unless($printedmorphs =~ /\Q$morph\E/){
#			print "$morph\t";
#				$printedmorphs = $printedmorphs.$morph;
#				$nbrOfMorph++;
#				}
#			}
#		}
#		while($nbrOfMorph<10){
#			print "ZZZ\t";
#			$nbrOfMorph++;
#		}
#	
#		# only one analysis, take pos from @$analyses[0]
#		if($mode eq '-train')
#		{
#			print "@$analyses[0]->{'pos'}";
#		}
#	
#		print "\n";
#	}
#}

