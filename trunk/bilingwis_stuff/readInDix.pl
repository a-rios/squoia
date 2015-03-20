#!/usr/bin/perl

use strict;
use utf8;
#use open ':utf8';
binmode STDOUT, ':utf8';
#binmode STDOUT, ':utf8';
use Storable;
use XML::LibXML;

my $num_args = $#ARGV + 1;
if ($num_args > 1 ) {
  print "\nUsage: perl readInDix.pl  (provide XML dix on STDIN) \n";
  exit;
  }

my $dom    = XML::LibXML->load_xml( IO => *STDIN );

my %mapTags2FormsNouns = (
	'+3.Sg.Poss' => '#n', 
	'+3.Sg.Poss+Abl' => '#nmanta', 
	'+3.Sg.Poss+Acc' => '#nta', 
	'+3.Sg.Poss+Gen' => '#npa', 
	'+3.Sg.Poss+Iclsv' => '#nnintin', 
	'+3.Sg.Poss+Loc' => '#npi', 
	'+3.Sg.Poss+Pl' => '#nkuna', 
	'+Abl' => 'manta', 
	'+Add' => 'pas', 
	'+Aff+Rflx' => 'ykaku', 
	'+Ben' => 'paq', 
	'+Cont' => 'raq', 
	'+Dat' => 'man',
	'+Dat+Sim' => 'manhina', 
	'+Dat+Term' => 'mankama', 
	'+Def' => 'puni', 
	'+Dim' => 'cha', 
	'+Gen' => '_PA', 
	'++Gen' => '_PA', 
	'+Iclsv' => '#ntin', 
	'+Iclsv+Abl' => '#ntinmanta', 
	'+Instr' => 'wan', 
	'+Intr' => 'taq', 
	'+Kaus' => 'rayku', 
	'+Lim' => 'lla', 
	'+Lim+3.Sg.Poss' => 'llan', 
	'+Lim+Disc' => 'llaña', 
	'+Loc' => 'pi', 
	'+MPoss' => 'sapa', 
	'+Pl' => 'kuna', 
	'--Poss' => '#yuq', 
	'+Poss' => '#yuq', 
	'+Sim' => 'hina', 
	'+Term' => 'kama',
	'+Top' => 'qa'

);
## '-' marks DB -> those are morph-elements in xml
#my %mapTags2FormsVerbs = (
#	'+Aff' => 'yku' ,
#	'+Aff+Caus' => 'yka-chi' ,
#	'+Aff+Iprs' => 'ykapu' ,
#	'+Aff+Rflx' => 'yka-ku' ,
#	'+Aff+Rzpr+Rflx' => 'ykuna-ku' ,
#	'+Ass' => 'ysi' ,
#	'+Autotrs' => 'lli' ,
#	'+Autotrs+Rflx' => 'lli-ku' ,
#	'+Caus' => '-chi' ,
#	'+Caus+Cis+Iprs' => '-chi-m-pu' ,
#	'+Caus+Iprs' => '-chi-pu' ,
#	'+Caus+Rflx' => '-chi-ku' ,
#	'+Caus+Rflx+Iprs' => '-chi-ka-pu' ,
#	'+Caus+Rzpr+Rflx' => '-chi-na-ku' ,
#	'+Cis' => 'mu' ,
#	'+Des' => 'naya' ,
#	'+Des+Caus' => 'naya-chi' ,
#	'+Disk' => 'tiya' ,
#	'+Inch' => 'ri' ,
#	'+Inch+Caus' => 'ri-chi' ,
#	'+Inch+Cis' => 'rimu' ,
#	'+Inch+Rflx' => 'ri-ku' ,
#	'+Inch+Rzpr+Rflx' => 'rina-ku' ,
#	'+Int' => 'rpari' ,
#	'+Intrup' => '#kacha' ,
#	'+Intrup+Caus' => '#kacha-chi' ,
#	'+Intrup+Rflx' => '#kacha-ku' ,
#	'+Iprs' => 'pu' ,
#	'+Iprs+Caus' => 'pu-chi' ,
#	'+Iprs+Rflx' => 'pa-ku' ,
#	'+Iprs+Rzpr+Rflx' => 'puna-ku' ,
#	'+Lim' => '-lla' ,
#	'+Lim+Caus' => '-lla-chi' ,
#	'+MRep' => 'paya' ,
#	'+MRep+Caus+Rflx' => 'paya-chi-ku' ,
#	'+MRep+Rflx' => 'paya-ku' ,
#	'+Perdur' => 'raya' ,
#	'+Perdur+Caus' => 'raya-chi' ,
#	'+Prog' => '-chka' ,
#	'+Rem' => 'ymana' ,
#	'+Rep' => 'pa' ,
#	'+Rep+Caus' => 'pa-chi' ,
#	'+Rep+Rflx' => 'pa-ku' ,
#	'+Rep+Rzpr+Rflx' => 'pana-ku' ,
#	'+Rflx' => '-ku' ,
#	'+Rflx+Caus' => '-ka-chi' ,
#	'+Rflx+Iprs' => '-ka-pu' ,
#	'+Rptn' => 'rqu' ,
#	'+Rptn+Caus' => 'rqa-chi' ,
#	'+Rptn+Iprs' => 'rqapu' ,
#	'+Rptn+Rflx' => 'rqa-ku' ,
#	'+Rzpr' => 'na' ,
#	'+Rzpr+Caus' => 'na-chi' ,
#	'+Rzpr+Rflx' => 'na-ku' 
#);

