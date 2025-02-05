#!/usr/bin/perl

use strict;
use utf8;
use open ':utf8';
binmode STDIN, ':utf8';
binmode STDERR, ':utf8';
binmode STDOUT, ':utf8';
use Storable;

# check if paramenter was given, either:
# -train (disambiguated input, add class in last row)
# -test (input to be disambiguated, leave last row empty)


my $num_args = $#ARGV + 1;
if ($num_args != 2) {
  print STDERR "\nUsage:  perl xfst2wapiti_morphTest.pl -1/-2/-3/-4 xfst_file (only with -1)\n";	
  print STDERR "-1: NS/VS, -2: nominal+verbal morph disamb, 3: independent suffixes disamb, 4: print disambiguated xfst\n";	
  exit;
}

my $mode = $ARGV[0];
unless($mode eq '-1' or $mode eq '-2' or $mode eq '-3' or $mode eq '-4' or !$mode){
	print STDERR "\nUsage:  perl xfst2wapiti_morphTest.pl -1/-2/-3/-4\n";	
 	print STDERR "-1: NS/VS, -2: nominal+verbal morph disamb, 3: independent suffixes disamb, 4: print disambiguated xfst\n";	
  	exit;
}
if($mode == '-1'){
	my $xfst = $ARGV[1];
	open XFST, "< $xfst" or die "Can't open $xfst (need xfst file with option -1): $!";
}

elsif($mode == '-2' or $mode == '-3' or $mode == '-4'){
	my $crf = $ARGV[1];
	open CRF, "< $crf" or die "Can't open $crf (need disambiguated crf file with option -2, -3 or -4): $!";
}


my @words;
my $newWord=1;
my $index=0;

