#!/usr/bin/perl

use utf8;                  # Source code is UTF-8
#use open ':utf8';

#binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';
use strict;
use XML::LibXML;
 use Error qw(:try);
 
 use Storable;

#read xml from STDIN
#my $parser = XML::LibXML->new({encoding => 'utf-8'});
my $dom    = XML::LibXML->load_xml( IO => *STDIN);
$dom->documentElement()->setAttribute( 'xmlns' , '' );



my @sentences = $dom->getElementsByTagName('s');



### features instead of lemmas
# Verb types
#lss="A11.transitive-causative" 			(old_type=transitive oder causative, args: subj,obj (pp) )
#lss="A12.diransitive-causative-state" 		(old_type=transitive, args: subj,obj, pp)
#lss="A13.ditransitive-causative-instrumental"	(old_type=transitive, args: subj,obj, pp)
#
#lss="A21.transitive-agentive-patient"		(old_type=transitive, args: subj,obj (pp))
#lss="A22.transitive-agentive-theme"		(old_type=transitive, args: subj, pp) (eg. entenderse con)
#lss="A23.transitive-agentive-extension"		(old_type=transitive, object_extension, impersonal, args: subj, obj, pp oder obj pp) 
#----------------------------------------
#ditransitive:
#
#lss="A31.ditransitive-patient-locative"		(old_type=ditransitive, benefactive, oblique_subject: args: subj,obj, (pp) (loc))
#lss="A32.ditransitive-patient-benefactive"
#lss="A33.ditransitive-theme-locative"
#lss="A34.ditransitive-patient-theme"
#lss="A35.ditransitive-theme-cotheme"
#----------------------------------------
#intransitive:
#
#lss="B11.unaccusative-motion"
#lss="B12.unaccusative-passive-ditransitive"
#lss="B21.unaccusative-state"
#lss="B22.unaccusative-passive-transitive"
#lss="B23.unaccusative-cotheme"
#lss="B23.unaccusative-theme-cotheme"
#
#lss="C11.state-existential"
#lss="C21.state-attributive"
#lss="C31.state-scalar"
#lss="C41.state-benefective"
#lss="C42.state-experiencer"
#
#lss="D11.inergative-agentive"
#lss="D21.inergative-experiencer"
#lss="D31.inergative-source"

# thematic roles (subject) Ancora, semantic labels:
# 'agentive':
# agt (agent): 					ani, hum, pot, soc
# cau (causer):   				ani, hum, pot, soc
# exp (experiencer):			ani, hum, soc
# src (source):					ani, hum, (cnc)		('chillar, destellar, escupir, relucir' -> src=person/thing)
# ins (instrument):				cnc, mat, pot
# loc (locative (??), abstract inanimate):	abs, loc, cnc, sem
#
# 'not agentive':
# pat (patient,passives):			all, except with C11: agentive
# tem (theme, unaccusat./anticaus.):	all
# all noun sem classes:
#	abs
#	ani
#	bpart
#	cnc
#	hum
#	loc
#	mat
#	mea
#	plant
#	pot
#	sem
#	soc
#	tmp
#	unit

		# for nouns
		# 0-13
		print STDOUT "abs,ani,bpart,cnc,hum,nloc,mat,mea,plant,pot,sem,soc,tmp,unit,";
		# 14-39
		print STDOUT "nSem03,nSem04,nSem05,nSem06,nSem07,nSem08,nSem09,nSem10,nSem11,nSem12,nSem13,nSem14,nSem15,nSem16,nSem17,nSem18,nSem19,nSem20,nSem21,nSem22,nSem23,nSem24,nSem25,nSem26,nSem27,nSem28,";
	
		
 		# print verb senses (wordnet)
 		# 40-54
        print STDOUT "Sem29,Sem30,Sem31,Sem32,Sem33,Sem34,Sem35,Sem36,Sem37,Sem38,Sem39,Sem40,Sem41,Sem42,Sem43,";
		
		# verb frames:
		# 55-78
		print STDOUT "A11,A12,A13,A21,A22,A23,A31,A32,A33,A34,A35,B11,B12,B21,B22,B23,C11,C21,C31,C41,C42,D11,D21,D31,";
		
		# verb: thematic roles of subject
		# 79-86
		print STDOUT "agt,cau,exp,ins,vloc,pat,src,tem,";
		
		# morphs
		# 87-126
		print STDOUT "NP,NRoot,NRootCMP,NRootES,NRootNUM,PrnDem,PrnInterr,PrnPers,VRoot,VRootES,+Aff,+Ass,+Aug,+Autotrs,+Cis_Trs,+Cont,+Des,+Dim,+Dir,+Fact,+Inch,+Int,+Intrup,+Multi,+NumOrd,+Perdur,+Pl,+Rep,+Res,+Rgr_Iprs,+Rptn,+Rzpr,+Sml,+Stat_Multi,+Trs,+Vdim,";
		
		# last features
		print "occursInPrevSentence,isPronoun,isTopic";
		
		print "\n";
		
