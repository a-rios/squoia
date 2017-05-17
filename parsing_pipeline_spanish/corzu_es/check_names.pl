#!/usr/bin/perl

use strict;
use utf8;
binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';
use Getopt::Long;
use Storable;
use File::Basename;
my $this_dir = dirname(__FILE__);

my $helpstring = "Usage: $0 [options]
available options are:
--help|h: print this help
--verbose|v: be verbose

check names in parsed/tagged conll file:
--conll|c: parsed conll

read in the lists of names (all 4 required):
--female-names|f: list of female first names
--male-names|m: list of male first names
--person-list|p: list of person denotations
--last-names|l: list of lastnames\n";

my $help;
my $conll;
my $fem;
my $male;
my $personlist;
my $lastnames;
my $verbose = '';

GetOptions(
	# general options
    'help|h'     => \$help,
    'conll|c=s' => \$conll,
    'female-names|f=s' => \$fem,
    'male-names|m=s' => \$male,
    'person-list|p=s' => \$personlist,
    'last-names|l=s' => \$lastnames,
    'verbose|v' => \$verbose
) or die "Incorrect usage!\n $helpstring";

if($help or !($conll or ($fem and $male and $personlist and $lastnames))){ print STDERR $helpstring; exit;}

open (CONLL, "<:encoding(UTF-8)", $conll) or die "Can't open conll file $conll: $!\n" if $conll;
open (FEM, "<:encoding(UTF-8)", $fem) or die "Can't open female names file $fem: $!\n" if $fem;
open (MALE, "<:encoding(UTF-8)", $male) or die "Can't open male names file $male: $!\n" if $male;
open (PERSONLIST, "<:encoding(UTF-8)", $personlist) or die "Can't open person list file $personlist: $!\n" if $personlist;
open (LASTNAMES, "<:encoding(UTF-8)", $lastnames) or die "Can't open person list file $lastnames: $!\n" if $lastnames;

my $personlist_string;
if($personlist){
    $personlist_string ="";
    while(<PERSONLIST>){
      chomp();
      $personlist_string .= "##$_";
    }
    $personlist_string .= "##";
    Storable::store \$personlist_string, "$this_dir/person.list.string.pl.stored" ;
}
else{
    my $personlist_string_ref = Storable::retrieve "$this_dir/person.list.string.pl.stored" ;
    $personlist_string = ${ $personlist_string_ref};
  #  print STDERR "pers list $personlist_string\n";
}


my @femnames;
my @malenames;
my @lastnames;

if($fem){
## read in Don's python thing
#   my $femline = <FEM>;
#     $femline =~ s/\\xc3\\xba/ú/g ; 
#     $femline =~ s/\\xc3\\xbc/ü/g ; 
#     $femline =~ s/\\xc3\\xa1/á/g ; 
#     $femline =~ s/\\xc3\\xa9/é/g ; 
#     $femline =~ s/\\xc3\\xb3/ó/g ; 
#     $femline =~ s/\\xc3\\xb1/ñ/g ; 
#     $femline =~ s/\\xc3\\xad/í/g ; 
#     $femline =~ s/\\xc3\\xb6/ö/g ; 
#     $femline =~ s/\\xc3\\xa4/ä/g ; 
#     $femline =~ s/\\xc3\\xa8/è/g ; 
#     $femline =~ s/\\xc3\\xb8/ø/g ;
#     $femline =~ s/\\xc3\\xab/ë/g ;
#     $femline =~ s/\\xc3\\xa2/â/g ;
#     $femline =~ s/\\xc3\\x9f/ß/g ;
#     $femline =~ s/\\xc3\\xa6/æ/g ;
#     $femline =~ s/\\xc3\\x84/Ä/g ;
#     $femline =~ s/\\xc3\\xa7/ç/g ;
#     $femline =~ s/\\xc3\\x81/Á/g ;
#     $femline =~ s/\\xc3\\xb2/ò/g ;
#     $femline =~ s/\\xc3\\x96/Ö/g ;
#     $femline =~ s/\\xc3\\xae/î/g ;
#     $femline =~ s/\\xc3\\x86/Æ/g ;

#     @femnames = ($femline =~ m/'([^']+)'/g);
    chomp(@femnames  = <FEM>);
    my @doubles = grep  { /\-/ } @femnames;
#   print STDERR "prenames @doubles\n";
    foreach my $d (@doubles){
#      print STDERR "$d\n";
     my ($pre, $post) = split('-', $d);
#       print STDERR "pre $pre, post: $post\n";
      push(@femnames, $pre);
      push(@femnames, $post);
   }
    Storable::store \@femnames, "$this_dir/fem.names.pl.stored" ;
}
else{
    my $femnames_ref = Storable::retrieve "$this_dir/fem.names.pl.stored" ;
    @femnames = @{ $femnames_ref };
}
    
