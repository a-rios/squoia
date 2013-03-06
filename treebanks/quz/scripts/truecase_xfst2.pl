#!/usr/bin/perl

# truecase_xfst.pl
# give morphological analyses of Quechua words the original casing (default by xfst: lowercased)

# usage: perl truecase_xfst.pl input_file  output_file 

# input_file: from xfst morphological analyser
#
# Puriykumi 	puri[VRoot][=andar][--]yku[VDeriv][+Aff][^DB][--]mi[VPers][+1.Sg.Subj]
# HINASPA	hina[VRoot][=hacer_así,ser_así][^DB][--]spa[NS][+SS]
# will be converted to:
# Puri[VRoot][=andar][--]yku[VDeriv][+Aff][^DB][--]mi[VPers][+1.Sg.Subj]
# HINA[VRoot][=hacer_así,ser_así][^DB][--]SPA[NS][+SS]

use utf8;
 use Encode;
 binmode STDOUT, ':utf8';
 binmode STDIN, ':utf8';

# $num_args = $#ARGV + 1;
# if ($num_args < 2 or $num_args > 3) {
#   print "\nUsage: truecase_xfst.pl xsft_analysed_INfile xfst_analysed_OUTfile\n";
#   exit;
# }
# 
# $xfst_file = $ARGV[0];
# $truecased_file = $ARGV[1];
# if ($num_args == 2) {
#  $all = 0;
# }

# else {
#   print "\nUsage: truecase_xfst.pl xsft_analysed_INfile xfst_analysed_OUTfile\n";
#   exit;
# }

# open XFST, "<:encoding(UTF-8)", "$xfst_file" or die "Can't open $xfst_file : $!";
# open TRUECASED, ">:encoding(UTF-8)", "$truecased_file" or die "Can't open $truecased_file : $!";

while (<>)
  {
   if (/\+\?$/) #unknown word, continue
      {
      print STDOUT "$_";
      }
   elsif($_ =~ /^$/) #empty line, continue
      {
      print STDOUT "$_";
      }
   elsif($_ =~ /\[\$/) #punctuation, continue
      {
      ($word, $analysis) = split(/\t/);
      print STDOUT "$analysis";
      }
   else
      {
       ($word, $analysis) = split(/\t/);
	$firstLetter = (substr($word, 0, 1));
	$secondLetter = (substr($word, 1, 1));
	if ($word eq lc($word)) #lowercased input word, copy as is to output file
	{
        print STDOUT "$analysis";
	}
	elsif ($firstLetter eq uc($firstLetter)) #test if first letter is uppercased
	  {
	    if ($secondLetter eq lc($secondLetter)) #test if second letter is lowercased
	    {
	    @morphemes = split(/(\[--\])/,$analysis);                                                                                                                                 
	    $length = @morphemes;
	    print STDOUT ucfirst(@morphemes[0]);
	    for ($i=1; $i<$length; $i++) { #print the rest of the analysis as is 
		print STDOUT @morphemes[$i];
		}
	    }	    
	    elsif ($word eq uc($word)) #uppercased input word, uppercase all morphemes in output file
	    {
	      @morphemes = split(/\[--\]/,$analysis);   
	      $lenght = @morphemes;
	      foreach (@morphemes){
 		  ($word,$rest)= split(/(\[.+)/);      
		  print STDOUT uc($word). $rest;     #uppercase the morpheme, print rest as is   
		  if(@morphemes[-1] ne $_ )
		  {
		  print STDOUT "[--]";
		  }
		  else
		  {
		  print STDOUT "\n";
		  }
	      }
	    } 
	    else
	    {
	          print STDOUT "$_";
	    }
	  }
      }
  }


# close(XFST);
# close(TRUECASED);