# '' marks DB > those are morphelements in xml
my %mapTags2FormsVerbs = (
	'+Aff' => 'yku' ,
	'+Aff+Caus' => 'ykachi' ,
	'+Aff+Iprs' => 'ykapu' ,
	'+Aff+Rflx' => 'ykaku' ,
	'+Aff+Rzpr+Rflx' => 'ykunaku' ,
	'+Ass' => 'ysi' ,
	'+Autotrs' => 'lli' ,
	'+Autotrs+Rflx' => 'lliku' ,
	'+Caus' => 'chi' ,
	'+Caus+Cis+Iprs' => 'chimpu' ,
	'+Caus+Iprs' => 'chipu' ,
	'+Caus+Rflx' => 'chiku' ,
	'+Caus+Rflx+Iprs' => 'chikapu' ,
	'+Caus+Rzpr+Rflx' => 'chinaku' ,
	'+Cis' => 'mu' ,
	'+Des' => 'naya' ,
	'+Des+Caus' => 'nayachi' ,
	'+Disk' => 'tiya' ,
	'+Inch' => 'ri' ,
	'+Inch+Caus' => 'richi' ,
	'+Inch+Cis' => 'rimu' ,
	'+Inch+Rflx' => 'riku' ,
	'+Inch+Rzpr+Rflx' => 'rinaku' ,
	'+Int' => 'rpari' ,
	'+Intrup' => '#kacha' ,
	'+Intrup+Caus' => '#kachachi' ,
	'+Intrup+Rflx' => '#kachaku' ,
	'+Iprs' => 'pu' ,
	'+Iprs+Caus' => 'puchi' ,
	'+Iprs+Rflx' => 'paku' ,
	'+Iprs+Rzpr+Rflx' => 'punaku' ,
	'+Lim' => 'lla' ,
	'+Lim+Caus' => 'llachi' ,
	'+MRep' => 'paya' ,
	'+MRep+Caus+Rflx' => 'payachiku' ,
	'+MRep+Rflx' => 'payaku' ,
	'+Perdur' => 'raya' ,
	'+Perdur+Caus' => 'rayachi' ,
	'+Prog' => 'chka' ,
	'+Rem' => 'ymana' ,
	'+Rep' => 'pa' ,
	'+Rep+Caus' => 'pachi' ,
	'+Rep+Rflx' => 'paku' ,
	'+Rep+Rzpr+Rflx' => 'panaku' ,
	'+Rflx' => 'ku' ,
	'+Rflx+Caus' => 'kachi' ,
	'+Rflx+Iprs' => 'kapu' ,
	'+Rptn' => 'rqu' ,
	'+Rptn+Caus' => 'rqachi' ,
	'+Rptn+Iprs' => 'rqapu' ,
	'+Rptn+Rflx' => 'rqaku' ,
	'+Rzpr' => 'na' ,
	'+Rzpr+Caus' => 'nachi' ,
	'+Rzpr+Rflx' => 'naku' 
);