if($mode eq '-1')
{
	while(<XFST>)
	{
		
		if (/^$/)
		{
			$newWord=1;
		}
		else
		{	
			my ($form, $analysis) = split(/\t/);
		
			my ($pos) = $analysis =~ m/(ALFS|CARD|NP|NRoot|Part|VRoot|PrnDem|PrnInterr|PrnPers|SP|\$|AdvES|PrepES|ConjES)/ ;
			
			if($pos eq 'NP'){
					$pos = 'NRoot';
			}
			
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
		
			#print "allmorphs: $allmorphs\n";
			#print "morphs: @morphtags\n\n";
			
			my ($lem) = ($_ =~ m/([A-Za-zñéóúíáüÑ']+?)\[/ );
			$lem = lc($lem);
			if($lem eq ''){
				#$lem = $form;
				$lem = 'ZZZ';
			}
		
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
	close XFST;
	my $disambiguatedForms=0;
	# if a word has more than one analysis that differ only in length of the root by 1, and last letter is -q/-y/-n 
	# delete the one with the shorter root (e.g. millay -> milla -y/millay, qapaq-> qapa-q/qapaq, allin -> alli -n/ allin)
	foreach my $word (@words)
	{
		
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
						$disambiguatedForms++;
						#print "1 to delete $root, compared with $postroot\n";
						last;	
					}
					elsif($root eq 'u' && $postroot eq 'o')
					{
						splice (@{$analyses},$j,1);	
						$j--;
						$disambiguatedForms++;
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
								$disambiguatedForms++;
								#print "2 to delete $root, compared with $preroot\n";
							}
							elsif($root eq 'u' && $preroot eq 'o')
							{
								splice (@{$analyses},$j,1);	
								$j--;
								$disambiguatedForms++;
								#print "2 to delete $root, compared with $postroot\n";
								last;	
							}
						}
					}
				}
				
				# if analysis differ in -kama +Dist vs. +Term -> take +Term, delete +Dist
				my $morphs = $analysis->{'morph'};
				#print "@$morphs\n";
				if(grep {$_ =~ /Dist/} @$morphs){
					# check if later analysis has +Term
					for(my $k=$j+1;$j<$k;$k--) 
					{
						my $analysis = @$analyses[$k];
						my $postmorphs = $analysis->{'morph'};
						if(grep {$_ =~ /Term/} @$postmorphs){
							splice (@{$analyses},$j,1);	
							$disambiguatedForms++;
							$j--;
							#print "2 to delete @$morphs\n";
							#print "compared with @$postmorphs\n";
							last;
						}
					}
					# check if previuous analysis has +Term
					for(my $k=0;$k<$j;$k++) 
					{
						my $analysis = @$analyses[$k];
						my $premorphs = $analysis->{'morph'};
						if(grep {$_ =~ /Term/} @$premorphs){
							splice (@{$analyses},$j,1);	
							$disambiguatedForms++;
							$j--;
							#print "2 to delete @$morphs\n";
							#print "compared with @$premorphs\n";
							last;
						}
					}
				}
				
				#print "\n";
			}
		}
	}
	#print "prev: $disambiguatedForms\n";
	store \$disambiguatedForms, 'tmp/prevdisambMorph1';

	# @word: 0: form, 1:@analyses, 2:@possibleClasses, 3:correctClass, 4: amb
	# get NS / VS ambiguities
	foreach my $word (@words)
	{
		my $analyses = @$word[1];
		my @possibleClasses = ();
		
		if(scalar(@$analyses)>1)
		{
			# VERBAL morphology
			# -sqayki
			if(&containedInOtherMorphs($analyses,"Perf","\Q+1.Sg.Subj_2.Sg.Obj.Fut\E"))
			{
				push(@possibleClasses, "Perf");
				push(@possibleClasses, "Fut");
				if(&containedInOtherMorphs($analyses,"Perf","\Q+IPst+1.Sg.Subj_2.Sg.Obj\E")){
					push(@possibleClasses, "IPst");
				}
				@$word[3] = "amb";
				#print "@$word[0]\n";
			}
			# -sqaykichik
			elsif(&containedInOtherMorphs($analyses,"Perf","\Q+1.Sg.Subj_2.Pl.Obj.Fut\E"))
			{
				push(@possibleClasses, "Perf");
				push(@possibleClasses, "Fut");
				if(&containedInOtherMorphs($analyses,"Perf","\Q+IPst+1.Sg.Subj_2.Pl.Obj\E")){
					push(@possibleClasses, "IPst");
				}
				@$word[3] = "amb";
			}
			# -sqa
			elsif(&containedInOtherMorphs($analyses,"Perf","\Q+IPst\E") || &containedInOtherMorphs($analyses,"Perf","\Q+3.Sg.Subj.IPst\E") )
			{
				push(@possibleClasses, "IPst");
				push(@possibleClasses, "Perf");
				#push(@ambWords,$word);
				@$word[3] = "amb";
				#print "@$word[0]\n";
			}
			# -y
			elsif(&containedInOtherMorphs($analyses,"\Q+2.Sg.Subj.Imp\E","Inf"))
			{
				push(@possibleClasses, "Imp");
				push(@possibleClasses, "Inf");
				#push(@ambWords,$word);
				@$word[3] = "amb";
				#print "@$word[0]\n";
			}
			# -yman
			elsif(&containedInOtherMorphs($analyses,"\Q+1.Sg.Subj.Pot\E","\Q+Inf+Dat_Ill\E"))
			{
				push(@possibleClasses, "Pot");
				push(@possibleClasses, "Inf");
				#push(@ambWords,$word);
				@$word[3] = "amb";
				#print "@$word[0]\n";
			}
			# -ykuna
			elsif(&containedInOtherMorphs($analyses,"\Q+Inf+Pl\E","\Q+Aff+Obl\E"))
			{
				push(@possibleClasses, "Inf");
				push(@possibleClasses, "Aff_Obl");
				#push(@ambWords,$word);
				@$word[3] = "amb";
				#print "@$word[0]\n";
			}
#			# -nakuna
#			elsif(&containedInOtherMorphs($analyses,"+Obl+Pl","+Rzpr+Rflx_Int+Obl"))
#			{
#				push(@possibleClasses, "Obl_Pl");
#				push(@possibleClasses, "Rzpr_Rflx_Obl");
#			}
			# -kuna
			elsif(&containedInOtherMorphs($analyses,"\Q+Pl\E","\Q+Rflx_Int+Obl\E"))
			{
				push(@possibleClasses, "Pl");
				push(@possibleClasses, "Rflx_Obl");
				#push(@ambWords,$word);
				@$word[3] = "amb";
				#print "@$word[0]\n";
			}
			# -cha
			elsif(&containedInOtherMorphs($analyses,"Fact","Dim"))
			{
				push(@possibleClasses, "Fact");
				push(@possibleClasses, "Dim");
				# should not be a verb, but you never know..
				if(&containedInOtherMorphs($analyses,"Dim","\Q+Vdim+Rflx_Int+Obl\E") or &containedInOtherMorphs($analyses,"Fact","Vdim") ){
					push(@possibleClasses, "Vdim");
				}
				#push(@ambWords,$word);
				@$word[3] = "amb";
				#print "@$word[0]\n";
			}
			# -waq (2.Pot) vs. -wa -q (Ag), waqninchik (+1.Pl.Incl.Subj.Pot)
			elsif(&containedInOtherMorphs($analyses,"\Q+1.Obj+Ag\E","\Q+2.Sg.Subj.Pot\E") or &containedInOtherMorphs($analyses,"\Q+1.Obj+Ag+3.Subj_1.Pl.Incl.Obj\E","\Q+1.Pl.Incl.Subj.Pot\E"))
			{
				push(@possibleClasses, "12Pot");
				push(@possibleClasses, "Ag");
				#push(@ambWords,$word);
				@$word[3] = "amb";
				#print "@$word[0]\n";
			}
			
			# else: other ambiguities, leave
			else
			{
				push(@possibleClasses, "ZZZ");
			}
		}
		# unambiguous forms: use pos tag, should help with context (hopefully)
		else
		{
			push(@possibleClasses, "ZZZ");
			#push(@possibleClasses, @$analyses[0]->{'pos'});
		}
		#push(@$word, \@possibleClasses);
		@$word[2] = \@possibleClasses;
		#print @$word[0].": @possibleClasses\n";
		
	}
	# store @words to disk
	store \@words, 'tmp/words1';
#	store \@ambWords, 'ambWords';
	printCrf(\@words);
	
}

