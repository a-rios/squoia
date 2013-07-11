#!/usr/bin/perl

use strict;
use utf8;
binmode STDIN, ':utf8';
binmode STDERR, ':utf8';
binmode STDOUT, ':utf8';
use Storable;

# get possible roots from xfst and store hash with this info to disk

my @words;
my $newWord=1;
my $index=0;

my @words;
my $newWord=1;
my $index=0;

my $storedWords;


while(<STDIN>){
		
		if (/^$/)
		{
			$newWord=1;
		}
		else
		{	
			unless(/RootG/){
				my ($form, $analysis) = split(/\t/);
			
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
				my ($lem) = ($_ =~ m/([A-Za-zñéóúíáüÑ']+?)\[/ );
				$lem = lc($lem);
				#print $lem."\n";
				
				my @morphtags =  $analysis =~ m/(\+.+?)\]/g ;
				
				my $allmorphs='';
				foreach my $morph (@morphtags){
					$allmorphs = $allmorphs."#".$morph;
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
}

my %wordforms =();

foreach my $word (@words){
		my $form = @$word[0];
		my $analyses = @$word[1];
		my @possibleClasses;
		
		if(exists $wordforms{$form}  ){
			my $possibleClassesRef = $wordforms{$form};
			@possibleClasses = @$possibleClassesRef;
		}
		
		foreach my $analysis (@$analyses){
				my $pos = $analysis->{'pos'};
				unless (grep {$_ =~ /\Q$pos\E/} @possibleClasses ){
					push(@possibleClasses, $pos);
			}
		}
		
		$wordforms{$form} = \@possibleClasses;
		
}

foreach my $word (keys %wordforms){
	#print "$word: ";
	my $possiblePos = $wordforms{$word};
	#print "@$possiblePos\n";
}

store \%wordforms, 'PossibleRootsForTrain';
		
		
my %Morphanalyses =();

foreach my $word (@words){
		my $form = @$word[0];
		my $analyses = @$word[1];
		my @possibleMorphs;
		
		if(exists $Morphanalyses{$form}  ){
			my $possibleMorphsRef = $Morphanalyses{$form};
			@possibleMorphs = @$possibleMorphsRef;
		}
		
		foreach my $analysis (@$analyses){
				my $allmorphs = $analysis->{'allmorphs'};
				unless (grep {$_ =~ /\Q$allmorphs\E/} @possibleMorphs ){
					push(@possibleMorphs, $allmorphs);
			}
		}
		
		$Morphanalyses{$form} = \@possibleMorphs;
		
}

foreach my $word (keys %Morphanalyses){
	#print "$word: ";
	my $possibleMorphs = $Morphanalyses{$word};
	#print "@$possibleMorphs\n";
}

store \%Morphanalyses, 'PossibleMorphsForTrain';

my %Lemmas =();

foreach my $word (@words){
		my $form = @$word[0];
		my $analyses = @$word[1];
		my @possibleLemmas;
		
		if(exists $Lemmas{$form}  ){
			my $possibleLemmasRef = $Lemmas{$form};
			@possibleLemmas = @$possibleLemmasRef;
		}
		
		foreach my $analysis (@$analyses){
				my $lem = $analysis->{'lem'};
				unless (grep {$_ =~ /\Q$lem\E/} @possibleLemmas ){
					push(@possibleLemmas, $lem);
			}
		}
		
		$Lemmas{$form} = \@possibleLemmas;
		
}

foreach my $word (keys %Lemmas){
#	print "$word: ";
	my $possibleLemmas = $Lemmas{$word};
#	print "@$possibleLemmas\n";
}

store \%Lemmas, 'PossibleLemmasForTrain';
				
		
		