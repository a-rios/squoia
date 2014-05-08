#!/usr/bin/perl

#use utf8;                  # Source code is UTF-8

use strict;
binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';

my $newSentence = 1;
my $prev;
my $prevPunc;
my $startedWithPunc=0;

my %sentLattice=();
my $wordcount=0;
my $nbrOfAltSents=1;

my $sentOpts=0;

while(<>){
	
	#skip empty line
    unless(/^\s*$/)
    {
    	if(/#EOS/)
    	{
      		$newSentence=1;
      		#print sentence(s) with $nrbOfSentAlts with previous sentence
      		my $lastWordAlternatives = scalar(@{$sentLattice{$wordcount}});
      		$nbrOfAltSents = $nbrOfAltSents * $lastWordAlternatives;
      		&printLattice(\%sentLattice, $nbrOfAltSents);
      		undef(%sentLattice);
    		#%sentLattice=();
      		$wordcount=0;
      		$nbrOfAltSents=1;
      		undef($prev); undef($prevPunc); $startedWithPunc=0;
    	}
    	# word with analysis
    	else
   		{
   			s/\t//g;
   			s/\n//g;
   			#punctuation marks come with their mi tag, split
   			#my ($word,$pmi) = split('-PUNC-');
   			#print  "pmi: $word, $pmi\n";
   			my $word = $_;
     		#start a new sentence 
    		if($newSentence == 1) 
    		{ 
    			$newSentence =0;
      			#print "new sentence\n";
      			#print "wc: $wordcount, nbrofAlts: $nbrOfAltSents\n";
      			#foreach my $key (keys %sentLattice){print "key: $key\n";}
    			$sentLattice{$wordcount}=[$word];
    		}
    		else
    		{
    			# alternative translation
				if($word =~ /^\/.+/){
					push($sentLattice{$wordcount}, $word);
				}
				else{
					# count entries for previous words and multiply with $nbrOfAltSents before storing new word
					my $prevWordAlternatives = scalar(@{$sentLattice{$wordcount}});
					#print "prevAlts: $prevWordAlternatives\n";
					$nbrOfAltSents = $nbrOfAltSents * $prevWordAlternatives;
					
					$wordcount++;
					$sentLattice{$wordcount}=[$word];
				}
    		}
   		}
    }
}

sub printLattice{
	my $sentLatticeref = $_[0];
	my %sentLattice = %$sentLatticeref;
	my $nbrOfAltSents = $_[1];
	#my %alternativeSentArrays=();
	my $nbrOfWords = scalar(keys %sentLattice);
	my %sentMatrix=();
	
	print "nbr of alts: $nbrOfAltSents\n";
	
	my @indexesOfAmbigWords;
	#create matrix: $nbrOfAltSents x $nbrOfWords that contains all possible sentences
	foreach my $key (sort { $a <=> $b} keys %sentLattice){
		my $wordarray = $sentLattice{$key};
		#print "at $key: ".@$wordarray[$key]."\n";
		# word with more than one option
		if(scalar(@$wordarray)>1){
			push(@indexesOfAmbigWords, $key);
		}
		# otherwise: fill matrix with $wordarray[0]
		else{
			for(my $opt=0;$opt<$nbrOfAltSents;$opt++){
				$sentMatrix{$opt}{$key}=@$wordarray[0];
			}
			
		}
	
	}
	#print "ambigs: @indexesOfAmbigWords\n";
	# if all words are ambiguous: initialize hash with dummy value
	if(scalar(@indexesOfAmbigWords) == scalar (keys %sentLattice)){
		for(my $opt=0;$opt<$nbrOfAltSents;$opt++){
				$sentMatrix{$opt}{0}="dummy";
			}
	}

	if(scalar(@indexesOfAmbigWords)>0){
		my $first=0;
		my $last =scalar(@indexesOfAmbigWords)-1;
		#print "non recursive with first:$first last:$last\n";
		&insertTransOpts(\%sentMatrix,$first,$last,\@indexesOfAmbigWords);		
	}

	$sentOpts=0;
	#&printMatrix(\%sentMatrix);
	&printSents(\%sentMatrix);
	#print "\n--------------------------\n";


}

sub insertTransOpts{
	my $sentMatrixRef = $_[0];
	my %sentMatrix = %$sentMatrixRef;	
	my $first = $_[1];
	my $last= $_[2];
	my $indexesOfAmbigWords = $_[3];
	
	my $wordarray = $sentLattice{@{$indexesOfAmbigWords}[$first]};
	my $thisindex = @$indexesOfAmbigWords[$first];
	
	for(my $indexInFirstArray=0; $indexInFirstArray<scalar(@$wordarray);$indexInFirstArray++)
	{
		#print "called with first:$first  last:$last , called at pos:$indexInFirstArray of $thisindex ".@$wordarray[$indexInFirstArray]." sentopts: $sentOpts\n";
		if($first<$last)
		{
			my $startOpts= $sentOpts;
			#print "recursive with first:$first  last:$last , called at pos:$indexInFirstArray of $thisindex ".@$wordarray[$indexInFirstArray]." sentopts: $sentOpts\n";
			&insertTransOpts($sentMatrixRef,$first+1,$last,$indexesOfAmbigWords);
			for(my $i=$startOpts;$i<$sentOpts;$i++){
					#print "set opt:$i with word ".@$wordarray[$indexInFirstArray]." at first $first\n";
					$sentMatrix{$i}{$thisindex}= @$wordarray[$indexInFirstArray];
			}	
		}
		else{
			$sentMatrix{$sentOpts}{@$indexesOfAmbigWords[$first]}= @$wordarray[$indexInFirstArray];
			#print "filled opt:$sentOpts with word ".@$wordarray[$indexInFirstArray]." at pos $first ";
			#print "opt+1 hieer\n"; 
			$sentOpts++;	
		}
	}

	#print "\n#####################\n";
	#&printMatrix(\%sentMatrix);
	#print "\n#####################\n";
}



sub printMatrix{
	my $sentMatrixRef = $_[0];
	my %sentMatrix = %$sentMatrixRef;
	
	foreach my $opt (sort { $a <=> $b} keys %sentMatrix){
		print "$opt: ";
		my $sent = $sentMatrix{$opt};
		foreach my $w (sort { $a <=> $b} keys %$sent){
			print $sentMatrix{$opt}{$w}." ";
		}
		print "\n";
	}
}


sub printSents{
	
	my $sentMatrixRef = $_[0];
	my %sentMatrix = %$sentMatrixRef;
	
	foreach my $opt (sort { $a <=> $b} keys %sentMatrix){
		print "$opt: ";
		my $sent = $sentMatrix{$opt};
		foreach my $w (sort { $a <=> $b} keys %$sent){
			#print $sentMatrix{$opt}{$w}." --";
			#punctuation marks come with their mi tag, split
   			my ($word,$pmi) = split('-PUNC-',$sentMatrix{$opt}{$w});
   			$word =~ s/^\/(.+)/$1/g;
			#print  "$word: $pmi\n";
     		#start a new sentence 
    		if($w == 0) 
    		{ 
				# uppercase first word in sentence
				#TODO
				if($word eq ',' || $pmi =~ /T$/ )
				{
					$startedWithPunc =1;
				}
				else
				{
					$word =ucfirst($word);
					print STDOUT "$word";
					$prev = $word;
					$prevPunc = $pmi;
					$startedWithPunc =0;
				}
    		}
			else
    		{
    			unless($word eq ',' && $prev eq ',')
				{
    				# if this is a punctuation mark,
					# check whether its closing (attach to previous word), pmi:
					# - ends with 'T'
					# - is FP (.), FC (,), FD (:), FX (;), FT (%), FS (...)
					# or opening (pmi ends with 'A') or is 
					# special case '/' (FH) -> no space at all
					# mathematical signs: -, +, = -> treat same as words (spaces both left and right)
					if(($pmi ne '' && $pmi =~ /T$/) || $pmi =~ /FH|FP|FC|FD|FX|FT|FS$/ ||  $pmi eq 'FH') 
					{
						print STDOUT "$word";
						$prevPunc = $pmi;
						$prev = $word;
					}
					elsif($pmi =~ /A$/ )
					{
						print STDOUT " $word";
						$prevPunc = $pmi;
					}
					elsif($prevPunc =~ /A$/ || $prevPunc eq 'FH' )
					{
						print STDOUT "$word";
						$prevPunc = '';
						$prev = $word;
					}
					else
					{
						print STDOUT " $word";
						$prev = $word;
					}
					
				}
    		}
		}
		print "\n";
	}
	
}
  