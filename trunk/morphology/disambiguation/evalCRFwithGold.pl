use strict;
use open ':utf8';
binmode STDIN, ':utf8';
binmode STDERR, ':utf8';
binmode STDOUT, ':utf8';

my $num_args = $#ARGV;

if ( $num_args != 1) {
  print "\nUsage: perl evalCRFwithGold.pl results.crf gold.crf \n";
  exit;
  }

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
		 
		 #print "$crfLine\n";
		#print " @rowsCRF[0], @rowsGOLD[0] ----  $classCRF, $classGOLD\n";
		unless($classGOLD eq 'none' && $classCRF eq 'none')
		{
			#print "$classCRF $classGOLD\n $crfLine $goldLine\n";
		}

		if($classCRF eq $classGOLD && $classGOLD ne 'none')
		{
			$correctClass++;
			$wordsToDisamb++;
			#print "correct:  $classCRF  $classGOLD\n";
		}
		# morph eval: count unambiguous forms
		elsif($classGOLD eq 'none'){
				#print "unamb: $classCRF $classGOLD\n";
				$unamb++;
		}
		# pos eval: count xfst failures
		# check if first pos in results is ZZZ, in this case, xfst could not analyse the word
		# -> count those separately for evaluation
		elsif(@rowsCRF[2] eq 'ZZZ')
		{
			$unknownWords++;
		}
		elsif($classGOLD ne 'none'){
			$wordsToDisamb++;
			#print "false: $classCRF $classGOLD\n";
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

my $correct = ($correctClass/$wcount)*100;
my $nbrOfwrong = ($wcount-$correctClass); 
my $wrong = ($nbrOfwrong/$wcount)*100;
my $truewrong = (($nbrOfwrong-$unknownWords)/$wcount)*100;


#my $wordsToDisamb = $wcount-$unamb;
$correctClass;
my $nbrOfCorrectMorph = ($correctClass/$wordsToDisamb)*100;

 
print "\n*************************************************\n\n";
print "POS EVAL:\n";
print "   total sentences: $nbrOfSentences\n";
print "   total words: $wcount\n";
print "   correct class: ";
   printf("%.2f", $correct); print "\n";
print "   wrong class: "; 
   printf("%.2f", $wrong); print "\n";
print "   wrong class, xfst failures not considered: "; 
   printf("%.2f", $truewrong); print "\n\n";
print "*************************************************\n\n";
print "MORPH EVAL:\n";
print "   morph disamb, ambiguous forms: $wordsToDisamb\n"; 
print "   correct: $correctClass : ";
	printf("%.2f", $nbrOfCorrectMorph); print "\n\n";   
print "*************************************************\n\n";


close CRF;
close GOLD;


