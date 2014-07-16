#!/usr/bin/perl
package squoia::esde::outputGermanMorph;

use strict;
use utf8;

my %mapGermanDate =       (
        'L'		=> 'Montag',
	'M'		=> 'Dienstag',
	'X'		=> 'Mittwoch',
	'J'		=> 'Donnerstag',
	'V'		=> 'Freitag',
	'S'		=> 'Samstag',
	'D'		=> 'Sonntag',
	'1'		=> 'Januar',
	'2'		=> 'Februar',
	'3'		=> 'März',
	'4'		=> 'April',
	'5'		=> 'Mai',
	'6'		=> 'Juni',
	'7'		=> 'Juli',
	'8'		=> 'August',
	'9'		=> 'September',
	'01'		=> 'Januar',
	'02'		=> 'Februar',
	'03'		=> 'März',
	'04'		=> 'April',
	'05'		=> 'Mai',
	'06'		=> 'Juni',
	'07'		=> 'Juli',
	'08'		=> 'August',
	'09'		=> 'September',
	'10'		=> 'Oktober',
	'11'		=> 'November',
	'12'		=> 'Dezember',
	'am'		=> 'morgens',	# Vormittag
	'pm'		=> 'abends'	# Nachmittag?
                );

sub outputGermanDate{
	my $daterec = $_[0];

	my $datestr = '';
	if ($daterec->{'siglo'}) {
		my $jahr100 = $daterec->{'siglo'};
		print STDERR "Jahrhundert: $jahr100\n";
		#$datestr = $datestr . "im ".uc($jahr100).". Jahrhundert";
		$datestr = $datestr .uc($jahr100).". Jahrhundert";
	}
	elsif ($daterec->{'semdia'} or $daterec->{'dia'}) {
		#$datestr = $datestr."am";
		if ($daterec->{'semdia'} ) {
			my $wochentag = $mapGermanDate{$daterec->{'semdia'}};
			print STDERR "Name des Tages: ".$wochentag."\n";
			$datestr = $datestr ." $wochentag";
			if ($daterec->{'dia'}) {
				$datestr = $datestr.", den";
			}
		}
		if ($daterec->{'dia'}) {
			my $tag = $daterec->{'dia'}.".";
			$tag =~ s/^0//;
			$datestr = $datestr ." $tag";
		}
		if ($daterec->{'mes'}) {
			my $monat = $mapGermanDate{$daterec->{'mes'}};
			print STDERR "Name des Monats: ".$monat."\n";
			$datestr = $datestr. " $monat";
			if ($daterec->{'anno'}) {
				my $jahr = $daterec->{'anno'};
				print STDERR "im Jahre: ".$jahr."\n";
				$datestr = $datestr." $jahr";
			}
		}
	}
	elsif ($daterec->{'mes'}) {
		my $monat = $mapGermanDate{$daterec->{'mes'}};
		print STDERR "Name des Monats: ".$monat."\n";
		#$datestr = $datestr. "im $monat";
		$datestr = $datestr. $monat;
		if ($daterec->{'anno'}) {
			my $jahr = $daterec->{'anno'};
			print STDERR "im Jahre: ".$jahr."\n";
			$datestr = $datestr." $jahr";
		}
	}
	elsif ($daterec->{'anno'}) {
		my $jahr = $daterec->{'anno'};
		print STDERR "im Jahre: ".$jahr."\n";
		$datestr = $datestr."in $jahr";
	}
	if ($daterec->{'hora'}) {
		my $zeit = $daterec->{'hora'};
		$zeit =~ s/^0//;
		print STDERR "um ". $zeit. " Uhr";
		$datestr = $datestr." um $zeit Uhr";
	}
	if ($daterec->{'min'}) {
		print STDERR $daterec->{'min'}."\n";
		$datestr = $datestr." ".$daterec->{'min'};
	}
	if ($daterec->{'ampm'}) {
		my $vornach = $mapGermanDate{$daterec->{'ampm'}};
		print STDERR "$vornach\n";
		$datestr = $datestr." $vornach";
	}
	return $datestr;
}

# German morphology information generation (to be processed by SttsGeneratorTool.fst, that finally produces the corresponding word forms)
# example:
#die_ART_Def.Fem.Nom.Sg
#Mutter_NN_Fem.Nom.Sg.*
#und_KON_
#der_ART_Def.Masc.Nom.Sg
#Vater_NN_Masc.Nom.Sg.*
#wollen_VM_Inf
#können_VMFIN_3.Pl.Pres.Ind
#dass_KOUS_
#der_ART_Def.Masc.Nom.Sg
#Sohn_NN_Masc.Nom.Sg.*
#Apfel_NN_Masc.Akk.Pl.*
#essen_VV_
#können_VMFIN_3.Sg.Pres.Ind
#._$._

my %mapPronoun =       (
        '3.Sg'		=> 'es',
	'2.Sg'		=> 'du',
	'1.Sg'		=> 'ich',
	'3.Pl'		=> 'sie',
	'2.Pl'		=> 'ihr',
	'1.Pl'		=> 'wir'
                );

