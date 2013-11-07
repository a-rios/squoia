#!/usr/bin/perl


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
require "$path/../util.pl";


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
		print STDOUT "vTense,vMod,vPers,vNum,hasSE,";
		
		# last row: class
		print STDOUT "relpron,agentive\n";;

my %verbLexWithFrames   = %{ retrieve("VerbLex") };
my %nounLex   = %{ retrieve("NounLex") };
my %verbLemClasses =  %{ retrieve("verbLemClasses") };

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
 	my @verbChunks = $sentence->findnodes('descendant::CHUNK[starts-with(@verbform, "rel") or NODE[starts-with(@verbform, "rel")]]');

 #	print STDERR scalar(@verbChunks)."\n";
 	
 	foreach my $verbChunk (@verbChunks)
 	{
 	  #  print STDERR "verb chunk nbr: ".$verbChunk->getAttribute('ord')."\n";
 		my $headNoun = &getHeadNoun($verbChunk);
 		my $mainV = &getMainVerb2($verbChunk);
 		unless($headNoun == -1)
		{
			if($mainV)
			{
	 			my $headlem = $headNoun->getAttribute('lem');
				my $headSem = $nounLex{$headlem};
				chomp($headSem);
				my @headSems = split('_',$headSem);
				my %headSemLabels = map { $_ => 0; } qw(abs ani bpart cnc hum loc mat mea plant pot sem soc tmp unit);
				
				print STDOUT "$headlem,";
				# print semantic classes of head noun
				foreach my $sem (@headSems){
					$headSemLabels{$sem}= 1;
				}
				
				foreach my $key (sort keys %headSemLabels){
					#print STDOUT "key $key:".$headSemLabels{$key}.",";
					print STDOUT $headSemLabels{$key}.",";
				}
				# print pos info of head noun
				my $headPos = $headNoun->getAttribute('mi');
				my $headNum = substr($headPos,3,1);
				my $cat = substr($headPos,1,1);
				my $properType = substr($headPos,4,2);
				
				#print STDOUT "Num:$headNum,cat:$cat,proper:$properType,";
				print STDOUT "$headNum,$cat,";
	
				my $mLem = $mainV->getAttribute('lem');
				my $mainFrames = $verbLexWithFrames{$mLem};
				my $mPos = $mainV->getAttribute('mi');
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
							
				my $mTense = substr($mPos,3,1);
				my $mMod = substr($mPos,2,1);
				my $mPers = substr($mPos,4,1);
				my $mNum = substr($mPos,5,1);
				#print "$mPos: tns:$mTense, mod:$mMod, prs:$mPers, num:$mNum";
				print "$mTense,$mMod,$mPers,$mNum,";
				
				# does this rel. clause have 'se'?
				if($verbChunk->exists('descendant::NODE[@form="se" or @form="Se"]') or $mLem =~ /rse$/){
					print "1,";
				}
				else{
					print "0,";
				}
				
				# print relative pronoun
				my ($relpron) = $verbChunk->findnodes('descendant::NODE[starts-with(@mi,"PR")][1]');
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


# print new xml to stdout
# my $docstring = $dom->toString(1);
# #print STDERR $dom->actualEncoding();
# print STDOUT $docstring;
