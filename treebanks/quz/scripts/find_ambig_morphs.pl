#!/usr/bin/perl


use utf8;
 use Encode;
 binmode STDIN, ':utf8';
 binmode STDOUT, ':utf8';

my @array = ();
while(<>)
{
    chomp;
my ($word, $analysis) = split /\t/;

    push(@array,$word);
}
@words = grep {$_} @array; 

for ($i=0; $i<scalar(@words); $i++) 
{ 
  #  print "@words[$i]\n";
	if(@words[$i] eq @words[$i+1])
      {
        print "@words[$i]:@words[$i+1] at $i\n "; 
      }
} 
