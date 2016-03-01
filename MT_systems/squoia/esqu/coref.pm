#!/usr/bin/perl

package squoia::esqu::coref;
use utf8;
use strict;

my $verbose = '';

sub main{
	my $dom = ${$_[0]};
	my $verbose = $_[1];
	#my $withCorzu=$_[2];

	print STDERR "#VERBOSE ". (caller(0))[3]."\n" if $verbose;

	my @sentenceList = $dom->getElementsByTagName('SENTENCE');
	
	my $activeSubj ;
	my $coreflem = '';
	my $corefmi = '';
	my $nbrOfsubjectlessVerbChunks = 0;
	my $nbrOfsubjectlessVerbChunksWhereSubjNotInserted =0;
	my $nbrOfsubjectlessVerbChunksWithoutFiniteVerb=0;
	my $nbrOfPronominalSubjs=0;
	my $blockedBysubjPrn=0;
	my $noActiveSubjDueToPrecedingPrn = 0;
	my $nbrOfinsertedSubjs=0;
	
	foreach my $sentence (@sentenceList)
	{
		# get all verb chunks and check if they have an overt subject, 
		# if they don't have an overt subject and precede the main clause -> look for subject in preceding sentence
		# if they don't have an overt subject and follow the main clause, and the main clause has an overt subject, this is the subject of the subordinated chunk
		#print STDERR "sentence:" if $verbose;
		#print STDERR $sentence->getAttribute('ord') if $verbose;
		
	 	
	 	# consider linear sequence in sentence; in xml the verb of the main clause comes always first, but in this case the subject of a preceding subordinated clause is probably coreferent with the subject of the preceding clause
	 	my @verbChunks = $sentence->findnodes('descendant::CHUNK[@type="grup-verb" or @type="coor-v"]');
	 	
	 	my %chunkSequence =();
	 	
	 	foreach my $verbChunk (@verbChunks)
	 	{
	 		# note: 'ord' of chunks is just top-down order, to get order of words in clause-> use idref (='ord' of head node in chunk)
	 		my $idref = $verbChunk->getAttribute('ord');
	 		$chunkSequence{$idref}= $verbChunk;
	 	}
	
	 	#iterate through verb chunks in their original sequence
	 	foreach my $idref (sort {$a<=>$b} (keys (%chunkSequence))) 
	 	{
	 		my $verbChunk = $chunkSequence{$idref};
			
	 		# only necessary for 3rd person subjects, no subjects of participle forms ('denominado Paltayoq' -> Paltayoq should not be Antecedent), also: ignore relative clauses, and ignore complement clauses 'dice que x se fue' -> x should not be antecedent
	 		if( $verbChunk->exists('CHUNK[(@type="sn" or @type="date") and (@si="suj" or @si="suj-a")]' ) && !$verbChunk->exists('CHUNK[@type="sn" and (@si="suj" or @si="suj-a")]/NODE[@rel="suj" and (@pos="pd" or @pos="pi")]' ) && !&isLocalPerson($verbChunk) && !squoia::util::isRelClause($verbChunk) && !$verbChunk->exists('self::CHUNK[@si="sentence" or @si="cd"]/NODE/NODE[@pos="cs"]') )
	 		{
	 			
	 			my $activeSubjCand = @{$verbChunk->findnodes('CHUNK[@type="sn" and (@si="suj" or @si="suj-a")]/NODE[@cpos="n"]')}[-1];
	 			
	 			# no time references as subject candidates!
	 			if($activeSubjCand && $activeSubjCand->getAttribute('lem') !~ /día|noche|año|mes|hora|segundo|minuto|enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre/ )
	 			#if($activeSubjCand )
	 			{
	 				$activeSubj = $activeSubjCand;
	 				$coreflem = $activeSubj->findvalue('@lem');
	 				$corefmi = $activeSubj->findvalue('@mi');
	 				
	 				#print STDERR " coreflem: $coreflem $corefmi\n" if $verbose;
	 				$blockedBysubjPrn=0;
	 			}
	 		}
	 		# if subj of this verb is a pronoun (personal or demonstrative) -> delete previous subject, might be something else, indefinite?
	 		elsif($activeSubj && $verbChunk->exists('child::CHUNK[@si="suj"]/NODE[@rel="suj" and (@pos="pp" or @pos="pd" )]') )
	 		{
	 			#print STDERR "deleted ".$activeSubj->findvalue('@lem')." as active subject due to pronominal subject in following verb chunk\n" if $verbose;
				$nbrOfPronominalSubjs++;
	 			#TODO find a way do coreference resolution for pronouns!!
	 			undef $activeSubj;
				$blockedBysubjPrn=1;
	 		}
	 		elsif(!&isHaceImpersonal($verbChunk) && !&isHay($verbChunk) && !&isConsta($verbChunk) )
	 		{
			    #elsif($activeSubj && !$verbChunk->exists('child::*[@si="suj" or @rel="suj"]' ) && !&isLocalPerson($verbChunk) && !squoia::util::isRelClause($verbChunk) && !$verbChunk->exists('CHUNK[@type="sn" and @si="impers"]') && !$verbChunk->exists('child::NODE[@form="hay" or @form="Hay"]') )
			    if($activeSubj && !$verbChunk->exists('child::*[@si="suj"]') && !&isLocalPerson($verbChunk) && !&isRelClause($verbChunk) && !$verbChunk->exists('child::NODE/descendant::NODE[(starts-with(@mi,"P") or @cpos="z")  and @rel="suj"]') && !$verbChunk->exists('descendant::CHUNK[@si="impers"]/NODE[@lem="se"]')  && !$verbChunk->exists('child::CHUNK[@si="cd/ci" and contains(@ord,".1") ]/NODE[@lem="se"]'))
			    {	
				    #print STDERR "heeeeere....!\n".$verbChunk->toString()."\n";
				    $nbrOfsubjectlessVerbChunks++;
				    #check if number is the same
				    my $finiteVerb = squoia::util::getFiniteVerb($verbChunk);
				    #print STDERR "finite verb: $finiteVerb\n";
			    #	if($finiteVerb && !$finiteVerb->getAttribute('mi') =~ /^VMM/ && &checkNumberAndPerson($finiteVerb, $activeSubj,$corefmi))
				    if($finiteVerb && !($finiteVerb->getAttribute('mi') =~ /^VMM/) && &checkNumberAndPerson($finiteVerb, $activeSubj,$corefmi) )
				    {
					    #print STDERR "finite verb in verb chunk nbr ".$verbChunk->getAttribute('ord').$finiteVerb->getAttribute('form')."\n" if $verbose;
					    $verbChunk->setAttribute('coref',$coreflem);
					    $verbChunk->setAttribute('corefmi',$corefmi);
					    #print STDERR "inserted coreflem: $coreflem $corefmi\n" if $verbose;
					    $nbrOfinsertedSubjs++;
				    }
				    elsif(!$finiteVerb)
				    {
					    $nbrOfsubjectlessVerbChunksWithoutFiniteVerb++;
				    }
				    else
				    {
					    $nbrOfsubjectlessVerbChunksWhereSubjNotInserted++;
				    }
			    }
			    elsif(!$activeSubj && $blockedBysubjPrn)
			    {
				    $noActiveSubjDueToPrecedingPrn++;
				    #print STDERR "no subject inserted due to previous subj=pers-prn in verb chunk nbr: ".$verbChunk->getAttribute('ord')."\n" if $verbose;
			    }
			 }
	 	
	 	} 
		#print STDERR "\n---------------------\n" if $verbose;
	}
#	print STDERR "\n****************************************************************************************\n";
#	print STDERR "total number of subjectless verb chunks: ".($nbrOfsubjectlessVerbChunks+$noActiveSubjDueToPrecedingPrn)."\n";
#	print STDERR "total number of subjectless verb chunks without finite verb: $nbrOfsubjectlessVerbChunksWithoutFiniteVerb\n";
#	print STDERR "total number of truly subjectless verb chunks: ".($nbrOfsubjectlessVerbChunks-$nbrOfsubjectlessVerbChunksWithoutFiniteVerb)."\n";
#	print STDERR "total number of inserted subjects: $nbrOfinsertedSubjs\n";
#	print STDERR "total number of subjectless verb chunks where no subject could be inserted: $nbrOfsubjectlessVerbChunksWhereSubjNotInserted\n";
#	print STDERR "total number of verbs with pronominal subjects (could not be resolved): $nbrOfPronominalSubjs\n";
#	print STDERR "total number of verbs where subject could not be inserted due to previuous pronominal subject: $noActiveSubjDueToPrecedingPrn\n";
#	print STDERR "\n****************************************************************************************\n";
#	# print new xml to stdout
#	my $docstring = $dom->toString(3);
#	#print $dom->actualEncoding();
#	print STDOUT $docstring;
#	return $dom;
}

