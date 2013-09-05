#!/usr/bin/perl

use strict;
use utf8;
use open ':utf8';
binmode STDIN, ':utf8';
binmode STDERR, ':utf8';
binmode STDOUT, ':utf8';
use Uplug::PreProcess::Tokenizer;

my $tokenizer = new Uplug::PreProcess::Tokenizer( lang => 'es' );

my $inStr = do { local $/; <STDIN> };

# escape glottalization, so words will be splitted at '
$inStr =~ s/(\w)\'(\w)/\1GLOTTALIZE\2/g; 
$inStr =~ s/(\w)\'(\w)/\1GLOTTALIZE\2/g;
$inStr =~ s/(\w)\’(\w)/\1GLOTTALIZE\2/g;

my @tokens = $tokenizer->tokenize( $inStr);

for(my $i=0; $i<scalar(@tokens);$i++) {
	my $t = @tokens[$i];
	if($t eq '#' and @tokens[$i+1] eq 'EOS'){
		print "#EOS\n";
		$i++;
	}
	else{
		$t =~ s/GLOTTALIZE/'/g;
		print $t."\n";
	}
}