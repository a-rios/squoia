use strict;
use open ':utf8';
binmode STDIN, ':utf8';
binmode STDERR, ':utf8';
binmode STDOUT, ':utf8';
use Storable;

my $num_args = $#ARGV;

if ( $num_args != 2) {
  print "\nUsage: perl evalCRFwithGold.pl results.crf/results.xfst gold.crf/gold.xfst -pos/-morph/-xfst \n";
  exit;
  }

my $mode = $ARGV[2];

if($mode eq '-pos' or $mode eq '-morph')
{
	 
	my $crfFile = $ARGV[0];
	my $goldFile = $ARGV[1];

	open CRF, "< $crfFile" or die "Can't open $crfFile : $!";
	open GOLD, "< $goldFile" or die "Can't open $goldFile : $!";
	#my $crfLine = <CRF>;
	#my $goldLine = <GOLD>;
	#print "$goldLine\n$crfLine\n\n";
	
	my $wcount=0;
	my $correctClass=0;
	my $unknownWords=0;
	my $nbrOfSentences=0;
	my $lines=0;
	my $unamb =0;
	my $wordsToDisamb =0;
	my $wrongClass =0;
	my $nbrTokens=0;

	while (!eof(CRF) and !eof(GOLD)) 
 	{
 	  
 	  my $crfLine= <CRF>;
      my $goldLine = <GOLD>;
      $lines++;

		# check xfst gold standard consistency
		
				my ($word,$rest) = split (/\t|\s/, $crfLine);	 
				 my ($word2,$rest2) = split (/\t|\s/, $goldLine);	 
				 
				  $word =~ s/e/i/g;
				 $word =~ s/o/u/g;
				 $word =~ s/ó/u/g;
				 
				 $word2 =~ s/e/i/g;
				 $word2 =~ s/o/u/g;

				if(lc($word) ne lc($word2)){
					#print "different words: $word vs. $word2, at line $lines\n";
				}

		#print "test: ".$crfLine;
		#print "gold: ".$goldLine;
		#print "$word : $word2\n";
		#if one of the lines is empty, but the other is not-> mismatch in files		
		if( ($crfLine =~ /^\s*$/) != ($goldLine =~ /^\s*$/) )
		{
			die "different sentence splitting at line $lines, cannot compare!\n"
			
		}	
		#skip empty lines (don't count them as words!)
		elsif($crfLine =~ /^\s*$/ and $goldLine =~ /^\s*$/ )
		{
			$nbrOfSentences++;
			next;
		}
		else
		{
			$nbrTokens++;
			 my @rowsCRF = split (/\t|\s/, $crfLine);	 
			 my @rowsGOLD = split (/\t|\s/, $goldLine);	 
			 
			 unless(@rowsCRF[1] eq 'n'){
			 	$wcount++;
			}
			 
			 # pos(morph) evaluation
			 my $classCRF = @rowsCRF[-1];
			 my $classGOLD = @rowsGOLD[-1]; 
			 
			 if($mode eq '-morph')
			 {
				if($classCRF eq $classGOLD){
					$correctClass++;
				}
				else{
					$wrongClass++;
					#print "$classCRF : $classGOLD\n";
				}
			
			 }
			 elsif($mode eq '-pos')
			 {
			 	# only pos: count ambiguos words
			 	if(@rowsCRF[3] ne 'ZZZ'){
	#		 		print "$classCRF : $classGOLD\n";
					$wordsToDisamb++;
			 	}
			 	# with lc, index 4, without, 3
				if($classCRF eq $classGOLD && @rowsCRF[3] ne 'ZZZ'){
					$correctClass++;
				}
				elsif($classCRF ne $classGOLD && @rowsCRF[3] ne 'ZZZ'){
					$wrongClass++;
					print "$classCRF : $classGOLD\n";
				}
				# pos eval: count xfst failures
				# check if first pos in results is ZZZ, in this case, xfst could not analyse the word
				# -> count those separately for evaluation
	#			elsif($classCRF ne $classGOLD && @rowsCRF[2] eq 'ZZZ')
	#			{
	#				$unknownWords++;
	#			}
			 }
		}

	}
	 
	if($mode eq '-morph')
	{
		#my $wordsToDisamb = $wcount-$unamb;
		my $nbrOfCorrectMorph = ($correctClass/$wcount)*100;
		my $nbrOfWrongMorph = ($wrongClass/$wcount)*100;
		
		print "\n*************************************************\n\n";
		print "MORPH EVAL:\n";
		print "   ambiguous forms: $wcount\n"; 
		print "   correct: $correctClass : ";
			printf("%.2f", $nbrOfCorrectMorph); print "%\n\n";  
		print "   wrong: $wrongClass : ";
			printf("%.2f", $nbrOfWrongMorph); print "%\n\n";  
		print "*************************************************\n\n";
	}
	elsif($mode eq '-pos')
	{
		my $correctPos = ($correctClass/$wordsToDisamb)*100;
		my $wrongPos = ($wrongClass/$wordsToDisamb)*100;
		
		my $totalWrong = ($wrongClass/$wcount)*100;
		#my $truewrongPos = (($wrongClass-$unknownWords)/$wordsToDisamb)*100;
		 
		print "\n*************************************************\n\n";
		print "POS EVAL:\n";
		print "   total sentences: $nbrOfSentences\n";
		print "   total token: $nbrTokens\n";
		print "   total words: $wcount\n";
		print "   ambiguous roots: $wordsToDisamb\n";
		print "   correct class: $correctClass : ";
		   printf("%.2f", $correctPos); print "%\n";
		print "   wrong class: $wrongClass : "; 
		   printf("%.2f", $wrongPos); print "%\n";
		print "total wrong  roots: ";
		 printf("%.2f", $totalWrong); print "%\n";
	#	print "   wrong class, xfst failures not considered: "; 
	#	   printf("%.2f", $truewrongPos); print "\n\n";
		print "*************************************************\n\n";
	}
	
	
	close CRF;
	close GOLD;
}