if($male){
#   my $maleline = <MALE>;
#   $maleline =~ s/\\xc3\\xba/ú/g ; 
#   $maleline =~ s/\\xc3\\xbc/ü/g ; 
#   $maleline =~ s/\\xc3\\xa1/á/g ; 
#   $maleline =~ s/\\xc3\\xa9/é/g ; 
#   $maleline =~ s/\\xc3\\xb3/ó/g ; 
#   $maleline =~ s/\\xc3\\xb1/ñ/g ; 
#   $maleline =~ s/\\xc3\\xad/í/g ;
#   $maleline =~ s/\\xc3\\xb6/ö/g ; 
#   $maleline =~ s/\\xc3\\xa4/ä/g ; 
#   $maleline =~ s/\\xc3\\xa8/è/g ; 
#   $maleline =~ s/\\xc3\\xb8/ø/g ;
#   $maleline =~ s/\\xc3\\xab/ë/g ;
#   $maleline =~ s/\\xc3\\xa2/â/g ;
#   $maleline =~ s/\\xc3\\x9f/ß/g ;
#   $maleline =~ s/\\xc3\\xa6/æ/g ;
#   $maleline =~ s/\\xc3\\x84/Ä/g ;
#   $maleline =~ s/\\xc3\\xa7/ç/g ;
#   $maleline =~ s/\\xc3\\x81/Á/g ;
#   $maleline =~ s/\\xc3\\xb2/ò/g ;
#   $maleline =~ s/\\xc3\\x96/Ö/g ;
#   $maleline =~ s/\\xc3\\xae/î/g ;
#   $maleline =~ s/\\xc3\\x86/Æ/g ;
# @malenames = ($maleline =~ m/'([^']+)'/g);
  
  ## read in list of names
    chomp(@malenames  = <MALE>);
    ## split double names 
    my @doubles = grep  { /\-/ } @malenames;
    foreach my $d (@doubles){
      my ($pre, $post) = split('-', $d);
  #     print STDERR "pre $pre, post: $post\n";
      push(@malenames, $pre);
      push(@malenames, $post);
    }
    #print STDERR "prenames @doubles\n";
    store \@malenames, "$this_dir/male.names.pl.stored" ;
}
else{ 
    my $malenames_ref = retrieve("$this_dir/male.names.pl.stored");
    @malenames = @{ $malenames_ref };
}


if($lastnames){  
  ## read in list of names
  chomp(@lastnames  = <LASTNAMES>);
  store \@lastnames, "$this_dir/last.names.pl.stored" ;
}
else{ 
    my $lastnames_ref = retrieve("$this_dir/last.names.pl.stored");
    @lastnames = @{ $lastnames_ref };
}

# foreach my $n (@femnames){
#   print "$n\n";
# }

# print STDERR "male names: @malenames\n";
# print STDERR "fem names: @femnames\n";
my $scount=0;
my $sentenceString="";
my %personnames =(); ## reverse, key=form, value=array of id's
my %geonames =();
my %orgnames =();
my %restnames=();
my %othernames =();

my $persons_string="";
my %conll=();

print STDERR "\t################ working on file $conll ########################\n" if ($conll and $verbose);

