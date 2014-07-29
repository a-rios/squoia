#!/usr/bin/perl

# count_dix_entries
#
# Input: bilingual dictionary in Matxin XML format
# Output: the number of entries in given categories

use strict;
use utf8;
use XML::LibXML;
#use DateTime;

#use POSIX qw/strftime/;
#my $date = strftime "%Y-%m-%d", localtime;

my $totalentries =0;
my $totalunspec =0;
my $totaltranslated =0;

my $dom    = XML::LibXML->load_xml( IO => *STDIN );

 # foreach my $section ($dom->getElementsByTagName('section'))
#     {
#       print STDOUT "section ".$section->getAttribute('id').": ";
  #print STDOUT scalar(@entries)."\n";
  #$total = $total + scalar(@entries);
     

# my ($verbsection) = $dom->findnodes('descendant::section[@id="verbs"]');
# my @entries = $verbsection->findnodes('child::e');
# my %entries = [];
# foreach my $e (@entries){
#   	my ($r) = $e->findnodes('child::p/r[1]');
# 
# 	if($entries{$e}){
#   		push($entries{$e}, $r);
# 	   # print $e->toString()."\n";
#  	 }
# 	 else{
# 	    $entries{$e} = [$r];
# 	  }
# }
# 
# my $nbrOfUntranslated =0;
# my $nbrOfTranslated =0;
# 
# foreach my $e (keys %entries){
# 	#print "test ".$entries{$e}[0]->textContent."\n";
# 	my $rs = $entries{$e};
# 	#print "test ".@$rs[0]->textContent."\n";
# 	if($rs && scalar(@$rs) ==1 && @$rs[0]->textContent =~ 'unspecified' ){
# 		$nbrOfUntranslated++;
# 	}
# 	elsif($rs){
# 		$nbrOfTranslated++;
# 	}
# 	else{
# 		delete $entries{$e};
# 		print "no rs: $e\n";
# 	}
# }

foreach my $section ($dom->getElementsByTagName('section')){
    my $translated =0;
    my $untranslated =0;
  
    my @entries = $section->findnodes('child::e');
     my %entries = [];
      foreach my $e (@entries){
	      my ($r) = $e->findnodes('child::p/r[1]');
	      if($entries{$e}){
		      push($entries{$e}, $r);
		# print $e->toString()."\n";
	      }
	      else{
		  $entries{$e} = [$r];
		}
      }
      
    foreach my $e (keys %entries){
    #print "test ".$entries{$e}[0]->textContent."\n";
	my $rs = $entries{$e};
	#print "test ".@$rs[0]->textContent."\n";
	if($rs && scalar(@$rs) ==1 && @$rs[0]->textContent eq 'unspecified' ){
		$untranslated++;
	}
	elsif($rs){
		$translated++;
	}
	else{
	  print "no r's: ".$entries{$e}."\n";
	  delete $entries{$e};
	}
    }
    
    $totalentries += scalar(keys %entries);
    $totaltranslated += $translated;
    $totalunspec += $untranslated;
    print "total number of lemmas in section ".$section->getAttribute('id').": ".scalar(keys %entries)."\n";
    print "number of entries with at least one translation: $translated\n";
    print "number of entries with no translation: $untranslated\n";  

}


print "total number of lemmas in dix: ".$totalentries."\n";
print "number of entries with at least one translation: $totaltranslated\n";
print "number of entries with no translation: $totalunspec\n";
#print STDOUT "total number of entries: $total\n";  
# my $total = 0;
# print "Number of entries in the bilingual dictionary\n";
# print "POS\tSize\tCategory\n";
# $total = $total + &count_entries("A","adjectives");
# $total = $total + &count_entries("C","conjunctions");
# $total = $total + &count_entries("D","determiners");
# $total = $total + &count_entries("NC","common nouns");
# $total = $total + &count_entries("NP","named entities");
# $total = $total + &count_entries("PI","indef pronouns");
# $total = $total + &count_entries("SP","prepositions");
# $total = $total + &count_entries("R","adverbs");
# $total = $total + &count_entries("V","verbs");
# 
# print "Total\t$total\tentries ($date)\n";

