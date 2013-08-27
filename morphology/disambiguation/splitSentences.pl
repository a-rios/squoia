#!/usr/bin/perl


use utf8;                  # Source code is UTF-8
binmode STDIN, ':utf8';
binmode STDERR, ':utf8';
binmode STDOUT, ':utf8';
use strict;
use Lingua::Sentence;

my $text;
while(<>){
	s/\n/ /g;
	$text .= " ".$_;
}

        my $splitter = Lingua::Sentence->new("es", "nonbreaking_prefix.es");

        #my $text = 'Esto es un parráfo. Contiene varias frases. "Pero porqué," me preguntas?';

       # print $splitter->split($text);
        my @sentences = $splitter->split_array($text);
        foreach my $s (@sentences){
        	unless($s =~ /^[\t\s]*$/){
        		print $s." #EOS\n";
        	}
        }
        
        