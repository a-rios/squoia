#!/usr/bin/perl

use strict;
use open ':utf8';
use utf8;
binmode STDIN, ':utf8';
binmode STDERR, ':utf8';
binmode STDOUT, ':utf8';
use Storable;

# check if paramenter was given, either:
# -train (disambiguated input, add class in last row)
# -test (input to be disambiguated, leave last row empty)

my $num_args = $#ARGV + 1;
if ($num_args != 1) {
  print STDERR "\nUsage:  perl xfstToCrf.pl -1/-2/-3\n";	
  print STDERR "-1: NS/VS, -2: nominal+verbal morph disamb, 3: independent suffixes disamb\n";	
  exit;
}

my $mode = $ARGV[0];
unless($mode eq '-1' or $mode eq '-2' or $mode eq '-3' or !$mode){
	print STDERR "\nUsage:  perl xfstToCrf.pl -1/-2/-3\n";	
 	print STDERR "-1: NS/VS, -2: nominal+verbal morph disamb, 3: independent suffixes disamb\n";	
  	exit;
}



my @words;
my $newWord=1;
my $index=0;

my $storedWords;
my $xfstWordsRefLem = retrieve('PossibleLemmasForTrain');
my %xfstwordsLem = %$xfstWordsRefLem;
my $xfstWordsRefMorph = retrieve('PossibleMorphsForTrain');
my %xfstwordsMorph = %$xfstWordsRefMorph;
my $xfstWordsRefPos = retrieve('PossibleRootsForTrain');
my %xfstwordsPos = %$xfstWordsRefPos;
my $xfstWordsRef = retrieve('WordsForTrain');
my %xfstWords = %$xfstWordsRef;