elsif($mode eq '-xfst')
{
	my $results = $ARGV[0];
	open RESULTS, "< $results" or die "Can't open $results: $!";
	
	my $gold = $ARGV[1];
	open GOLD, "< $gold" or die "Can't open $gold: $!";
	
	
	# read in xfst (we can't do that line by line in parallel, 
	# because results can still contain ambiguous words, 
	# so the line numbering might not not the same in $results and $gold)
	my @words;
	my $newWord=1;
	my $index=0;
	my $nbrOfSentences=0;
	
	while(<RESULTS>)
	{
		
		if (/^$/)
		{
			$newWord=1;
		}
		else
		{	
			my ($form, $analysis) = split(/\t/, $_, 2);
			# remove roots for comparison
			unless($analysis =~ /\+\?/){
				my ($root) = ($analysis =~ m/(.+?)\[/ );
				$analysis =~ s/\Q$root\E// ;
			}
			#print "$analysis\n";
	    	if($form eq '#EOS'){
	    		$nbrOfSentences++;
	    	}
			if($newWord)
			{
				my @analyses = ($analysis);
				my @word = ($form, \@analyses);
				push(@words,\@word);
				$index++;
			}
			else
			{
				my $thisword = @words[-1];
				my $analyses = @$thisword[1];
				push(@$analyses, $analysis);
			}
			$newWord=0;	
	 }
		
	}
	close XFST;
	
	my @goldwords;
	while(<GOLD>)
	{
		#ignore empty lines
		unless(/^$/)
		{	
			my ($form, $analysis) = split(/\t/, $_, 2);
			# remove roots for comparison
			unless($analysis =~ /\+\?/){
				my ($root) = ($analysis =~ m/(.+?)\[/ );
				$analysis =~ s/\Q$root\E// ;
			}

			my @word = ($form, $analysis);
			push(@goldwords, \@word);
		 }
		
	}
	close GOLD;
	
#	foreach my $w (@goldwords){
#		print @$w[0]."\n";
#		print @$w[1]."\n\n";
#	}
	
#	foreach my $w (@words){
#		print @$w[0]."\n";
#		my $analyses = @$w[1];
#		
#		foreach my $analysis (@$analyses){
#			print $analysis."\n";
#		}
#		print "\n";
#	}
	# check if files contain the same number of words
	if(scalar(@goldwords) != scalar(@words)){
		print STDERR "different number of words, cannot compare!\n";
#		for (my $i=0;$i<scalar(@words) or $i<scalar(@goldwords);$i++ ){
#			my $g = @goldwords[$i];
#			my $w = @words[$i];
#			print "test: @$w[0] , gold: @$g[0]\n";
#		}
		print STDERR "results file contains ".scalar(@words)." words, but gold file contains ".scalar(@goldwords)."!\n";
		exit;
	}

	my $correctAnalysis = 0;
	my $wrongAnalysis = 0;
	my $stillAmbigForms = 0;
	my $totalAmbigForms  = retrieve('totalAmbigForms');
	my $xfstFailures=0;
	my $punct =0;

	for (my $i=0;$i<scalar(@words) or $i<scalar(@goldwords);$i++ ){
		my $g = @goldwords[$i];
		my $w = @words[$i];
		
		my $analyses = @$w[1];
		# more than one analysis: word is still ambiguous (root lemma)
		if(scalar(@$analyses)>1){
			$stillAmbigForms++;
		}
		else{
			#print @$analyses[0]."\n".@$g[1]."\n\n";
			unless(@$g[1] =~ /#EOS/)
			{
				if(@$analyses[0] eq @$g[1]){
					$correctAnalysis++;
					#print @$analyses[0]; #."---".@$g[1]."\n";
				}
				#xfst failures, count separately
				elsif(@$analyses[0] =~ /\+\?$/){
					$xfstFailures++;
				}
				# punctuation marks, don't count them
				elsif(@$analyses[0] =~ /\$/){
					$punct++;
				}
				else{
					$wrongAnalysis++;
					print "result: ".@$analyses[0]."gold: ".@$g[1]."\n";
				}
			}
			
		}
		
		
		# find differences in line numbering:
		#print "gold : @$g[0], results: @$w[0]\n";
	}
	
		#my $correct = ($correctAnalysis/$$totalAmbigForms)*100;
	#	my $wrong = ($wrongAnalysis/$$totalAmbigForms)*100;
		
		my $wordforms = scalar(@words)-$punct;
		my $correct = ($correctAnalysis/$wordforms)*100;
		my $wrong = ($wrongAnalysis/$wordforms)*100;
		
		my $correctOfAmbForms = $$totalAmbigForms-$stillAmbigForms-$wrongAnalysis;
		my $correctOfAmb = ($correctOfAmbForms/$$totalAmbigForms)*100;
		my $wrongOfAmb = ($wrongAnalysis/$$totalAmbigForms)*100;
		#my $truewrongPos = (($wrongClass-$unknownWords)/$wordsToDisamb)*100;
		 
		print "\n*************************************************\n\n";
		print "XFST EVAL:\n";
		print "   total sentences: $nbrOfSentences\n";
		print "   total token ".(scalar(@words)-$nbrOfSentences)."\n";
		print "   total word forms $wordforms\n";
		 print "   punctuation marks: $punct\n";  
		print "   total with correct analysis: $correctAnalysis : ";
		 printf("%.2f", $correct); print "%\n";
		print "   total with wrong analysis: $wrongAnalysis : ";
		  printf("%.2f", $wrong); print "%\n";
		print "   xfst failures: $xfstFailures\n"; 
		print "   total still ambiguous: $stillAmbigForms\n ";
		
		print "   correct of ambiguous: $correctOfAmbForms : ";
		   printf("%.2f", $correctOfAmb); print "%\n";
		print "   wrong of ambiguous: $wrongAnalysis : "; 
		   printf("%.2f", $wrongOfAmb); print "%\n\n";
		
		print "*************************************************\n\n";
	
}


# old stuff
#	unless($classGOLD eq 'none' && $classCRF eq 'none')
#		{
#			#print "$classCRF $classGOLD\n $crfLine $goldLine\n";
#		}
#
#		if($classCRF eq $classGOLD && $classGOLD ne 'none')
#		{
#			$correctClass++;
#			$wordsToDisamb++;
#			#print "correct:  $classCRF  $classGOLD\n";
#		}
#		# morph eval: count unambiguous forms
#		elsif($classGOLD eq 'none'){
#				#print "unamb: $classCRF $classGOLD\n";
#				$unamb++;
#		}
#		# pos eval: count xfst failures
#		# check if first pos in results is ZZZ, in this case, xfst could not analyse the word
#		# -> count those separately for evaluation
#		elsif(@rowsCRF[2] eq 'ZZZ')
#		{
#			$unknownWords++;
#		}
#		elsif($classGOLD ne 'none'){
#			$wordsToDisamb++;
#			#print "false: $classCRF $classGOLD\n";
#		}
#