if($mode eq '-2')
{
	# @word: 0: form, 1:@analyses, 2:@possibleClasses, 3: amb
	#retrieve words from disk
	my $wordsref = retrieve('tmp/words1');
	@words = @$wordsref;
	
	# disambiguate with crf file
	&disambMorph1(\@words);
	
	# get verbal / nominal ambiguities
	foreach my $word (@words){
		my $analyses = @$word[1];
		my @possibleClasses = ();
		
		if(scalar(@$analyses)>1)
		{
			# VERBAL morphology
			# -sun
			if(&containedInOtherMorphs($analyses,"\Q+1.Pl.Incl.Subj.Imp\E","\Q+1.Pl.Incl.Subj.Fut\E"))
			{
				push(@possibleClasses, "Imp");
				push(@possibleClasses, "Fut");
				@$word[3] = "amb2";
			}
			# -nqa
			elsif(&containedInOtherMorphs($analyses,"\Q+3.Sg.Subj+Top\E","\Q+3.Sg.Subj.Fut\E"))
			{
				push(@possibleClasses, "Top");
				push(@possibleClasses, "Fut");
				@$word[3] = "amb2";
			}
			# -sqaykiku
			elsif(&containedInOtherMorphs($analyses,"\Q+IPst+1.Pl.Excl.Subj_2.Sg.Obj\E","\Q+1.Pl.Excl.Subj_2.Sg.Obj.Fut\E"))
			{
				push(@possibleClasses, "IPst");
				push(@possibleClasses, "Fut");
				@$word[3] = "amb2";
			}
			# NOMINAL morphology
#			# -nkuna
#			elsif(&containedInOtherMorphs($analyses,"+3.Pl.Poss+Pl","+3.Sg.Poss+Pl"))
#			{
#				push(@possibleClasses, "Sg");
#				push(@possibleClasses, "Pl");
#				@$word[3] = "amb2";
#			}
#			# -ykuna
#			elsif(&containedInOtherMorphs($analyses,"+1.Pl.Excl.Poss+Pl","+1.Sg.Poss+Pl"))
#			{
#				push(@possibleClasses, "Sg");
#				push(@possibleClasses, "Pl");
#				@$word[3] = "amb2";
#			}
			# -wanku 
			elsif(&containedInOtherMorphs($analyses,"\Q+1.Obj\E.*\Q+3.Pl.Subj\E","\Q+3.Subj_1.Pl.Excl.Obj\E" )  )
			{
				push(@possibleClasses, "1Sg");
				push(@possibleClasses, "1Pl");
				@$word[3] = "amb2";
			}
			# -wanqaku 
			elsif(&containedInOtherMorphs($analyses,"\Q+1.Obj+3.Pl.Subj.Fut\E","\Q+3.Subj_1.Pl.Excl.Obj.Fut\E" ) or &containedInOtherMorphs($analyses,"\Q+1.Obj+Prog+3.Pl.Subj.Fut\E","\Q+3.Subj_1.Pl.Excl.Obj.Fut\E" )  )
			{
				push(@possibleClasses, "1Sg");
				push(@possibleClasses, "1Pl");
				@$word[3] = "amb2";
			}
			# -npuni: -n -puni or -m -pu -ni (problem: occurs onyl as -n -puni in training material!)
			elsif(&containedInOtherMorphs($analyses,"\Q+3.Sg.Subj+Def\E","\Q+Cis_Trs+Rgr_Iprs+1.Sg.Subj\E" )){
				push(@possibleClasses, "1Sg");
				push(@possibleClasses, "3Sg");
				@$word[3] = "amb2";
			}
			# else: other ambiguities, leave
			else
			{
				push(@possibleClasses, "ZZZ");
			}
		}
		# unambiguous forms: use pos tag, should help with context (hopefully)
		else
		{
			push(@possibleClasses, "ZZZ");
			#push(@possibleClasses, @$analyses[0]->{'pos'});
		}
		#push(@$word, \@possibleClasses);
		@$word[2] = \@possibleClasses;
		#print @$word[0].": @possibleClasses\n";
		
	}
	# store @words to disk
	store \@words, 'tmp/words2';
	&printCrf(\@words);
	#&printXFST(\@words);
}

