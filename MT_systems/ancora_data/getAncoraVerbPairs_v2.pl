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
	'perfect'			=> 2,
	'passive'			=> 2,
	'obligative'		=> 3,
	'agentive'			=> 4,
	'SS'	=> 6,
	'DS'		=> 6,
	'switch'		=> 6,
	'main'		=> 7,
	'ambiguous'		=> -1,
	
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

 		# print main verb lemma and senses (wordnet)
        print STDOUT "mLem,mSem29,mSem30,mSem31,mSem32,mSem33,mSem34,mSem35,mSem36,mSem37,mSem38,mSem39,mSem40,mSem41,mSem42,mSem43,";
		# main verb frames:
		print STDOUT "mA11,mA12,mA13,mA21,mA22,mA23,mA31,mA32,mA33,mA34,mA35,mB11,mB12,mB21,mB22,mB23,mC11,mC21,mC31,mC41,mC42,mD11,mD21,mD31,";
		
		# main verb morphology
		print STDOUT "mTense,mMod,mPers,mNum,";
		
		# print subordinated verb lemma and senses (wordnet)
        print STDOUT "sLem,sSem29,sSem30,sSem31,sSem32,sSem33,sSem34,sSem35,sSem36,sSem37,sSem38,sSem39,sSem40,sSem41,sSem42,sSem43,";
        
		# subordinated verb frames:
		print STDOUT "sA11,sA12,sA13,sA21,sA22,sA23,sA31,sA32,sA33,sA34,sA35,sB11,sB12,sB21,sB22,sB23,sC11,sC21,sC31,sC41,sC42,sD11,sD21,sD31,";
		
		# subordinated verb morphology
		print STDOUT "sTense,smMod,sPers,sNum,";
		
		# last row: class
		print STDOUT "linker,form\n";;

my %verbLexWithFrames   = %{ retrieve("VerbLex") };
my %verbLemClasses =  %{ retrieve("verbLemClasses") };

#read xml from STDIN
my $parser = XML::LibXML->new({encoding => 'utf-8'});
my $dom    = XML::LibXML->load_xml( IO => *STDIN);

my @sentenceList = $dom->getElementsByTagName('SENTENCE');