while(<CONLL>){
	    #skip empty line
	    if(/^\s*$/)
	    {
	      #print "$scount: ".$sentenceString."\n";
	      $conll{$scount}{'string'}= $sentenceString;
	      $sentenceString="";
	      $scount++;
	    }
	    elsif(/^#begin/){
		chomp;
		$conll{$scount}{'articleBegin'} = $_;
		#print STDERR "found begin in $scount: $_\n";
	    }
	    elsif(/^#end/){
		chomp;
		$conll{$scount}{'articleEnd'} = $_;
	    }
	    # word with analysis
	    else
	    {
		     # create a new word 
		     my %word = ();

		     my ($id, $wordform, $lem, $cpos, $pos, $morph, $head, $rel, @rest) = split (/\t|\s/);	 
		     
		     
		     $word{'ord'}=$id; 
		     $word{'form'}=$wordform;
		     $word{'lem'}=$lem;
		     $word{'morph'}=$morph;
		     $word{'cpos'}=$cpos;
		     $word{'pos'}=$pos;
		     $word{'head'}=$head;
		     $word{'rel'}=$rel;
		     $word{'rest'}=\@rest;
	 
		 
		     $conll{$scount}{$id}= \%word;	     
		   
		      
		      #create string for easier reference
		      $sentenceString .= "$wordform ";
		      
		      # build a hash with wordforms as key, values are the id's (possibly more than one) of these words in the sentence
# 		      if($conllWordFormsIds{$scount}{$wordform}){
# 		      	push( @{$conllWordFormsIds{$scount}{$wordform}}, $id);
# 		      }
# 		      else{
# 		      	$conllWordFormsIds{$scount}{$wordform} = [$id];
# 		      }
		      
		      my $sid = $scount.":".$id;
		      if($morph =~ /eagles=NP00SP0/){
		        if(&notPerson($wordform)){
			  ## if not a person, add to V0, 'other'
			  $word{'pos'} = "NP00V00";
			  print STDERR "changed $wordform from person to VO class\n" if $verbose;
			  $restnames{$sid} = $wordform;
		        }
			else{
			  &addPerson($wordform, $sid);
			}
		      }
		      
		      elsif($morph =~ /eagles=NP00G00/){
			  &addPerson($wordform, $sid) if (&partInPersonList($wordform) );
			  $geonames{$sid} = $wordform;
		      }
		      
		      elsif($morph =~ /eagles=NP00O00/){
			  &addPerson($wordform, $sid) if (&partInPersonList($wordform) );
			 $orgnames{$sid} = $wordform;
		      }
		      
		       elsif($morph =~ /eagles=NP00V00/){
			  &addPerson($wordform, $sid) if (&partInPersonList($wordform));
			 $restnames{$sid} = $wordform;
			
			#print STDERR "inserted $wordform in VO with $sid\n";
		      }
		      
# 		      print STDERR "inserted for word $wordform in sentence $scount id number: $id\n";
	    }
}
$persons_string .= "##";
# print "personlist: $personlist_string\n";
print  STDERR "persons: $persons_string\n" if $verbose; 

	 
#  print STDERR "checking GO:\n";
&change_names(\%geonames, 'location');
#  print STDERR "checking O0:\n";
&change_names(\%orgnames, 'organization');
#  print STDERR "checking VO:\n";
&change_names(\%restnames, 'other');

foreach my $sentencenr (sort { $a <=> $b } keys %conll){
    # print conll
    my $articleBegin = $conll{$sentencenr}{'articleBegin'};
    my $articleEnd = $conll{$sentencenr}{'articleEnd'};
#     print STDERR "sent $sentencenr has id $articleBegin\n" if $verbose;
    if($articleBegin =~ /#begin/){
	print "$articleBegin\n";
    }
    
    for(my $tokennr=1;$tokennr<scalar(keys (%{$conll{$sentencenr}}));$tokennr++){
        my $word = $conll{$sentencenr}{$tokennr};
        unless($word->{'form'} eq ''){
	  print "$tokennr\t".$word->{'form'}."\t".$word->{'lem'}."\t".$word->{'cpos'}."\t".$word->{'pos'}."\t".$word->{'morph'}."\t".$word->{'head'}."\t".$word->{'rel'};
	  foreach my $r (@{$word->{'rest'}}){
	      #print STDERR "r is $r\n";
	      print "\t".$r;
	  }
	  print "\n";
	  
        }
    }
     if($articleEnd =~ /#end/){
	print "$articleEnd\n";
    }
    print "\n";
}

