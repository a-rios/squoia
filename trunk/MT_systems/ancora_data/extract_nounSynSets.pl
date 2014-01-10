#!/usr/bin/perl

#use utf8;                  # Source code is UTF-8

#use strict;
use Storable;

binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';
use open ':utf8';

my %VerbSem;
my %synsets;

my $spa2ilimap = "/home/ozli/squoia/mcr30/spaWN/wei_spa-30_to_ili.tsv";
my $ilirecord = "/home/ozli/squoia/mcr30/data/wei_ili_record.tsv";
my $lexnames = "/home/ozli/squoia/mcr30/data/wei_lexnames.tsv";
my $variant = "/home/ozli/squoia/mcr30/spaWN/wei_spa-30_variant.tsv";

open SPA2ILI, "< $spa2ilimap" or die "Can't open $spa2ilimap : $!";
open ILIREC, "< $ilirecord" or die "Can't open $ilirecord : $!";
#open LEXNAMES, "< $lexnames" or die "Can't open $lexnames : $!";
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
	#print "$ili : $class\n";
     }
}

# my %lexnames;
# while(<LEXNAMES>){
#     my ($class,$name) = split('\t');
# 	$lexnames{$class} = $name;
# 	#print "$ili : $class\n";
# }



while(<VARIANT>){
    unless( /^\s*$/ )
    { 
	chomp;
	my ($lem,$n,$synset,$pos,$rest) = split('\t');
	$lem =~ s/se$//;
	
	if($pos eq 'n'){
	    unless( grep {$_ =~ /\Q$synset\E/} @{$VerbSem{$lem}} ){
		push(@{$VerbSem{$lem}},$synset);
		print STDERR "pushed $lem :  $synset\n";
	    }
	   $synsets{$synset}=1;
	}

    }
}

my %verbLemClasses=();
# get classes for each verb
foreach my $lem (keys %VerbSem){
      foreach my $spa (@{${VerbSem}{$lem}}){
            my $ili = $spa2ili{$spa};
            my $class = $ilirecs{$ili};
            if( $verbLemClasses{$lem}{$class} > 0 )
            {
		$verbLemClasses{$lem}{$class}++;
		#print "$lem $class ".$verbLemClasses{$lem}{$class}."\n";
		# print "$class\n";
	    }
	    else{
		$verbLemClasses{$lem}{$class} = 1;
	    }
      }
}

# verbs: 15 classes, 29-43
store \%nounLemClasses, 'nounLemClasses';

# max number of synsets per verb = 35 
# my $maxlength=1;
# foreach my $lem (keys %VerbSem){
# 
#     if(scalar( @{$VerbSem{$lem}}) > $maxlength){
#        $maxlength = scalar( @{$VerbSem{$lem}} );
#     }
# }
# 
# print "maxlength: $maxlength\n";
# print "nbr synsets: ".scalar(keys %synsets)."\n";

# my %nbrOfSynsets;
# #sort by nbr of synsets
# foreach my $lem (keys %VerbSem){  
#     $nbrOfSynsets{$lem} = scalar( @{$VerbSem{$lem}}) ;
# }
# 
# foreach my $key (  sort { $nbrOfSynsets{$b} <=> $nbrOfSynsets{$a} } keys %nbrOfSynsets  ){
#    # print "$key: ".$nbrOfSynsets{$key}.":\t";
#     print $nbrOfSynsets{$key}.":\t";
#     my @sorted = sort @{$VerbSem{$key}};
#     print  "@sorted \n";
# }

# foreach my $s (  sort keys %synsets  ){
#    print "$s\n";
# }