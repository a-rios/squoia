#!/usr/bin/perl


use utf8;                  # Source code is UTF-8
binmode STDIN, ':utf8';
binmode STDERR, ':utf8';
binmode STDOUT, ':utf8';
use strict;
use Storable;


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
#my $hasPAS =0;
my $hasMdirect =0;

while(<STDIN>){
	
	if (/^$/)
	{
		$newWord=1;
	}
	else
	{	
		my ($form, $analysis) = split(/\t/);
	
		my ($root) = $analysis =~ m/(ALFS|CARD|NP|NRoot|Part|VRoot|PrnDem|PrnInterr|PrnPers|SP|\$|AdvES|PrepES|ConjES)/ ;
		
		my $isNP = 0;
		if($root eq 'NP'){
			$root = 'NRoot';
			$isNP =1;
			#print $form."\n";
		}
		
#		if($analysis =~ /\@PAS/){
#			$hasPAS =1;
#			#print STDERR "has pas\n";
#		}
		if($analysis =~ /\@mMI/){
			$hasMdirect =1;
		}
		
		if($root =~ /AdvES|PrepES|ConjES/){
			$root = 'SP';
			$isNP =1;
			#print $form."\n";
		}
		
		elsif($root eq ''){
			if($form eq '#EOS'){
				$root = '#EOS';
			}
			else{
				$root = "ZZZ";
			}
		}
		
		my ($lem) = ($_ =~ m/([A-Za-zñéóúíáüÑ']+?)\[/ );
		$lem = lc($lem);
		if($lem eq ''){
			#$lem = $form;
			$lem = 'ZZZ';
		}
		
		#print STDERR "$lem\n";
		
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
		$hashAnalysis{'lem'} = $lem;
		$hashAnalysis{'isNP'} = $isNP;
		$hashAnalysis{'string'} = $analysis;
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
my $ambigPos =0;
my $ambigForms=0;


my $xfstWordsRefLem = retrieve('../PossibleLemmasForTrain');
my %xfstwordsLem = %$xfstWordsRefLem;
my $xfstWordsRefMorph = retrieve('../PossibleMorphsForTrain');
my %xfstwordsMorph = %$xfstWordsRefMorph;
my $xfstWordsRefPos = retrieve('../PossibleRootsForTrain');
my %xfstwordsPos = %$xfstWordsRefPos;

# check dialectal variations: 
# -if direct evidential suffix occurs as -m -> delete all analyses of -n as DirE (can only be 3.Sg.Poss or 3.Sg.Subj)
# -if additive suffix ocurrs as -pas -> delete all analyses of -pis as additive (must be Loc + IndE in this case)

if($hasMdirect)
{
	foreach my $word (@words)
	{
		my $analyses = @$word[1];
		my $form = @$word[0];
		for(my $j=0;$j<scalar(@$analyses);$j++) 
		{
				my $analysis = @$analyses[$j];
				my $string = $analysis->{'string'};
				
				# keep only analysis with m@mMI[Amb][+DirE]
				if($hasMdirect && $string =~ /\Qm[Amb][+DirE]\E/ && scalar(@$analyses) > 1)
				{
					#print STDERR "delete: $allmorphs\n";
					splice (@{$analyses},$j,1);	
					$j--;
				}
#				# keep only analysis with pas@PAS[Amb][+Add]
#				if($hasPAS && $string =~ /\Qpas[Amb][+Add]\E/ && scalar(@$analyses) > 1)
#				{
#					print STDERR "$form: delete: $string\n";
#					#print STDERR "delete: $allmorphs\n";
#					splice (@{$analyses},$j,1);	
#					$j--;
#				}
				# delete Flags "@mMI" and "@PAS"
				$string =~ s/\@mMI//g;
				#$string =~ s/\@PAS//g;
				$analysis->{'string'} = $string;
		}
	}
}

foreach my $word (@words){
	my $analyses = @$word[1];
	my $form = @$word[0];
	
	# count ambiguous words in total for evaluation
	if(scalar(@$analyses)>1){
		$ambigForms++;
	}
	
	if($form eq '#EOS' ){
		unless($lastlineEmpty == 1){
		print "\n";
		$lastlineEmpty =1;
		next;
		}
	}
	else
	{
		#print "$form\t";
		print lc($form)."\t";
		
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
		my $nbrOfPossiblePos=0;
		my $isNP;
		foreach my $analysis (@$analyses){
			my $pos = $analysis->{'pos'};
			$isNP = $analysis->{'isNP'};
			unless($printedroots =~ /\Q$pos\E/){
				print "$pos\t";
				$printedroots = $printedroots.$pos;
				$nbrOfPos++;
				$nbrOfPossiblePos++;
			}
		}
		# get possible roots from stored hash (need xfst analysis to get those!)
		if($mode eq '-train'){
			my $possiblePosRef = $xfstwordsPos{$form};
			foreach my $possPos (@$possiblePosRef){
				if($possPos eq 'NP'){
					$possPos = 'NRoot';
				}
				unless($printedroots =~ /\Q$possPos\E/ or $isNP){
					print "$possPos\t";
					$printedroots = $printedroots.$possPos;
					$nbrOfPos++;
				}
			}
		}
		
		if($nbrOfPos > 1){
			$ambigPos++;
		}
	
		while($nbrOfPos<4){
			print "ZZZ\t";
			$nbrOfPos++;
		}
	
		#possible morph tags, variant 1: take only those morph tags into account that are present in ALL analyses
		my $printedmorphs='';
		my $nbrOfMorph =0;
		my $allmorphs;	
	
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
		
		# get possible morphs from stored hash (need xfst analysis to get those!)
		if($mode eq '-train'){
			my $possibleMorphsRef = $xfstwordsMorph{$form};
			foreach my $possAllmorph (@$possibleMorphsRef){
				my @morphs = split('#', $possAllmorph);
				foreach my $morph (@morphs){
					unless($printedmorphs =~ /\Q$morph\E/ or $isNP){
						print "$morph\t";
						$printedmorphs = $printedmorphs.$morph;
						$nbrOfMorph++;
					}
				}
			}
		}
		
		while($nbrOfMorph<10){
			print "ZZZ\t";
			$nbrOfMorph++;
		}
		
		#print possible lemmas 
		# possible root pos
		my $printedlems='#';
		my $nbrOfLems =0;
		foreach my $analysis (@$analyses){
			my $lem = $analysis->{'lem'};
			unless($printedlems =~ /\Q#$lem#\E/ or $nbrOfLems >= 2){
				print "$lem\t";
				$printedlems = $printedlems.'#'.$lem."#";
				$nbrOfLems++;
			}
		}
		
		# get possible lemmas from stored hash (need xfst analysis to get those!)
		if($mode eq '-train'){
			my $possibleLemmasRef = $xfstwordsLem{$form};
			foreach my $lem (@$possibleLemmasRef){
				unless($printedlems =~ /\Q#$lem#\E/ or $nbrOfLems >= 2 or $isNP){
					print "$lem\t";
					$printedlems = $printedlems.'#'.$lem."#";
					$nbrOfLems++;
				}
			}
		}
		
		my $ambigLems=0;
		if($nbrOfLems > 1){
			$ambigLems++;
		}
	
		while($nbrOfLems<2){
			print "ZZZ\t";
			$nbrOfLems++;
		}
		
	
		# only one analysis, take pos from @$analyses[0]
		if($mode eq '-train')
		{
			print "@$analyses[0]->{'pos'}";
		}
		# in test mode: print label of unambiguous words
		elsif($mode eq '-test' or $mode eq ''){
			if($nbrOfPossiblePos==1){
				print "@$analyses[0]->{'pos'}";
			}
		}
	
		print "\n";
	}
}

print STDERR "forms with ambiguos root pos: $ambigPos\n";
print STDERR "forms with more than one analysis: $ambigForms\n";
	store \$ambigForms, 'totalAmbigForms';

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