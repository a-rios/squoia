#!/usr/bin/perl

# count_dix_entries
#
# Input: bilingual dictionary in Matxin XML format
# Output: the number of entries in given categories

use strict;
use utf8;
use XML::LibXML;
#use DateTime;

use POSIX qw/strftime/;
my $date = strftime "%Y-%m-%d", localtime;

my $total =0;

my $dom    = XML::LibXML->load_xml( IO => *STDIN );

  foreach my $section ($dom->getElementsByTagName('section'))
   {
      print STDOUT "section ".$section->getAttribute('id').": ";
      my @entries = $section->findnodes('child::e');
      print STDOUT scalar(@entries)."\n";
      $total = $total + scalar(@entries);
     
  }

print STDOUT "total number of entries: $total\n";  
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

