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
	'+Dat+Sim' => 'manhina', 
	'+Dat+Term' => 'mankama', 
	'+Def' => 'puni', 
	'+Dim' => 'cha', 
	'+Gen' => '_PA', 
	'++Gen' => '_PA', 
	'+Iclsv' => '#ntin', 
	'+Iclsv+Abl' => '#ntinmanta', 
	'+Instr' => 'wan', 
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
	'+Term' => 'kama'

);

my %mapTags2FormsVerbs = (
	'+Aff' => 'yku' ,
	'+Aff+Caus' => 'ykachi' ,
	'+Aff+Iprs' => 'ykapu' ,
	'+Aff+Rflx' => 'ykaku' ,
	'+Aff+Rzpr+Rflx' => 'ykanaku' ,
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



my %lex = ();

my @nounentries = $dom->findnodes('descendant::section[@id="nouns" or id="months" or id="kinship_terms" or id="animals_gender" or id="gender_sensitive_roots"]/e');

foreach my $e (@nounentries){
	my ($l) = $e->findnodes('child::p/l[1]');
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
	
	unless($s_pos eq 'adj'){
		if(exists($lex{'noun'}{$eslem})){
			push($lex{'noun'}{$eslem}, $quMainLem."#$preform");
		}
		else{
			$lex{'noun'}{$eslem} = [$quMainLem."#$preform"];
		}
		
	}
	
}

my @verbentries = $dom->findnodes('descendant::section[@id="verbs" or id="Verb-aux"]/e');
foreach my $e (@verbentries){
	my ($l) = $e->findnodes('child::p/l[1]');
	my $eslem = $l->textContent;
	
	my ($r) = $e->findnodes('child::p/r[1]');
	my ($quMainLem) = ($r->toString() =~ /r>(.+?)</);
	my ($s_pos) = ($r->toString() =~ /s_pos\"\/>(.+?)</);
	my ($preform) = ($r->toString() =~ /preform\"\/>\#(.+?)</); 
	my ($add_mi) = ($r->toString() =~ /add_mi\"\/>(.+?)</); 
	my $quMainLem2 = ''; # needed for verbs with ykacha/kacha
	
	if($add_mi ne ''){
		my $form = $mapTags2FormsVerbs{$add_mi};
		# use both kacha and ykacha
		my $form2 =~ s/#/y/;
		$form =~ s/#//;
		
		
		$quMainLem .= $form;
		$quMainLem2 = $quMainLem.$form2;
		#print "$add_mi\n";
	}
	if(exists($lex{'verb'}{$eslem})){
			push($lex{'verb'}{$eslem}, $quMainLem."#$preform");
	}else{
		$lex{'verb'}{$eslem} = [$quMainLem."#$preform"];
	}
	
	if($quMainLem2 ne ''){
		if(exists($lex{'verb'}{$eslem})){
			push($lex{'verb'}{$eslem}, $quMainLem2."#$preform");
		}else{
			$lex{'verb'}{$eslem} = [$quMainLem2."#$preform"];
		}
	}
}

#print hash:
#foreach my $section (keys %lex){
#	print "sec: $section\n";
#	foreach my $lem (keys $lex{$section}){
#		print $lem."\t";
#		foreach my $quz (@{$lex{$section}{$lem}} ){
#			print "$quz, ";
#		}
#		print "\n";
#	}
#}

#print hash:
foreach my $section (keys %lex){
	print "sec: $section\n";
	if($section eq 'verb'){
		foreach my $lem (keys $lex{$section}){
			print $lem."\t";
			foreach my $quz (@{$lex{$section}{$lem}} ){
				print "$quz, ";
			}
			print "\n";
		}
	}
}

store \%lex, 'lexicon-es-qu';