sub genGerman{
	my $node = $_[0];
	
	my $format = "molif";
	#my $format = "smor";	# smor (morphisto)
	return &genMorphGenInput($node,$format);
}

sub mapCase{	# TODO or map with hash?
	my $cas = $_[0];
	my $format = $_[1];
	
	if ($format eq "smor") {
		$cas =~ s/Akk/Acc/;
	}
	return $cas;
}

sub genADJA{
	my $format = $_[0];
	my $lem = $_[1];
	my $grad= $_[2];
	my $gen = $_[3];
	my $cas = $_[4];
	my $num = $_[5];
	my $flex= $_[6];

	my $morphStr;
	if ($format eq "molif") {
		# ADJA: attributive adjective with flexion
		# 	lemma_ADJA_grad.gen.cas.num.flex
		#	bauchig_ADJA_Pos.Fem.Dat.Sg.St

		$morphStr = $lem."_ADJA_$grad.$gen.$cas.$num.$flex";
	}
	elsif ($format eq "smor") {
		# +ADJ:
		#	lemma<+ADJ><grad><gen><cas><num>(<flex>)?	# grad=(Pos|Comp|Sup) ; flex=(St|Wk|Mix?) not always necessary; TODO flex=Mix => never?
		#	gelb<+ADJ><Pos><Fem><Nom><Sg>		=> gelbe
		#	gelb<+ADJ><Pos><Neut><Nom><Sg><St>	=> gelbes
		#	lang<+ADJ><Sup><NoGend><Nom><Pl><Wk>	=> laengsten
		#	lang<+ADJ><Sup><NoGend><Dat><Sg><Wk>	=> laengsten	# TODO beware: Dat/Sg can also have NoGend
		#	streng<+ADJ><Sup><Fem><Gen><Sg><St>	=> strengster
		$gen = "NoGend" if ($num =~ /Pl/);
		$morphStr = "$lem<+ADJ><$grad><$gen><$cas><$num>";
		$flex = "St" if ($flex =~ /Mix/);		# TODO flex=Mix => never?
		if (not ($cas eq "Dat" and $num eq "Pl") ) {	# TODO conditions where flex is needed....
			$morphStr = $morphStr."<$flex>";
		}
	}
	else {
		print STDERR "don't know this format!...\n";
	}
	return $morphStr;
}

sub genADJD{
	my $format = $_[0];
	my $lem = $_[1];
	my $grad= $_[2];

	my $morphStr;
	if ($format eq "molif") {
		# ADJD: adverbially or predicatively used adjective only with graduation
		#	lemma_ADJD_grad
		#	bauchig_ADJD_Comp
		$morphStr = $lem."_ADJD_$grad";
	}
	elsif ($format eq "smor") {
		# <+ADJ>:
		#	lemma<+ADJ><grad><Pred>
		#	lang<+ADJ><Comp><Pred>	=> laenger
		$morphStr = "$lem<+ADJ><$grad><Pred>";
	}
	else {
		print STDERR "don't know this format!...\n";
	}
	return $morphStr;
}

sub genADV{
	my $format = $_[0];
	my $lem = $_[1];

	my $morphStr;
	if ($format eq "molif") {
		# ADV: adverbs (closed word classes) are not in mOLIF
		#	lemma_ADV
		#	gern_ADV
		#	sehr_ADV
		$morphStr = $lem."_ADV";
	}
	elsif ($format eq "smor") {
		# <+ADV>: "true" adverbs
		#	lemma<+ADV>
		#	gern<+ADV>
		# adverbs from adjectives:
		#	lieb<+ADJ><Comp><Adv>	=> lieber
		$morphStr = "$lem<+ADV>";
	}
	else {
		print STDERR "don't know this format!...\n";
	}
	return $morphStr;
}

sub genAPPRART{
	my $format = $_[0];
	my $lem = $_[1];
	my $gen = $_[2];
	my $cas = $_[3];
	my $num = $_[4];

	my $morphStr;
	if ($format eq "molif") {
		# APPRART: APpositions/PRepositions with ARTicle
		# 	lemma_APPRART_gen.cas.num
		#	an-das_APPRART_Neut.Akk.Sg	=> ans
		#	an-das_APPRART_Neut.Dat.Sg	=> am
		#	zu-der_APPRART_Neut.Dat.Sg	=> zum
		# complete list of merged preposition with definite article:
		#	am, ans, aufs, beim, durchs, hinterm, hintern, hinters, im, ins, ums, unterm, untern, vom, vorm, vors, zum, zur
		$morphStr = $lem."_APPRART_$gen.$cas.$num";
		$morphStr =~ s/d\(er\)(_APPRART_Masc)/der\1/;
		$morphStr =~ s/d\(er\)(_APPRART_Fem)/die\1/;
		$morphStr =~ s/d\(er\)(_APPRART_Neut)/das\1/;
	}
	elsif ($format eq "smor") {
		# <+PREPART>: PREPositions with ARTicle
		#	lemma<+PREPART><gen><cas><num>
		#	an<+PREPART><Neut><Acc><Sg>	=> ans
		#	zu<+PREPART><Masc><Dat><Sg>	=> zum
		$lem =~ s/-.*//;		# an-das => an
		#$cas =~ s/Akk/Acc/;
		$cas = &mapCase($cas,$format);
		$morphStr = $lem."<+PREPART><$gen><$cas><$num>";
	}
	else {
		print STDERR "don't know this format!...\n";
	}
	return $morphStr;
}