if($mode eq '-3')
{	
	# @word: 0: form, 1:@analyses, 2:@possibleClasses, 3:correctClass, 4: amb 5: hasEvidential, 6: previousHasGenitive
	#retrieve words from disk
	my $wordsref = retrieve('tmp/words2');
	@words = @$wordsref;
	
	# disambiguate with crf file
	&disambMorph2(\@words);
	
	# get ambiguities in independent suffixes
	for(my $i=0;$i<scalar(@words);$i++){
		my $word = @words[$i];
		my $analyses = @$word[1];
		my @possibleClasses = ();
		
		if(scalar(@$analyses)>1)
		{
			# yku-n
			if(&containedInOtherMorphs($analyses,"\Q+1.Pl.Excl.Subj+DirE\Q","\Q+Aff+3.Sg.Subj\E") )
			{
				push(@possibleClasses, "DirEs");
				push(@possibleClasses, "Subj");
				@$word[3] = "amb3";
				# check if sentence already contains an evidential suffix
				@$word[5] = &sentenceHasEvid(\@words, $i);
				#print STDERR "@$word[0], has evid: ".&sentenceHasEvid(\@words, $i)."\n";
				
				#print "@$word[0]: evid @$word[4], gen: @$word[5] \n";
				#print STDERR "-ykun \n";
			}
			# -n
			elsif(&containedInOtherMorphs($analyses,"\Q+DirE\E","\Q+3.Sg.Poss\E") )
			{
				push(@possibleClasses, "DirE");
				push(@possibleClasses, "Poss");
				@$word[3] = "amb3";
				# check if sentence already contains an evidential suffix
				@$word[5] = &sentenceHasEvid(\@words, $i);
				#print "@$word[0], has evid: ".&sentenceHasEvid(\@words, $i)."\n";
				# check if preceding word has a genitive suffix
				unless($i==0){
					my $preword = @words[$i-1];
					my $preanalyses =  @$preword[1];
					if(@$preanalyses[0]->{'allmorphs'} =~ /\+Gen/){
						@$word[6] = 1;
					}
					else{
						@$word[6] = 0;
					}
				}
				#print STDERR "-n \n";
				#print STDERR "@$word[0]: evid @$word[4], gen: @$word[5] \n";
			}
			# -pis
			elsif(&containedInOtherMorphs($analyses,"\Q+Loc+IndE\E","Add"))
			{
				push(@possibleClasses, "Loc_IndE");
				push(@possibleClasses, "Add");
				@$word[3] = "amb3";
				@$word[5] = &sentenceHasEvid(\@words, $i);
				#print STDERR "-pis \n";
			}
	
			# -s with Spanish roots: Plural or IndE (e.g. derechus)
			elsif(!&notContainedInMorphs($analyses, "+IndE"))
			{
				foreach my $analisis(@$analyses)
				{
					my $string = $analisis->{'string'};
					#if($string =~ /s\[NRootES/  )
					if($string =~ /\QNRootES][--]s[Num\E/ )
					{
						push(@possibleClasses, "Pl");
						push(@possibleClasses, "IndE");
						@$word[3] = "amb3";
						@$word[5] = &sentenceHasEvid(\@words, $i);
					}
				}
				#print STDERR "-s \n";
			}
			# else: lexical ambiguities, leave
			else
			{
				push(@possibleClasses, "ZZZ");
			}
		}
		# unambiguous forms: use pos tag, should help with context (hopefully)
		else
		{
			push(@possibleClasses, "ZZZ");
			#push(@possibleClasses, @$analyses[0]->{'pos'});
		}
		#push(@$word, \@possibleClasses);
		@$word[2] = \@possibleClasses;
#		if(scalar(@possibleClasses)>1){
#			print STDERR @$word[0].": possible classes: @possibleClasses\n";
#		}
	}
	# store @words to disk
	store \@words, 'tmp/words3';
	printCrf(\@words);
	#&printXFST(\@words);
	
}

if($mode eq '-4')
{	
	# @word: 0: form, 1:@analyses, 2:@possibleClasses, 3:correctClass, 4: amb
	#retrieve words from disk
	my $wordsref = retrieve('tmp/words3');
	@words = @$wordsref;
	
	# disambiguate with crf file
	&disambMorph3(\@words);
	#&printXFST(\@words);
	
}


my $lastlineEmpty=0;

