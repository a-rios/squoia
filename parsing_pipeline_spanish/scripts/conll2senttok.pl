#!/usr/bin/perl


use strict;
use utf8;
binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';

my $sentenceString="";

while(<STDIN>){
	    #empty line = new sentence
	    if(/^\s*$/){
	      print $sentenceString."\n";
	      $sentenceString="";
	    }
	    # word with analysis
	    elsif($_ !~ /#begin document|#end document/){
		 my ($id, $wordform, $lem, $cpos, $pos, $morph, $head, $rel, $phead, $prel) = split (/\t|\s/);
		 # $wordform =~ s/\_/ /g; ## uncomment to split multi-word tokens
		 $sentenceString .= "$wordform ";  
	    }
	if(eof()){
	  print $sentenceString."\n";
	}
}