foreach my $sentence (@sentenceList)
{
	# get all verb chunks and check if they have an overt subject, 
	# if they don't have an overt subject and precede the main clause -> look for subject in preceding sentence
	# if they don't have an overt subject and follow the main clause, and the main clause has an overt subject, this is the subject of the subordinated chunk
	#print STDERR "Looking for verb pairs in sentence:";
	#print STDERR "sent.".$sentence->getAttribute('ord').",";
	
 	
 	# consider linear sequence in sentence; in xml the verb of the main clause comes always first, but in this case the subject of a preceding subordinated clause is probably coreferent with the subject of the preceding clause
 	my @verbChunks = $sentence->findnodes('descendant::CHUNK[@type="grup-verb"]');

 #	print STDERR scalar(@verbChunks)."\n";
 	
 	foreach my $verbChunk (@verbChunks)
 	{
 	  # print STDERR "verb chunk nbr: ".$verbChunk->getAttribute('ord')."\n";	
	   if($verbChunk->findvalue('child::CHUNK[@type="grup-verb" or @type="coor-v"]/@verbform') ne 'ambiguous' && $verbChunk->findvalue('child::CHUNK[@type="grup-verb" or @type="coor-v"]/@verbform') ne '')
	   { 
	   		my $sentenceID = $verbChunk->findvalue('ancestor::SENTENCE/@ord');
			print STDERR "disambiguating verb sentence nr. $sentenceID: \n ";
			print "sent.".$sentenceID.", ";
			my $mainV = &getMainVerb2($verbChunk);
			my $mLem = $mainV->getAttribute('lem');
			my $mainFrames = $verbLexWithFrames{$mLem};
			my $mPos = $mainV->getAttribute('mi');
			my %mainLabels = map { $_ => 0; } qw(mA11 mA12 mA13 mA21 mA22 mA23 mA31 mA32 mA33 mA34 mA35 mB11 mB12 mB21 mB22 mB23 mC11 mC21 mC31 mC41 mC42 mD11 mD21 mD31);
			my %mainClasses = map { $_ => 0; } qw(mSem29 mSem30 mSem31 mSem32 mSem33 mSem34 mSem35 mSem36 mSem37 mSem38 mSem39 mSem40 mSem41 mSem42 mSem43);
				
			my @subV = $verbChunk->findnodes('child::CHUNK[(@type="grup-verb" or @type="coor-v") and not(@verbform="" or @verbform="ambiguous" or contains(@verbform,"rel:"))]');
			my @CoorsubV = $verbChunk->findnodes('child::CHUNK[@type="coor-v" and not(@verbform="" or @verbform="ambiguous")]/CHUNK[@type="grup-verb" and not(@verbform="" or @verbform="ambiguous"  or contains(@verbform,"rel:"))]');
				
			push(@subV,@CoorsubV);
			
			if($mainV && scalar(@subV)>0)
			{
			  foreach my $subVchunk (@subV)
			  {
			  	# check if there's a finite verb in this chunk
			  	my $finiteVerb = &getFiniteVerb($subVchunk);
			  	if($finiteVerb)
			  	{
				    my $form = $subVchunk->getAttribute('verbform');
				    my $formnominal = $mapMorphsToClasses{$form};
				    my $subV = &getMainVerb2($subVchunk);
				    my $linker = $subVchunk->findvalue('child::NODE/NODE[@mi="CS"][1]/@lem');
				    # set linker (only necessary for desr output, in ancora, linker depends always on subordinated verb)
				    if ($linker eq '' )
				    { $linker = '0';}
				    
				    if($subV && $formnominal ne '' && $linker ne '')
				    {
						my $subFrames = $verbLexWithFrames{$subV};
						my %subLabels = map { $_ => 0; } qw(sA11 sA12 sA13 sA21 sA22 sA23 sA31 sA32 sA33 sA34 sA35 sB11 sB12 sB21 sB22 sB23 sC11 sC21 sC31 sC41 sC42 sD11 sD21 sD31);
						my %subClasses =  map { $_ => 0; } qw(sSem29 sSem30 sSem31 sSem32 sSem33 sSem34 sSem35 sSem36 sSem37 sSem38 sSem39 sSem40 sSem41 sSem42 sSem43);
			
						my $sPos = $subV->getAttribute('mi');
						my $sLem = $subV->getAttribute('lem');
						my $subFrames = $verbLexWithFrames{$sLem};
						
						print "$mLem,";
						# print semantic class(es)
						if($verbLemClasses{$mLem}){
							foreach my $class (keys %{$verbLemClasses{$mLem}}){
								#print STDERR "$mainV: $class ".$verbLemClasses{$mainV}{$class}."\n";
								my $mclass = "mSem".$class;
								$mainClasses{$mclass}= $verbLemClasses{$mLem}{$class};
							}
						}
						foreach my $key ( sort keys %mainClasses) {
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
								# some errors in Ancora dix! skip those... (e.g. 'dar' has a frame 'a3'?!)
								unless($label eq ''){
									$label = "m".$label;
									#print "$label  $f\n";
									$mainLabels{$label}=1;
								}
							}
						}
						
						foreach my $key ( sort keys %mainLabels) {
							#print STDERR "$key: ".$mainLabels{$key}." ";
							print "$mainLabels{$key},";
						} 
						
						my $mTense = substr($mPos,3,1);
						my $mMod = substr($mPos,2,1);
						my $mPers = substr($mPos,4,1);
						my $mNum = substr($mPos,5,1);
						#print "$mPos: tns:$mTense, mod:$mMod, prs:$mPers, num:$mNum";
						print "$mTense,$mMod,$mPers,$mNum,";
						
						 # sub verb
						 print "$sLem,";
						 # print semantic class(es)
						if($verbLemClasses{$sLem}){
							foreach my $class (keys %{$verbLemClasses{$sLem}}){
								#print STDERR "$sub: $class ".$verbLemClasses{$sub}{$class}."\n";
								my $sclass = "sSem".$class;
								$subClasses{$sclass}= $verbLemClasses{$sLem}{$class};
							}
						}
						foreach my $key ( sort keys %subClasses) {
							#print STDERR "$key: ".$subClasses{$key}."\n";
							#print "$subClasses{$key},";
							if($subClasses{$key}>0){
								print "1,";
							}
							else{
								print "0,";
							}
						}
						
						# print sub verb frames
						if($subFrames){
							foreach my $f (@$subFrames){
								my ($label) = ($f =~ m/^(.\d\d)/);
								# some errors in Ancora dix! skip those... (e.g. 'dar' has a frame 'a3'?!)
								unless($label eq ''){
									$label = "s".$label;
									#print "$label  $f\n";
									$subLabels{$label}=1;
								}
							}
						}
						
						foreach my $key ( sort keys %subLabels) {
							#print STDERR "$key: ".$subLabels{$key}." ";
							print "$subLabels{$key},";
						}
						my $sTense = substr($sPos,3,1);
						my $sMod = substr($sPos,2,1);
						my $sPers = substr($sPos,4,1);
						my $sNum = substr($sPos,5,1);
						
						print "$sTense,$sMod,$sPers,$sNum,$linker,";
						
						print $mapMorphsToClasses{$form}."\n";
						
				    }
						
				    # print STDOUT "main verb: ".$mainV->getAttribute('lem')." :".$verbLexWithFrames{$mainV->getAttribute('lem')}." sub verb: ".$subV->getAttribute('lem')." :".$verbLexWithFrames{$subV->getAttribute('lem')}."\n";
				     # print STDOUT $mainV->getAttribute('lem').",".$subV->getAttribute('lem').",".$linker.",".$formnominal."\n";
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
		print STDERR "main verb not found in sentence nr. $sentenceID: \n ";
		print STDERR $relClause->toString();
		print STDERR "\n";
	}
 }


# print new xml to stdout
# my $docstring = $dom->toString(1);
# #print STDERR $dom->actualEncoding();
# print STDOUT $docstring;
