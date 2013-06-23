#!/usr/bin/perl

#use utf8;                  # Source code is UTF-8

use strict;

 binmode STDOUT, ':utf8';
 binmode STDIN, ':utf8';
 


# read conll file and create xml (still flat)
my $newWord=1; #sentence ord
my %docHash;
my %conllHash; # hash to store each sentence as conll, in case second analysis is needed

my $sentence; # actual sentence

while (<>) 
  {
    #skip empty line
    if(/^\s*$/ )
    {
      $newWord=1;
    }
    else
    {
    	$newWord=0;
      	s/\s+//g;					# remove blanks
  		my ($rootig,@igs) = split /\[--\]/;	# split root IG from following IGs at the delimiter [^DB][--]
  		my ($root) = split(/\[/,$rootig);
  		
  		print "root: $root\n";

	}
}