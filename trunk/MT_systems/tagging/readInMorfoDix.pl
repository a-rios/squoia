#!/usr/bin/perl


use strict;
use utf8;
use Storable;    # to retrieve hash from disk
use open ':utf8';
binmode STDIN, ':utf8';
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");




my %lemmas;
my %forms=();


#while (<>) 
#{
#   my ($form, @entries) = split(/\s/);
#   
#   # print lexicon for treetagger
#   #print "$form";
#   my $nbrOfEntries =0;
#   my %lems=();
#   my %tags=();
#   for (my $i=0; $i<scalar(@entries); $i=$i+3)
#   {
#                
#                my $lemma = @entries[$i];
#                my $tag = @entries[$i+1];
#                my $analyisis = $lemma."##".$tag;
#                $forms{$form}{$analyisis} = 1;
#                $nbrOfEntries++;
##               if(exists $tags{$tag}){
##                       print STDERR "$tag in form $form has more than one possible lemma\n";
##               }
##               else{
##                       $tags{$tag}=$lemma;
##               }
#                # print lexicon for treetagger
#                if(exists($tags{$tag})){
#                        $tags{$tag} = $tags{$tag}.",".$lemma;
#                }
#                else{
#                        $tags{$tag}=$lemma;
#                }
#        # print for treetagger
#                #print "$tag\n";
#                
#                #print for svmtool
#                #print "$form $tag $lemma\n";
#                
#                $lems{$lemma}=1;
#
#
#                
#        }
##       foreach my $t (keys %tags){
##               #print "\t$t ".$tags{$t};
##       }
#      ## print ambiguous tags for svmtool
##    if(scalar (keys %tags) > 1){
##       foreach my $t (keys %tags){
##                       print "$t\n";
##               }
##    }
#         #print lexicon for treetagger
#    #print "\n";
#        
#
#
#
#
#        
#}


#foreach my $form (keys %forms){
#       print "$form\t";
#       foreach my $analyisis (keys $forms{$form}){
#               print "val: $analyisis\t";
#       }
#       print "\n";
#}

# with crfmorfo format
while (<>) 
{
   my ($form, @entries) = split(/\t/);
   
  
   my $nbrOfEntries =0;
   my %lems=();
   my %tags=();
   for (my $i=1; $i<scalar(@entries); $i=$i+2)
   {
                
                my $lemma = @entries[$i];
                if($lemma eq 'ZZZ' or $lemma == 1){
                	last;
                }
                else{
	                my $tag = @entries[$i+1];
	                my $analysis = $lemma."##".$tag;
	                $forms{$form}{$analysis} = 1;
	                $nbrOfEntries++;
                }
    }        
}

#foreach my $form (keys %forms){
#	print "$form:  ";
#	 foreach my $analysis (keys $forms{$form}){
#	 	print " $analysis ";
#	 }
#	 print "\n";
#}

#print "analysis for salir: ";
#foreach my $s (keys $forms{'salir'}){
#	print " $s ";
#}
#print "\n";

store \%forms, 'Morfodix';