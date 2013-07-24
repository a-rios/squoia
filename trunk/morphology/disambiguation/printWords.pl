#!/usr/bin/perl

# print out sentences from disambiguated xfst
# in case a word still remains ambiguous: print first option as default

use strict;
use utf8;
binmode STDIN, ':utf8';
binmode STDERR, ':utf8';
binmode STDOUT, ':utf8';



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
			my ($form, $analysis) = split(/\t/);
			#print $form."\n";
			
			my ($root) = $analysis =~ m/^([^\[]+?)\[/ ;
			#print "$root\n";
	    
			if($newWord)
			{
				my @analyses = ($analysis) ;
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

my $openquot=1;
my $needspace=1;

foreach my $word (@words){
		my $form = @$word[0];
		my $analyses = @$word[1];
		my $firstanalysis = @$analyses[0];
		$firstanalysis =~ s/\n//g;
		#print $firstanalysis."\n";
		
		if($firstanalysis =~ /\$/)
		{
			my ($punc,$rest) = split(/\[/, $firstanalysis);
			# opening punctuation
			if($openquot && $punc =~ m/\"|\'|\-|—/) {
				print " $punc";
				$openquot =0;
				$needspace=0;
			}
			elsif($punc =~ /„|¿|¡|\(|\[|«/){
				print " $punc";
				$needspace=0;
			}
			# closing punctuation
			elsif(!$openquot && $punc =~ /\"|\'|-|—|/){
				print "$punc";
				$openquot =1;
				$needspace=1;
			}
			else{# other closing punctuation
				print "$punc";
				$needspace=1;
			}
		}
		elsif($firstanalysis=~ /#EOS/) {
			print "\n";
		}
		# word not recognized: print form
		elsif($firstanalysis!~ /\[/) {
			print " $form";
			$needspace =1;
		}
		else
		{
			my $outWordForm ="";
			my @morphs = ($firstanalysis =~ m/([A-Za-zñéóúíáüÑ']+?)\[/g );
			unless($needspace==0){
				print " ";}
			#if(scalar(@morphs)>0){
			#print " ";}
			
			# check if first letter should be uppercase
			my $upper = 0;
			my $firstletter = substr($form,0,1);
			if( $firstletter eq uc($firstletter)){
				$upper = 1;
			}
			
			for(my $i=0;$i<scalar(@morphs);$i++){
				my $m = @morphs[$i];
				if($upper ==1 && $i==0){
					#print ucfirst("$m");
					$outWordForm = ucfirst("$m");
				}
				else{
					#print "$m";
					$outWordForm = $outWordForm."$m";
				}
			}
			print $outWordForm;
			$needspace=1;
			
			#if still ambiguous, more than one analysis
			if(scalar(@$analyses)>1)
			{ 
				my $moreOutWordForms = $outWordForm."##";
				for(my $j=1;$j<scalar(@$analyses);$j++)
				{
					my $nextanalysis = @$analyses[$j];
					my @morphs = ($nextanalysis =~ m/([A-Za-zñéóúíáüÑ']+?)\[/g );
					# check if first letter should be uppercase
					my $upper = 0;
					my $firstletter = substr($form,0,1);
					if( $firstletter eq uc($firstletter)){
						$upper = 1;
					}
					my $nextOutWordForm ="";
					for(my $i=0;$i<scalar(@morphs);$i++){
						my $m = @morphs[$i];
						if($upper ==1 && $i==0){
							#print ucfirst("$m");
							$nextOutWordForm = ucfirst("$m");
						}
						else{
							#print "$m";
							$nextOutWordForm = $nextOutWordForm."$m";
						}
					}
					# don't print if this is exactly the same as before
					unless($moreOutWordForms =~ /\Q$nextOutWordForm\E##/){
						print "/".$nextOutWordForm;
						$moreOutWordForms = $nextOutWordForm."##";
						
					}
					#print "/".$nextOutWordForm;
					
				}
			}
			
		}
}
#while(<>){
#	
#	s/\n//g;
#	unless(/^$/){
#	if(/\$/){
#		my ($punc,$rest) = split('\t');
#		# opening punctuation
#		if($openquot && $punc =~ m/\"|\'|\-|—/) {
#			print " $punc";
#			$openquot =0;
#			$needspace=0;
#		}
#		elsif($punc =~ /„|¿|¡|\(|\[|«/){
#			print " $punc";
#			$needspace=0;
#		}
#		# closing punctuation
#		elsif(!$openquot && $punc =~ /\"|\'|-|—|/){
#			print "$punc";
#			$openquot =1;
#			$needspace=1;
#		}
#		else{# other closing punctuation
#			print "$punc";
#			$needspace=1;
#		}
#	}
#	elsif($_=~ /#EOS.*\+\?$/) {
#		print "\n";
#	}
#	elsif($_=~ /\+\?$/) {
#		my ($word, $rest)  = split('\t');
#		unless($needspace==0){
#			print " ";}
#		print "$word";
#		$needspace=1;
#	}
#	else{
#		my ($form, $analysis) = split('\t');
#		my @morphs = ($analysis =~ m/([A-Za-zñéóúíáüÑ']+?)\[/g );
#		unless($needspace==0){
#			print " ";}
#		#if(scalar(@morphs)>0){
#		#print " ";}
#		
#		# check if first letter should be uppercase
#		my $upper = 0;
#		my $firstletter = substr($form,0,1);
#		if( $firstletter eq uc($firstletter)){
#			$upper = 1;
#		}
#		
#		for(my $i=0;$i<scalar(@morphs);$i++){
#			my $m = @morphs[$i];
#			if($upper ==1 && $i==0){
#				print ucfirst("$m");
#			}
#			else{
#				print "$m";
#			}
#		}
#		
#		
#		$needspace=1;
#		
#		}
#	}
#}
