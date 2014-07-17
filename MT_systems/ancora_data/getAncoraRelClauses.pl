#!/usr/bin/perl

#BEGIN {push @INC, 'home/clsquoia/google_squoia/MT_systems'}
use utf8;                  # Source code is UTF-8
#use open ':utf8';
use Storable; # to retrieve hash from disk
#binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';
use strict;
use XML::LibXML;
use File::Spec::Functions qw(rel2abs);
use File::Basename;
my $path = dirname(rel2abs($0));
#require "$path/../util.pl";
#import squoia::util;


my %mapMorphsToClasses = (
	'rel:agentive'			=> 1,
	'rel:not.agentive'			=> 0,
);

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

		# head noun lemma and semantic classes
		print STDOUT "headLem,abs,ani,bpart,cnc,hum,nloc,mat,mea,plant,pot,sem,soc,tmp,unit,";
		print STDOUT "nSem03,nSem04,nSem05,nSem06,nSem07,nSem08,nSem09,nSem10,nSem11,nSem12,nSem13,nSem14,nSem15,nSem16,nSem17,nSem18,nSem19,nSem20,nSem21,nSem22,nSem23,nSem24,nSem25,nSem26,nSem27,nSem28,";
		
		# head noun: pos
		# type of proper noun not given in Ancora!
		#print STDOUT "Num,cat,properType";
		print STDOUT "nNum,nCat,";
		
 		# print verb lemma and senses (wordnet)
        print STDOUT "Lem,Sem29,Sem30,Sem31,Sem32,Sem33,Sem34,Sem35,Sem36,Sem37,Sem38,Sem39,Sem40,Sem41,Sem42,Sem43,";
		# verb frames:
		print STDOUT "A11,A12,A13,A21,A22,A23,A31,A32,A33,A34,A35,B11,B12,B21,B22,B23,C11,C21,C31,C41,C42,D11,D21,D31,";
		
		# verb: thematic roles of subject
		print STDOUT "agt,cau,exp,ins,vloc,pat,src,tem,";
		
		# verb morphology
		#print STDOUT "vTense,vMod,vPers,vNum,hasSE,";
		print STDOUT "vTense,vMod,vNum,hasSE,hasCreg,hasCC,hasCI,hasCag,hasCpred,";
		
		# last row: class
		print STDOUT "relpron,agentive\n";;
# ancora ver frames
my %verbLexWithFrames   = %{ retrieve("VerbLex") };
# Spanish Resource Grammar lexicon
my %nounLex   = %{ retrieve("NounLex") };
# Spanish wordnet
my %verbLemClasses =  %{ retrieve("verbLemClasses") };
my %nounLemClasses =  %{ retrieve("nounLemClasses") };

#print STDERR $nounLex{'amor'}."\n";

##read xml from STDIN
my $parser = XML::LibXML->new({encoding => 'utf-8'});
my $dom    = XML::LibXML->load_xml( IO => *STDIN);

my @sentenceList = $dom->getElementsByTagName('SENTENCE');