sub genART{
	my $format = $_[0];
	my $lem = $_[1];
	my $type= $_[2];
	my $gen = $_[3];
	my $cas = $_[4];
	my $num = $_[5];

	my $morphStr;
	if ($format eq "molif") {
		# ARTicles
		# 	lemma_ART_deftype.gen.cas.num
		#	die_ART_Def.Fem.Nom.Sg
		#	das_ART_Def.Neut.Akk.Sg
		#	die_ART_Def.*.Akk.Pl		# no gender specification in plural
		$gen = "*" if ($num =~ /Pl/);
		$morphStr = $lem."_ART_$type.$gen.$cas.$num";
		$morphStr =~ s/d\(er\)(_ART_Def\.Masc)/der\1/;
		$morphStr =~ s/d\(er\)(_ART_Def\.Fem)/die\1/;
		$morphStr =~ s/d\(er\)(_ART_Def\.Neut)/das\1/;
		$morphStr =~ s/d\(er\)(_ART_Def\.\*\.\w+\.Pl)/die\1/;
	}
	elsif ($format eq "smor") {
		# lem<+ART><type><gen><cas><num><flex>	=> TODO type=(Def|Indef) more? ; always flex=St ?
		# die<+ART><Def><NoGend><Acc><Pl><St>	=> die	# NoGend in plural
		# die<+ART><Def><Masc><Dat><Sg><St>	=> dem
		# eine<+ART><Indef><Fem><Nom><Sg><St>	=> eine
		# eine<+ART><Indef><Neut><Acc><Sg><Wk>	=> ein
		# eine<+ART><Indef><Neut><Nom><Sg><Wk>	=> ein
		# eine<+ART><Indef><Masc><Nom><Sg><Wk>	=> ein
		
		$cas = &mapCase($cas,$format);
		my $flex = "St";	# TODO type=Def => flex=St; type=?
		if ($type =~ /Def/) {	# if definite article then
			$flex = "St";	# 	strong flexion
		}
		elsif ($type =~ /Indef/ and $num =~ /Sg/ and (($gen =~ /Neut/ and $cas =~ /Acc|Nom/) or ($gen =~ /Masc/ and $cas =~ /Nom/) ) ) {
			$flex = "Wk";
		}
		$lem =~ s/d\(er\)/die/;
		$lem =~ s/ein$/eine/;
		$gen = "NoGend" if ($num =~ /Pl/);
		$morphStr = "$lem<+ART><$type><$gen><$cas><$num><$flex>";
	}
	else {
		print STDERR "don't know this format!...\n";
	}
	return $morphStr;
}

sub genNN{
	my $format = $_[0];
	my $lem = $_[1];
	my $gen = $_[2];
	my $cas = $_[3];
	my $num = $_[4];

	my $morphStr;
	if ($format eq "molif") {
		# Nouns
		# NN: Normales Nomen: common nouns
		#	lemma_NN_gen.cas.num.*
		#	Mutter_NN_Fem.Nom.Sg.*
		$morphStr = $lem."_NN_$gen.$cas.$num.*";
	}
	elsif ($format eq "smor") {
		# <+NN>
		#	lemma<+NN><gen><cas><num>(<flex>)?	=> TODO sometimes a flexion, like in "Angestellten" = Angestellte<+NN><Masc><Acc><Pl><Wk>
		#	Bruder<+NN><Masc><Acc><Sg>	=> Bruder
		$cas = &mapCase($cas,$format);
		$morphStr = "$lem<+NN><$gen><$cas><$num>";		
	}
	else {
		print STDERR "don't know this format!...\n";
	}
	return $morphStr;
}