sub isRelClause{
	my $verbchunk = $_[0];
	
#	print STDERR "testing for rel clause : ".$verbchunk->toString()."\n";
#	print STDERR "parent is of type:".$verbchunk->findvalue('parent::CHUNK/@type')."\n";
	# normal case
	return 1 if($verbchunk->exists('child::NODE/descendant::NODE[starts-with(@mi,"PR")]'));
	#with preposition
	return 1 if($verbchunk->exists('child::CHUNK[@type=grup-sp or @type="coor-sp"]/NODE[@pos="sp"]/descendant::NODE[starts-with(@mi,"PR")]'));
	# second part of coordinated rel clause
	return 1 if($verbchunk->exists('parent::CHUNK[@type="coor-v"]/NODE/descendant::NODE[starts-with(@mi,"PR")]'));
	# less restrictive (but risky): if chunk is labeled as 'S' and has a nominal head, assume its a relative clause
	if($verbchunk->getAttribute('si') eq 'S' && !$verbchunk->exists('child::NODE/descendant::NODE[@mi="CS"]') && $verbchunk->exists('parent::CHUNK[@type="grup-verb" or @type="coor-v"]/parent::CHUNK[@type="sn" or @type="coor-n"]') && $verbchunk->exists('parent::CHUNK[@type="grup-verb" or @type="coor-v"]/descendant::NODE[count(child::NODE[@pos="da"])=0]/NODE[starts-with(@mi,"PR")]') ){
		#return 2;
		return 1; # bit uncertain, but probably the second part of a coordinated relative clause
	}
	return 0;
	
}

