#!/usr/bin/perl

#use utf8;                  # Source code is UTF-8

#use strict;
use Storable;

binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';
use open ':utf8';

my %NounSem;
my %synsets;

my $spa2ilimap = "/home/ozli/squoia/mcr30/spaWN/wei_spa-30_to_ili.tsv";
my $ilirecord = "/home/ozli/squoia/mcr30/data/wei_ili_record.tsv";
my $lexnames = "/home/ozli/squoia/mcr30/data/wei_lexnames.tsv";
my $variant = "/home/ozli/squoia/mcr30/spaWN/wei_spa-30_variant.tsv";

open SPA2ILI, "< $spa2ilimap" or die "Can't open $spa2ilimap : $!";
open ILIREC, "< $ilirecord" or die "Can't open $ilirecord : $!";
open LEXNAMES, "< $lexnames" or die "Can't open $lexnames : $!";
open VARIANT, "< $variant" or die "Can't open $variant : $!";

my %spa2ili;

while(<SPA2ILI>){
    my ($ili,$pos,$spa,$rest) = split('\t');
    if($pos eq 'n'){
	$spa2ili{$spa} = $ili;
	#print "$spa: $ili\n";
     }
}

my %ilirecs;
while(<ILIREC>){
    my ($ili,$pos,$bla,$bli,$class,$rest) = split('\t');
    if($pos eq 'n'){
	$ilirecs{$ili} = $class;
	#print STDERR "$ili : $class\n";
     }
}

my %lexnames;
while(<LEXNAMES>){
    my ($class,$name) = split('\t');
	$lexnames{$class} = $name;
	#print STDERR "$class : $name\n";
}



while(<VARIANT>){
    unless( /^\s*$/ )
    { 
	chomp;
	my ($lem,$n,$synset,$pos,$rest) = split('\t');
	$lem =~ s/se$//;
	
	if($pos eq 'n'){
	    unless( grep {$_ =~ /\Q$synset\E/} @{$NounSem{$lem}} ){
		push(@{$NounSem{$lem}},$synset);
		#print STDERR "pushed $lem :  $synset\n";
	    }
	   $synsets{$synset}=1;
	}

    }
}

my %nounLemClasses=();
# get classes for each noun
foreach my $lem (keys %NounSem){
      foreach my $spa (@{${NounSem}{$lem}}){
            my $ili = $spa2ili{$spa};
            my $class = $ilirecs{$ili};
            if( $nounLemClasses{$lem}{$class} > 0 )
            {
		$nounLemClasses{$lem}{$class}++;
		#print STDERR "$lem $class ".$nounLemClasses{$lem}{$class}."--".$lexnames{$class}." \n";
		# print "$class\n";
	    }
	    else{
		$nounLemClasses{$lem}{$class} = 1;
	    }
      }
}

# nouns: 
store \%nounLemClasses, 'nounLemClasses';
#
#print "cambio: ";
#foreach my $class (keys $nounLemClasses{'cambio'}){
#    print $class.",";
#}
#print "\n";
#print keys($nounLemClasses{'falta'})."\n";
# foreach my $lem (keys %nounLemClasses){
#     foreach my $class (keys $nounLemClasses{$lem}){
#         print $class."\n";
#     }
# }
# -> classes: 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28

# max number of synsets per noun ?
# my $maxlength=1;
# foreach my $lem (keys %NounSem){
# 
#     if(scalar( @{$NounSem{$lem}}) > $maxlength){
#        $maxlength = scalar( @{$NounSem{$lem}} );
#     }
# }
# 
# print "maxlength: $maxlength\n";
# print "nbr synsets: ".scalar(keys %synsets)."\n";

# my %nbrOfSynsets;
# #sort by nbr of synsets
# foreach my $lem (keys %NounSem){  
#     $nbrOfSynsets{$lem} = scalar( @{$NounSem{$lem}}) ;
# }
# 
# foreach my $key (  sort { $nbrOfSynsets{$b} <=> $nbrOfSynsets{$a} } keys %nbrOfSynsets  ){
#    # print "$key: ".$nbrOfSynsets{$key}.":\t";
#     print $nbrOfSynsets{$key}.":\t";
#     my @sorted = sort @{$NounSem{$key}};
#     print  "@sorted \n";
# }

# foreach my $s (  sort keys %synsets  ){
#    print "$s\n";
# }