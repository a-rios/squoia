#!/usr/bin/perl

 binmode STDOUT, ':utf8';
 binmode STDIN, ':utf8';
 
# xfst2pml.perl
# transform morphological analyses of Quechua words
# to "tokenised" sentences (with roots and IGs as token units)
# in Prague Markup Language (pml) format
#
### NOTE: ambiguous morphological analyses!!! ###
# => brute force disambiguation: take only the first analysis
# OR
# write the alternatives with "@" preceding the root (option -a)
#
# one sentence per line;
# end of sentence marks = [.?!;]

# usage: script_name  input_file  output_file [-a]

# input_file: from xfst morphological analyser
#
# 	puri[VRoot][=andar][--]yku[VDeriv][+Aff][^DB][--]mi[VPers][+1.Sg.Subj]
# => root:
#	word:	puriyku
#	pos:	Root
#	morph:	VRoot+Aff
#	translation:	=andar
# => igs:
#	word:	-mi
#	pos:	VPers
#	morph:	+1.Sg.Subj
#	(translation:	--)
#	
#
# output_file: body part of the pml word file:
#  <body>
#    <s id="s1">
#      <saphi>
#        <nonterminal id="s1_VROOT">
#          <cat>VROOT</cat>
#          <children>
#            <terminal>
#              <order>1</order>
#              <label>$</label>
#              <word>Aqopiya</word>
#              <pos>NP</pos>
#              <morph></morph>
#            </terminal>
#            <terminal>
#              <order>2</order>
#              <label>$</label>
#              <word>-manta</word>
#              <pos>Cas</pos>
#              <morph><tag>+Abl</tag></morph>
#            </terminal>
#            <terminal>
#              <order>3</order>
#              <label>$</label>
#              <word>ka</word>
#              <pos>VRoot</pos>
#              <translation>=ser</translation>
#              <morph>Root</morph>
#              <secedges>
#              </secedges>
#            </terminal>
#          </children>
#        </nonterminal>
#      </saphi>
#    </s>
#  </body>

# option: -a
#  writes all alternative analyses, the first one without "@", the following with "@"

# $num_args = $#ARGV + 1;
# if ($num_args < 2 or $num_args > 3) {
#   print "\nUsage: xfst2pml.perl xsft_analysed_INfile pml_OUTfile [-a]\n";
#   exit;
# }
# 
# $xfst_file = $ARGV[0];
# $pml_file = $ARGV[1];
# if ($num_args == 2) {
#  $all = 0;
# }
# elsif ($ARGV[2] eq "-a") {
#  $all = 1;
# }
# else {
#   print "\nUsage: xfst2pml.perl xsft_analysed_INfile pml_OUTfile [-a]\n";
#   exit;
# }
# 
# open XFST, "< $xfst_file" or die "Can't open $xfst_file : $!";
# open PML, "> $pml_file" or die "Can't open $pml_file : $!";


$all=1;
$new_analysis = 1;		# flag to take only the first analysis
$in_sentence = 0;		# flag to avoid printing empty sentences!...
$new_sent = "<s id=\"s1\"><saphi><nonterminal id=\"s1_VROOT\"><cat>VROOT</cat><children>\n";
$end_sent = "</children></nonterminal></saphi></s>\n";
my $header = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<corpus id=\"ahk1968-2008_qu_disamb\">
  <head>
    <schema href=\"../qu_schema.xml\" />
  </head>
  <body>\n";
