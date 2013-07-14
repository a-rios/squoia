#!/usr/bin/perl

# print out sentences from disambiguated xfst
# in case a word still remains ambiguous: print first option as default

use strict;
use utf8;
binmode STDIN, ':utf8';
binmode STDERR, ':utf8';
binmode STDOUT, ':utf8';


my $openquot=1;
my $needspace=1;

while(<>){
	
	s/\n//g;
	unless(/^$/){
	if(/\$/){
		my ($punc,$rest) = split('\t');
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
	elsif($_=~ /#EOS.*\+\?$/) {
		print "\n";
	}
	elsif($_=~ /\+\?$/) {
		my ($word, $rest)  = split('\t');
		unless($needspace==0){
			print " ";}
		print "$word";
		$needspace=1;
	}
	else{
		my ($form, $analysis) = split('\t');
		my @morphs = ($analysis =~ m/([A-Za-zñéóúíáüÑ']+?)\[/g );
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
				print ucfirst("$m");
			}
			else{
				print "$m";
			}
		}
		
		
		$needspace=1;
		
		}
	}
}
