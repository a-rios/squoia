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

my $spa2ilimap = "/mnt/storage/hex/projects/clsquoia/resources/mcr30/spaWN/wei_spa-30_to_ili.tsv";
my $ilirecord = "/mnt/storage/hex/projects/clsquoia/resources/mcr30/data/wei_ili_record.tsv";
my $lexnames = "/mnt/storage/hex/projects/clsquoia/resources/mcr30/data/wei_lexnames.tsv";
my $variant = "/mnt/storage/hex/projects/clsquoia/resources/mcr30/spaWN/wei_spa-30_variant.tsv";

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
#foreach my $class (keys %{$nounLemClasses{'tigre'}}){
#    print $class.",";
#}
#print "\n";
 
#my @test =  %{$nounLemClasses{'carro'}};
#print "@test\n";

#print keys($nounLemClasses{'falta'})."\n";
# foreach my $lem (keys %nounLemClasses){
#     foreach my $class (keys %{$nounLemClasses{$lem}}){
#         print $class."\n";
#     }
# }

 foreach my $lem (keys %nounLemClasses){
    
   if(grep {/^14$/} keys %{$nounLemClasses{$lem}}){
     print "is human: $lem\n";
   }
 }


# -> classes: 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28
#00	all
#01	pert
#02	all
#03	Tops
#04	act
#05	animal
#06	artifact
#07	attribute
#08	body
#09	cognition
#10	communication
#11	event
#12	feeling
#13	food
#14	group
#15	location
#16	motive
#17	object
#18	person
#19	phenomenon
#20	plant
#21	possession
#22	process
#23	quantity
#24	relation
#25	shape
#26	state
#27	substance
#28	time
#29	body
#30	change
#31	cognition
#32	communication
#33	competition
#34	consumption
#35	contact
#36	creation
#37	emotion
#38	motion
#39	perception
#40	possession
#41	social
#42	stative
#43	weather
#44	ppl

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
#     print "$key: ".$nbrOfSynsets{$key}.":\t";
#     print $nbrOfSynsets{$key}.":\t";
#     my @sorted = sort @{$NounSem{$key}};
#     print  "@sorted \n";
# }

# foreach my $s (  sort keys %synsets  ){
#    print "$s\n";
# }