sub isHay{
	my $verbchunk = $_[0];
	
	my ($topverb) = $verbchunk->findnodes('child::NODE[1]');
	#print STDERR "found topverb $topverb in verb chunk \n";
	
	# if 'haber' is main verb (top directly under chunk)
	if($topverb && $topverb->getAttribute('lem') eq 'haber'){
		
		# either: 3 singular, hay, había, hubo..
		if($topverb->getAttribute('mi') =~ /3S/){
			#print STDERR "found 3s haber top verb in \n\t".$topverb->toString()."\n";
			$verbchunk->setAttribute('pleonastic', 'yes');
			return 1;
		}
		# or: infinitive + modal verb, puede haber, debe haber
		elsif($topverb->getAttribute('mi') =~ /^VMN0000|VAN0000/ && $topverb->exists('descendant::NODE[contains(@mi,"3S")]') ){
			#print STDERR "found infinitive haber with 3s finite verb in \n\t".$topverb->toString()."\n";
			$verbchunk->setAttribute('pleonastic', 'yes');
			return 1;
		}
		# or: ha/había/habrá habido
		elsif($topverb->getAttribute('form') =~ /^[Hh]abido/ && $topverb->exists('descendant::NODE[contains(@mi,"3S") and @lem="haber"]') ){
			$verbchunk->setAttribute('pleonastic', 'yes');
			return 1;
		}	
	}
	
	# exclude 'ha de +inf' and 'hay que +inf'
	# maybe not 'ha de' ?
	elsif($topverb->getAttribute('mi') =~ /^V[SM]N0000/ && $topverb->exists('descendant::NODE[@lem="haber" and contains(@mi,"3S")]') && $topverb->exists('descendant::NODE[@lem="que" or @lem="de"]')){
		return 1;
	}
	# wrong parse with modal verb on top: TODO
#	  <CHUNK type="grup-verb" si="top" ord="1">
#      <NODE ord="1" form="puede" lem="poder" pos="vm" cpos="v" rel="sentence" mi="VMIP3S0"/>
#      <CHUNK type="grup-verb" si="suj" ord="2">
#        <NODE ord="2" form="haber" lem="haber" pos="vm" cpos="v" rel="suj" mi="VMN0000">
	
	
	
	
	return 0;
	
}

sub isConsta{
	my ($verbchunk) = $_[0];
	
	my ($topverb) = $verbchunk->findnodes('child::NODE[1]');
	
	if($topverb and $topverb->getAttribute('form') =~ /^[Cc]onsta$/){
		# consta que, or (me,te..) consta que
		
		#get next node in linear sequence
		my $constaOrd = $topverb->getAttribute('ord');
	#	print STDERR "consta ord: $constaOrd\n";
		my $xpathstring = 'ancestor::SENTENCE/descendant::NODE[@ord="'.($constaOrd+1).'"]';
		#print STDERR $xpathstring."\n";
		my ($nextnode) = $verbchunk->findnodes($xpathstring);
		if($nextnode && $nextnode->getAttribute('lem') eq 'que'){
			$verbchunk->setAttribute('pleonastic', 'yes');
			return 1;
		}
		# note: consta and que dont need to be adjacent, less reliable method: check verbchunk has a verbchunk child subordinated with que
		elsif($verbchunk->exists('child::CHUNK[@type="grup-verb" or @type="coor-v"]/NODE/descendant-or-self::NODE[@lem="que"]')){
			$verbchunk->setAttribute('pleonastic', 'yes');
			return 1;
		}
		
		
	}
	return 0;
}

