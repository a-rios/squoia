use strict;
use open ':utf8';
binmode STDIN, ':utf8';
binmode STDERR, ':utf8';
binmode STDOUT, ':utf8';

my $num_args = $#ARGV;

if ( $num_args != 2) {
  print "\nUsage: perl evalCRFwithGold.pl results.crf gold.crf -pos/-morph \n";
  exit;
  }

my $crfFile = $ARGV[0];
my $goldFile = $ARGV[1];
my $mode = $ARGV[2];


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

 while (!eof(CRF) and !eof(GOLD)) {
 	  
 	  my $crfLine= <CRF>;
      my $goldLine = <GOLD>;
      $lines++;

	#print "test: ".$crfLine;
	#print "gold: ".$goldLine;
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
		 $wcount++;
		 my @rowsCRF = split (/\t|\s/, $crfLine);	 
		 my @rowsGOLD = split (/\t|\s/, $goldLine);	 
		 
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
			}
		
		 }
		 elsif($mode eq '-pos')
		 {
		 	# only pos: count ambiguos words
		 	if(@rowsCRF[3] ne 'ZZZ'){
#		 		print "$classCRF : $classGOLD\n";
				$wordsToDisamb++;
		 	}
		 	
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

# check xfst gold standard consistency
#	else{
#		my ($word,$rest) = split (/\t|\s/, $crfLine);	 
#		 my ($word2,$rest2) = split (/\t|\s/, $goldLine);	 
#		 
#		if($word ne $word2)
#		{die "different words: $word vs. $word2, at line $lines\n";}
#	}

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
	#my $truewrongPos = (($wrongClass-$unknownWords)/$wordsToDisamb)*100;
	 
	print "\n*************************************************\n\n";
	print "POS EVAL:\n";
	print "   total sentences: $nbrOfSentences\n";
	print "   total words: $wcount\n";
	print "   ambiguous words: $wordsToDisamb\n";
	print "   correct class: $correctClass : ";
	   printf("%.2f", $correctPos); print "%\n";
	print "   wrong class: $wrongClass : "; 
	   printf("%.2f", $wrongPos); print "%\n";
#	print "   wrong class, xfst failures not considered: "; 
#	   printf("%.2f", $truewrongPos); print "\n\n";
	print "*************************************************\n\n";
}


close CRF;
close GOLD;


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