sub genPPER {
	my $format = $_[0];
	my $lem = $_[1];
	my $pers = $_[2];
	my $num = $_[3];
	my $gen = $_[4];
	my $cas = $_[5];

	my $morphStr;
	if ($format eq "molif") {
		# PPER: personal pronoun
		#	lemma_PPER_pers.num.gen.cas
		#	sie_PPER_3.Sg.Fem.Dat		=> ihr
		#	wir_PPER_1.Pl.*.Nom		=> wir
		$morphStr = $lem."_PPER_$pers.$num.$gen.$cas";
		print STDERR "molif PPER\n";
	}
	elsif ($format eq "smor") {
		# sie<+PPRO><type><pers><num><gen><cas><flex>	=> TODO: type= (Pers|Prfl) from ? ; always flex=Wk ?
		# sie<+PPRO><Pers><1><Pl><NoGend><Nom><Wk>	=> wir
		# sie<+PPRO><Prfl><1><Sg><NoGend><Acc><Wk>	=> mich
		# sie<+PPRO><Pers><3><Sg><Masc><Acc><Wk>	=> ihn
		# sie<+PPRO><Pers><2><Sg><NoGend><Gen><Wk>	=> deiner
		# $lem = "sie";
		my $pprotype = "Pers";
		$gen =~ s/\*/NoGend/;
		$cas = &mapCase($cas,$format);
		# $flex = "Wk";
		$morphStr = "sie<+PPRO><$pprotype><$pers><$num><$gen><$cas><Wk>";		
		print STDERR "smor PPRO\n";
	}
	else {
		print STDERR "don't know this format!...\n";
	}
	return $morphStr;
}