my %mapTags2FormsConj = (
	'+SS' => 'spa',
	'+SS+Top' => 'spaqa',
	'+SS+Add' => 'spapas',
	'+DirE' => 'm__',
	'+IndE' => 's__',
	'+Acc' => 'ta',
	'+Abl+Top' => 'mantaqa',
	'+Abl+Add' => 'mantapas',
	'+2.Sg.Subj.Imp+Neg' => 'ychu',
	'++Intrup' => 'ykacha',
	'+Acc' => 'ta',
	'+Instr+Add' => 'wanpas',
	'+Sim+Top' => 'hinaqa',
	'+Lim+Abl' => 'llamanta',
	'+Lim+Loc' => 'llapi',
	'+Abtmp' => 'pacha',
	'+3.Sg.Poss+Top' => '#nqa',
	
);

my %mapTagsFromDix2TagsFromXfst = (
	'++Lim' => '+Lim_Aff',
	'++Intr' => '+Con_Intr',
	'++Dat' => '+Dat_Ill',
	'++Cis' => '+Cis_Trs',
	'++Instr' => '+Con_Inst',
	'++Neg' => '+Intr_Neg',
	'++Rflx' => '+Rflx_Int',
	'++Iprs' => '+Rgr_Iprs',
	'++Lim+Intr' => '+Lim_Aff+Con_Intr',
	'++Instr+Add' => '+Con_Inst+Add'
);

my %eslex = ();

my @nounentries = $dom->findnodes('descendant::section[@id="nouns" or @id="months" or @id="kinship_terms" or @id="animals_gender" or @id="gender_sensitive_roots"]/e');

