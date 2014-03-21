#!/usr/bin/perl

use strict;
use open ':utf8';
binmode STDIN, ':utf8';
binmode STDERR, ':utf8';
binmode STDOUT, ':utf8';

my $num_args = $#ARGV;

if ( $num_args != 1) {
  print STDERR "\nUsage: perl disambiguate.pl disambiguated.crf ambiguous.xfst \n";
  exit;
  }


my $crfFile = $ARGV[0];
my $xfstFile = $ARGV[1];

open XFST, "< $xfstFile" or die "Can't open $xfstFile : $!";
open CRF, "< $crfFile" or die "Can't open $crfFile : $!";


my @words;
my $newWord=1;
my $index=0;

while(<XFST>){
	
	if (/^$/)
	{
		$newWord=1;
	}
	else
	{	
		my ($form, $analysis) = split(/\t/);
	
		my ($root) = $analysis =~ m/(ALFS|CARD|NP|NRoot|Part|VRoot|PrnDem|PrnInterr|PrnPers|SP|\$|AdvES|PrepES|ConjES)/ ;
		
		if($root eq 'NP'){
					$root = 'NRoot';
		}
		
		if($root eq ''){
			if($form eq '#EOS'){
				$root = '#EOS';
			}
			else{
				$root = "ZZZ";
			}
		}
		
		my @morphtags =  $analysis =~ m/(\+.+?)\]/g ;
	
		#print "$form: $root morphs: @morphtags\n";
		my %hashAnalysis;
		$hashAnalysis{'pos'} = $root;
		$hashAnalysis{'morph'} = \@morphtags;
		$hashAnalysis{'string'} = $_;
    
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

chomp(my @crfLines = <CRF>);

# remove empty lines at the end of crf file, then compare length to xfst (must be the same!)
my $i = -1;
while(@crfLines[$i] =~ /^$/){
	pop(@crfLines);
}

# find differences in files
for(my $i=0;$i<scalar(@words);$i++){
	my $line = @crfLines[$i];
	my ($crfform, $rest) = split('\t',$line);
	
	my $word = @words[$i];
	my $analyses = @$word[1];
	my $form = @$word[0];
	
	if(lc($form) ne $crfform ){
		unless($form eq '#EOS' and $crfform eq ''){
		print STDERR "pos disamb: not the same word in line ".($i+1).": xfst:$form, crf:$crfform\n";
		#exit;
		}
	}
	#print "same word in line ".($i+1).": xfst:$form, crf:$crfform\n";
	
}

#my $last = @words[-1];
#my $last2 = @words[-2];
#print "last word in xfst:".@$last[0]."\n";
#print "prelast word in xfst:".@$last2[0]."\n";

#if(scalar(@crfLines) != scalar(@words)){
#	print "crf file and xfst file do not contain the same number of words, cannot disambiguate!\n";
#	print "words in $crfFile: ".scalar(@crfLines)."\n";
#	print "words in $xfstFile: ".scalar(@words)."\n";
#	exit;
#}

#foreach my $line (@crfLines){
#	my ($word, $rest) = split('\t',$line);
#	print "$word\n";
#}

my $unambigForms = 0;
my $ambigForms = 0;
my $stillambigForms =0;
my $disambiguatedForms=0;

for(my $i=0;$i<scalar(@words);$i++){
	my $word = @words[$i];
	my $analyses = @$word[1];
	my $form = @$word[0];
	
	# only one analysis, print as is
	if(scalar(@$analyses) == 1){
		print @$analyses[0]->{'string'}."\n";
		$unambigForms++;
	}
	
	else
	{	
		$ambigForms++;
		# get valid pos from crf file (same index!)
		my $crfline = @crfLines[$i];
		my (@rows) = split('\t',$crfline);
		my $correctPos = @rows[-1];
		
		# possible root pos
		for(my $j=0;$j<scalar(@$analyses);$j++) {
			my $analysis = @$analyses[$j];
			my $pos = $analysis->{'pos'};
			
			if($pos !~ /\Q$correctPos\E/ && scalar(@$analyses) > 1){
				splice (@{$analyses},$j,1);	
				$disambiguatedForms++;
				$j--;		
			}
		}

		for(my $j=0;$j<scalar(@$analyses);$j++) {
			my $analysis = @$analyses[$j];
				print @$analyses[$j]->{'string'};
		}

		# for debugging: print only forms that are still ambiguous
		if(scalar(@$analyses) > 1){
				$stillambigForms++;
#				for(my $j=0;$j<scalar(@$analyses);$j++) {
#				my $analysis = @$analyses[$j];
#				print @$analyses[$j]->{'string'};
#			}
	}
		
		print "\n";
		
	}
}

	#&printXFST(\@words);
	my $totalWords = scalar(@words);
	my $unamb = $unambigForms/$totalWords;
	my $amb = $ambigForms/$totalWords;
	my $disamb = $disambiguatedForms/$ambigForms;
	my $stillamb = $stillambigForms/$ambigForms;
	
	print STDERR "number of words: $totalWords\n"; 
	print STDERR "unambiguous forms: $unambigForms: "; printf STERR ("%.2f", $unamb); print STDERR "\n";
	print STDERR "ambiguous forms: $ambigForms: "; printf STDERR ("%.2f", $amb); print STDERR "\n";
	print STDERR "disambiguated with pos: $disambiguatedForms: "; printf STDERR ("%.2f", $disamb); print STDERR "\n";
	print STDERR "still ambiguous after pos disambiguation $stillambigForms: "; printf STDERR ("%.2f", $stillamb); print STDERR "\n";
	
