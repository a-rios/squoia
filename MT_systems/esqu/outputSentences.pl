#!/usr/bin/perl

#use utf8;                  # Source code is UTF-8

use strict;
binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';

my $newSentence = 1;
my $prev;
my $prevPunc;
my $startedWithPunc=0;

while (<>) 
  {
    #skip empty line
    unless(/^\s*$/)
    {
    	if(/#EOS$/)
    	{
      		$newSentence=1;
    	}
    	# word with analysis
    	else
   		{
   			s/\t//g;
   			s/\n//g;
   			#punctuation marks come with their mi tag, split
   			my ($word,$pmi) = split('-PUNC-');
   			#print STDERR "pmi: $pmi\n";
     		#start a new sentence 
    		if($newSentence == 1) 
    		{ 
				# uppercase first word in sentence
				#TODO
				if($word eq ',' || $pmi =~ /T$/ )
				{
					$startedWithPunc =1;
				}
				else
				{
					print STDOUT "\n";
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
    		unless($startedWithPunc ==1){
    			$newSentence = 0;
    		}
   		}
    }
  }