foreach my $e (@nounentries){
	my ($l) = $e->findnodes('child::p/l[1]');
	#print $l->toString()."\n";
	my $eslem = $l->textContent;
	
	my ($r) = $e->findnodes('child::p/r[1]');
	my ($quMainLem) = ($r->toString() =~ /r>(.+?)</);
	my ($s_pos) = ($r->toString() =~ /s_pos\"\/>(.+?)</);
	my ($preform) = ($r->toString() =~ /preform\"\/>\#(.+?)</); 
	my ($add_mi) = ($r->toString() =~ /add_mi\"\/>(.+?)</); 
	
	#print STDERR "es lem: $eslem, quz: $quMainLem, pre: $preform, add: $add_mi, s_pos: $s_pos\n";
	if($add_mi ne ''){
		my $form = $mapTags2FormsNouns{$add_mi};
		if($quMainLem =~ /[^aeiouá]$/){
			$form =~ s/#/ni/;
			$form =~ s/_PA/pa/;
		}
		else{
			$form =~ s/#//;
			$form =~ s/_PA/p/;
		}
		$quMainLem .= $form;
		#print "lem: $quMainLem: ".$add_mi."\n";
	}
	
	if($s_pos ne 'adj'){
		if(exists($eslex{'noun'}{$eslem})){
			push(@{$eslex{'noun'}{$eslem}}, $quMainLem."#$preform");
		}
		else{
			$eslex{'noun'}{$eslem} = [$quMainLem."#$preform"];
		}
		
	}
	else{
		if(exists($eslex{'adjective'}{$eslem})){
			push(@{$eslex{'adjective'}{$eslem}}, $quMainLem."#$preform");
		}
		else{
			$eslex{'adjective'}{$eslem} = [$quMainLem."#$preform"];
		}
	}
	
}

my @verbentries = $dom->findnodes('descendant::section[@id="verbs" or id="Verb-aux"]/e');
foreach my $e (@verbentries){
	my ($l) = $e->findnodes('child::p/l[1]');
	my $eslem = $l->textContent;
	
	my ($r) = $e->findnodes('child::p/r[1]');
	my ($quMainLem) = ($r->toString() =~ /r>(.+?)</);
	my ($preform) = ($r->toString() =~ /preform\"\/>\#(.+?)</); 
	my ($add_mi) = ($r->toString() =~ /add_mi\"\/>(.+?)</); 
	my $quMainLem2 = ''; # needed for verbs with ykacha/kacha
	
	if($add_mi ne ''){
		my $form = $mapTags2FormsVerbs{$add_mi};
		if($form =~ /^#/){
			# use both kacha and ykacha
			my $form2 =~ s/#/y/;
			$form =~ s/#//;
			$quMainLem2 = $quMainLem.$form2;
		}
		
		
		$quMainLem .= $form;

		#print "$add_mi\n";
	}
	if(exists($eslex{'verb'}{$eslem})){
			push(@{$eslex{'verb'}{$eslem}}, $quMainLem."#$preform");
	}else{
		$eslex{'verb'}{$eslem} = [$quMainLem."#$preform"];
	}
	
	if($quMainLem2 ne ''){
		if(exists($eslex{'verb'}{$eslem})){
			push(@{$eslex{'verb'}{$eslem}}, $quMainLem2."#$preform");
		}else{
			$eslex{'verb'}{$eslem} = [$quMainLem2."#$preform"];
		}
	}
}

my @numberentries = $dom->findnodes('descendant::section[@id="numbers" or @id="ordinals"]/e');
foreach my $e (@numberentries){
	my ($l) = $e->findnodes('child::p/l[1]');
	my $eslem = $l->textContent;
	
	my ($r) = $e->findnodes('child::p/r[1]');
	my ($quMainLem) = ($r->toString() =~ /r>(.+?)</);
	my ($preform) = ($r->toString() =~ /preform\"\/>\#(.+?)</); 
	
	
	if(exists($eslex{'number'}{$eslem})){
			push(@{$eslex{'number'}{$eslem}}, $quMainLem."#$preform");
	}else{
		$eslex{'number'}{$eslem} = [$quMainLem."#$preform"];
	}
	
}

my @interjectionsentries = $dom->findnodes('descendant::section[@id="interjections"]/e');
foreach my $e (@interjectionsentries){
	my ($l) = $e->findnodes('child::p/l[1]');
	my $eslem = $l->textContent;
	
	my ($r) = $e->findnodes('child::p/r[1]');
	my ($quMainLem) = ($r->toString() =~ /r>(.+?)</);
	
	
	if(exists($eslex{'interjection'}{$eslem})){
			push(@{$eslex{'interjection'}{$eslem}}, $quMainLem);
	}else{
		$eslex{'interjection'}{$eslem} = [$quMainLem];
	}
	
}


# pronouns, note: NOT LEMMA, wordforms!:
$eslex{'prspronoun'}{'conmigo'}=['ñuqawan'];
$eslex{'prspronoun'}{'consigo'}=['paywan'];
$eslex{'prspronoun'}{'contigo'}=['qamwan'];
$eslex{'prspronoun'}{'ella'}=['pay'];
$eslex{'prspronoun'}{'él'}=['pay'];
$eslex{'prspronoun'}{'ello'}=['chay'];
$eslex{'prspronoun'}{'ellas'}=['paykuna'];
$eslex{'prspronoun'}{'ellos'}=['paykuna'];
$eslex{'prspronoun'}{'la'}=['payta', 'chayta'];
$eslex{'prspronoun'}{'las'}=['paykunata', 'chaykunata'];
$eslex{'prspronoun'}{'lo'}=['payta', 'chayta'];
$eslex{'prspronoun'}{'los'}=['paykunata', 'chaykunata'];
$eslex{'prspronoun'}{'le'}=['payman', 'payta', 'chayman', 'chayta'];
$eslex{'prspronoun'}{'les'}=['paykunaman', 'paykunata', 'chaykunaman', 'chaykunata'];
$eslex{'prspronoun'}{'me'}=['-wa', 'ñuqata', 'ñuqaman'];
$eslex{'prspronoun'}{'mí'}=['-wa',  'ñuqa']; #only ñuqa -> a mí, de mí -> preposition aligned to suffixes
$eslex{'prspronoun'}{'nos'}=['-wa', 'ñuqayku', 'ñuqanchik'];
$eslex{'prspronoun'}{'nosotros'}=['ñuqayku', 'ñuqanchik'];
$eslex{'prspronoun'}{'nosotras'}=['ñuqayku', 'ñuqanchik'];
$eslex{'prspronoun'}{'os'}=['-su', 'qamkuna'];
$eslex{'prspronoun'}{'se'}=['-ku'];
$eslex{'prspronoun'}{'sí'}=['-ku'];
$eslex{'prspronoun'}{'te'}=['-su', 'qamta', 'qamman'];
$eslex{'prspronoun'}{'ti'}=['-su', 'qam'];
$eslex{'prspronoun'}{'tú'}=['qam'];
$eslex{'prspronoun'}{'usted'}=['qam'];
$eslex{'prspronoun'}{'ustedes'}=['qamkuna'];
$eslex{'prspronoun'}{'vos'}=['-su', 'qamkuna'];
$eslex{'prspronoun'}{'vosotras'}=['qamkuna'];  
$eslex{'prspronoun'}{'vosotros'}=['qamkuna'];
$eslex{'prspronoun'}{'yo'}=['ñuqa'];                                                                                                                                                                                         
                                                                                                                                                                                                     

my @otherpronounsentries = $dom->findnodes('descendant::section[@id="pronouns"]/e');
foreach my $e (@otherpronounsentries){
	my ($l) = $e->findnodes('child::p/l[1]');
	my $eslem = $l->textContent;
	
	my ($r) = $e->findnodes('child::p/r[1]');
	my ($quMainLem) = ($r->toString() =~ /r>(.+?)</);
	my ($add_mi) = ($r->toString() =~ /add_mi\"\/>(.+?)</);
	my ($preform) = ($r->toString() =~ /preform\"\/>\#(.+?)</);
	
	#print STDERR "es lem: $eslem, quz: $quMainLem, pre: $preform, add: $add_mi, s_pos: $s_pos\n";
	if($add_mi ne ''){
		my $form = $mapTags2FormsNouns{$add_mi};
		if($quMainLem =~ /[^aeiouá]$/){
			$form =~ s/#/ni/;
			$form =~ s/_PA/pa/;
		}
		else{
			$form =~ s/#//;
			$form =~ s/_PA/p/;
		}
		$quMainLem .= $form;
		#print "lem: $quMainLem: ".$add_mi."\n";
	}
	if(exists($eslex{'otherpronoun'}{$eslem})){
			push(@{$eslex{'otherpronoun'}{$eslem}}, $quMainLem."#$preform");
		}
		else{
			$eslex{'otherpronoun'}{$eslem} = [$quMainLem."#$preform"];
		}
		
	
}

my @conjunctionsentries = $dom->findnodes('descendant::section[@id="conjunctions"]/e');
foreach my $e (@conjunctionsentries){
	my ($l) = $e->findnodes('child::p/l[1]');
	my $eslem = $l->textContent;
	
	my ($r) = $e->findnodes('child::p/r[1]');
	my ($quMainLem) = ($r->toString() =~ /r>(.+?)</);
	my ($mi) = ($r->toString() =~ /mi\"\/>(.+?)</);
	
	#print STDERR "es lem: $eslem, quz: $quMainLem, pre: $preform, add: $add_mi, s_pos: $s_pos\n";
	if($mi ne ''  and $mi !~ /^\+\+/ ){
		my $form = $mapTags2FormsNouns{$mi};
		if($form eq ''){$form = $mapTags2FormsConj{$mi}; }
		if($quMainLem =~ /[^aeiouá]$/){
			$form =~ s/#/ni/;
			$form =~ s/_PA/pa/;
			# -mi/-si
			$form =~ s/__/i/;
		}
		else{
			$form =~ s/#//;
			$form =~ s/_PA/p/;
			# -mi/-si
			$form =~ s/__//;
		}
		$quMainLem .= $form;
		#print "lem: $quMainLem: ".$add_mi."\n";
	}
	# if translation is a suffix
	elsif($mi =~ /^\+\+/ or $quMainLem =~ /^\+/){
		my $xfst_mi = $mapTagsFromDix2TagsFromXfst{$mi};
		$quMainLem = ($xfst_mi)	? $xfst_mi:	$mi;
	}
	if(exists($eslex{'conjunction'}{$eslem})){
			push(@{$eslex{'conjunction'}{$eslem}}, $quMainLem);
		}
		else{
			$eslex{'conjunction'}{$eslem} = [$quMainLem];
		}
}

# possessive determiners:
$eslex{'posspronoun'}{'mi'}=[ '-y', '-niy', 'ñuqap'];
$eslex{'posspronoun'}{'mío'}=[ '-y', '-niy', 'ñuqap'];
$eslex{'posspronoun'}{'tu'}=['-yki', '-niyki', 'qampa'];
$eslex{'posspronoun'}{'tuyo'}=['-yki', '-niyki', 'qampa'];
$eslex{'posspronoun'}{'su'}=['-n', '-nin', 'paypa'];
$eslex{'posspronoun'}{'suyo'}=['-n', '-nin', 'paypa'];
$eslex{'posspronoun'}{'nuestro'}=['-yku', '-niyku', '-nchik', '-ninchik', 'ñuqaykup', 'ñuqanchikpa'];
$eslex{'posspronoun'}{'vuestro'}=['-ykichik', '-niykichik', 'qamkunapa'];


my @determinerentries = $dom->findnodes('descendant::section[@id="determiners"]/e');
foreach my $e (@determinerentries){
	my ($l) = $e->findnodes('child::p/l[1]');
	my $eslem = $l->textContent;
	
	my ($r) = $e->findnodes('child::p/r[1]');
	my ($quMainLem) = ($r->toString() =~ /r>(.+?)</);
	my ($preform) = ($r->toString() =~ /preform\"\/>\#(.+?)</); 
	my ($add_mi) = ($r->toString() =~ /add_mi\"\/>(.+?)</); 
	
	#print STDERR "es lem: $eslem, quz: $quMainLem, pre: $preform, add: $add_mi, s_pos: $s_pos\n";
	if($add_mi ne '' ){
		my $form = $mapTags2FormsNouns{$add_mi};
		if($quMainLem =~ /[^aeiouá]$/){
			$form =~ s/#/ni/;
			$form =~ s/_PA/pa/;
		}
		else{
			$form =~ s/#//;
			$form =~ s/_PA/p/;
		}
		$quMainLem .= $form;
		#print "lem: $quMainLem: ".$add_mi."\n";
	}
	if(exists($eslex{'determiner'}{$eslem})){
		push(@{$eslex{'determiner'}{$eslem}}, $quMainLem."#$preform");
	}
	else{
		$eslex{'determiner'}{$eslem} = [$quMainLem."#$preform"];
	}
		
}

my @adverbssentries = $dom->findnodes('descendant::section[@id="adverbs"]/e');
foreach my $e (@adverbssentries){
	my ($l) = $e->findnodes('child::p/l[1]');
	my $eslem = $l->textContent;
	
	my ($r) = $e->findnodes('child::p/r[1]');
	my ($quMainLem) = ($r->toString() =~ /r>(.+?)</);
	my ($preform) = ($r->toString() =~ /preform\"\/>\#(.+?)</);
	my ($mi) = ($r->toString() =~ /mi\"\/>(.+?)</);
	
	#print STDERR "es lem: $eslem, quz: $quMainLem, pre: $preform, add: $add_mi, s_pos: $s_pos\n";
	my $form;
	if($mi ne '' and $mi !~ /^\+\+/){
		$form = $mapTags2FormsNouns{$mi};
		if($form eq ''){$form = $mapTags2FormsConj{$mi}; }
		if($quMainLem =~ /[^aeiouá]$/){
			$form =~ s/#/ni/;
			$form =~ s/_PA/pa/;
			# -mi/-si
			$form =~ s/__/i/;
		}
		else{
			$form =~ s/#//;
			$form =~ s/_PA/p/;
			# -mi/-si
			$form =~ s/__//;
		}
		$quMainLem .= $form;
		#print "lem: $quMainLem: ".$add_mi."\n";
	}
	# if translation is a suffix
	elsif($mi =~ /^\+\+/ or $quMainLem =~ /^\+/){
		my $xfst_mi = $mapTagsFromDix2TagsFromXfst{$mi};
		$quMainLem = ($xfst_mi)	? $xfst_mi:	$mi;
	}
	if(exists($eslex{'adverb'}{$eslem})){
			push(@{$eslex{'adverb'}{$eslem}}, $quMainLem."#$preform");
		}
		else{
			$eslex{'adverb'}{$eslem} = [$quMainLem."#$preform"];
		}
		
	
}


# prepositions: -> '-': suffixes, else words, but match at beginning, might have additionals suffixes!
$eslex{'preposition'}{'a'}=[ '-ta', '-man'];
$eslex{'preposition'}{'a_causa_de'}=[ '-rayku'];
$eslex{'preposition'}{'acerca_de'}=[ '-qa'];
$eslex{'preposition'}{'a_comienzo_de'}=[ 'qallariyninpi'];
$eslex{'preposition'}{'a_comienzos_de'}=[ 'qallariyninpi'];
$eslex{'preposition'}{'a_consecuencia_de'}=[ '-rayku'];
$eslex{'preposition'}{'a_espaldas_de'}=[ 'wasanpi'];
$eslex{'preposition'}{'a_final_de'}=[ 'tukuyninpi'];
$eslex{'preposition'}{'a_finales_de'}=[ 'tukuyninpi'];
$eslex{'preposition'}{'a_fin_de'}=[ '-paq'];
$eslex{'preposition'}{'afuera_de'}=[ 'hawa', 'hawanpi'];
$eslex{'preposition'}{'al_borde_de'}=[ 'patanpi', 'pata'];
$eslex{'preposition'}{'al_centro_de'}=[ 'chawpinman'];
$eslex{'preposition'}{'al_igual_que'}=[ 'hina'];
$eslex{'preposition'}{'al_derredor_de'}=[ 'muyu'];
$eslex{'preposition'}{'alrededor_de'}=[ 'muyu'];
$eslex{'preposition'}{'al_inicio_de'}=[ 'qallariyninpi'];
$eslex{'preposition'}{'al_interior_de'}=[ 'ukhunman'];
$eslex{'preposition'}{'al_lado_de'}=[ 'kuska', 'kinraynin'];
$eslex{'preposition'}{'al_margen_de'}=[ 'patanpi', 'pata'];
$eslex{'preposition'}{'al_modo_de'}=[ 'hina'];
$eslex{'preposition'}{'a_modo_de'}=[ 'hina'];
$eslex{'preposition'}{'al_objeto_de'}=[ '-paq'];
$eslex{'preposition'}{'a_la_derecha_de'}=[ 'paña'];
$eslex{'preposition'}{'a_la_izquierda_de'}=[ "lluq'i"];
$eslex{'preposition'}{'a_la_manera_de'}=[ 'hina'];
$eslex{'preposition'}{'a_manera_de'}=[ 'hina'];
$eslex{'preposition'}{'a_partir_de'}=[ '-manta'];
$eslex{'preposition'}{'a_principios_de'}=[ 'qallariyninpi'];
$eslex{'preposition'}{'ante'}=[ "ñawk'in"];
$eslex{'preposition'}{'antes_de'}=[ 'manaraq'];
$eslex{'preposition'}{'a_pesar_de'}=[ 'hinata'];
$eslex{'preposition'}{'arriba_de'}=[ 'hanaq', 'hawa'];
$eslex{'preposition'}{'bajo'}=[ 'uran', 'uraynin'];
$eslex{'preposition'}{'cerca_de'}=[ 'sichpa'];
$eslex{'preposition'}{'como'}=[ 'hina'];
$eslex{'preposition'}{'con'}=[ '-wan'];
$eslex{'preposition'}{'con_fin_de'}=[ '-paq'];
$eslex{'preposition'}{'con_el_fin_de'}=[ '-paq'];
$eslex{'preposition'}{'con_objeto_de'}=[ '-paq'];
$eslex{'preposition'}{'con_el_objetivo_de'}=[ '-paq'];
$eslex{'preposition'}{'con_lo_que_respecta_a'}=[ '-qa'];
$eslex{'preposition'}{'de'}=[ '-pa', '-p', '-manta'];
$eslex{'preposition'}{'de_al_lado_de'}=[ 'kinraynin'];
$eslex{'preposition'}{'debajo_de'}=[ 'uran', 'uraynin'];
$eslex{'preposition'}{'delante_de'}=[ 'ñawpa'];
$eslex{'preposition'}{'dentro_de'}=[ 'ukhu'];
$eslex{'preposition'}{'detrás_de'}=[ 'qhipa'];
$eslex{'preposition'}{'desde'}=[ '-manta', '-pacha'];
$eslex{'preposition'}{'después_de'}=[ 'qhipa'];
$eslex{'preposition'}{'desque'}=[ '-manta', '-pacha'];
$eslex{'preposition'}{'en'}=[ '-pi', '-man'];
$eslex{'preposition'}{'en_cercanías_de'}=[ 'sichpa'];
$eslex{'preposition'}{'en_compañía_de'}=[ 'kuska'];
$eslex{'preposition'}{'en_derredor_de'}=[ 'muyu'];
$eslex{'preposition'}{'en_el_centro_de'}=[ 'chawpinpi', 'chawpi'];
$eslex{'preposition'}{'en_el_entorno_de'}=[ 'muyu'];
$eslex{'preposition'}{'en_el_interior_de'}=[ 'ukhunpi', 'ukhu'];
$eslex{'preposition'}{'en_el_otro_lado_de'}=[ 'kinrayninpi', 'huklawpi'];
$eslex{'preposition'}{'en_las_proximidades_de'}=[ 'sichpa'];
$eslex{'preposition'}{'en_la_temporada_de'}=[ 'pachapi'];
$eslex{'preposition'}{'en_mitad_de'}=[ 'chawpi'];
$eslex{'preposition'}{'en_tiempo_de'}=[ 'pachapi'];
$eslex{'preposition'}{'encima'}=[ 'hawa', 'hana'];
$eslex{'preposition'}{'encima_de'}=[ 'hawa', 'hana'];
$eslex{'preposition'}{'en_cuanto_a'}=[ '-qa'];
$eslex{'preposition'}{'en_medio_de'}=[ 'chawpi'];
$eslex{'preposition'}{'entre'}=[ 'chawpi', 'ukhu', '-pura'];
$eslex{'preposition'}{'frente_a'}=[ 'chimpa'];
$eslex{'preposition'}{'al_frente_de'}=[ 'chimpa'];
$eslex{'preposition'}{'enfrente_de'}=[ 'chimpa'];
$eslex{'preposition'}{'en_frente_de'}=[ 'chimpa'];
$eslex{'preposition'}{'fuera_de'}=[ 'hawa'];
$eslex{'preposition'}{'hacia'}=[ '-man'];
$eslex{'preposition'}{'hasta'}=[ '-kama'];
$eslex{'preposition'}{'lejos_de'}=[ 'karu'];
$eslex{'preposition'}{'junto_a'}=[ 'qayllu', 'kuska'];
$eslex{'preposition'}{'luego_de'}=[ 'qhipa'];
$eslex{'preposition'}{'mediante'}=[ '-wan'];
$eslex{'preposition'}{'para'}=[ '-paq'];
$eslex{'preposition'}{'perteneciente_a'}=[ '-pa', '-p'];
$eslex{'preposition'}{'por'}=[ '-rayku', '-n-ta', '-wan', '-pi'];
$eslex{'preposition'}{'por_el_motivo_de'}=[ '-rayku'];
$eslex{'preposition'}{'por_motivo_de'}=[ '-rayku'];
$eslex{'preposition'}{'por_causa_de'}=[ '-rayku'];
$eslex{'preposition'}{'por_debajo_de'}=[ 'uran'];
$eslex{'preposition'}{'por_deleante_de'}=[ 'ñawpan'];
$eslex{'preposition'}{'por_detrás_de'}=[ 'qhipa'];
$eslex{'preposition'}{'por_encima_de'}=[ 'hana', 'hawa'];
$eslex{'preposition'}{'por_el_centro_de'}=[ 'chawpi'];
$eslex{'preposition'}{'por_al_lado_de'}=[ 'kinray'];
$eslex{'preposition'}{'por_este_lado_de'}=[ 'kinray'];
$eslex{'preposition'}{'por_el_otro_lado_de'}=[ 'kinray'];
$eslex{'preposition'}{'según'}=[ 'hina'];
$eslex{'preposition'}{'sin'}=[ 'mana', '-nnaq'];
$eslex{'preposition'}{'sobre'}=[ 'hawa', 'hana', '-manta'];
$eslex{'preposition'}{'tras'}=[ 'qhipa'];


##print hash:
#foreach my $section (keys %eslex){
#	print "sec: $section\n";
#	my $printed =0;
#	foreach my $lem (keys $eslex{$section}){
#		foreach my $quz (@{$eslex{$section}{$lem}} ){
#			if($quz =~ /^\+/){
#				print $lem."\t";
#				print "$quz, ";
#				$printed =1;
#			}
#			else{
#				$printed=0;
#			}
#			if($printed){print "\n";}
#		}
#	}
#}


#print hash:
foreach my $section (keys %eslex){
	print "sec: $section\n";
	if($section eq 'adverb'){
		foreach my $lem (keys %{$eslex{$section}}){
			print $lem."\t";
			foreach my $quz (@{$eslex{$section}{$lem}} ){
				print "$quz, ";
			}
			print "\n";
		}
	}
}

store \%eslex, 'lexicon-es-qu';