sub printCrf{
	my $wordsref = $_[0];
	my @words = @$wordsref;
	
	for (my $i=0;$i<scalar(@words);$i++)
	{	# @word: 0: form, 1:@analyses, 2:@possibleClasses, 3:correctClass, 4: amb
		my $word = @words[$i];
		my $analyses = @$word[1];
		my $form = @$word[0];
		my $possibleClasses = @$word[2];
		my $amb = @$word[3];
		#print "amb: $amb\n";
		
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
		
		while($nbrOfLems<2){
			print "ZZZ\t";
			$nbrOfLems++;
		}
		
		
		#possible morph tags: take ALL morph tags into account 
		my $printedmorphs='';
		my $nbrOfMorph =0;
		foreach my $analysis (@$analyses){
			my $morphsref = $analysis->{'morph'};
			#print $morphsref;
			foreach my $morph (@$morphsref){
			unless($printedmorphs =~ /\Q$morph\E/){
				# in portmanteau forms -sunki -> only +3.Subj_2.Sg.Obj, -> insert +2/1.Obj in order to have the same morphtags as with regular sequences (-su .. -nki)
				if($morph =~ /.+_2\.(Sg|Pl)\.Obj/ && $printedmorphs !~ /\+2\.\Obj/){
					print "+2.Obj\t";
					$printedmorphs = $printedmorphs."+2.Obj";
					$nbrOfMorph++;
				}
				if($morph =~ /.+_1\.(Sg|Pl(\.Incl|\.Excl))\.Obj/ && $printedmorphs !~ /\+1\.\Obj/){
					print "+1.Obj\t";
					$printedmorphs = $printedmorphs."+1.Obj";
					$nbrOfMorph++;
				}
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
		
		# for morph3: add info about evidential and genitive suffixes 
			if($mode eq '-3'){
				if(@$word[5] eq ''){
					print "ZZZ\t";
				}
				else{
					print "@$word[5]\t";
				}
				if(@$word[6] eq ''){
					print "ZZZ\t";
				}
				else{
					print "@$word[6]\t";
				}
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
		
		unless(scalar(@$possibleClasses)>1){
			#print "@$analyses[0]->{'pos'}";
			print "none";
		}
		print "\n";
		}
	}
}		
		

sub containedInOtherMorphs{
	my $analyses = $_[0];
	my $string1 = $_[1];
	my $string2 = $_[2];
	
	for(my $j=0;$j<scalar(@$analyses);$j++) 
	{
		my $analysis = @$analyses[$j];
		my $allmorphs = $analysis->{'allmorphs'};
		#print STDERR @$analyses[$j]->{'lem'}." morphs: $allmorphs  string: $string1 $string2\n";
		if($allmorphs =~ /$string1/)
		{	
			# check if later analysis has +Term
			for(my $k=$j+1;$j<$k;$k--) 
			{
				my $analysis2 = @$analyses[$k];
				my $postmorphs = $analysis2->{'allmorphs'};
				#print "next: $postmorphs\n";
				if($postmorphs =~ /$string2/ )
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
				#print "prev: $premorphs\n";
				if($premorphs =~ /$string2/)
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

sub printXFST{
	my $wordsref = $_[0];
	my @words = @$wordsref;
	
	foreach my $word (@words){
		my $analyses = @$word[1];
		foreach my $analysis (@$analyses){
			print STDERR $analysis->{'string'};
		}
		print STDERR "\n";
	}
	
}

sub disambMorph1{
	my $wordsref = $_[0];
	my @words = @$wordsref;
	#&printXFST(\@words);
	
	my $unambigForms = 0;
	my $ambigForms = 0;
	my $stillambigForms =0;
	my $disambiguatedForms=0;
	
	my @crfLines = <CRF>;
	# note: if wapiti inserts empty line at the end, delete it
	if(scalar(@crfLines) == scalar(@words)+1 && @crfLines[-1] =~ /^\s*$/){
		pop(@crfLines);
	}
	
	for(my $i=0;$i<scalar(@crfLines);$i++){
		my $crfline = @crfLines[$i];
		my $word = @words[$i];
			
			my @crfRows = split('\t', $crfline);
			if( (lc(@$word[0]) eq @crfRows[0]) or (@$word[0] eq '#EOS' and $crfline =~ /^\s*$/ ) )
			{
				# check if marked as ambiguous
				if(@$word[3] eq 'amb'){
					$ambigForms++;
					#print STDERR "xfst: @$word[0]  crf: @crfRows[0]\n";
					my $correctMorph = @crfRows[-1];
					my $analyses = @$word[1];
					#print STDERR "$correctMorph\n"; #----- ".@$word[0]."\n";
					for(my $j=0;$j<scalar(@$analyses);$j++)
					{
							my $analysis = @$analyses[$j];
							my $allmorphs = $analysis->{'allmorphs'};
							
							# at this point, all the classes/tags are mutually exclusive, so we can just check whether the class is contained in allmorphs		
							# -sqayki: Perf, IPst, Fut
							# -sqaykichik: Perf, IPst, Fut
							# -sqa: Perf, IPst
							# -y: Inf, Imp
							# -yman: Inf, Pot
							# -ykuna: Inf, Aff_Obl
							# -kuna: Pl, Rflx_Obl
							# -cha: Fact, Dim
							# -waq(ninchik): 12Pot, Ag
							#$correctMorph = s/\n//;
							chomp($correctMorph);
							if($correctMorph eq 'Aff_Obl'){$correctMorph = 'Aff+Obl';}
							if($correctMorph eq 'Rflx_Obl'){$correctMorph = 'Rflx+Obl';}
							if($correctMorph eq '12Pot'){$correctMorph = '\.Pot';}
							if($correctMorph eq 'Ag'){$correctMorph = '+1.Obj+Ag';}
							#print STDERR "$form: all: $allmorphs, correct: $correctMorph"."ll\n";
							if($allmorphs !~ /\Q$correctMorph\E/ && scalar(@$analyses) > 1){
								#print STDERR "delete: $allmorphs\n";
								splice (@{$analyses},$j,1);	
								$disambiguatedForms++;
								$j--;		
							}
						}
				
						# for debugging: print disambiguated forms
#						for(my $j=0;$j<scalar(@$analyses);$j++) {
#							my $analysis = @$analyses[$j];
#								print STDERR @$analyses[$j]->{'string'};
#						}
#						print STDERR "\n";
					# for debugging: print only forms that are still ambiguous
					if(scalar(@$analyses) > 1){
								$stillambigForms++;
				#				for(my $j=0;$j<scalar(@$analyses);$j++) {
				#				my $analysis = @$analyses[$j];
				#				print @$analyses[$j]->{'string'};
				#			}
					}
					
				}
				else{
					$unambigForms++;
				}
				
			}
			else{ 
				# if the lines in xfst and crf output don't match, something's wrong.. 
				print STDERR "not equal in crf line $i: xfst: @$word[0]  crf: @crfRows[0]\n";
				exit;
			}
	}

	# retrieve number of previously disambiguated forms ('rule' based, e.g +Dist/+Term, chiqan/chiqa etc.)
	my $prevdisamb = retrieve('tmp/prevdisambMorph1');
	#print "prev $$prevdisamb\n";
	
	# for testing: print xfst to STDERR
	#&printXFST(\@words);
	my $totalWords = scalar(@words);
	#print "words: "$totalWords;
	$ambigForms = $$prevdisamb + $ambigForms;
	my $unamb = $unambigForms/$totalWords;
	my $amb = ($$prevdisamb + $ambigForms)/$totalWords;
	my $disamb=0;
	my $stillamb=0;
	if($ambigForms > 0){
	    $disamb = ($$prevdisamb + $disambiguatedForms)/$ambigForms;
	    $stillamb = $stillambigForms/$ambigForms;
	}

	
	print STDERR "number of words: $totalWords\n"; 
	print STDERR "unambiguous forms: $unambigForms : "; printf STDERR ("%.2f", $unamb); print STDERR "\n";
	print STDERR "ambiguous forms: $ambigForms : "; printf STDERR ("%.2f", $amb); print STDERR "\n";
	print STDERR "disambiguated with morph1: rules: $$prevdisamb, crf: $disambiguatedForms : "; printf STDERR ("%.2f", $disamb); print STDERR "\n";
	print STDERR "still ambiguous after morph1 disambiguation: $stillambigForms : "; printf STDERR ("%.2f", $stillamb); print STDERR "\n";
	
	close CFG;
}


sub disambMorph2{
	my $wordsref = $_[0];
	my @words = @$wordsref;
	#print "@words\n";
	#&printXFST(\@words);
	
	
	my $unambigForms = 0;
	my $ambigForms = 0;
	my $stillambigForms =0;
	my $disambiguatedForms=0;
	
	my @crfLines = <CRF>;
	# note: if wapiti inserts empty line at the end, delete it
	if(scalar(@crfLines) == scalar(@words)+1 && @crfLines[-1] =~ /^\s*$/){
		pop(@crfLines);
	}
	
	for(my $i=0;$i<scalar(@crfLines);$i++)
	{
		my $crfline = @crfLines[$i];
		my $word = @words[$i];
		my $analyses = @$word[1];
		
		# not a real ambiguitiy: rqari vs. rqa-ri -> keep -rqari
		if(&containedInOtherMorphs($analyses,"\Q+Multi\Q","\Q+Rptn+Inch\E") ){
			for(my $j=0;$j<scalar(@$analyses);$j++) {
				my $analysis = @$analyses[$j];
				if($analysis->{'allmorphs'} =~ /\+Rptn\+Inch/){
					splice (@{$analyses},$j,1);	
					$disambiguatedForms++;
					$j--;
				}
			}
		}
			
		my @crfRows = split('\t', $crfline);
		if( (lc(@$word[0]) eq @crfRows[0]) or (@$word[0] eq '#EOS' and $crfline =~ /^\s*$/ ))
		{
				# check if marked as ambiguous
				if(@$word[3] eq 'amb2')
				{
					$ambigForms++;
					#print STDERR "xfst: @$word[0]  crf: @crfRows[0]\n";
					my $correctMorph = @crfRows[-1];
					my $form = @$word[0];
					$correctMorph =~ s/\n//;
					#print "$correctMorph\n"; #----- ".@$word[0]."\n";
					
					for(my $j=0;$j<scalar(@$analyses);$j++)
					{
						my $analysis = @$analyses[$j];
						my $allmorphs = $analysis->{'allmorphs'};
						
						# at this point, the classes/tags are NOT unique (Sg,Pl), so we cannot just check whether the class is contained in allmorphs		
						# -wanku: 1Sg, 1Pl
						# -wanqaku: 1Sg, 1Pl
						# -npuni: 1Sg, 3Sg
						if($correctMorph eq '1Pl'  && $form =~ /wa.*nqaku/)
						{
							if($allmorphs !~ /\Q1.Pl.Excl\E/ && scalar(@$analyses) > 1){
								splice (@{$analyses},$j,1);	
								$disambiguatedForms++;
								$j--;
							}					
						}
						elsif($correctMorph eq '1Sg'  && $form =~ /wa.*nqaku/)
						{
							if($allmorphs !~ /\Q3.Pl.Subj\E/ && scalar(@$analyses) > 1){
								splice (@{$analyses},$j,1);	
								$disambiguatedForms++;
								$j--;
							}
							
						}
						elsif($correctMorph eq '1Pl'  && $form =~ /wa.*nku/)
						{
							if($allmorphs !~ /\Q1.Pl.Excl\E/ && scalar(@$analyses) > 1){
								splice (@{$analyses},$j,1);	
								$disambiguatedForms++;
								$j--;
							}					
						}
						elsif($correctMorph eq '1Sg'  && $form =~ /wa.*nku/)
						{
							if($allmorphs !~ /\Q3.Pl.Subj\E/ && scalar(@$analyses) > 1){
								splice (@{$analyses},$j,1);	
								$disambiguatedForms++;
								$j--;
							}
							
						}
						elsif($correctMorph eq '1Sg'  && $form =~ /[nm]puni/)
						{
							if($allmorphs !~ /\Q1.Sg.Subj\E/ && scalar(@$analyses) > 1){
								splice (@{$analyses},$j,1);	
								$disambiguatedForms++;
								$j--;
							}
							
						}
						elsif($correctMorph eq '3Sg'  && $form =~ /[nm]puni/)
						{
							if($allmorphs !~ /\Q3.Sg.Subj\E/ && scalar(@$analyses) > 1){
								splice (@{$analyses},$j,1);	
								$disambiguatedForms++;
								$j--;
							}
							
						}
						# no confusion with other tags, just check whether allmorphs contains them
						else
						{
							#print STDERR "$form: all: $allmorphs, correct: $correctMorph"."ll\n";
							if($allmorphs !~ /$correctMorph/ && scalar(@$analyses) > 1){
								#print STDERR "delete: $allmorphs\n";
								splice (@{$analyses},$j,1);	
								$disambiguatedForms++;
								$j--;		
							}
						}
						
					}
					# for debugging: print disambiguated forms
			#		for(my $j=0;$j<scalar(@$analyses);$j++) {
			#			my $analysis = @$analyses[$j];
			#				print @$analyses[$j]->{'string'};
			#		}
					#print "\n";
					# for debugging: print only forms that are still ambiguous
					if(scalar(@$analyses) > 1){
								$stillambigForms++;
				#				for(my $j=0;$j<scalar(@$analyses);$j++) {
				#				my $analysis = @$analyses[$j];
				#				print @$analyses[$j]->{'string'};
				#			}
					}
				}
				else{
					$unambigForms++;
				}
		}
		else{
			print STDERR "not equal in crf line $i: xfst: @$word[0]  crf: @crfRows[0]\n";
			exit;
		}
	}
	# retrieve number of previously disambiguated forms ('rule' based, e.g +Dist/+Term, chiqan/chiqa etc.)
	my $prevdisamb = retrieve('tmp/prevdisambMorph1');
	#print "prev $$prevdisamb\n";
	
	# for testing: print xfst to STDERR
	#&printXFST(\@words);
	my $totalWords = scalar(@words);
	my $unamb = $unambigForms/$totalWords;
	my $amb = $ambigForms/$totalWords;
	my $disamb=0;
	my $stillamb=0;
	if($ambigForms > 0){
	      $disamb = $disambiguatedForms/$ambigForms;
	      $stillamb = $stillambigForms/$ambigForms;
	}
	
	print STDERR "number of words: $totalWords\n"; 
	print STDERR "unambiguous forms: $unambigForms : "; printf STDERR ("%.2f", $unamb); print STDERR "\n";
	print STDERR "ambiguous forms: $ambigForms : "; printf STDERR ("%.2f", $amb); print STDERR "\n";
	print STDERR "disambiguated with morph2: $disambiguatedForms : "; printf STDERR ("%.2f", $disamb); print STDERR "\n";
	print STDERR "still ambiguous after morph2 disambiguation: $stillambigForms : "; printf STDERR ("%.2f", $stillamb); print STDERR "\n";
	
	close CFG;
}


sub disambMorph3{
	my $wordsref = $_[0];
	my @words = @$wordsref;
	
	
	my $unambigForms = 0;
	my $ambigForms = 0;
	my $stillambigForms =0;
	my $disambiguatedForms=0;
	
	my @crfLines = <CRF>;
	# note: if wapiti inserts empty line at the end, delete it
	if(scalar(@crfLines) == scalar(@words)+1 && @crfLines[-1] =~ /^\s*$/){
		pop(@crfLines);
	}
	
	for(my $i=0;$i<scalar(@crfLines);$i++)
	{
		my $crfline = @crfLines[$i];
		my $word = @words[$i];
			
			my @crfRows = split('\t', $crfline);
			if( (lc(@$word[0]) eq @crfRows[0]) or (@$word[0] eq '#EOS' and $crfline =~ /^\s*$/ ))
			{
				# check if marked as ambiguous
				if(@$word[3] eq 'amb3')
				{
					$ambigForms++;
					print STDERR "xfst: @$word[0]  crf: @crfRows[0]\n";
					my $correctMorph = @crfRows[-1];
					my $analyses = @$word[1];
					#print STDERR "$correctMorph\n"; #----- ".@$word[0]."\n";
					for(my $j=0;$j<scalar(@$analyses);$j++)
					{
							my $analysis = @$analyses[$j];
							my $allmorphs = $analysis->{'allmorphs'};
							#my $form = @$word[0];
							my $string = $analysis->{'string'};
							
							# at this point, the classes/tags are NOT unique (Sg,Pl), so we cannot just check whether the class is contained in allmorphs		
							# -n: DirE, Poss
							# -n: DirEs, Subj
							# -pis: Loc_IndE, Add
							# -s: IndE, Pl
							$correctMorph =~ s/\n//g;
							if($correctMorph eq 'DirE')
							{
								if($string !~ /\Qn[Amb][+DirE]\E/ && scalar(@$analyses) > 1){
									splice (@{$analyses},$j,1);	
									$disambiguatedForms++;
									$j--;
								}
							}
							elsif($correctMorph eq 'Poss'  )
							{
								if($string !~ /\Qn[NPers][+3.Sg.Poss]\E/ && scalar(@$analyses) > 1){
									splice (@{$analyses},$j,1);	
									$disambiguatedForms++;
									$j--;
								}
							}
							if($correctMorph eq 'DirEs')
							{
								if($string !~ /\Qn[Amb][+DirE]\E/ && scalar(@$analyses) > 1){
									splice (@{$analyses},$j,1);	
									$disambiguatedForms++;
									$j--;
								}
							}
							elsif($correctMorph eq 'Subj'  )
							{
								if($string !~ /\Q+Aff][^DB][--]n[VPers][+3.Sg.Subj\E/ && scalar(@$analyses) > 1){
									splice (@{$analyses},$j,1);	
									$disambiguatedForms++;
									$j--;
								}
							}
							elsif($correctMorph eq 'Loc_IndE' )
							{
								if($string !~ /\Qpi[Cas][+Loc][^DB][--]s[Amb][+IndE]\E/ && scalar(@$analyses) > 1){
									splice (@{$analyses},$j,1);	
									$disambiguatedForms++;
									$j--;
								}
							}
							elsif($correctMorph eq 'Add' )
							{
								if($string !~ /p[ai]\Qs[Amb][+Add]\E/ && scalar(@$analyses) > 1){
									#print "delete: ".$string;
									splice (@{$analyses},$j,1);	
									$disambiguatedForms++;
									$j--;
								}
							}
							elsif($correctMorph eq 'IndE' )
							{
								if($string !~ /\QNRootES][^DB][--]s[Amb][+IndE]\E/ && scalar(@$analyses) > 1){
									splice (@{$analyses},$j,1);	
									$disambiguatedForms++;
									$j--;
								}
							}
							elsif($correctMorph eq 'Pl' )
							{
								if($string !~ /\Qs[NRootES]\E/ && scalar(@$analyses) > 1){
									splice (@{$analyses},$j,1);	
									$disambiguatedForms++;
									$j--;
								}
							}
							
						}
					# for debugging: print only forms that are still ambiguous
					if(scalar(@$analyses) > 1){
								$stillambigForms++;
				#				for(my $j=0;$j<scalar(@$analyses);$j++) {
				#				my $analysis = @$analyses[$j];
				#				print @$analyses[$j]->{'string'};
				#			}
					}
			}
			else{
				$unambigForms++;
			}
				
		}
		else{
			print STDERR "not equal in crf line $i: xfst: @$word[0]  crf: @crfRows[0]\n";
			exit;
		}
	}
	# retrieve number of previously disambiguated forms ('rule' based, e.g +Dist/+Term, chiqan/chiqa etc.)
	my $prevdisamb = retrieve('tmp/prevdisambMorph1');
	#print "prev $$prevdisamb\n";	
	#print xfst to STDOUT
	#&printXFST(\@words);
	foreach my $word (@words){
		my $analyses = @$word[1];
		foreach my $analysis (@$analyses){
			print  $analysis->{'string'};
		}
		print "\n";
	}
		
	
	
	my $totalWords = scalar(@words);
	$ambigForms = $$prevdisamb + $ambigForms;
	my $unamb = $unambigForms/$totalWords;
	my $amb = ($$prevdisamb + $ambigForms)/$totalWords;
	my $disamb=0;
	my $stillamb=0;
	if($ambigForms > 0){
	    $disamb = ($$prevdisamb + $disambiguatedForms)/$ambigForms;
	    $stillamb = $stillambigForms/$ambigForms;
	}
	
	
	print STDERR "number of words: $totalWords\n"; 
	print STDERR "unambiguous forms: $unambigForms : "; printf STDERR ("%.2f", $unamb); print STDERR "\n";
	print STDERR "ambiguous forms: $ambigForms : "; printf STDERR ("%.2f", $amb); print STDERR "\n";
	print STDERR "disambiguated with morph3: rules: $$prevdisamb, crf: $disambiguatedForms : "; printf STDERR ("%.2f", $disamb); print STDERR "\n";
	print STDERR "still ambiguous after morph3 disambiguation: $stillambigForms : "; printf STDERR ("%.2f", $stillamb); print STDERR "\n";
	
	close CFG;
}

sub sentenceHasEvid{
	my $wordsref = $_[0];
	my @words = @$wordsref;
	my $i = $_[1];
	
	my $word = @words[$i];
	
	my $analyses = @$word[1];
	my $form = @$word[0];
	
	my $j = $i-1;
	my $prestring = $form;
	#print "word: $prestring\n";
	while($prestring !~ /\[\$/ && $j>= 0){
		my $preword = @words[$j];
		my $preanalyses = @$preword[1];
		# don't consider forms that are still ambiguous
		if(scalar(@$preanalyses)==1){
			$prestring = @$preanalyses[0]->{'string'};
			my $preallmorphs = @$preanalyses[0]->{'allmorphs'};
			if($preallmorphs =~ /DirE|IndE|Asmp/ && $prestring!~ /hinaspan/ ){
				#print "found $prestring, $preallmorphs\n";
				return 1;
			}
		}
		$j--;
	}
	my $j = $i+1;
	my $poststring = $form;
	#print "word: $poststring\n";
	while($poststring !~ /\[\$/ && $j< scalar(@words) ){
		my $postword = @words[$j];
		my $postanalyses = @$postword[1];
		if(scalar(@$postanalyses)==1){
			$poststring = @$postanalyses[0]->{'string'};
			my $postallmorphs = @$postanalyses[0]->{'allmorphs'};
			if($postallmorphs =~ /DirE|IndE|Asmp/ && $poststring !~ /hinaspan/  ){
				#print "found $poststring, $postallmorphs\n";
				return 1;
			}
		}
		$j++;
	}
	#print "\n";
	return 0;
}