while(<STDIN>){
		
		if (/^$/)
		{
			$newWord=1;
		}
		else
		{	
			my ($form, $analysis) = split(/\t/);
			#print $form."\n";
		
			my ($pos) = $analysis =~ m/(ALFS|CARD|NP|NRoot|Part|VRoot|PrnDem|PrnInterr|PrnPers|SP|\$|AdvES|PrepES|ConjES)/ ;
			
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
			
			my $allmorphs='';
			foreach my $morph (@morphtags){
				$allmorphs = $allmorphs.$morph;
			}
		
			my ($lem) = ($_ =~ m/([A-Za-zñéóúíáüÑ']+?)\[/ );
			$lem = lc($lem);
			if($lem eq ''){
				#$lem = $form;
				$lem = 'ZZZ';
			}
			#print "allmorphs: $allmorphs\n";
			#print "morphs: @morphtags\n\n";
		
			#print "$form: $root morphs: @morphtags\n";
			my %hashAnalysis;
			$hashAnalysis{'pos'} = $pos;
			$hashAnalysis{'morph'} = \@morphtags;
			$hashAnalysis{'string'} = $_;
			$hashAnalysis{'root'} = $root;
	    	$hashAnalysis{'allmorphs'} = $allmorphs;
	    	$hashAnalysis{'lem'} = $lem;
	    
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
if($mode eq '-1')
{
	# get NS/ VS ambiguities
	foreach my $word (@words)
	{
		my $analyses = @$word[1];
		my @possibleClasses = ();
		my $actualClass;
		my $allmorphs = @$analyses[0]->{'allmorphs'};
		my $string = @$analyses[0]->{'string'};
		my $form = @$word[0];
		my $xfstAnalyses =  $xfstWords{$form};
		
		if(exists($xfstWords{$form}) && scalar(@$xfstAnalyses)>1)
		{
			# VERBAL morphology
			# -sqayki
			if(&containedInOtherMorphs($xfstAnalyses,"+Perf","+1.Sg.Subj_2.Sg.Obj.Fut"))
			{
				push(@possibleClasses, "Perf");
				push(@possibleClasses, "Fut");
				if(&containedInOtherMorphs($xfstAnalyses,"+Perf","+IPst+1.Sg.Subj_2.Sg.Obj")){
					push(@possibleClasses, "IPst");
				}
				if($allmorphs =~ /Perf/){$actualClass = "Perf";}
				elsif($allmorphs =~  /Fut/){$actualClass = "Fut";}
				elsif($allmorphs =~ /IPst/ ){$actualClass = "IPst";}
			}
			# -sqaykichik
			elsif(&containedInOtherMorphs($xfstAnalyses,"+Perf","+1.Sg.Subj_2.Pl.Obj.Fut"))
			{
				push(@possibleClasses, "Perf");
				push(@possibleClasses, "Fut");
				if(&containedInOtherMorphs($xfstAnalyses,"+Perf","+IPst+1.Sg.Subj_2.Pl.Obj")){
					push(@possibleClasses, "IPst");
				}
				if($allmorphs =~ /Perf/){$actualClass = "Perf";}
				elsif($allmorphs =~  /Fut/){$actualClass = "Fut";}
				elsif($allmorphs =~ /IPst/ ){$actualClass = "IPst";}
			}
			# -sqa
			elsif(&containedInOtherMorphs($xfstAnalyses,"+Perf","+IPst") || &containedInOtherMorphs($xfstAnalyses,"+Perf","+3.Sg.Subj.IPst") )
			{
				push(@possibleClasses, "IPst");
				push(@possibleClasses, "Perf");
				if($allmorphs =~ /IPst/  ){$actualClass = "IPst";}
				if($allmorphs =~ /Perf/  ){$actualClass = "Perf";}
				#print "@$word[0]\n";
			}
			# -y
			elsif(&containedInOtherMorphs($xfstAnalyses,"+2.Sg.Subj.Imp","+Inf"))
			{
				push(@possibleClasses, "Imp");
				push(@possibleClasses, "Inf");
				if($allmorphs =~  /Imp/){$actualClass = "Imp";}
				elsif($allmorphs =~ /Inf/ ){$actualClass = "Inf";}
				#print "@$word[0]\n";
			}
			# -yman
			elsif(&containedInOtherMorphs($xfstAnalyses,"+1.Sg.Subj.Pot","+Inf+Dat_Ill"))
			{
				push(@possibleClasses, "Pot");
				push(@possibleClasses, "Inf");
				if($allmorphs =~ /Inf/  ){$actualClass = "Inf";}
				elsif($allmorphs =~ /Pot/  ){$actualClass = "Pot";}
				#print "@$word[0]\n";
			}
			# -ykuna
			elsif(&containedInOtherMorphs($xfstAnalyses,"+Inf+Pl","+Aff+Obl"))
			{
				push(@possibleClasses, "Inf");
				push(@possibleClasses, "Aff_Obl");
				if($allmorphs =~ /\Q+Inf+Pl\E/ ){$actualClass = "Inf";}
				elsif($allmorphs =~ /Aff\+Obl/  ){$actualClass = "Aff_Obl";}
				#print "@$word[0]\n";
			}
			# -kuna
			elsif(&containedInOtherMorphs($xfstAnalyses,"+Pl","+Rflx_Int+Obl"))
			{
				push(@possibleClasses, "Pl");
				push(@possibleClasses, "Rflx_Obl");
				if($allmorphs =~ /\Q+Pl\E/  ){$actualClass = "Pl";}
				elsif($allmorphs =~ /\Q+Rflx_Int+Obl\E/ ){$actualClass = "Rflx_Obl";}
				#print "@$word[0]\n";
			}
			# -cha
			elsif(&containedInOtherMorphs($xfstAnalyses,"+Fact","+Dim"))
			{
				push(@possibleClasses, "Fact");
				push(@possibleClasses, "Dim");
				# should not be a verb, but you never know..
				if(&containedInOtherMorphs($xfstAnalyses,"+Dim","+Vdim+Rflx_Int+Obl") or &containedInOtherMorphs($xfstAnalyses,"+Fact","+Vdim") ){
					push(@possibleClasses, "Vdim");
				}
				if($allmorphs =~  /\Q+Fact\E/){$actualClass = "Fact";}
				elsif($allmorphs =~ /\Q+Dim\E/){$actualClass = "Dim";}
				elsif($allmorphs =~ /\Q+Vdim\E/){$actualClass = "Vdim";}
				#print "@$word[0]\n";
			}
		}
		# else: other ambiguities, leave
		else
		{
				push(@possibleClasses, "ZZZ");
				# TODO test what's better...
				$actualClass = "none";
				#$actualClass = @$analyses[0]->{'pos'};
		}
	
		push(@$word, \@possibleClasses);
		push(@$word, $actualClass);
	}
}

if($mode eq '-2')
{
	# get nominal/verbal ambiguities
	foreach my $word (@words)
	{
		my $analyses = @$word[1];
		my @possibleClasses = ();
		my $actualClass;
		my $allmorphs = @$analyses[0]->{'allmorphs'};
		my $string = @$analyses[0]->{'string'};
		my $form = @$word[0];
		my $xfstAnalyses =  $xfstWords{$form};
		#print "$form ".$xfstWords{'tukunqa'}[0]->{'string'}."\n";
		
		if(exists($xfstWords{$form}) && scalar(@$xfstAnalyses)>1)
		{
			# VERBAL morphology
			# -sun
			if(&containedInOtherMorphs($xfstAnalyses,"+1.Pl.Incl.Subj.Imp","+1.Pl.Incl.Subj.Fut"))
			{
				push(@possibleClasses, "Imp");
				push(@possibleClasses, "Fut");
				if($allmorphs =~  /Imp/){$actualClass = "Imp";}
				elsif($allmorphs =~ /Fut/ ){$actualClass = "Fut";}
			}
			# -nqa
			elsif(&containedInOtherMorphs($xfstAnalyses,"+3.Sg.Subj+Top","+3.Sg.Subj.Fut"))
			{
				push(@possibleClasses, "Top");
				push(@possibleClasses, "Fut");
				if($allmorphs =~  /Top/){$actualClass = "Top";}
				elsif($allmorphs =~ /Fut/ ){$actualClass = "Fut";}
			}
			# -sqaykiku
			elsif(&containedInOtherMorphs($xfstAnalyses,"+IPst+1.Pl.Excl.Subj_2.Sg.Obj","+1.Pl.Excl.Subj_2.Sg.Obj.Fut"))
			{
				push(@possibleClasses, "IPst");
				push(@possibleClasses, "Fut");
				if($allmorphs =~ /Fut/ ){$actualClass = "Fut";}
				elsif($allmorphs =~ /IPst/  ){$actualClass = "IPst";}
			} 
			# -wanku 
			elsif(&containedInOtherMorphs($xfstAnalyses,"+1.Obj+3.Pl.Subj","+3.Subj_1.Pl.Excl.Obj" ) or &containedInOtherMorphs($xfstAnalyses,"+1.Obj+NPst+3.Pl.Subj","+3.Subj_1.Pl.Excl.Obj" ) or &containedInOtherMorphs($analyses,"+1.Obj+IPst+3.Pl.Subj","+3.Subj_1.Pl.Excl.Obj" ) &containedInOtherMorphs($analyses,"+1.Obj+Prog+3.Pl.Subj","+3.Subj_1.Pl.Excl.Obj" ) )
			{
				push(@possibleClasses, "1Sg");
				push(@possibleClasses, "1Pl");
				if($allmorphs =~  /Excl/){$actualClass = "1Pl";}
				elsif($allmorphs =~ /\+1\.Obj.+\+3\.Pl\.Subj/ ){$actualClass = "1Sg";}
			}
			# -wanqaku 
			elsif(&containedInOtherMorphs($xfstAnalyses,"+1.Obj+3.Pl.Subj.Fut","+3.Subj_1.Pl.Excl.Obj.Fut" ) or &containedInOtherMorphs($xfstAnalyses,"+1.Obj+Prog+3.Pl.Subj.Fut","+3.Subj_1.Pl.Excl.Obj.Fut" )  )
			{
				push(@possibleClasses, "1Sg");
				push(@possibleClasses, "1Pl");
				if($allmorphs =~  /Excl/){$actualClass = "1Pl";}
				elsif($allmorphs =~ /\+1\.Obj.+\+3\.Pl\.Subj\.Fut/ ){$actualClass = "1Sg";}
			}
	
			# else: other ambiguities, leave
			else
			{
				push(@possibleClasses, "ZZZ");
				# TODO test what's better...
				$actualClass = "none";
				#$actualClass = @$analyses[0]->{'pos'};
			}
		}
		push(@$word, \@possibleClasses);
		push(@$word, $actualClass);
	}
}

if($mode eq '-3')
{	
	# @word: 0: $form (string), 1: $analyses (arrayref) , 2: $possibleClasses (arrayref), 3: $actualClass (string), 4: $sentenceHasEvid (boolean) 5: $precedingGenitive (boolean)
	# check remaining ambiguities
	# disambiguate indepenent suffixes 
	for(my $i=0;$i<scalar(@words);$i++)
	{
		my $word = @words[$i];
		my $analyses = @$word[1];
		my @possibleClasses = ();
		my $actualClass;
		my $allmorphs = @$analyses[0]->{'allmorphs'};
		my $string = @$analyses[0]->{'string'};
		my $form = @$word[0];
		my $xfstAnalyses =  $xfstWords{$form};
		#print "$form morphs: $allmorphs\n";
		
		if(exists($xfstWords{$form}) && scalar(@$xfstAnalyses)>1)
		{
			# yku-n
			if(&containedInOtherMorphs($xfstAnalyses,"+1.Pl.Excl.Subj+DirE","+Aff+3.Sg.Subj") )
			{
				push(@possibleClasses, "DirEs");
				push(@possibleClasses, "Subj");
				if($allmorphs =~  /DirE/){$actualClass = "DirE";}
				elsif($allmorphs =~ /\Q+3.Sg.Subj\E/ ){$actualClass = "Subj";}
				# check if sentence already contains an evidential suffix
				@$word[4] = &sentenceHasEvid(\@words, $i);
				#print "@$word[0], has evid: ".&sentenceHasEvid(\@words, $i)."\n";
				
				#print "@$word[0]: evid @$word[4], gen: @$word[5] \n";
			}
			# -n
			elsif(&containedInOtherMorphs($xfstAnalyses,"+DirE","+3.Sg.Poss") )
			{ 
				push(@possibleClasses, "DirE");
				push(@possibleClasses, "Poss");
				if($allmorphs =~ /DirE/){$actualClass = "DirE";}
				elsif($allmorphs =~ /Poss/ ){$actualClass = "Poss";}
				# check if sentence already contains an evidential suffix
				@$word[4] = &sentenceHasEvid(\@words, $i);
				#print "@$word[0], has evid: ".&sentenceHasEvid(\@words, $i)."\n";
				# check if preceding word has a genitive suffix
				unless($i==0){
					my $preword = @words[$i-1];
					my $preanalyses =  @$preword[1];
					if(@$preanalyses[0]->{'allmorphs'} =~ /\+Gen/){
						@$word[5] = 1;
					}
					else{
						@$word[5] = 0;
					}
				}
				#print "@$word[0]: evid @$word[4], gen: @$word[5] \n";
				#print "$form class $actualClass\n";
			}
			# -pis
			elsif(&containedInOtherMorphs($xfstAnalyses,"+Loc+IndE","+Add"))
			{
				push(@possibleClasses, "Loc_IndE");
				push(@possibleClasses, "Add");
				if($allmorphs =~ /\Q+Loc+IndE\E/){$actualClass = "Loc_IndE";}
				elsif($allmorphs =~ /Add/ ){$actualClass = "Add";}
				@$word[4] = &sentenceHasEvid(\@words, $i);
			}
	
			# -s with Spanish roots: Plural or IndE (e.g. derechus)
			elsif(!&notContainedInMorphs($xfstAnalyses, "+IndE"))
			{
				foreach my $analisis(@$xfstAnalyses)
				{
					my $string = $analisis->{'string'};
					if($string =~ /s\[NRootES/  )
					{
						push(@possibleClasses, "Pl");
						push(@possibleClasses, "IndE");
						@$word[4] = &sentenceHasEvid(\@words, $i);
						if($allmorphs =~ /\Q+IndE\E/){$actualClass = "IndE";}
						else{$actualClass = "Pl";}
					}
				}
				
			}
			# else: lexical ambiguities, leave
			else
			{
				#print "$form, $actualClass\n";
				push(@possibleClasses, "ZZZ");
				# TODO test what's better...
				$actualClass = "none";
				#$actualClass = @$analyses[0]->{'pos'};
			}

		}
		@$word[2] = \@possibleClasses;
		@$word[3] = $actualClass;
	}
}

my $lastlineEmpty=0;

#my $xfstWordsRefLem = retrieve('PossibleLemmasForTrain');
#my %xfstwordsLem = %$xfstWordsRefLem;
#my $xfstWordsRefMorph = retrieve('PossibleMorphsForTrain');
#my %xfstwordsMorph = %$xfstWordsRefMorph;

# print only ambiguous words, with context as features

for (my $i=0;$i<scalar(@words);$i++){
	my $word = @words[$i];
	my $analyses = @$word[1];
	my $form = @$word[0];
	my $possibleClasses = @$word[2];
	my $correctClass = @$word[3];
	
   if(scalar(@$possibleClasses)>1 && $correctClass ne ''  && $correctClass ne 'none'){
		print lc($form)."\t";
   
		my $pos = @$analyses[0]->{'pos'};
		#if($pos =~ /ConjES|AdvES|PrepES/){$pos = 'SP';}
		if($pos eq 'NP'){$pos = 'NRoot';}
		print $pos."\t";

		# print lemma(s)
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
				unless($printedlems =~ /\Q#$lem#\E/ or $nbrOfLems >= 2 ){
					print "$lem\t";
					$printedlems = $printedlems.'#'.$lem."#";
					$nbrOfLems++;
				}
			}
		}
		
		while($nbrOfLems<2){
			print "ZZZ\t";
			$nbrOfLems++;
		}
		
		my $nbrOfClasses =0;
		# possible classes
		foreach my $class (@$possibleClasses){
			print "$class\t";
			$nbrOfClasses++;
		}
		
		while($nbrOfClasses<4){
			print "ZZZ\t";
			$nbrOfClasses++;
		}

		#possible morph tags: take ALL morph tags into account 
		my $printedmorphs='';
		my $nbrOfMorph =0;
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
		# add other possible morphs for ambiguous forms (need xfst analysis for this!)
		# TODO: only for -1/-3? with -3, there shouldn't be other ambiguities...(?)
		# get possible morphs from stored hash (need xfst analysis to get those!)
		if($mode eq '-1' or $mode eq '-2'){
			my $possibleMorphsRef = $xfstwordsMorph{$form};
			foreach my $possAllmorph (@$possibleMorphsRef){
				my @morphs = split('#', $possAllmorph);
				foreach my $morph (@morphs){
					unless($printedmorphs =~ /\Q$morph\E/){
						print "$morph\t";
						$printedmorphs = $printedmorphs.$morph;
						$nbrOfMorph++;
					}
				}
			}
		}
		# mode -3: add missing morphs:
		# +3.Sg.Poss for DirE and vice versa
		# +Loc+IndE for Add and vice versa
		elsif($mode eq '-3'){
			if($correctClass eq 'DirE'){
				print "+3.Sg.Poss\t";
				$nbrOfMorph++;
			}
			elsif($correctClass eq 'Poss'){
				print "+DirE\t";
				$nbrOfMorph++;
			}
			elsif($correctClass eq 'DirEs'){
				print "+Aff\t+3.Sg.Subj\t";
				$nbrOfMorph+=2;
			}
			elsif($correctClass eq 'Subj'){
				print "+1.Pl.Excl.Subj\t+DirE\t";
				$nbrOfMorph+=2;
			}
			elsif($correctClass eq 'Loc_IndE'){
				print "+Add\t";
				$nbrOfMorph++;
			}
			elsif($correctClass eq 'Add'){
				print "+Loc\t+IndE\t";
				$nbrOfMorph +=2;
			}
			elsif($correctClass eq 'Pl'){
				print "+IndE\t";
				$nbrOfMorph++;
			}
		}
		
		while($nbrOfMorph<10){
			print "ZZZ\t";
			$nbrOfMorph++;
		}
		
			my $bos =0;
			# print context words (preceding)
			for (my $j=$i-1;$j>($i-3);$j--)
			{
				my $word = @words[$j];
				my $analyses = @$word[1];
				my $form = @$word[0];
				
				if($form eq '#EOS')
				{
					$bos =1;
				}
				if($bos!=1)
				{
					print "$form\t";
					#print @$analyses[0]->{'pos'}."\t";
					my $pos = @$analyses[0]->{'pos'};
					#if($pos =~ /ConjES|AdvES|PrepES/){$pos= 'SP';}
					if($pos eq 'NP'){$pos = 'NRoot';}
					print $pos."\t";
					# print lemma(s) of context words
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
							unless($printedlems =~ /\Q#$lem#\E/ or $nbrOfLems >= 2 ){
								print "$lem\t";
								$printedlems = $printedlems.'#'.$lem."#";
								$nbrOfLems++;
							}
						}
					}
					
					while($nbrOfLems<2){
						print "ZZZ\t";
						$nbrOfLems++;
					}
					#print morphs of context words
					my $printedmorphs='';
					my $nbrOfMorphP =0;
					foreach my $analysis (@$analyses){
						my $morphsref = $analysis->{'morph'};
						#print $morphsref;
						foreach my $morph (@$morphsref){
						unless($printedmorphs =~ /\Q$morph\E/){
						print "$morph\t";
							$printedmorphs = $printedmorphs.$morph;
							$nbrOfMorphP++;
							}
						}
					}
					# get possible morphs from stored hash (need xfst analysis to get those!)
					if($mode eq '-1' or $mode eq '-2'){
						my $possibleMorphsRef = $xfstwordsMorph{$form};
						foreach my $possAllmorph (@$possibleMorphsRef){
							my @morphs = split('#', $possAllmorph);
							foreach my $morph (@morphs){
								unless($printedmorphs =~ /\Q$morph\E/){
									print "$morph\t";
									$printedmorphs = $printedmorphs.$morph;
									$nbrOfMorphP++;
								}
							}
						}
					}
					
					while($nbrOfMorphP<10){
						print "ZZZ\t";
						$nbrOfMorphP++;
					}
				}
				# else: if bos
				else
				{	my $nbrOfMorphP =0;
					# without lems: 12, with lems: 14
					#while($nbrOfMorphP<12){	
					while($nbrOfMorphP<14){
						print "ZZZ\t";
						$nbrOfMorphP++;
					}
				}
			}
			
			my $eos =0;
			
			# print context words (following)
			for (my $j=$i+1;$j<($i+3);$j++)
			{
				my $word = @words[$j];
				my $analyses = @$word[1];
				my $form = @$word[0];
				
				if($form eq '#EOS')
				{
					$eos =1;
				}
				if($eos!=1)
				{
					print "$form\t";
					#print @$analyses[0]->{'pos'}."\t";
					my $pos = @$analyses[0]->{'pos'};
					#if($pos =~ /ConjES|AdvES|PrepES/){$pos= 'SP';}
					if($pos eq 'NP'){$pos = 'NRoot';}
					print $pos."\t";
					# print lemma(s) of context words
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
							unless($printedlems =~ /\Q#$lem#\E/ or $nbrOfLems >= 2 ){
								print "$lem\t";
								$printedlems = $printedlems.'#'.$lem."#";
								$nbrOfLems++;
							}
						}
					}
					
					while($nbrOfLems<2){
						print "ZZZ\t";
						$nbrOfLems++;
					}
					
					#print morphs of context words
					my $printedmorphs='';
					my $nbrOfMorphF =0;
					foreach my $analysis (@$analyses){
						my $morphsref = $analysis->{'morph'};
						#print $morphsref;
						foreach my $morph (@$morphsref){
						unless($printedmorphs =~ /\Q$morph\E/){
						print "$morph\t";
							$printedmorphs = $printedmorphs.$morph;
							$nbrOfMorphF++;
							}
						}
					}
					# get possible morphs from stored hash (need xfst analysis to get those!)
					if($mode eq '-1' or $mode eq '-2'){
						my $possibleMorphsRef = $xfstwordsMorph{$form};
						foreach my $possAllmorph (@$possibleMorphsRef){
							my @morphs = split('#', $possAllmorph);
							foreach my $morph (@morphs){
								unless($printedmorphs =~ /\Q$morph\E/){
									print "$morph\t";
									$printedmorphs = $printedmorphs.$morph;
									$nbrOfMorphF++;
								}
							}
						}
					}
					while($nbrOfMorphF<10){
						print "ZZZ\t";
						$nbrOfMorphF++;
					}
				}
				# else: if eos
				else
				{	my $nbrOfMorphF =0;
					# without lems: 12, with lems: 14
					#while($nbrOfMorphF<12){
					while($nbrOfMorphF<14){
						print "ZZZ\t";
						$nbrOfMorphF++;
					}
				}
			}
		# for morph3: add info about evidential and genitive suffixes 
		if($mode eq '-3'){
			if(@$word[4] eq ''){
				print "ZZZ\t";
			}
			else{
				print "@$word[4]\t";
			}
			if(@$word[5] eq ''){
				print "ZZZ\t";
			}
			else{
				print "@$word[5]\t";
			}
			
		}
		print "$correctClass";
		print "\n\n";
	}
}