## relabel some very common and annoying Freeling mistakes
sub notPerson{
      my $string = $_[0];
      return ($string =~ /\b(latino)?am[eé]rica\b|^áfrica|\beurasia\b|^australia\b|^arabia\b|^israel\b|^islam(ismo)?$|^bangladesh|^acto\b|^acuerdo\b|^Alemania|^Alepp?o|^hamas\b|^h[ei][zs]b[ou]ll?[aá]h?|^gaza\b|^ddt\b|^ippc\b|^ánalisis|^consenso\b|^convenio\b|^(Nor)corea|\bcrédito\b|^derechos?\b|\bfinancial\b|^foreign|^google|^twitter|Hizbolá|^movimiento|^rusia\b|^tesoro\b|^Cuan[td][oas?\b]|^Est(e|á)\b|^Demasiado|^Estudio|^protocolo|^pronto|^programa|^proyecto|^puerto|^Qui[ée]nes|^santuario|^talib[aá]n|^templo|^todav[íi]a|^tribunal|^traducción|^twenty|^uss_|^Uu\b|^venezuela|^what\b|^when\b|^wiki(pedia|leaks)\b|^yahoo|^youtube\b|^resource|^revolución|^pib\b|^pbi\b|^people|^pax_de|^pacto|^partido|^our\b|^Orient(e|al)\b|^mientras\b|^manda(to|miento)\b|^l[oa]s_|^internet\b|^index\b|^índice\b|^imperio\b|^Human\b|^How_|^europe(an|ans)?$|^estilo\b|^e\.e\.u\.\.u\b|^docuemnto\b|^concilio\b|^china\b|^associated\b|^arab[ií]a\b|^comité|^Hoy|\bleague\b|\bh[eé]bdo/i);
}

sub addPerson{
   my $wordform = $_[0];
   my $sid = $_[1];
   $persons_string .= "##$wordform";
   if(exists($personnames{$wordform}) ){
    push( @{$personnames{$wordform}} , $sid);
  }
  else{
    @{$personnames{$wordform}} = [$sid];
  }
}

sub partInPersonList{
      my $string = $_[0];
      my @parts = split('_', $string);
      my $probName =0;
    #  if(grep { /^@parts[0]$/i } @femnames or grep { /^@parts[0]$/i } @malenames or $personlist_string =~ m/#\Q@parts[0]\E#/i){
      if($personlist_string =~ m/#\Q@parts[0]\E#/i){
	$probName =1;
	print STDERR "added to probable persons: $string due to ".@parts[0]."\n" if $verbose;
      }
      
#       foreach my $part(@parts){
# 	if($personlist_string =~ m/#\Q$part\E#/i or grep { /^\Q$part\E$/i } @lastnames){
# 	$probName =1;
# 	print STDERR "added to probable persons: $string due to $part\n";
# 	last;
# 	}
#       }
      return $probName;
}

#print STDERR "person string: $persons_string\n";