print STDOUT $header;
$sn=1;
$wn=1;
while (<>) {
 if (/^#EOS\t#EOS\t\+\?$/) {	# placeholder <br> not analysed
  if ($in_sentence) {
   print STDOUT $end_sent;		# print EOS
   $sn++;			# and prepare new sentence
   $new_sent = "<s id=\"s$sn\"><saphi><nonterminal id=\"s${sn}_VROOT\"><cat>VROOT</cat><children>\n";
   $wn = 1;
   $in_sentence = 0;
  }
 }
 elsif (/\+\?$/) {		# unknown word, not analysed
  ($a,$b,$c) = split /\t/;
  if ($new_sent) {
   print STDOUT $new_sent;
   $new_sent = "";
  }
  $a =~ s/&/&amp;/;
 # print STDOUT "<terminal id=\"s${sn}_$wn\"><order>$wn</order><label>\$</label><word>$a</word><pos>UNKNOWN</pos></terminal>\n";
  print STDOUT "<terminal><order>$wn</order><label>\$</label><word>$a</word><pos>UNKNOWN</pos></terminal>\n";
  $in_sentence = 1;
  $wn++;
 }
 else {				# analysed word with root and IGs, a concatenation of "w[pos][morph]"
  chomp;
  s/\s+//g;					# remove blanks
  s/&/&amp;/;					# escape sensitive stuff
  ($rootig,@igs) = split /\[\^DB\]\[--\]/;	# split root IG from following IGs at the delimiter [^DB][--]
  if (not $rootig) {				# empty line between original tokens
   $new_analysis = 1;				# reset the flag
  }
  elsif ($all or $new_analysis) {		# take the first analysis (new_analysis) or anyway all alternative analyses
   ($root,@suffs) = split(/\[--\]/,$rootig);	# root + possible suffix morphems
   $root =~ s/\]//g;
   ($rtok,$rpos,$translation) = split(/\[/,$root);	# root token, pos and translation
   $word = $rtok;
   $pos = $rpos;
   if ($pos =~ /^\$/) {
    $label = "punc";				# special dependency label for punctuation
    $morph = "";				# no morph tag
   }
   elsif ($pos =~ /^SP$/) {			# no morph tag for Spanish words pos tagged with [SP]
    $morph = "";
    $label = "\$";
   }
   elsif ($pos =~ /^CARD$/) {			# replace CARD with NRootNUM, so all numerals have the same tag
    $morph = "<tag>NRootNUM</tag>";
    $pos = "Root";
    $label = "\$";
   }
   elsif ($pos =~ /^ALFS$/) {			# no morph tag for single letters
    $morph = "";
    $label = "\$";
   }
   else {
    $morph = "<tag>$pos</tag>";	# in this case switch morph and pos tags!
    $pos = "Root";
    $label = "\$";
   }
   foreach $suff (@suffs) {
    $suff =~ s/\]//g;
    ($sufftok,$suffpos,$suffmorph) = split(/\[/,$suff);	# root suffix token, pos and morph
    $word .= $sufftok;
     if($suffpos =~ /Root/) #if nominal compound or verb with incorporated noun, 'suffix' is root -> pos is Root, morph is NRoot/VRoot, morph is empty, $suffmorph is translation
      {
	$morph .= "<tag>$suffpos</tag>";
	$pos = "Root";
	$translation = $suffmorph;
	#print STDERR "pos: $pos, morph: $morph, translation: $translation \n";
      }
    else
      {
	$pos .= "_$suffpos";
	$morph .= "<tag>$suffmorph</tag>";
      }
   }
   if ($new_sent) {
    print STDOUT $new_sent;
    $new_sent = "";
   }
   #print STDOUT "<terminal id=\"s${sn}_$wn\"><order>$wn</order><label>$label</label>";
   
   unless ($word eq '#EOS'){
   print STDOUT "<terminal><order>$wn</order><label>$label</label>";
  
   if ($new_analysis) {
    print STDOUT "<word>$word</word>";
   }
   else {
    print STDOUT "<word>\#$word</word>";
   }
   print STDOUT "<pos>$pos</pos><translation>$translation</translation><morph>$morph</morph></terminal>\n";
   $wn++;
   $in_sentence = 1;
   for $ig (@igs) {		# suffix IGs as individual terminal nodes
    @suffs = split(/\[--\]/,$ig);	# merge different suffixes to an IG
    $word = "-";			# put a hyphen at the begin of the IG
    $pos = "";
    $morph = "";
    foreach $suff (@suffs) {
     $suff =~ s/\]//g;
     ($sufftok,$suffpos,$suffmorph) = split(/\[/,$suff);	# suffix token, pos and morph
     $word .= $sufftok;
    if($suffpos =~ /Root/) #if nominal compound or verb with incorporated noun, 'suffix' is root -> pos is Root, morph is NRoot/VRoot, morph is empty, $suffmorph is translation
      {
	$morph .= "<tag>$suffpos</tag>";
	$pos = "Root";
	$translation = $suffmorph;
	print STDERR "pos: $pos, morph: $morph, translation: $translation \n";
      }
    else
      {
	$pos .= "_$suffpos";
	$morph .= "<tag>$suffmorph</tag>";
      }
    }
    $pos =~ s/^_//;		# remove underscore before first pos tag
    #print STDOUT "<terminal id=\"s${sn}_$wn\"><order>$wn</order><label>\$</label>";
    print STDOUT "<terminal><order>$wn</order><label>\$</label>";
    print STDOUT "<word>$word</word>";
    if($suffpos =~ /Root/)
    {
      print STDOUT "<pos>$pos</pos><morph>$morph</morph><translation>$translation</translation></terminal>\n";
    }
    else
    {
      print STDOUT "<pos>$pos</pos><morph>$morph</morph></terminal>\n";
    }
    $wn++;
   }}
   if ($rtok =~ /^[.?!;]+$/ or $rtok =~ /#EOS/) {	# end of sentence
    if ($in_sentence) {
     print STDOUT $end_sent;	# print EOS
     $sn++;			# and prepare new sentence
     $new_sent = "<s id=\"s$sn\"><saphi><nonterminal id=\"s${sn}_VROOT\"><cat>VROOT</cat><children>\n";
     $wn = 1;
     $in_sentence = 0;
    }
    else {
     print "this is strange... it shouldn't happen!\n";
    }
   }
   $new_analysis = 0;		# unset the flag
  }
  else {			# skip other analyses
				# do nothing
  }
 }
}
if ($in_sentence) {		# if sentence not yet "ended"
 print STDOUT $end_sent;		# print EOS
}
print STDOUT "</body>\n</corpus>\n";

# close(XFST);
# close(PML);
