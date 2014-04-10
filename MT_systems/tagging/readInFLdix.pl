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
my $maxNBofEntries=1;
my $maxNBofLems=1;
my $maxNBofTags=1;

my %AllTags=();


while (<>) 
{
   my ($form, @entries) = split(/\s/);
   
   # print lexicon for treetagger
   #print "$form";
   my $nbrOfEntries =0;
   my %lems=();
   my %tags=();
   for (my $i=0; $i<scalar(@entries); $i=$i+2)
   {
                
                my $lemma = @entries[$i];
                my $tag = @entries[$i+1];
                my $analyisis = $lemma."##".$tag;
                $forms{$form}{$analyisis} = 1;
                $nbrOfEntries++;
                # collect tags
                $AllTags{$tag}=1;
                
#               if(exists $tags{$tag}){
#                       print STDERR "$tag in form $form has more than one possible lemma\n";
#               }
#               else{
#                       $tags{$tag}=$lemma;
#               }
                # print lexicon for treetagger
                if(exists($tags{$tag})){
                        $tags{$tag} = $tags{$tag}.",".$lemma;
                }
                else{
                        $tags{$tag}=$lemma;
                }
        # print for treetagger
                #print "$tag\n";
                
                #print for svmtool
                #print "$form $tag $lemma\n";
                
                $lems{$lemma}=1;


                
        }
#       foreach my $t (keys %tags){
#               #print "\t$t ".$tags{$t};
#       }
      ## print ambiguous tags for svmtool
#    if(scalar (keys %tags) > 1){
#       foreach my $t (keys %tags){
#                       print "$t\n";
#               }
#    }
         #print lexicon for treetagger
    #print "\n";
        
        if($nbrOfEntries>$maxNBofEntries){
                $maxNBofEntries = $nbrOfEntries;
        }
        # get nbr of lems & tags
        my $nbrOfLems = scalar( keys %lems);
        my $nbrOfTags = scalar( keys %tags);
        if($nbrOfLems > $maxNBofLems){$maxNBofLems = $nbrOfLems;}
        if($nbrOfTags > $maxNBofTags){$maxNBofTags = $nbrOfTags;}
        my $lemstr;


        
}


#foreach my $form (keys %forms){
#       print "$form\t";
#       foreach my $analyisis (keys $forms{$form}){
#               print "val: $analyisis\t";
#       }
#       print "\n";
#}


print STDERR "max nbr of entries: $maxNBofEntries\n";
print STDERR "max nbr of lems: $maxNBofLems\n";
print STDERR "max nbr of tags: $maxNBofTags\n";


store \%forms, 'FLdix';
store \%AllTags, 'FLtags';