# ancora verb frames
my %verbLexWithFrames   = %{ retrieve("VerbLex") };
# Spanish Resource Grammar lexicon
my %nounLex   = %{ retrieve("NounLex") };
# Spanish wordnet
my %verbLemClasses =  %{ retrieve("verbLemClasses") };
my %nounLemClasses =  %{ retrieve("nounLemClasses") };



my %mapNsem1ToVec = ( 'abs' => 0, 'ani' => 1, 'bpart' => 2, 'cnc' => 3,'hum' => 4,'nloc' => 5,'mat' => 6,'mea' => 7,'plant' => 8,'pot' => 9,'sem' => 10, 
'soc' => 11,'tmp' => 12,'unit' => 13);

my %mapNsem2ToVec = ( 'nSem03' => 14, 'nSem04' => 15, 'nSem05' => 16, 'nSem06' => 17, 'nSem07' => 18, 'nSem08' => 19, 'nSem09' => 20, 'nSem10' => 21, 'nSem11' => 22, 
'nSem12' => 23, 'nSem13' => 24, 'nSem14' => 25, 'nSem15' => 26, 'nSem16' => 27, 'nSem17' => 28, 'nSem18' => 29, 'nSem19' => 30, 'nSem20' => 31, 'nSem21' => 32, 
'nSem22' => 33, 'nSem23' => 34, 'nSem24' => 35, 'nSem25' => 36, 'nSem26' => 37, 'nSem27' => 38, 'nSem28' => 39
);

my %mapVsemToVec = ( 'Sem29' => 40, 'Sem30' => 41, 'Sem31' => 42, 'Sem32' => 43, 'Sem33' => 44, 'Sem34' => 45, 'Sem35' => 46, 'Sem36' => 47, 'Sem37' => 48, 'Sem38' => 49, 
'Sem39' => 50, 'Sem40' => 51, 'Sem41' => 52, 'Sem42' => 53, 'Sem43' => 54
);
my %mapFramesToVec = (
	'A11'	=> 55, 'A12'	=> 56, 'A13'	=> 57, 'A21'	=> 58, 'A22'	=> 59, 'A23'	=> 60, 'A31'	=> 61, 'A32'	=> 62, 'A33'	=> 63, 'A34'	=> 64, 'A35'	=> 65,
	'B11'	=> 66, 'B12'	=> 67, 'B21'	=> 68, 'B22'	=> 69, 'B23'	=> 70,
	'C11'	=> 71, 'C21'	=> 72, 'C31'	=> 73, 'C41'	=> 74, 'B42'	=> 75,
	'D11'	=> 76, 'D21'	=> 77, 'D31'	=> 78
);

my %mapRolesToVec = ( 'agt' => 79, 'cau' => 80 ,'exp' => 81 , 'ins' => 82 , 'vloc' => 83 , 'pat' => 84, 'src' => 85, 'tem' =>86 );

my %mapMorphsToVec = ('NP' => 87, 'NRoot' => 88, 'NRootCMP' => 89, 'NRootES' => 90, 'NRootNUM' => 91, 'PrnDem' => 92, 'PrnInterr' => 93, 'PrnPers' => 94, 
'VRoot' => 95, 'VRootES' => 96, '+Aff' => 97, '+Ass' => 98, '+Aug' => 99, 
'+Autotrs' => 100, '+Cis_Trs' => 101, '+Cont' => 102, '+Des' => 103, '+Dim' => 104, '+Dir' => 105, '+Fact' => 106, '+Inch' => 107, '+Int' => 108, '+Intrup' => 109, '+Multi' => 110, 
'+NumOrd' => 111, '+Perdur' => 112, '+Pl' => 113, '+Rep' => 114, '+Res' => 115, '+Rgr_Iprs' => 116, '+Rptn' => 117, '+Rzpr' => 118, '+Sml' => 119, '+Stat_Multi' => 120, 
'+Trs' => 121, '+Vdim' =>122 );

my @length; $length[14] = undef;
my $i =40; # values verb (word net) Sem29-Sem43 -> map to values for slots 40-54
my $j=29; 
my %mapSemsToVec =  map { $j++ => $i++; } @length;					
my @vec = map { 0 } 0..122;