foreach my $sentence (@sentenceList)
{
	# get all verb chunks and check if they have an overt subject, 
	# if they don't have an overt subject and precede the main clause -> look for subject in preceding sentence
	# if they don't have an overt subject and follow the main clause, and the main clause has an overt subject, this is the subject of the subordinated chunk
	#print STDERR "Looking for verb pairs in sentence:";
	#print STDERR $sentence->getAttribute('ord')."\n";
	
 	
 	# consider linear sequence in sentence; in xml the verb of the main clause comes always first, but in this case the subject of a preceding subordinated clause is probably coreferent with the subject of the preceding clause
 	# all relclauses
 	my @verbChunks = $sentence->findnodes('descendant::CHUNK[( starts-with(@verbform, "rel") or NODE[starts-with(@verbform, "rel")] ) and (not(@HLRC) and not(@IHRC))]');
 	#only guessed rel clauses:
	#my @verbChunks = $sentence->findnodes('descendant::CHUNK[@guessed and (starts-with(@verbform, "rel") or NODE[starts-with(@verbform, "rel")]) ]');

 #	print STDERR scalar(@verbChunks)."\n";
 	
 	foreach my $verbChunk (@verbChunks)
 	{
 	    
 		my $headNoun = &getHeadNoun($verbChunk);
 		print STDERR "verb chunk nbr: ".$verbChunk->getAttribute('ord')." ".$headNoun."\n";
 		my $mainV = &getMainVerb2($verbChunk);
		my ($relpron) = $verbChunk->findnodes('descendant::NODE[starts-with(@mi,"PR")][1]');
		
 		unless($headNoun == -1)
		{
			if($mainV && $relpron)
			{
				if( ($relpron->getAttribute('lem') eq 'que' || $relpron->getAttribute('lem') eq 'quien' ) )
				{
		 			my $headlem = $headNoun->getAttribute('lem');
					my $headSem = $nounLex{$headlem};
					chomp($headSem);
					my @headSems = split('_',$headSem);
					my %headSemLabels = map { $_ => 0; } qw(abs ani bpart cnc hum loc mat mea plant pot sem soc tmp unit);
					
					my %nounSemClassWN = map { $_ => 0; } qw(nSem03 nSem04 nSem05 nSem06 nSem07 nSem08 nSem09 nSem10 nSem11 nSem12 nSem13 nSem14 nSem15 nSem16 nSem17 nSem18 nSem19 nSem20 nSem21 nSem22 nSem23 nSem24 nSem25 nSem26 nSem27 nSem28);
					
					# remove ',' and ' in lemma (in proper names) -> conflicts with csv format
					$headlem =~ s/,|'//g;
					
					# get pos info of head noun
					my $headPos = $headNoun->getAttribute('mi');
					my $headNum = substr($headPos,3,1);
					my $cat = substr($headPos,1,1);
					my $properType = substr($headPos,4,2);
					
					# get pos info of verb
					my $mLem = $mainV->getAttribute('lem');
					my $mainFrames = $verbLexWithFrames{$mLem};
					my $mPos = $mainV->getAttribute('mi');
					# if main verb is not finite: get pos of finte verb
					if($mPos !~ /1|2|3/){
						my $finiteVerb = &getFiniteVerb($verbChunk);
						if($finiteVerb){
							$mPos = $finiteVerb->getAttribute('mi');
						}
					}			
					my $mTense = substr($mPos,3,1);
					my $mMod = substr($mPos,2,1);
					# many subjunctives in Ancora wrongly tagged as imperatives -> change
					if($mMod eq 'M'){$mMod = 'S'};
					my $mPers = substr($mPos,4,1);
					my $mNum = substr($mPos,5,1);
					if($mNum eq 'C'){$mNum = '0';}
					
					if($mNum eq $headNum)
					{
						print STDOUT "$headlem,";
						# print semantic classes of head noun
						foreach my $sem (@headSems){
							$headSemLabels{$sem}= 1;
						}
						
						foreach my $key (sort keys %headSemLabels){
							#print STDOUT "key $key:".$headSemLabels{$key}.",";
							print STDOUT $headSemLabels{$key}.",";
						}
						
						# print semantic class(es)
						if($nounLemClasses{$headlem})
						{
								foreach my $class (keys %{$nounLemClasses{$headlem}}){
								#print STDERR "$mainV: $class ".$verbLemClasses{$mainV}{$class}."\n";
									my $nclass = "nSem".$class;
									$nounSemClassWN{$nclass}= $nounLemClasses{$headlem}{$class};
								}
						}
						foreach my $key ( sort keys %nounSemClassWN) 
						{
							#print STDERR "$key: ".$mainClasses{$key}."\n";
							#print "$mainClasses{$key},";
							if($nounSemClassWN{$key}>0){
											print "1,";
							}
							else{
								print "0,";
							}
						}
						
						# print pos info of head noun
						#print STDOUT "Num:$headNum,cat:$cat,proper:$properType,";
						if($headNum eq 'N' or $headNum eq 'C'){$headNum = '0';}
						print STDOUT "$headNum,$cat,";
			
					
						my %mainLabels = map { $_ => 0; } qw(A11 A12 A13 A21 A22 A23 A31 A32 A33 A34 A35 B11 B12 B21 B22 B23 C11 C21 C31 C41 C42 D11 D21 D31);
						my %mainClasses = map { $_ => 0; } qw(Sem29 Sem30 Sem31 Sem32 Sem33 Sem34 Sem35 Sem36 Sem37 Sem38 Sem39 Sem40 Sem41 Sem42 Sem43);
						my %mainSubjRoles = map { $_ => 0; } qw(agt cau exp ins loc pat src tem);
						
						
							
						print "$mLem,";
						# print semantic class(es)
						if($verbLemClasses{$mLem})
						{
								foreach my $class (keys %{$verbLemClasses{$mLem}}){
								#print STDERR "$mainV: $class ".$verbLemClasses{$mainV}{$class}."\n";
									my $mclass = "Sem".$class;
									$mainClasses{$mclass}= $verbLemClasses{$mLem}{$class};
								}
						}
						foreach my $key ( sort keys %mainClasses) 
						{
							#print STDERR "$key: ".$mainClasses{$key}."\n";
							#print "$mainClasses{$key},";
							if($mainClasses{$key}>0){
											print "1,";
							}
							else{
								print "0,";
							}
						}
						#print main verb
						if($mainFrames){
								#print "main: $main ";
								foreach my $f (@$mainFrames){
									my ($label) = ($f =~ m/^(.\d\d)/);
									my ($role) = ($f =~ m/##(.+)/);
									#print STDERR "$mLem: $f\n";
									# some errors in Ancora dix! skip those... (e.g. 'dar' has a frame 'a3'?!)
									unless($label eq ''){
										#print "$label  $f\n";
					 					$mainLabels{$label}=1;
									}
									unless($role eq''){
										#print STDERR $role."\n";
										# fix erroneous tag
										if($role eq 'caucau'){
											$role = 'cau';
										}
										$mainSubjRoles{$role}=1;
									}
								}
						}
									
						foreach my $key ( sort keys %mainLabels) {
								#print STDERR "$mLem: $key: ".$mainLabels{$key}."\n";
								print "$mainLabels{$key},";
						}
						foreach my $key (sort keys %mainSubjRoles){
							#print STDERR "$mLem: $key ".$mainSubjRoles{$key}."\n";
							print $mainSubjRoles{$key}.",";
						} 
						
						# print pos of verb
						#print "$mPos: tns:$mTense, mod:$mMod, prs:$mPers, num:$mNum";
						#print "$mTense,$mMod,$mPers,$mNum,";
						#without number (always 3)
						print "$mTense,$mMod,$mNum,";
						
						# does this rel. clause have 'se'?
						if($verbChunk->exists('descendant::NODE[@form="se" or @form="Se"]') or $mLem =~ /rse$/){
							print "1,";
						}
						else{
							print "0,";
						}
						# hasCreg,hasCC,hasCI,hasCag,hasCpred"
						my $hasCreg = ($verbChunk->exists('descendant::CHUNK[@si="creg"]')) ? 1 : 0;
						my $hasCC = ($verbChunk->exists('descendant::CHUNK[@si="cc"]')) ? 1 : 0;
						my $hasCI = ($verbChunk->exists('descendant::CHUNK[@si="ci"]')) ? 1 : 0;
						my $hasCag = ($verbChunk->exists('descendant::CHUNK[@si="cag"]')) ? 1 : 0;
						my $hasCpred = ($verbChunk->exists('descendant::CHUNK[@si="cpred"]')) ? 1 : 0;
						
						print "$hasCreg,$hasCC,$hasCI,$hasCag,$hasCpred,";
						
						# print relative pronoun
						if($relpron){
							my $relpronLem = $relpron->getAttribute('lem');
							print STDOUT "$relpronLem,";
						}
						else{
							print "0,";
						}
						
						# print class
						my $form = $mainV->getAttribute('verbform');
						if($form eq ''){
							$form = $verbChunk->getAttribute('verbform');
						}
						# f still empty
						if($form eq ''){
							print STDERR "no verbform:::\n".$verbChunk->toString()."\n";
						}
						print $mapMorphsToClasses{$form}."\n";
						
						# print STDOUT "main verb: ".$mainV->getAttribute('lem')." :".$verbLexWithFrames{$mainV->getAttribute('lem')}." sub verb: ".$subV->getAttribute('lem')." :".$verbLexWithFrames{$subV->getAttribute('lem')}."\n";
						# print STDOUT $mainV->getAttribute('lem').",".$subV->getAttribute('lem').",".$linker.",".$formnominal."\n"
					}
				}
			}
	    }
 	}
 	
}

sub getMainVerb2{
	my $relClause = $_[0];
	
	# main verb is always the first child of verb chunk	
	my $verb = @{$relClause->findnodes('child::NODE[starts-with(@mi,"V")][1]')}[-1];
	if($verb)
	{
		return $verb;
	}
	else
	{
		#get sentence id
		my $sentenceID = $relClause->findvalue('ancestor::SENTENCE/@ord');
	#	print STDERR "main verb not found in sentence nr. $sentenceID: \n ";
	#	print STDERR $relClause->toString();
	#	print STDERR "\n";
	}
 }

sub getHeadNoun($;$){
	my ($relClause, $parentchunk) = @_;
	
	if(!defined($parentchunk))
	{
		$parentchunk = $relClause->parentNode();
	}	
#	print STDERR $parentchunk->getAttribute('type');
#	print STDERR "\n";
	my $headNoun;
	
	#if preceded by single noun
	if($parentchunk->exists('self::CHUNK[@type="sn"]'))
	{#print STDERR "1\n";
		# if head noun is a demonstrative pronoun (doesn't ocurr? TODO: check)
		# old: head noun = noun or prsprn -> atm, prsprn no chunk
		#$headNoun = @{$parentchunk->findnodes('descendant::NODE[starts-with(@mi,"N") or starts-with(@mi,"PP")][1]')}[-1];
		$headNoun = @{$parentchunk->findnodes('descendant::NODE[starts-with(@mi,"N") or starts-with(@mi,"PP")][1]')}[-1];
	}
	# if this is a coordinated relclause -> look for head noun one level higher up
	elsif($parentchunk->exists('self::CHUNK[@type="coor-v"]/NODE/NODE[@pos="pr" or NODE[@pos="pr"] ]'))
	{
		($headNoun) = $parentchunk->findnodes('parent::CHUNK[@type="sn" or @type="coor-n"]/descendant::NODE[starts-with(@mi,"N") or starts-with(@mi,"PP")][1]');
		#print STDERR $headNoun->toString()."\n";
	}

	#assure that head noun is above rel-clause (in cases of wrong analysis)
	if($headNoun && isAncestor($relClause,$headNoun))
	{
			undef($headNoun);
	}
	#if head noun is defined, return 
	if($headNoun)
	{
		return $headNoun;
	}
	else
	{   #get sentence id
		my $sentenceID = $relClause->findvalue('ancestor::SENTENCE/@ord');
		#print STDERR "Wrong analysis in sentence nr. $sentenceID? no head noun found, head chunk is: ";
		#print STDERR $parentchunk->toString();
		return -1;
	}
}
sub isAncestor{
	my $relClause = $_[0];
	my $headNoun = $_[1];
	
	my $headNounOrd = $headNoun->getAttribute('ord');
	my $xpath = 'descendant::NODE[@ord="'.$headNounOrd.'"]';
	

	return($relClause->exists($xpath));
}


sub getFiniteVerb{
	my $verbchunk = $_[0];
	# finite verb is the one with a person marking (1,2,3)
	my $verb = @{$verbchunk->findnodes('child::NODE[starts-with(@mi,"V") and (contains(@mi,"3") or contains(@mi,"2") or contains(@mi,"1")) ][1]')}[-1];
	my $verb2Cand = @{$verbchunk->findnodes('child::NODE/NODE[starts-with(@mi,"V") and (contains(@mi,"3") or contains(@mi,"2") or contains(@mi,"1")) ][1]')}[-1];
	my $verb3Cand = @{$verbchunk->findnodes('child::NODE/NODE/NODE[starts-with(@mi,"V") and (contains(@mi,"3") or contains(@mi,"2") or contains(@mi,"1")) ][1]')}[-1];
	
	if($verb)
	{
		return $verb;
	}
	elsif($verb2Cand)
	{
		return $verb2Cand;	
	}
	elsif($verb3Cand)
	{
		return $verb3Cand;	
	}
	else
	{
		#print STDERR "finite verb not found in chunk: ";
		#print STDERR $verbchunk->getAttribute('ord')."\n";
		#print STDERR $verbchunk->toString();
		#print STDERR "\n";
		return 0;
	}	
	
}
# print new xml to stdout
# my $docstring = $dom->toString(1);
# #print STDERR $dom->actualEncoding();
# print STDOUT $docstring;