sub genMorphGenInput{
	my $node = $_[0];
	my $format = $_[1];

	my $pos = $node->getAttribute('pos');
	my $lem = $node->getAttribute('lem');
	#TODO: UpCase can only be applied on the generated morphological form...
	#my $upC = $node->getAttribute('UpCase');
	#if ($upC =~ /first/) {
	#	$lem = ucfirst($lem);
	#}
	#elsif ($upC =~ /all/) {
	#	$lem = uc($lem);
	#}
	#else { $upC=none: nothing to do}
	my $mi  = $node->getAttribute('mi');
	my $cas = $node->getAttribute('cas');	# may not be set
	if (not $node->hasAttribute('cas')) {
		$cas = 'Nom';			# default case is nominative
	}
	my $flex;
	my $gen;
	my $num;
	my $morphStr = $lem."_".$pos;
	my $morphInfo;
	print STDERR "** $lem vom pos $pos mit mi $mi\n";
	# APPRART: APpositions/PRepositions with ARTicle
	# 	lemma_APPRART_gen.cas.num
	# complete list of merged preposition with definite article:
	#	am, ans, aufs, beim, durchs, hinterm, hintern, hinters, im, ins, ums, unterm, untern, vom, vorm, vors, zum, zur
	if ($pos =~ /APPRART/) {
		my ($gen,$num) = split(/\./,$mi);
		$morphStr = &genAPPRART($format,$lem,$cas,$gen,$num);
	}
	# ARTicles
	# 	lemma_ART_deftype.gen.cas.num
	elsif ($pos =~ /ART/) {
		my $deftype = $node->getAttribute('deftype');
		my ($gen,$num) = split(/\./,$mi);
print STDERR "def type: $deftype\tgender: $gen\tnumber $num\n";
		$morphStr = &genART($format,$lem,$deftype,$gen,$cas,$num);
	}
	# ADJectives
	elsif ($pos =~ /ADJ/) {
		my $grad = "Pos"; # Pos|Comp|Sup; TODO: this should come from the Spanish part and be present as tag in the node
		if ($node->hasAttribute('grad')) {
			$grad = $node->getAttribute('grad');
		}
		# ADJA: attributive adjective with flexion
		# 	lemma_ADJA_grad.gen.cas.num.flex
		if ($pos eq "ADJA") {
			my ($gen,$num) = split(/\./,$mi);
			if ($node->hasAttribute('flex')) {
				$flex = $node->getAttribute('flex');
			}
			else {			# if there is no flex attribute, probably there is no determiner
				$flex = "St";	# in that case the strong flexion is used
			}
			$morphStr = &genADJA($format,$lem,$grad,$gen,$cas,$num,$flex);
		}
		# ADJD: adverbially or predicatively used adjective only with graduation
		#	lemma_ADJD_grad
		else {
			$morphStr = &genADJD($format,$lem,$grad);
		}
	}
	# Nouns
	# NN: Normales Nomen: common nouns
	#	lemma_NN_gen.cas.num.*
	#	Mutter_NN_Fem.Nom.Sg.*
	elsif ($pos =~ /NN/) {
		my ($gen,$num) = split(/\./,$mi);
		$morphStr = &genNN($format,$lem,$gen,$cas,$num);
	}
	# NE: Eigenname: named entity
	#	lemma_NE
	#	TODO: could generate a genitive form like "Marias Haus"?
	elsif ($pos =~ /NE/) {
		$morphStr = $morphStr."_".$morphInfo;
	}
	# Pronouns
	# PDAT: attributive demonstrative pronoun
	#	lemma_PDAT_gen.cas.num
	#	dieser_PDAT_Masc.Akk.Sg
	# PIAT: attributive indefinite pronoun
	#	lemma_PIAT_gen.cas.num
	#	jeder_PIAT_Fem.Akk.Sg		=> jede
	# PIS: substitutive indefinite pronoun
	#	lemma_PIS_gen.cas.num
	#	jeder_PIS_Fem.Akk.Sg		=> jede
	#	all_PIS_*.Dat.Pl		=> allen
	# PPOSAT: attributive possessive pronoun
	#	lemma_PPOSAT_gen.cas.num
	#	du_PPOSAT_*.Dat.Pl
	# PPOSS: substitutive possessive pronoun
	#	lemma_PPOSS_gen.cas.num
	#	du_PPOSS_*.Dat.Pl		=> deinen
	#	er_PPOSS_Masc.Nom.Sg		=> seiner, sein
	# PWAT: attributive interrogative pronoun
	#	lemma_PWAT_gen.cas.num
	#	welcher_PWAT_*.Dat.Pl		=> welchen
	#	welcher_PWAT_Masc.Dat.Sg	=> welchem
	# PWS: substitutive interrogative pronoun
	#	lemma_PWS_gen.cas.num
	#	welcher_PWS_*.Nom.Pl		=> welche
	#	welcher_PWS_Neut.Akk.Sg		=> welches
	#	wer_PWS_*.Nom.Sg		=> wer
	#	wer_PWS_*.Akk.Sg		=> wen
	#	wer_PWS_*.Dat.Sg		=> wem
	elsif ($pos =~ /PDAT|PIAT|PIS|PPOSAT|PPOSS|PWAT|PWS/) {
		my ($gen,$num) = split(/\./,$mi);
		$gen = "*" if ($num =~ /Pl/);
		$morphInfo = "$gen.$cas.$num";
		my @altlems = split(/\|\|/,$lem);
		my @morpharr;
		foreach my $l (@altlems) {
			my $morphstring = $l."_".$pos."_".$morphInfo;
			push(@morpharr,$morphstring);
		}
		#$morphStr = $morphStr."_".$morphInfo;
		$morphStr = join("\n/\n",@morpharr);
	}
	# PPER: personal pronoun
	#	lemma_PPER_pers.num.gen.cas
	#	sie_PPER_3.Sg.Fem.Dat		=> ihr
	#	wir_PPER_1.Pl.*.Nom		=> wir
	elsif ($pos =~ /PPER/) {
		my ($pers, $num, $gen) = split(/\./,$mi);
		if (not $node->hasAttribute('lem')) {
			$lem = $mapPronoun{$mi};
			$gen = "*";
			$gen = 'Neut' if ($mi =~ /3\.Sg/);
		#	$mi = $mi.".$gen";
		#	$morphStr = $lem."_".$pos;
		}
		#$morphInfo = "$mi.$cas";
		#$morphStr = $morphStr."_".$morphInfo;
		$morphStr = &genPPER($format,$lem,$pers,$num,$gen,$cas);
	}
	# PRELAT: relative pronoun, attributive
	#	lemma_PRELAT_gen.cas.num	TODO: in molif as PRELS and not PRELAT as it should be!...
	#	der_PRELS_Masc.Gen.Sg		=> dessen
	#	die_PRELS_Fem.Gen.Sg		=> deren
	#	das_PRELS_Neut.Gen.Sg		=> dessen
	#	die_PRELS_*.Gen.Pl		=> deren
	elsif ($pos =~ /PRELAT/) {
		my ($gen,$num) = split(/\./,$mi);
		$gen = "*" if ($num =~ /Pl/);
		$morphInfo = "$gen.Gen.$num";
		$morphStr = $morphStr."_".$morphInfo;		# lemma_ART_deftype.gen.cas.num ; TODO: pick up lemma der/die/das...
		#$morphStr =~ s/d\(er\)_PRELAT_Masc/der_PRELS_Masc/; 	# TODO: pick the second option that molif generates!!!
		#$morphStr =~ s/d\(er\)_PRELAT_Fem/die_PRELS_Fem/;
		#$morphStr =~ s/d\(er\)_PRELAT_Neut/das_PRELS_Neut/;
		#$morphStr =~ s/d\(er\)_PRELAT_\*\.Gen\.Pl/die_PRELS_\*\.Gen\.Pl/;
		$morphStr =~ s/d\(er\)_PRELAT_Masc/dessen_PRELS_Masc/;	# momentarily workaround before picking the better molif generated form
		$morphStr =~ s/d\(er\)_PRELAT_Fem/deren_PRELS_Fem/;
		$morphStr =~ s/d\(er\)_PRELAT_Neut/dessen_PRELS_Neut/;
		$morphStr =~ s/d\(er\)_PRELAT_\*\.Gen\.Pl/deren_PRELS_\*\.Gen\.Pl/;
		# add comma before relative pronoun; TODO: better place to add it? Problem with prepositions!!!
		#$morphStr = ",\n". $morphStr;
	}
	# PRELS: relative pronoun
	#	lemma_PRELS_gen.cas.num
	#	das_PRELS_Neut.Akk.Sg		=> das
	#	die_PRELS_*.Dat.Pl		=> denen
	elsif ($pos =~ /PRELS/) {
		my ($gen,$num) = split(/\./,$mi);
		$gen = "*" if ($num =~ /Pl/);
		$morphInfo = "$gen.$cas.$num";
		$morphStr = $morphStr."_".$morphInfo;		# lemma_ART_deftype.gen.cas.num ; TODO: pick up lemma der/die/das...
		$morphStr =~ s/d\(er\)(_PRELS_Masc)/der\1/;
		$morphStr =~ s/d\(er\)(_PRELS_Fem)/die\1/;
		$morphStr =~ s/d\(er\)(_PRELS_Neut)/das\1/;
		$morphStr =~ s/d\(er\)(_PRELS_\*\.\w+\.Pl)/die\1/;
		# add comma before relative pronoun; TODO: better place to add it? Problem with prepositions!!!
		#$morphStr = ",\n". $morphStr;
	}
	# PRF: reflexive pronouns
	#	lemma_PRF_pers.num.cas
	#	sie_PRF_*.*.*		=> sich
	#	wir_PRF_1.Pl.Akk	=> uns
	#	ihr_PRF_2.Pl.Akk	=> euch
	#	du_PRF_2.Sg.Akk		=> dich
	#	ich_PRF_1.Sg.Dat	=> mir
	elsif ($pos =~/PRF/) {
		if ($lem =~ /sie/) {
			$morphInfo = "*.*.*";
		}
		else {
			$morphInfo = $mi.".Akk";
		}
		#lem already lemma_pos
		$morphStr = $lem."_".$morphInfo;
		# TODO maybe do something for the Dat case?
	}	
	# TRUNC
	# from Spanish adjectives that form German compounds
	#	mundial => Welt-
	elsif ($pos =~/TRUNC/) {
		#already lemma_pos
	}	
	# Verbs
	# TODO: check if verb type matters (Voll|Aux|Modal)
	# VVFIN: Voll Verb Finite: main verb finite
	#	lemma_VVFIN_pers.num.temp.mod
	#	machen_VVFIN_3.Sg.Past.Konj	=> machte
	elsif ($pos =~ /V[AMV]FIN/) {
		if ($node->hasAttribute('subjnum')) {
			my $subjnum = $node->getAttribute('subjnum');
			my ($pers, $num, $temp, $mod) = split(/\./,$mi);
			$mi = "$pers.$subjnum.$temp.$mod";
		}
		$morphStr = $morphStr."_".$mi;		# mi="pers.num.temp.mod"
	}
	# V.IMP: Verb Imperative
	#	lemma_VVIMP_num
	#	machen_VVIMP_Sg		=> mache
	#	machen_VVIMP_Pl		=> macht
	elsif ($pos =~ /V[AMV]IMP/) {
		$num = $mi;			# attribute "mi" (morphological information) only contains the number information
		$morphStr = $morphStr."_".$num;
	}
	# V.INF: Verb Infinitive
	#	lemma_VVINF
	#	machen_VVINF
	elsif ($pos =~ /V[AMV]INF/) {
		if ($node->getAttribute('zu') eq "yes"){
			if ($lem =~ /\|/) {	# separable verb prefix
				$morphStr =~ s/VVINF/VVIZU/;
				$morphStr =~ s/\|/zu/;	# TODO: trick because the generation of zu forms does not seem to work in molif...
			}
			else {
				$morphStr = "zu\n".$morphStr;
			}
		}
		$morphStr = $morphStr."_";	# already lemma_pos
	}
	# V.IZU: Verb Infinitive with "zu"; only for verbs with separable prefix
	#	lemma_VVIZU_
	#	an|fangen_VVIZU_	=> anzufangen
	elsif ($pos =~ /V[AMV]IZU/) {
		$morphStr = $morphStr."_";	# already lemma_pos
	}
	# V.PP: Past Participle
	#	lemma_VVPP
	#	machen_VVPP
	elsif ($pos =~ /V[AMV]PP/) {
		$morphStr = $morphStr."_" if ($pos !~ /VMPP/);	# already lemma_pos; TODO: trick: keep "können_VMPP" without final "_" to avoid the generation of VMPP forms like "gekonnt" => it gets cleaned later!
	}
	# VV: Gerund
	#	lemma_VVPP
	#	machen_VVPP
	elsif ($pos eq "VV" and $mi eq "Ger") { # TODO: gerund form
		# already lemma_pos
	}
	# closed classes without flexion
	# Adverbs: ADV
	# Conjunctions: KON, KOUS
	# Prepositions: APPR; TODO: what about the contraction form APPRART?
	# Pronouns: PWAV
	# Punctuation signs: $. and $, and $(
	# Separable verb prefix: PTKVZ
	# ADVerbs
	elsif ($pos =~ /ADV/) {		# TODO map the pos of closed classes from molif to smor? do we really need this?
		$morphStr = &genADV($format,$lem);
	}
	elsif ($pos =~/ADV|KON|KOUS|APPR|\$\.|\$,|\$\(|PTKVZ|PWAV/) {
		#already lemma_pos
	}
	# Dates: [W] (not CARD nor NN because dates are automatically mapped to [W], the lemma written with digits and placeholders)
	# 	Format: [wd:dd/mm/yyyy:hh.min:(am|pm)]; wd=(L|M|X|J|V|S|D)
	#	Example: [??:??/11/1969:??.??:??] with lemma "noviembre_de_1969"
	#		[??:26:09:1992:03.00:pm] with lemma "las_tres_de_la_tarde_del_26_de_septiembre_de_1992"
	#		[s:xix] for "siglo_XIX"
	elsif ($pos =~/\[W\]/) {
		# TODO: map the date format to German words!
print STDERR "HELLO, I found the date $lem\n";
		my $date_record = &splitDate($lem);
		$morphStr = &outputGermanDate($date_record);
print STDERR "in German: $morphStr\n";
	}
	# Numbers: [Z] (DeSR: CARD from DN...; FL: not CARD because numbers are automatically mapped to [Z], the lemma written with digits)
	# TODO: mwu? slem="media_docena" smi="Z" pos="[Z]"
	elsif ($pos =~/\[Z\]|CARD/) {
		# maybe an ordinal number originally written with digits, e.g. 5º piso => 5. Stockwerk
		if ($lem =~ /(\d+)[ºªoa]/) {
			$morphStr = "$1.";
		}
	}
	# Ordinal numbers written with letters and tagged as AO....
	elsif ($node->getAttribute('smi') =~/^AO/ and $node->getAttribute('slem') =~ /^(\d+)$/) {
		$morphStr = "$1.";
	}
	else {
		print STDERR "unknown pos: $pos for lemma: $lem\n";
		#print STDOUT "$lem\n";
		$morphStr = "*unkPOS*". $morphStr;
	}

	return $morphStr;
}
sub main{
	my $dom = ${$_[0]};
	my $tmpfile = $_[1];
	open (OUTFILE, ">:encoding(UTF-8)", $tmpfile) or die "Can't open $tmpfile : $!";
	binmode OUTFILE, ':utf8';


	# get all SENTENCE chunks, iterate over childchunks
	foreach my $sentence  ( $dom->getElementsByTagName('SENTENCE'))
	{
		print OUTFILE "<s". $sentence->getAttribute('ref') . ">\n";
		#print STDERR $sentence->toString;
		#get all direct child CHUNKS within SENTENCE
		my @sentenceCHUNKS = $sentence->findnodes('descendant::CHUNK');

		my %orderhash;
		foreach my $chunk (@sentenceCHUNKS)
		{
			my $ord = $chunk->getAttribute('ord');
			$orderhash{$ord} = $chunk;
		}
		foreach my $ord (sort { $a <=> $b } keys %orderhash) {
			my $chunk = $orderhash{$ord};
			#print STDERR "ref: ".$chunk->getAttribute('ref')."\tord: ".$chunk->getAttribute('ord')."\ttype: ".$chunk->getAttribute('type')."\n";
			my @childnodes = squoia::util::getNodesOfSingleChunk($chunk);
			my %nodeorder;
			foreach my $child (@childnodes) {
				my $ord;
				if ($child->hasAttribute('ord')) {
					$ord = $child->getAttribute('ord');
				}
				else {
					$ord = $child->getAttribute('ref');
				}
				$nodeorder{$ord} = $child;
			}
			foreach my $ord (sort { $a <=> $b } keys %nodeorder) {
				my $node = $nodeorder{$ord};
				#print STDERR "\tnode ref: ".$node->getAttribute('ref')."\tnode ord: ".$node->getAttribute('ord')."\tnode lemma: ".$node->getAttribute('lem')."\n";
				# TODO: call whatever subroutines to output the node information you want, e.g. the lemma
				if ($node->hasAttribute('delete') and $node->getAttribute('delete') eq 'yes') {
					print STDERR "[".$node->getAttribute('slem')."]\n";
				}
				# unknown word
				# i.e. the word is not in the bilingual dictionary and could not be lexically transfered
				# and there is no "pos" attribute
				elsif ($node->hasAttribute('unknown')) { # and $node->getAttribute('smi') !~ /^(Z|AO)/) 
					my $unknownStr = "*".$node->getAttribute('slem');
					if ($node->hasAttribute('sform')) {
						$unknownStr = "*".$node->getAttribute('sform');
					}
					print STDERR "unknown $unknownStr\n";
					print OUTFILE "$unknownStr\n";
				}
				else {
					print STDERR $node->getAttribute('lem')." ";
					my $morphstring = &genGerman($node);
					print OUTFILE "$morphstring\n";
				}
			}
		}
		print OUTFILE "\n";	# empty line between sentences
	}
	close(OUTFILE);
}

sub generateMorphWord{
	my $infile = $_[0];
	my $outfile = $_[1];
	my $generator= $_[2];

	print STDERR "Morphology generator: $generator\n";
        open (INFILE, "<:encoding(UTF-8)", $infile) or die "Can't open $infile : $!";
	open (OUTFILE, ">", $outfile) or die "Can't open $outfile : $!";

	while(<INFILE>) {
		chomp;
		if (/\|/) {
			my ($pref,$verb) = split /\|/;
			print STDERR "Prefix: $pref ; verb: $verb\n";
			my $morph = `echo "$verb" | $generator `;
			if ($morph !~ /\+\?/) {
				my ($stts,$form) = split(/\t/,$morph);
				chomp($morph);
				print OUTFILE $pref."|".$stts."\t".$pref.$form;
			}
			else {
				print OUTFILE $pref."|".$morph;
			}
		}
		else {
			print STDERR "Stts string: $_ to generate\n";
			my $morph = `echo "$_" | $generator `;
			print OUTFILE $morph;
		}
	}
	close(INFILE);
	close(OUTFILE);
}
# List of POS tags to separate the word form from the tag
my $POSre = "_(\\\$|ADJ[AD]_|ADV|APPR(ART)?|APPO|APZR|ART|CARD|ITJ|KOU[IS]|KON|KOKOM|NE_|NN_|PDS|PDAT|PIS|PIAT|PIDAT|PPER|PPOSS|PPOSAT|PRELS|PRELAT|PRF|PWS|PWAT|PWAV|PAV|PTK(ZU|NEG|VZ|ANT|A)|TRUNC|V[AMV](FIN|INF|IMP|IZU|PP)_)";

# APPRART: contractions of preposition with definite article
# compulsary for the following forms: am, beim, im, vom, zum und zur
my %apprart = ();
$apprart{"an"}{"dem"} = "am";
$apprart{"bei"}{"dem"} = "beim";
$apprart{"in"}{"dem"} = "im";
$apprart{"von"}{"dem"} = "vom";
$apprart{"zu"}{"dem"} = "zum";
$apprart{"zu"}{"der"} = "zur";

sub getWordForm{
	my $outfst = $_[0];

	$outfst =~ s/<[^>]+>//g;	# get rid of the xml tags
	$outfst =~ s/^_//g;		# word form is the first string between "_"
	$outfst =~ s/_.*//g;		# eliminate the rest

	return $outfst;	
}

sub printWordForms{
	my $fh = shift;
	my $outarrayref = $_[0];

	my $sentence = "";
	my $len = @$outarrayref;
	for (my $i=0; $i < $len; $i++) {
		my $wordform = $outarrayref->[$i]->[-1];
		# print the last word form alternative #TODO: have some probabilistic preferences?
		print STDERR "$wordform ";
		$sentence .= "$wordform ";
	}
	$sentence =~ s/\ban dem\b/am/g;
	$sentence =~ s/\bbei dem\b/beim/g;
	$sentence =~ s/\bin dem\b/im/g;
	$sentence =~ s/\bvon dem\b/vom/g;
	$sentence =~ s/\bzu der\b/zur/g;
	$sentence =~ s/\bzu dem\b/zum/g;

	print $fh "$sentence";
}

sub cleanFstOutput{
	my $infile = $_[0];
        my $outfile = $_[1];

        open (INFILE, "<:encoding(UTF-8)", $infile) or die "Can't open $infile : $!";
        binmode INFILE, ':utf8';
        open (my $out_fh, ">:encoding(UTF-8)", $outfile) or die "Can't open $outfile : $!";
        binmode $out_fh, ':utf8';

	my @outarray = ();
	my $prev_infst = "";
	my $wordForm = "";
	while(<INFILE>) {
		chomp;
		if (/^$/) {	# flookup puts an empty line between words
			$prev_infst="";
			next;
		}
		my ($infst,$outfst) = split /\t/;
		if ($infst =~ /^$/) {	# empty line between sentence has been "generated" as "\t\+\?", i.e. $infst = "" and $outfst="+?"
			&printWordForms($out_fh,\@outarray);
			print $out_fh "\n";
			@outarray = ();
		}
		elsif ($infst eq $prev_infst) {
			# push further word form alternatives into array
			$wordForm = &getWordForm($outfst);
			push(@{$outarray[-1]},$wordForm);
		}
		elsif ($outfst =~ /\+\?/) {
			if ($infst =~ /^\*/) {		# begins with an asterisk, i.e. is unknown so print the whole string as "lemma"
				push(@outarray,["$infst"]);
			}
			else {
				print STDERR "$infst ";
				my ($lemma,$rest) = split(/$POSre|_VMPP/,$infst);
				print STDERR "with lemma $lemma\n";
	 			#my ($lemma,$pos) = split(/_/,$infst); # TODO: Named entities have also underscores; check this before cutting only the first part of the NE!
				$lemma =~ s/\|//g;	# eliminate the separable verb prefix mark "|" still present in infinitive forms
				push(@outarray,["$lemma"]);
			}
		}
		else {
			my $wordForm = &getWordForm($outfst);
			push(@outarray,["$wordForm"]);		
		}
		$prev_infst = $infst;
	}
	close(INFILE);
	close($out_fh);
}
1;