sub isHaceImpersonal{
    my ($verbchunk) = $_[0];
    
    if($verbchunk->exists('child::NODE[@lem="hacer"]'))
    {
	  my ($cd) = $verbchunk->findnodes('child::CHUNK[@si="cd" or @si="cd-a" or @si="cc"]');
	  if($cd and $cd->findvalue('child::NODE/@lem') =~ /día|mes|año|segundo|minuto|hora|tiempo|calor|frío|sol|lluvia|nieve|graniza|cálido|fresco/)
	  { #TODO: insert special translation in dix & rules
	      $verbchunk->setAttribute('pleonastic', 'yes');
	      return 1;
	  }
    }
    
    return 0;
}

sub isLocalPerson{
	my $verbChunk = $_[0];

	if($verbChunk)
	{
		my $finiteVerb = squoia::util::getFiniteVerb($verbChunk);

		if($finiteVerb)
		{
			return ($finiteVerb->getAttribute('mi') =~ /1|2/ );
		}
		#return $verbChunk->exists('NODE/@mi[contains(., "2")]') || $verbChunk->exists('NODE/NODE/@mi[contains(., "2")]') || $verbChunk->exists('NODE/@mi[contains(., "1")]') || $verbChunk->exists('NODE/NODE/@mi[contains(., "1")]') ;
	}
	#this shouldn't happen!
	else
	{
		print STDERR "failed to get person of finite verb\n";
	}
}



sub checkNumberAndPerson {
	my $finiteVerb = $_[0];
	my $activeSubj = $_[1];
	my $corefmi = $_[2];
	
	if($finiteVerb && $activeSubj)
	{
		my $verbmi =  $finiteVerb->getAttribute('mi');
		my $corefPerson;
		my $corefNumber;
		my $VerbPerson = substr ($verbmi, 4, 1);
		my $VerbNumber = substr ($verbmi, 5, 1);
	
		#if coref candidate noun is a pronoun, get person
		if($corefmi =~ /^PP/)
		{
			$corefPerson =  substr ($corefmi, 2, 1);
		 	$corefNumber =  substr ($corefmi, 4, 1);
		}
		else
		{
			$corefPerson = '3';
			
			#if activeSubj is a coordinated np -> plural
			if($activeSubj->parentNode()->exists('self::CHUNK[@type="coor-n"]') ||  $activeSubj->parentNode()->exists('parent::CHUNK[@type="coor-n"]'))
			{
				$corefNumber = 'P';
			}
			else
			{
				$corefNumber = substr ($corefmi, 3, 1);
				# proper names have no number, check if article/adj present that might reveal number
				if($corefNumber eq '0' && $activeSubj->exists('child::NODE'))
				{
					my $modfiermi = $activeSubj->findvalue('NODE/@mi');
					#if modifier is a number -> plural
					if($modfiermi eq 'Z')
					{
						$corefNumber = 'P';
					}
					#if adj or det, number is at position 4
					elsif($modfiermi =~ /^$[AD]/)
					{
						$corefNumber = substr ($modfiermi, 4, 1);
					}
				}
			}
		}
#		my $corefform = $activeSubj->getAttribute('form');
#		my $verbform =  $finiteVerb->getAttribute('form');
#		print STDERR "\n $corefform:$verbform  $corefmi, $verbmi: nr $corefNumber, $VerbNumber; prs: $VerbPerson, $corefPerson\n" if $verbose;
		# if person on verb and noun don't match, return false
		if($VerbPerson ne $corefPerson)
		{
			return 0;
		}
		# else, if verb and noun have same person, check number
		else
		{	
			#if number is not the same, not coreferent
			if ($corefNumber eq $VerbNumber || $corefNumber eq '0')
			{
				#check if clause has a pronoun as subject (demonstrative, algunos hicieron..) -> if so, check also gender
				if($finiteVerb->exists('child::NODE[@rel="suj" and @cpos="p" ]'))
				{
					my $prnSubjOfVerb = $finiteVerb->findvalue('child::NODE[@rel="suj" and @cpos="p"]/@mi');
					my $gender =  substr ($prnSubjOfVerb, 3, 1);
					my $corefgender =  substr ($corefmi, 2, 1);
				#	print STDERR "gender: $gender, coref gender: $corefgender\n" if $verbose;
				
					return ($corefgender eq  $gender || $gender eq '0' || $corefgender eq '0');
				}
				return 1;
			}
			# else, if number of head noun & verb are not the same, return 0
			else
			{
				return 0;
			}
		}
	}
	# this shouldn't happen
	else 
	{
		print STDERR "failed to check congruence of finite verb possible antecedent\n";
	}
}





1;


