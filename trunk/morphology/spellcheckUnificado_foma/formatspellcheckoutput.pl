#/usr/bin/perl -w

# input: "output" of the spell check given a list of unknown tokens
# Calculating heuristic [h]
# Using confusion matrix.
#
# patalin*cha
# Catalinacha
# Cost[f]: 4
#
# 
# Ratalin*cha
# Catalinacha
# Cost[f]: 4



# output: the tokens together with the corrections suggested by the spell checker (fmed)
#Catalinacha:
#	patalincha
#	Ratalincha
#	...

use utf8;
binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';

$i = 0;
$new = 1;
$corr;
$word;
@words;
%spellings;

while (<>)
{
 if (/Cost\[f\]:/ or /^Calculating heuristic/ or /^Using confusion matrix/) {
  # do nothing
 }
 elsif (/^$/) {
  $new = 1;
 }
 else {
  chomp;
 # s/\*//g;
  if ($new) {
   $corr = $_;
   $new = 0;
  }
  else {
   $word = $_;
   if ($i==0 or ($words[$i-1] ne $word)) {
    $words[$i] = $word;
    $i++;
   }	
   $spellings{$word}{$corr}=1;	
  }
 }
}

foreach $word (@words) {
 print "$word:\n";
 
 foreach $corr (keys %{$spellings{$word}}) {
  print "\t$corr\n";
 }
}
