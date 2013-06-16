#!/usr/bin/perl


use utf8;                  # Source code is UTF-8
binmode STDIN, ':utf8';
binmode STDERR, ':utf8';
binmode STDOUT, ':utf8';
use strict;



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

while(<STDIN>){
	
	if (/^$/)
	{
		$newWord=1;
	}
	else
	{	
		my ($form, $analysis) = split(/\t/);
	
		my ($root) = $analysis =~ m/(ALFS|CARD|NP|NRoot|Part|VRoot|PrnDem|PrnInterr|PrnPers|SP|\$)/ ;
		
		if($root eq ''){
			if($form eq '#EOS'){
				$root = '#EOS';
			}
			else{
				$root = "ZZZ";
			}
		}
		
		my @morphtags =  $analysis =~ m/(\+.+?)\]/g ;
		# simplify tags
#		for (my $i=0;$i<scalar(@morphtags);$i++){
#			my $tag = @morphtags[$i];
#			if($tag =~ /Subj/){
#				@morphtags[$i] = "+Subj"
#			}
#			if($tag =~ /Poss/){
#				@morphtags[$i] = "+Poss"
#			}
#		}
		
		my $allmorphs='';
		foreach my $morph (@morphtags){
			$allmorphs = $allmorphs.$morph;
		}
	
		#print "$form: $root morphs: @morphtags\n";
		my %hashAnalysis;
		$hashAnalysis{'pos'} = $root;
		$hashAnalysis{'morph'} = \@morphtags;
		$hashAnalysis{'allmorphs'} = $allmorphs;
	
#	   ALFS 
#       CARD 
#       NP NRoot NRootES NRootNUM
#       Part_Affir Part_Cond Part_Conec Part_Contr Part_Disc Part_Neg Part_Neg_Imp Part_Sim 
#       PrnDem PrnInterr PrnPers 
#       SP 
#       VRoot VRootES 

       
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

my $lastlineEmpty=0;

foreach my $word (@words){
	my $analyses = @$word[1];
	#my $analysis = @$analyses[0];
	#print "pos:".$analysis->{'pos'}."\n";
	my $analysis2 = @$analyses[1];
	#print $analysis2->{'pos'}."\n";
	
	my $form = @$word[0];
	
	if($form eq '#EOS' ){
		unless($lastlineEmpty == 1){
		print "\n";
		$lastlineEmpty =1;
		next;
		}
	}
	else
	{
		print "$form\t";
		$lastlineEmpty =0;
		# uppercase/lowercase?
		#punctuation (punctuation has never more than one analysis, so we can just take @$analyses[0])
		if(@$analyses[0]->{'pos'} eq '$'){
			print "n\t";
		}
		elsif(substr($form,0,1) eq uc(substr($form,0,1))){
			print "uc\t";
		}
		# lowercase
		else{
			print "lc\t";
		}
	
		# possible root pos
		my $printedroots='';
		my $nbrOfPos =0;
		foreach my $analysis (@$analyses){
			my $pos = $analysis->{'pos'};
			unless($printedroots =~ /\Q$pos\E/){
				print "$pos\t";
				$printedroots = $printedroots.$pos;
				$nbrOfPos++;
			}
		}
	
		while($nbrOfPos<4){
			print "ZZZ\t";
			$nbrOfPos++;
		}
	
		#possible morph tags, variant 1: take only those morph tags into account that are present in ALL analyses
		my $printedmorphs='';
		my $nbrOfMorph =0;
		my $allmorphs;
#		foreach my $analysis (@$analyses){
#			my $morphsref = $analysis->{'morph'};
#			foreach my $morph (@$morphsref){
#				if(&isContainedInAllAnalyses($analyses,$morph) ){
#					unless($printedmorphs =~ /\Q$morph\E/){
#					print "$morph\t";
#					$printedmorphs = $printedmorphs.$morph;
#					$nbrOfMorph++;
#					}
#				}
#			}	
#		}	
	
		#possible morph tags, variant 2: take ALL morph tags into account 
		foreach my $analysis (@$analyses){
			my $morphsref = $analysis->{'morph'};
			#print $morphsref;
			foreach my $morph (@$morphsref){
			unless($printedmorphs =~ /\Q$morph\E/){
			print "$morph\t";
				$printedmorphs = $printedmorphs.$morph;
				$nbrOfMorph++;
				}
			}
		}
		while($nbrOfMorph<10){
			print "ZZZ\t";
			$nbrOfMorph++;
		}
	
		# only one analysis, take pos from @$analyses[0]
		if($mode eq '-train')
		{
			print "@$analyses[0]->{'pos'}";
		}
	
		print "\n";
	}
}


sub isContainedInAllAnalyses{
	my $analyses = $_[0];
	my $morph = $_[1];
	my $inAll = 1;
	
	foreach my $analysis (@$analyses){
		my $allmorphs = $analysis->{'allmorphs'};
		#print "$allmorphs--$morph";
		if($allmorphs !~ /\Q$morph\E/){
			$inAll =0;
		}
	}
	return $inAll;
}