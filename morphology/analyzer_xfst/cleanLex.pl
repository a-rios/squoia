#!/usr/bin/perl

use strict;
my %lex = ();

while (<>) 
{
  chomp;
   s/\s+//g;
  my ($stuff, $word) = split(/\[{(.+)\}\"/) ;

 if (!exists $lex{$word} ) 
 {
  $lex{$word} = $_;
 }
 else
 {
    print STDOUT "1: ".$lex{$word}."\n";
    print STDOUT "2: ".$_."\n\n";
 }
  
}