for(my $i=0;$i<scalar(@sentences);$i++)
{
	my $sentence = @sentences[$i];
	
	my @subjects = $sentence->findnodes('descendant::terminal[label[text()="sntc"] or label[text()="co"] ]/children/terminal[label[text()="subj"] and not(pos[text()="DUMMY" ]) ] ');
   
    my @sorted_subjs = sort order_sort  @subjects;
   	foreach my $subj (@sorted_subjs){
		
		# for testing:
   		#print "subj ".$subj->getAttribute('id').":\t";
		
   		my $lemma = $subj->findvalue('word');
   		
   		my $translation = $subj->findvalue('translation');
   		my @morphtags = $subj->findnodes('morph/tag');
  		if(scalar(@morphtags)>5){ print STDERR "More than 5 morphtags in word ".$subj->getAttribute('id')."\n...aborting\n"; exit(0);}
  		
  		my @spanish_lems = split(',',$translation);
  		
  		
#  		my %verbLabels = map { $_ => 0; } qw(A11 A12 A13 A21 A22 A23 A31 A32 A33 A34 A35 B11 B12 B21 B22 B23 C11 C21 C31 C41 C42 D11 D21 D31);
#		my %verbClasses = map { $_ => 0; } qw(Sem29 Sem30 Sem31 Sem32 Sem33 Sem34 Sem35 Sem36 Sem37 Sem38 Sem39 Sem40 Sem41 Sem42 Sem43);
#		my %verbSubjRoles = map { $_ => 0; } qw(agt cau exp ins loc pat src tem);
#  		
#  		my %nounSemLabels = map { $_ => 0; } qw(abs ani bpart cnc hum loc mat mea plant pot sem soc tmp unit);
#		my %nounSemClassWN = map { $_ => 0; } qw(nSem03 nSem04 nSem05 nSem06 nSem07 nSem08 nSem09 nSem10 nSem11 nSem12 nSem13 nSem14 nSem15 nSem16 nSem17 nSem18 nSem19 nSem20 nSem21 nSem22 nSem23 nSem24 nSem25 nSem26 nSem27 nSem28);
#  			 
  		
  		#print "sp lems @spanish_lems\n";
  		if(@morphtags[0] =~ /NRoot/)
  		{
  						
  			# take first translation if more than one
  			my $nounlem = @spanish_lems[0];
  			$nounlem =~ s/^=//;
  			#print "noun: $nounlem\n";
  			my $nounSem = $nounLex{$nounlem};
			chomp($nounSem);
			my @nounSems = split('_',$nounSem);
  			foreach my $sem (@nounSems){
				#$nounSemLabels{$sem}= 1;
				@vec[$mapNsem1ToVec{$sem}]=1;
			}
			# print semantic class(es)
			if($nounLemClasses{$nounlem})
			{
				foreach my $class (keys %{$nounLemClasses{$nounlem}})
				{
					#print STDERR "$mainV: $class ".$verbLemClasses{$mainV}{$class}."\n";
					my $nclass = "nSem".$class;
					#$nounSemClassWN{$nclass}= $nounLemClasses{$nounlem}{$class};
					my $value = $nounLemClasses{$nounlem}{$class};
					#print "hieer: $class, $value\n";
					if($value>0){
						@vec[$mapNsem2ToVec{$nclass}]=1;
					}
				}
			}
  		}
  		elsif(@morphtags[0] =~ /VRoot/)
  		{
  			my $verblem = @spanish_lems[0];
  			$verblem =~ s/=//;
  			#print "verb: $verblem\n";
  			#get semantic class main verb
			if($verbLemClasses{$verblem})
			{
					foreach my $class (keys %{$verbLemClasses{$verblem}})
					{
						#print STDERR "$verblem: $class position:".$mapSemsToVec{$class}."\n";
						@vec[$mapSemsToVec{$class}]=1;
					}
			}
			# get frames verb
			my $mainFrames = $verbLexWithFrames{$verblem};
			if($mainFrames)
			{
					#print "main: $main ";
					foreach my $f (@$mainFrames){
						my ($label) = ($f =~ m/^(.\d\d)/);
						my ($role) = ($f =~ m/##(.+)/);
						# some errors in Ancora dix! skip those... (e.g. 'dar' has a frame 'a3'?!)
						unless($label eq ''){
							#	print STDERR "$label  $f position: ".$mapFramesToVec{$label}."\n" if $verbose;
								@vec[$mapFramesToVec{$label}]=1;
						}
						unless($role eq''){
								#print STDERR $role."\n";
								# fix erroneous tag
								if($role eq 'caucau'){
										$role = 'cau';
								}
								@vec[$mapRolesToVec{$role}]=1;
								}
					}
			}
  		}
  		# map morph tags to vector
  		foreach my $tag (@morphtags){
  			if($tag =~ /^PrnPers/){
  				$tag = "PrnPers";
  			}
  			@vec[$mapMorphsToVec{$tag}]=1;
  		}

   		
   		foreach my $feature (@vec){
   			print "$feature,";
   		}
   		#print "length: ".scalar(@vec)."\n";
   		
   		
   		my $occursinPrevSentence=0;
   		unless($i==0){
		   		#occurs in previous sentence
		   		my $prevSentence = @sentences[$i-1];
		   		my $xpath = 'descendant::terminal/word[text()="'.$lemma.'"]';
		   		$occursinPrevSentence =  $prevSentence->exists($xpath);
		 }
		 print "$occursinPrevSentence,";
   		
		# is pronoun
		
		my $isPronoun = ($subj->findvalue('morph/tag') =~ /^Prn/) ? 1:0;
		print "$isPronoun,";   		
   		
   		#my $discourse = $subj->findvalue('discourse');
   		my $isTopic = ($subj->findvalue('discourse') eq 'TOPIC') ? 1:0;

   		print "$isTopic\n";
   }

}


# $a,$b -> terminal nodes
sub order_sort {
	my ($order_a) = $a->findvalue('child::order/text()');
	my ($order_b) = $b->findvalue('child::order/text()');
	
	#print "order a: $order_a, order b: $order_b\n";
	
	if($order_a > $order_b){
		return 1;
	}
	elsif($order_b > $order_a){
		return -1;
	}
	return 0;
}

sub setLabel{
	my $node = $_[0];
	my $labeltext = $_[1];
	my $label= @{$node->getChildrenByLocalName('label')}[0];
	$label->removeChildNodes();
	$label->appendText($labeltext);
}


sub setOrder{
	my $node = $_[0];
	my $ordertext = $_[1];
	my $order= @{$node->getChildrenByLocalName('order')}[0];
	$order->removeChildNodes();
	$order->appendText($ordertext);
}

#print "Lemma,morph1,morph2,morph3,morph4,morph5,occursInPrevSentence,isPronoun,isTopic\n";

## with lemmas
#for(my $i=0;$i<scalar(@sentences);$i++)
#{
#	my $sentence = @sentences[$i];
#	
#	my @subjects = $sentence->findnodes('descendant::terminal[label[text()="sntc"] or label[text()="co"] ]/children/terminal[label[text()="subj"] and not(pos[text()="DUMMY" ]) ] ');
#   
#    my @sorted_subjs = sort order_sort  @subjects;
#   	foreach my $subj (@sorted_subjs){
#		
#		# for testing:
#   		#print "subj ".$subj->getAttribute('id').":\t";
#		
#   		my $lemma = $subj->findvalue('word');
#   		# replace ' in quechua words with _ (weka can't deal with apostrophes within words)
#   		$lemma =~ s/'/_/g;
#   		
#   		print lc("$lemma");
#   		my @morphtags = $subj->findnodes('morph/tag');
#  		if(scalar(@morphtags)>5){ print STDERR "More than 5 morphtags in word ".$subj->getAttribute('id')."\n...aborting\n"; exit(0);}
#   		
#   		my $printedTags =0;
#   		foreach my $tag (@morphtags){
#   			print ",".$tag->textContent();
#   			$printedTags++;
#   		}
#   		while($printedTags<5){
#   			print ",-";
#   			$printedTags++;
#   		}
#   		
#   		my $occursinPrevSentence=0;
#   		unless($i==0){
#		   		#occurs in previous sentence
#		   		my $prevSentence = @sentences[$i-1];
#		   		my $xpath = 'descendant::terminal/word[text()="'.$lemma.'"]';
#		   		$occursinPrevSentence =  $prevSentence->exists($xpath);
#		 }
#		 print ",$occursinPrevSentence";
#   		
#		# is pronoun
#		
#		my $isPronoun = ($subj->findvalue('morph/tag') =~ /^Prn/) ? 1:0;
#		print ",$isPronoun";   		
#   		
#   		#my $discourse = $subj->findvalue('discourse');
#   		my $isTopic = ($subj->findvalue('discourse') eq 'TOPIC') ? 1:0;
#
#   		print ",$isTopic\n";
#   }
#   
#}