sub change_names{
  my $othernames = $_[0];
  my $class = $_[1];
  %othernames =  %{ $othernames };
  
  foreach my $othername_id (keys %othernames){
      my $othername = $othernames{$othername_id};
      if( $persons_string =~ /##$othername##/){
	  ## get all matching person names, not just exact matches
	  my @matches = ($persons_string =~ m/##([^#]*$othername[^#]*)##/ig);
	  if(&passFilter($othername) and $verbose){  
	    print  STDERR " NP found: $othername in class $class with $othername_id\n";
	    print  STDERR "\tin personnames\n";
	    print  STDERR "\tmatches: @matches\n";
	  }
	  
	  my $surePerson =0;
	  ## check if one of these matches contains a female or male first name, or a word from person list
	  foreach my $match (@matches){
	    my @parts = split(/-|_/, $match);
	    foreach my $part (@parts){
		  if(grep { /^$part$|^$part-|-$part$/i } @malenames or grep { /^$part$|^$part-|-$part$/i } @femnames ){
		    if(&passFilter($part) and $verbose) {  
		      print STDERR  "\ttrying part $part\n";
		      print STDERR  "\tin name list: $part\n";
		      print STDERR "\t\tin fem list" if grep { /^$part$/i } @femnames;
		      print STDERR "\t\tin male list" if grep { /^$part$/i } @malenames;
		    }
		    $surePerson=1;
		    last;
		  }
		  elsif($personlist_string =~ m/#$part#/i or grep { /^$part$/i } @lastnames){
		    print STDERR "\tin person or last name list: $part\n" if $verbose;
# 		    my ($m) = ($personlist_string =~ m/([^#]+\b$part\b[^#]+)/i);
# 		    print STDERR "\t\t matched $m\n";
		    $surePerson=1;
		    last;
		  }

	    }
	    last if $surePerson;
	  }
	  ## if this should be a person: change tag in conll
	  if($surePerson){
	      &changeMorph($othername_id, 'person');
# 	      my ($scount, $tokenid) = split(':', $othername_id);
# 	      my $word = $conll{$scount}{$tokenid};
# 	      my $morph = $word->{'morph'};
# 	    #  print "changing tag from $morph\n";
# 	      $morph =~ s/ne=other/ne=person/;
# 	      $morph =~ s/eagles=NP00V00/eagles=NP00SP0/;
# 	      $word->{'morph'} = $morph;
#     # 	  print "  to morph: $morph\n";
# 	      print STDERR "\tchanged morph of $scount, $tokenid, $othername\n";  
	  }
	  else{
	      ### if there was a match in person names, should we change that one to the NP class of this curren NP class?
# 	      ## TODO
	      foreach my $match (@matches){
		my   $ids_to_this_match = $personnames{$match};
		foreach my $id ( @{$ids_to_this_match} ) {
		   print STDERR "match is $match, corresponding ids in person names: $id, current tag is $class\n" if (&passFilter($match) and $verbose);
		   &changeMorph($id, $class);
		}
	      }
	  }

      } 
  }
} 



sub changeMorph{
  my $id = $_[0];
  my $newTag = $_[1];
  
   my ($scount, $tokenid) = split(':', $id);
   my $word = $conll{$scount}{$tokenid};
   my $morph = $word->{'morph'};
   #  print "changing tag from $morph\n";
   $morph =~ s/ne=(other|location|person|organization)/ne=$newTag/;
   $morph =~ s/eagles=NP00..0/eagles=NP00SP0/ if $newTag eq 'person';
   $morph =~ s/eagles=NP00..0/eagles=NP00V00/ if $newTag eq 'other';
   $morph =~ s/eagles=NP00..0/eagles=NP00G00/ if $newTag eq 'location';
   $morph =~ s/eagles=NP00..0/eagles=NP00O00/ if $newTag eq 'organization';
   $word->{'morph'} = $morph;
   # 	  print "  to morph: $morph\n";
   print STDERR "\tchanged morph of $scount, $tokenid, ".$word->{'form'}." to new tag $newTag\n" if (&passFilter($word->{'form'}) and $verbose);


}

sub passFilter{
  my $string = $_[0];
  return ($string !~ m/Google|Hamás|Hamas|Corea|Ippc|Gaza|Mozambique|Qaeda|áfrica|Pcc|Ghana|Islam|Ddt|H[ei][zs]b[ou]ll?[aá]h?|Pbi|Kgb|Gazprom|qa[ei]da|fatah|Birmania|Twitter|Uber|pkk|Jezbolá|yahoo|wal-mart|fairtrade|wiki|yukos|gazprom|enron/i);
}
	 
close(CONLL);
close(MALE);
close(FEM);
close(PERSONLIST);