sub sentenceHasEvid{
	my $wordsref = $_[0];
	my @words = @$wordsref;
	my $i = $_[1];
	
	my $word = @words[$i];
	
	my $analyses = @$word[1];
	my $form = @$word[0];
	my $allmorphs = @$analyses[0]->{'allmorphs'};
	
	my $j = $i-1;
	my $prestring = $form;
	#print "word: $prestring\n";
	while($prestring !~ /\[\$/){
		my $preword = @words[$j];
		my $preanalyses = @$preword[1];
		$prestring = @$preanalyses[0]->{'string'};
		my $preallmorphs = @$preanalyses[0]->{'allmorphs'};
		if($preallmorphs =~ /DirE|IndE|Asmp/ && $prestring!~ /hinaspan/ ){
			#print "found $prestring, $preallmorphs\n";
			return 1;
		}
		$j--;
	}
	my $j = $i+1;
	my $poststring = $form;
	#print "word: $poststring\n";
	while($poststring !~ /\[\$/){
		my $postword = @words[$j];
		my $postanalyses = @$postword[1];
		$poststring = @$postanalyses[0]->{'string'};
		my $postallmorphs = @$postanalyses[0]->{'allmorphs'};
		if($postallmorphs =~ /DirE|IndE|Asmp/ && $poststring !~ /hinaspan/  ){
			#print "found $poststring, $postallmorphs\n";
			return 1;
		}
		$j++;
	}
	#print "\n";
	return 0;
}


sub containedInOtherMorphs{
	my $analyses = $_[0];
	my $string1 = $_[1];
	my $string2 = $_[2];
	
	for(my $j=0;$j<scalar(@$analyses);$j++) 
	{
		my $analysis = @$analyses[$j];
		my $allmorphs = $analysis->{'allmorphs'};
		$allmorphs =~ s/#//g;
		#print STDERR @$analyses[$j]->{'lem'}." morphs: $allmorphs  string1: $string1  string2: $string2\n";
		if($allmorphs =~ /\Q$string1\E/)
		{	
			# check if later analysis has +Term
			for(my $k=$j+1;$j<$k;$k--) 
			{
				my $analysis2 = @$analyses[$k];
				my $postmorphs = $analysis2->{'allmorphs'};
				$postmorphs =~ s/#//g;
				#print "  next: $postmorphs\n";
				if($postmorphs =~ /\Q$string2\E/ )
				{		
					#print "2 found $allmorphs\n";
					#print "2compared with $postmorphs\n";
					return 1;
				}
			}
			# check if previuous analysis has +Term
			for(my $k=0;$k<$j;$k++) 
			{
				my $analysis3 = @$analyses[$k];
				my $premorphs = $analysis3->{'allmorphs'};
				$premorphs =~ s/#//g;
				#print "   prev: $premorphs\n";
				if($premorphs =~ /\Q$string2\E/)
				{
					#print "3 found $allmorphs\n";
					#print "3 compared with $premorphs\n";
					return 1;
				}
			}
		}
	}
	return 0;
}

sub notContainedInMorphs{
	my $analyses = $_[0];
	my $string = $_[1];
	
	foreach my $analysis (@$analyses)
	{
		my $allmorphs = $analysis->{'allmorphs'};
		if($allmorphs =~ /\Q$string\E/){
			return 0;
		}
	}
	return 1;
}