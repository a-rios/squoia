#!/usr/bin/perl

package squoia::conll2xml;

# TODO: dates.. freeling tokenisiert->zusammen, parser modell zusammen, werden aber im Moment noch gesplittet in crf2conll -> parser kennt das nicht
use strict;
use utf8;
#use XML::LibXML;
#binmode STDIN, ':utf8';
#binmode STDOUT, ':utf8';
#binmode (STDERR);
use File::Spec::Functions qw(rel2abs);
use File::Basename;

my %mapCliticToEaglesTag =       (
        'la'		=> 'PP3FSA00',
        'las'		=> 'PP3FPA00',
        'lo'		=> 'PP3MSA00',
        'los'		=> 'PP3MPA00',
        'le'		=> 'PP3CSD00',
        'les'		=> 'PP3CPD00',
        'me'		=> 'PP1CS000', # PP1CS000?
        'te'		=> 'PP2CS000', # PP2CS000?
        'se'		=> 'PP3CN000', # PP3CN000? could be le|les => se  or refl se ...or passive|impersonal se ...?
        'nos'		=> 'PP1CP000', # PP1CP000?
        'os'		=> 'PP2CP000' # PP2CP000?
                );

my %mapCliticFormToLemma =       (
        'la'		=> 'lo',
        'las'		=> 'lo',
        'lo'		=> 'lo',
        'los'		=> 'lo',
        'le'		=> 'le',
        'les'		=> 'le',
        'me'		=> 'me',
        'te'		=> 'te',
        'se'		=> 'se',
        'nos'		=> 'nos',
        'os'		=> 'os'
                );


# read conll file and create xml (still flat)
my $scount=1; #sentence ord
my %docHash;
my %conllHash; # hash to store each sentence as conll, in case second analysis is needed

my $dom = XML::LibXML->createDocument ('1.0', 'UTF-8');
my $root = $dom->createElementNS( "", "corpus" );
$dom->setDocumentElement( $root );
my $sentence; # actual sentence
# necessary to differentiate between opening and closing quotes, tagger doesn't do that
my $openQuot=1;
my $openBar=1;

my $verbose = '';

sub main{
	my $InputLines = $_[0];
	binmode($InputLines, ':utf8');
	$verbose = $_[1];

	print STDERR "#VERBOSE ". (caller(0))[3]."\n" if $verbose;

	while(<$InputLines>)

	{
		my $line = $_;
#	  	print $line;
#	  	if($line =~ /ó|í|á/){print "matched line is: ".$line;
#	  		my $encoding_name = Encode::Detect::Detector::detect($line);
#	  		print "encoding is: ".$encoding_name."\n";
#	  	}
#	  	else{print "not matched line is: ".$line;}
	    #skip empty line
	    if($line =~ /^\s*$/)
	    {
	      $scount++;
	      undef $sentence;
	    }
	    # word with analysis
	    else
	    {
	     #create a new sentence node 
	     if(!$sentence) 
	     {
	     $sentence = XML::LibXML::Element->new( 'SENTENCE' );
	     $sentence->setAttribute( 'ord', $scount );
	     $root->appendChild($sentence);
	     }
	     # create a new word node and attach it to sentence
	     my $wordNode = XML::LibXML::Element->new( 'NODE' );
	     $sentence->appendChild($wordNode);
	     my ($id, $word, $lem, $cpos, $pos, $info, $head, $rel, $phead, $prel) = split (/\t|\s/, $line);	 
	    # print STDERR "line: $id, $word, $lem, $cpos, $pos, $info, $head, $rel, $phead, $prel\n";
	     
	     
	     # quotes, opening -> fea, closing -> fet
	     if($pos eq 'Fe')
	     {
	     	# for some reason, apostrophes are not encoded by libxml -> leads to crash!
	     	# -> replace them with quotes..
	     	$word = '"';
	     	$lem = '"';
	     	if($openQuot){
	     		$pos = 'Fea';
	     		$openQuot=0;}
	     	else{
				$pos = 'Fet';
	     		$openQuot=1;}
	     }
	     # hyphen, opening -> fga, closing -> fgt
	     if($pos eq 'Fg')
	     {
	     	if($openQuot){
	     		$pos = 'Fga';
	     		$openBar=0;}
	     	else{
				$pos = 'Fgt';
	     		$openBar=1;}
	     }
	     
	     my ($eaglesTag) = ($info =~ /eagles=(.+)/);
	     # if verb (gerund,infinitve or imperative form) has clitic(s) then make new node(s)
	     if($eaglesTag =~ /^V.[GNM]/ and $word =~ /(me|te|nos|os|se|[^l](la|las|lo|los|le|les))$/ and $word !~ /parte|frente|adelante|base|menos$/ and $word !~ /_/)
	     {
			#print STDERR "clitics in verb $lem: $word\n" if $verbose;
			my $clstr = splitCliticsFromVerb($word,$eaglesTag,$lem);
			if ($clstr !~ /^$/){	# some imperative forms may end on "me|te|se|la|le" and not contain any clitic
				&createAppendCliticNodes($sentence,$scount,$id,$clstr);
			}
	     }
	     if($eaglesTag =~ /^NP/){
	     	$pos="np";
	     }
	     # set rel of 'y' and 'o' to coord
	     if($lem eq 'y' || $lem eq 'o'){
	     	$rel = 'coord';
	     }

	     # often: 'se fue' -> fue tagged as 'ser', VSIS3S0 -> change to VMIS3S0, set lemma to 'ir'
	     if($eaglesTag =~ /VSIS[123][SP]0/ && $lem eq 'ser'){
	     	my $precedingWord = $docHash{$scount.":".($id-1)};
	     	#print STDERR "preceding of fue: ".$precedingWord->getAttribute('lem')."\n" if $verbose;
	     	if($precedingWord && $precedingWord->getAttribute('lem') eq 'se'){
	     		$eaglesTag =~ s/^VS/VM/ ;
	     		#print STDERR "new tag: $eaglesTag\n" if $verbose;
	     		$lem = 'ir';
	     	}
	     }
#	     # if 'hay' tagged as VA -> changed to VM!
#	     if($eaglesTag eq 'VAIP3S0' && $word =~ /^[Hh]ay$/){
#	     		$eaglesTag = 'VMIP3S0' ;
#	     		print STDERR "new tag for hay: $eaglesTag\n" if $verbose;
#	     }
	     # freeling error for reirse, two lemmas, reír/reir -> change to reír
	     if($lem =~ /\/reir/){
				$lem = 'reír';
		}
	     
	     $wordNode->setAttribute( 'ord', $id );
	     $wordNode->setAttribute( 'form', $word );
	     $wordNode->setAttribute( 'lem', $lem );
	     $wordNode->setAttribute( 'pos', lc($pos) );
	     $wordNode->setAttribute( 'cpos', $cpos );
	     $wordNode->setAttribute( 'head', $head );
	     $wordNode->setAttribute( 'rel', $rel );
		 if($eaglesTag eq ''){
		 	$wordNode->setAttribute( 'mi', $pos );
		 }
		 else{
	    	 $wordNode->setAttribute( 'mi', $eaglesTag );
		 }
	
	    # print "$eaglesTag\n";
	     # store node in hash, key sentenceId:wordId, in order to resolve dependencies
	     my $key = "$scount:$id";
	     $docHash{$key}= $wordNode;
	     
	     $conllHash{$scount} =  $conllHash{$scount}.$line;
	     }
	  }
	
	#my $docstring = $dom->toString(3);
	#print STDERR $docstring;

	
	## adjust dependencies (word level), 
	my @sentences = $dom->getElementsByTagName('SENTENCE');
	#foreach my $sentence  ( $dom->getElementsByTagName('SENTENCE'))

	for(my $i = 0; $i < scalar(@sentences); $i++)
	{  
			my $sentence = @sentences[$i];
			my $sentenceId = $sentence->getAttribute('ord');
			print STDERR "adjusting dependencies in sentence: ".$sentence->getAttribute('ord')."\n" if $verbose;
			#print STDERR "2: ".$sentence->toString."\n" if $verbose;
			my @nodes = $sentence->getElementsByTagName('NODE');
		
			foreach my $node (@nodes)
			{
				#print STDERR $node->getAttribute('ord')."\n" if $verbose;
				my $head = $node->getAttribute('head');
				if ($head ne '0')
				{
					my $headKey = "$sentenceId:$head";
					#print STDERR "Head key: $headKey\n" if $verbose;
					my $word = $node->getAttribute('form');
					#print "$word= $headKey\n";
					my $parent = $docHash{$headKey};
					eval
					{
						$parent->appendChild($node);
					}
					or do
					{
						print STDERR "loop detected in sentence: ".$sentence->getAttribute('ord')."\n" if $verbose;
						$i--;
						last;
					}
				}
				# if this is the head, check if it's a good head (should not be a funcion word!), and if not, 
				# check if there are >3 words in this sentence (otherwise it might be a title)
#				else
#				{
#					my $pos = $node->getAttribute('pos');
#				
#					if($pos =~ /d.|s.|p[^I]|c.|n.|r.|F./ && scalar(@nodes) > 4)
#					{
#						$i--;
#						last;
#					}
#				}
			}
		}

#	my $docstring = $dom->toString(3);
#	print STDERR $docstring;


	
    if($verbose){
		my $docstring = $dom->toString(3);
		print STDERR $docstring if $verbose;
		print STDERR "------------------------------------------------\n";
		print STDERR "------------------------------------------------\n";
	}
#	# insert chunks
#	
	foreach my $sentence  ( $dom->getElementsByTagName('SENTENCE'))
	{
		
		my $sentenceId = $sentence->getAttribute('ord');
		#print STDERR "insert chunks in sentence: $sentenceId\n" if $verbose;
		#my $chunkCount = 1;
		my $parent;
		my @nodes =  $sentence->getElementsByTagName('NODE');
		my $nonewChunk = 0;
		
		for(my $i=0; $i<scalar(@nodes); $i++)
		{ 
			#my $docstring = $dom->toString(3);
			my $node = @nodes[$i];
			my $head = $node->getAttribute('head');
			my $headKey = "$sentenceId:$head";
			my $word = $node->getAttribute('form');
			#print STDERR "node at $i: ".$node->toString()."\n" if $verbose;
			if ($head ne '0')
			{
				#print "$word= $headKey\n";
				$parent = $docHash{$headKey};
				# in case no parent found, assume parent is sentence (this shouldn't happen)
				if(!$parent)
				{
					$parent = $sentence; 
				}
			}
			#if head of sentence, parent is sentence node
			else
			{
				$parent = $sentence;
			}

				#if this is a main verb or auxiliary used as main verb 
				# (as auxiliary rel=v, auxilaries don't get their own chunk, they should live inside the main verbs' chunk)
				# if this is a finite verb with rel=v, check if its a finite verb and head is non-finite
				# -> avoid having two finite verbs in one chunk!
				if ($node->exists('self::NODE[starts-with(@mi,"V")] and not(self::NODE[@rel="v"])')  )
				{
					 my $verbchunk = XML::LibXML::Element->new( 'CHUNK' );
					  #if this node is parent of a coordination
					 if ($node->exists('child::NODE[@lem="ni" or @rel="coord"]'))
					 {
					 	$verbchunk->setAttribute('type', 'coor-v');
					 }
					 # no coordination
					 else
					 {
					 	$verbchunk->setAttribute('type', 'grup-verb');
					 }
					 

					 
					 # if this is the main verb in the chunk labeled as VA, change pos to VM
					 if($node->getAttribute('pos') eq 'va' && !$node->exists('child::NODE[@pos="vm"]'))
					 {
					 	my $eaglesTag = $node->getAttribute('mi');
					 	substr($eaglesTag, 1, 1) = "M";
					 	$node->setAttribute('mi',$eaglesTag);
					 	$node->setAttribute('pos', 'vm');
					 	print STDERR "changed mi of ".$node->{'form'}." to $eaglesTag\n" if $verbose;
					 }


				# head of rel-clause as suj to rel-clause-verb
# Maltparser: La mujer a quien vieron ya no vive aquí.
#  <SENTENCE ord="1">
#    <NODE ord="5" form="vieron" lem="ver" pos="vm" cpos="v" head="0" rel="sentence" mi="VMIS3P0">
#      <NODE ord="2" form="mujer" lem="mujer" pos="nc" cpos="n" head="5" rel="suj" mi="NCFS000">
#        <NODE ord="1" form="La" lem="el" pos="da" cpos="d" head="2" rel="spec" mi="DA0FS0"/>
#      </NODE>
#      <NODE ord="3" form="a" lem="a" pos="sp" cpos="s" head="5" rel="cc" mi="SPS00">
#        <NODE ord="4" form="quien" lem="quien" pos="pr" cpos="p" head="3" rel="sn" mi="PR0CS000"/>
#      </NODE>
#      <NODE ord="6" form="ya" lem="ya" pos="rg" cpos="r" head="5" rel="cc" mi=""/>
#      <NODE ord="8" form="vive" lem="vivir" pos="vm" cpos="v" head="5" rel="cd" mi="VMIP3S0">
#        <NODE ord="7" form="no" lem="no" pos="rn" cpos="r" head="8" rel="mod" mi="RN"/>
#        <NODE ord="9" form="aquí" lem="aquí" pos="rg" cpos="r" head="8" rel="cc" mi=""/>
#      </NODE>
#      <NODE ord="10" form="." lem="." pos="fp" cpos="F" head="5" rel="f" mi="Fp"/>
#    </NODE>
#  </SENTENCE>



					 # find rel-prn within PP
					 my $relprn = ${$node->findnodes('NODE[@pos="sp"]/NODE[starts-with(@mi,"PR")]')}[-1];
					 my $subj =  ${$node->findnodes('../descendant::*[(@rel="suj" or @rel="cd-a") and @cpos="n"][1]')}[0];

				
					 
					 #check if subj should be the head of the rel-clause (head preceeds rel-prn)
					 if($relprn && $subj && ( $relprn->getAttribute('ord') > $subj->getAttribute('ord') && &preceedNoVerbinBetween($subj,$node) ))
					 { 
					 	 	$node->setAttribute('head', $subj->getAttribute('ord'));
					 	 	$head = $subj->getAttribute('ord');
					 	 	$node->setAttribute('rel', 'S');
					 	 	$parent->appendChild($subj);
					 	 	$subj->appendChild($node);
					 	
					 	 	if($parent->nodeName() eq 'SENTENCE')
					 	 	{
					 	 		$subj->setAttribute('si', 'top');
					 	 		$subj->setAttribute('head', '0');
					 	 	}
					 	 	else
					 	 	{
					 	 		if($parent->nodeName() eq 'NODE')
					 	 		{
					 	 			$subj->setAttribute('head', $parent->getAttribute('ord'));
					 	 		}
					 	 		else
					 	 		{
					 	 			$subj->setAttribute('head', $parent->getAttribute('ord'));
					 	 		}
					 	 	}
					 	 	$parent=$subj;
					 }

# rel-clause attached to main verb instead of nominal head.... leave?
#  <SENTENCE ord="1">
#    <NODE ord="8" form="vive" lem="vivir" pos="vm" cpos="v" head="0" rel="sentence" mi="VMIP3S0">
#      <NODE ord="2" form="mujer" lem="mujer" pos="nc" cpos="n" head="8" rel="suj" mi="NCFS000">
#        <NODE ord="1" form="La" lem="el" pos="da" cpos="d" head="2" rel="spec" mi="DA0FS0"/>
#      </NODE>
#      <NODE ord="3" form="a" lem="a" pos="sp" cpos="s" head="8" rel="cd" mi="SPS00">
#        <NODE ord="4" form="quien" lem="quien" pos="pr" cpos="p" head="3" rel="sn" mi="PR0CS000"/>
#      </NODE>
#      <NODE ord="5" form="dejaron" lem="dejar" pos="vm" cpos="v" head="8" rel="v" mi="VMIS3P0"/>
#      <NODE ord="6" form="ya" lem="ya" pos="rg" cpos="r" head="8" rel="cc" mi=""/>
#      <NODE ord="7" form="no" lem="no" pos="rn" cpos="r" head="8" rel="mod" mi="RN"/>
#      <NODE ord="9" form="aquí" lem="aquí" pos="rg" cpos="r" head="8" rel="cc" mi=""/>
#      <NODE ord="10" form="." lem="." pos="fp" cpos="F" head="8" rel="f" mi="Fp"/>
#    </NODE>
#  </SENTENCE>



					 	# if this verb is labeled as 'suj', but is local person -> change label to 'S'
					 	if($node->getAttribute('rel') eq 'suj' && $node->getAttribute('mi') =~ /1|2/ )
					 	{
					 		$node->setAttribute('rel','S');
					 	}
					 	# if this is a gerund labeled as 'suj' with no verbal child node -> change label to 'cc'
					 	elsif($node->getAttribute('rel') eq 'suj' && $node->getAttribute('mi') =~ /^VMG/ && !$node->exists('child::NODE[@lem="estar"]'))
					 	{
					 		$node->setAttribute('rel','gerundi');
					 	}
					 	#if this verb chunk is labeled as 'cd' but main verb has no 'que' and this is not an infinitive: change label to 'S'
					 	elsif($node->getAttribute('rel') eq 'cd' && $node->getAttribute('mi') !~ /^V[MAS]N/ && !$parent->exists('descendant::NODE[@lem="que"]' ))
					 	{
					 		$node->setAttribute('rel','S');
					 	}
					 # relative clauses: if head of verbchunk is a nominal chunk + verbchunk has descendant = relative pronoun -> set si="S"
					 if($node->exists('parent::NODE[@cpos="n"]') && $node->exists('child::NODE[@pos="pr"]'))
					 {
					 		 $verbchunk->setAttribute('si', 'S');
					 }
					 else
					 {
					 	$verbchunk->setAttribute('si', $node->getAttribute('rel'));
					 }
					 
				
			    	$verbchunk->setAttribute('ord', $node->getAttribute('ord'));
				
					#$node->removeAttribute('rel');
					$node->removeAttribute('head');
					$verbchunk->appendChild($node);
			 
					 eval{$parent->appendChild($verbchunk);};
					 warn  "could not attach verbchunk".$node->getAttribute('ord')."to head in sentence: $sentenceId" if $@;
					 
					 # the key in hash should point now to the chunk instead of the node
					 my $ord = $node->getAttribute('ord');
					 my $idKey = "$sentenceId:$ord";
					 $docHash{$idKey}= $verbchunk;
				}
				# if this is a noun, a personal or a demonstrative pronoun, or a number, make a nominal chunk (sn)
				# change 13.04.2015: put PT (interrogative non-attributive pronouns) in their own chunk, so they can be moved independently of the verb
				elsif ($node->exists('self::NODE[@cpos="n" or @pos="pp" or @pos="pd" or @pos="pi" or @pos="Z" or @pos="pt"]'))
				{
					 my $nounchunk = XML::LibXML::Element->new( 'CHUNK' );
					 #if this node is parent of a coordination
					 if ($node->exists('child::NODE[@lem="ni" or @rel="coord"]'))
					 {
					 	$nounchunk->setAttribute('type', 'coor-n');
					 	# if coordinated prsprn -> mostly wrong-> correct
					 	if($node->getAttribute('pos') eq 'pp')
					 	{
					 		&correctCoord($node, $sentenceId);
					 	}
					 }
					 # no coordination
					 else
					 {
					 	$nounchunk->setAttribute('type', 'sn');
					 }
					 #print STDERR "node: ".$node->getAttribute('lem')." ,parent: ".$parent->toString."\n" if $verbose;
					 # if this is suj -> check if congruent with finite verb, check also if parent is a verbchunk
					 if($node->getAttribute('rel') eq 'suj' && $parent->exists('self::*[@type="grup-verb" or @cpos="v" or @type="coor-v"]') && &isCongruent($node, $parent) == 0)
					 {
					 		$node->setAttribute('rel', 'cd-a');
					 }
					 # if this is 'lo/la' and pp-> change to cd
					 if($node->getAttribute('lem') eq 'lo')
					 {
					 	$node->setAttribute('rel', 'cd'); 
					 }
					 # if this is 'le' and pp-> change to ci
					 elsif($node->getAttribute('lem') eq 'le')
					 {
					 	$node->setAttribute('rel', 'ci'); 
					 }
					 # if this is tú/yo/ etc and congruent with verb -> this is the subject
					 #if($node->getAttribute('lem') =~ /^yo|tú|él|ellos|nosotros|vosotros/ && $parent->exists('self::*[@type="grup-verb" or @cpos="v"]') && &isCongruent($node,$parent) ==1 )
					 # problem: STDIN is set to :utf8, libxml doesn't like that, can't match tú/él directly
					 if($node->getAttribute('mi') =~ /PP2CSN0.|PP3.S000/ && $parent->exists('self::*[@type="grup-verb" or @cpos="v"]') && &isCongruent($node,$parent))
					 {
					 	$node->setAttribute('rel', 'suj-a');
					 }
					 elsif($node->getAttribute('lem') =~ /^yo|ellos|nosotros|vosotros/ && $parent->exists('self::*[@type="grup-verb" or @cpos="v"]') && &isCongruent($node,$parent) )
					 {
					 	$node->setAttribute('rel', 'suj-a');
					 }
					 $nounchunk->setAttribute('si', $node->getAttribute('rel'));
					 $nounchunk->setAttribute('ord', $node->getAttribute('ord'));
					 #$node->removeAttribute('rel');
					 $node->removeAttribute('head');
					 $nounchunk->appendChild($node);
					 $parent = &attachNewChunkUnderChunk($nounchunk,$parent,$sentence); # $parent->appendChild($nounchunk);
					 # the key in hash should point now to the chunk instead of the node
					 my $ord = $node->getAttribute('ord');
					 my $idKey = "$sentenceId:$ord";
					 $docHash{$idKey}= $nounchunk;
					 #check if there are already child chunks attached (corrected rel. clauses), if so, attach them to noun chunk
					 for my $chunkchild ($node->getElementsByTagName('CHUNK'))
					 {
					 	$nounchunk->appendChild($chunkchild);	
					 }
				}
				# if this is a preposition, make a prepositional chunk (grup-sp)
				elsif ($node->exists('self::NODE[starts-with(@mi,"SP")]'))
				{
					 #print STDERR "parent of prep: \n".$parent->toString."\n" if $verbose;
					 # if head is an infinitive (para hacer, voy a hacer, de hacer etc)-> don't create a chunk, preposition just hangs below verb
					 # check if preposition precedes infinitive, otherwise make a chunk
					 if($parent->exists('self::CHUNK/NODE[@mi="VMN0000" or @mi="VSN0000"]') && $parent->getAttribute('ord')> $node->getAttribute('ord'))
					 {
					 }
					 else
					 {
					 	my $ppchunk = XML::LibXML::Element->new( 'CHUNK' );
					  	#if this node is parent of a coordination
					 	if ($node->exists('child::NODE[@lem="ni" or @rel="coord"]'))
					 	{
					 		$ppchunk->setAttribute('type', 'coor-sp');
						 }
						 # no coordination
						 else
						 {
					 		$ppchunk->setAttribute('type', 'grup-sp');
						 }
						 my $rel = $node->getAttribute('rel');
						 # check if preposition has been labeled as subject -> happens in dates since maltparser hasnt learned how to parse those splitted (multitokens in ancora)
						 # -> change label to atr
						 if($rel eq 'suj'){
						 	$rel = 'atr';
						 }
						 elsif($rel eq 'cd' && $node->getAttribute('lem') ne 'a'){
						 	$rel = 'cc';
						 }
						
						 $ppchunk->setAttribute('si', $rel);
						 $ppchunk->setAttribute('ord', $node->getAttribute('ord'));
						 #$node->removeAttribute('rel');
						 $node->removeAttribute('head');
						 $ppchunk->appendChild($node);
						 $parent->appendChild($ppchunk);
						  # the key in hash should point now to the chunk instead of the node
						 my $ord = $node->getAttribute('ord');
						 my $idKey = "$sentenceId:$ord";
						 $docHash{$idKey}= $ppchunk;
					 }
				}
				# if this is an adjective, make an adjective chunk (sa)
				elsif ($node->exists('self::NODE[starts-with(@mi,"A")]'))
				{
					 my $sachunk = XML::LibXML::Element->new( 'CHUNK' );
					  #if this node is parent of a coordination
					 if ($node->exists('child::NODE[@lem="ni" or @rel="coord"]'))
					 {
					 	$sachunk->setAttribute('type', 'coor-sa');
					 }
					 # no coordination
					 else
					 {
					 	$sachunk->setAttribute('type', 'sa');
					 }
					 $sachunk->setAttribute('si', $node->getAttribute('rel'));
					 $sachunk->setAttribute('ord', $node->getAttribute('ord'));
					 #$node->removeAttribute('rel');
					 $node->removeAttribute('head');
					 $sachunk->appendChild($node);
					$parent = &attachNewChunkUnderChunk($sachunk,$parent,$sentence);
					 #$parent->appendChild($sachunk);
					  # the key in hash should point now to the chunk instead of the node
					 my $ord = $node->getAttribute('ord');
					 my $idKey = "$sentenceId:$ord";
					 $docHash{$idKey}= $sachunk;
				}
				
				# if this is an adverb, make an adverb chunk (sadv)
				elsif ($node->exists('self::NODE[starts-with(@mi,"R")]'))
				{
					 my $sadvchunk = XML::LibXML::Element->new( 'CHUNK' );
					  #if this node is parent of a coordination
					 if ($node->exists('child::NODE[@lem="ni" or @rel="coord"]'))
					 {
					 	$sadvchunk->setAttribute('type', 'coor-sadv');
					 }
					 # no coordination
					 else
					 {
					 	$sadvchunk->setAttribute('type', 'sadv');
					 }
					 $sadvchunk->setAttribute('si', $node->getAttribute('rel'));
					 $sadvchunk->setAttribute('ord', $node->getAttribute('ord'));
					 #$node->removeAttribute('rel');
					 $node->removeAttribute('head');
					 $sadvchunk->appendChild($node);
					$parent = &attachNewChunkUnderChunk($sadvchunk,$parent,$sentence);
					#if ($parent->nodeName eq 'NODE') {
					#	print STDERR "adverb chunk" . $sadvchunk->toString(). " within NODE ". $parent->toString() ." has to be appended to a higher CHUNK\n" if $verbose;
					#	$parent = @{$parent->findnodes('ancestor::CHUNK[1]')}[0];
					#}
					 #$parent->appendChild($sadvchunk);
					  # the key in hash should point now to the chunk instead of the node
					 my $ord = $node->getAttribute('ord');
					 my $idKey = "$sentenceId:$ord";
					 $docHash{$idKey}= $sadvchunk;
				}
				# if this is a subordination (CS), check if attached to correct verb (gets often attached to main clause instead of subordinated verb)
				elsif($node->getAttribute('pos') eq 'cs' && !$parent->exists('child::NODE[@pos="vs"]') )
				{
					&attachCSToCorrectHead($node, $sentence);
				}
				# if this is punctuation mark 
				elsif ($node->exists('self::NODE[starts-with(@mi,"F")]'))
				{
					 my $fpchunk = XML::LibXML::Element->new( 'CHUNK' );
					 $fpchunk->setAttribute('type', 'F-term');
					 $fpchunk->setAttribute('si', 'term');
					 $fpchunk->setAttribute('ord', $node->getAttribute('ord'));
					 $node->removeAttribute('rel');
					 $node->removeAttribute('head');
					 $fpchunk->appendChild($node);
					 				 
					 # if punctuation has childnodes -> wrong, append those to parent of punctuation mark
					 # unless this is the head of the sentence, in this case make first verb head of sentence
	
					if($parent->nodeName eq 'SENTENCE')
					{
					 	my $realMainVerb = @{$node->findnodes('child::NODE[@cpos="v" and not(@rel="v")][1]')}[0];
					 	my $firstchild = @{$node->findnodes('child::NODE[not(@cpos="F")][1]')}[0];
					 	
					 	if($realMainVerb)
					 	{
					 		$parent->appendChild($realMainVerb);
					 		$realMainVerb->setAttribute('head', '0');
					 		$parent = $realMainVerb;
					 	}
					 	# else, no main verb (this is a title), take first child as head of sentence
					 	elsif($firstchild)
					 	{
					 		$parent->appendChild($firstchild);
					 		$firstchild->setAttribute('head', '0');
					 		$parent = $firstchild;
					 	}
					 	# else: sentence consists only of punctuation marks? 
					 	# append to Chunk and leave as is..
					 	else
					 	{
					 		$fpchunk->appendChild($node);
					 		eval {$parent->appendChild($fpchunk);};
							warn  "could not append punctuation chunk to parent chunk".$node->getAttribute('ord')." in sentence: $sentenceId" if $@;
					 		next;
					 	}
					 }
					 my @children = $node->childNodes();
					 foreach my $child (@children)
					 {
					 	{	eval
					 		{
					 			$parent->appendChild($child);
					 			$child->setAttribute('head', $parent->getAttribute('ord'));
					 		};
							warn  "could not reattach child of punctuation chunk".$node->getAttribute('ord')." in sentence: $sentenceId" if $@;	
					 	}
					 }
	
					 eval {$parent->appendChild($fpchunk);};
					 warn  "could not append punctuation chunk to parent chunk".$node->getAttribute('ord')." in sentence: $sentenceId" if $@;
				     # the key in hash should point now to the chunk instead of the node
					 my $ord = $node->getAttribute('ord');
					 my $idKey = "$sentenceId:$ord";
					 $docHash{$idKey}= $fpchunk;
				}
				# if this is a date
				elsif ($node->exists('self::NODE[@mi="W"]') or ( $node->exists('self::NODE[@mi="Z"]') && &numberIsPartOfDate($node)  ) )
				{
					 my $datechunk = XML::LibXML::Element->new( 'CHUNK' );
					 $datechunk->setAttribute('type', 'date');
					 $datechunk->setAttribute('si', $node->getAttribute('rel'));
					 $datechunk->setAttribute('ord', $node->getAttribute('ord')); 
					 $node->removeAttribute('rel');
					 $node->removeAttribute('head');
					 $datechunk->appendChild($node);
					 $parent->appendChild($datechunk);
					 # the key in hash should point now to the chunk instead of the node
					 my $ord = $node->getAttribute('ord');
					 my $idKey = "$sentenceId:$ord";
					 $docHash{$idKey}= $datechunk;
				}
				# if this is an interjection
				elsif ($node->exists('self::NODE[@mi="I"]'))
				{
					 my $interjectionchunk = XML::LibXML::Element->new( 'CHUNK' );
					 $interjectionchunk->setAttribute('type', 'interjec');
					 $interjectionchunk->setAttribute('si', $node->getAttribute('rel'));
					 $interjectionchunk->setAttribute('ord', $node->getAttribute('ord')); 
					 $node->removeAttribute('rel');
					 $node->removeAttribute('head');
					 $interjectionchunk->appendChild($node);
					 $parent->appendChild($interjectionchunk);
					 # the key in hash should point now to the chunk instead of the node
					 my $ord = $node->getAttribute('ord');
					 my $idKey = "$sentenceId:$ord";
					 $docHash{$idKey}= $interjectionchunk;
				}			
				else
				{
					#if this is a chunk
					if($node->nodeName() eq 'CHUNK')
					{
						$parent->appendChild($node);
					}
	
				}		
			# set si of root to 'top'
			if($head eq '0')
			{
				my $chunkparent = $node->parentNode();
				if($chunkparent && $chunkparent->exists('self::CHUNK') )
				{
					$chunkparent->setAttribute('si', 'top');
					$chunkparent->setAttribute('ord', $node->getAttribute('ord'));
				}
			}
		}
#	#my $docstring = $dom->toString(3);
#	#print STDERR $docstring;
#	#print STDERR "\n------------------------\n";
#		
	 	# sentence complete: check if topnode is a CHUNK, if not, change this
	 	# otherwise lexical transfer crashes!
		if($sentence->exists('child::NODE'))
		{
			&moveTopNodeUnderChunk($sentence);
		}
		# soler+inf -> inf as cd -> change			
#						  <SENTENCE ord="1">
#						    <CHUNK type="grup-verb" si="top" ord="1">
#						      <NODE ord="1" form="Solían" lem="soler" pos="vm" cpos="v" rel="sentence" mi="VMII3P0"/>
#						      <CHUNK type="grup-verb" si="cd" ord="2">
#						        <NODE ord="2" form="dormir" lem="dormir" pos="vm" cpos="v" rel="cd" mi="VMN0000"/>
#						        <CHUNK type="sadv" si="cc" ord="3">
#						          <NODE ord="3" form="temprano" lem="temprano" pos="rg" cpos="r" rel="cc" mi="RG"/>
#						        </CHUNK>
#						      </CHUNK>
#						      <CHUNK type="F-term" si="term" ord="4">
#						        <NODE ord="4" form="." lem="." pos="fp" cpos="F" mi="Fp"/>
#						      </CHUNK>
#						    </CHUNK>
#						  </SENTENCE>
						
				my @solerswithCD = $sentence->findnodes('descendant::CHUNK[(@type="grup-verb" or @type="coor-v") and NODE[@lem="soler"] and CHUNK[(@type="grup-verb" or @type="coor-v") and @si="cd"]/NODE[@mi="VMN0000"] ]');
				if(scalar(@solerswithCD)>0){
					foreach my $solerchunk (@solerswithCD){
						my ($inf) = $solerchunk->findnodes('child::CHUNK[(@type="grup-verb" or @type="coor-v") and @si="cd" and NODE[@mi="VMN0000"] ]');
						if($inf){
							my $inford = $inf->findvalue('child::NODE[@mi="VMN0000"]/@ord');
							my $solerord = $solerchunk->findvalue('child::NODE[@lem="soler"]/@ord');
							if($solerord+1 == $inford){
								my $solerparent = $solerchunk->parentNode();
								my ($solernode) = $solerchunk->findnodes('child::NODE[@lem="soler"]');
								my ($infnode) = $inf->findnodes('child::NODE[@mi="VMN0000"]');
								
								if($solerparent && $solernode && $infnode){
									$infnode->appendChild($solernode);
									$solernode->setAttribute('rel', 'v');
									$solerparent->appendChild($inf);
									my @solerchildren = $solerchunk->childNodes();
							
									foreach my $solerchild(@solerchildren){
										$inf->appendChild($solerchild);
									}
									
									$inf->setAttribute('si', $solerchunk->getAttribute('si'));
									$solerparent->removeChild($solerchunk);
								}
								
								
								
							}
							
							#print STDERR "ord soler $solerord, ord inf: $inford\n";
						}
					}
				}

				# if there is a main verb in the chunk labeled as VA with a child node  VMG -> make gerund head!
				my @falseAux = $sentence->findnodes('descendant::CHUNK[(@type="grup-verb" or @type="coor-v") and NODE[(@lem="estar" and @pos="va") or @lem="ser"] and CHUNK[NODE[@mi="VMG0000"]] ]');
				if(scalar(@falseAux) > 0)
				{ 
					foreach my $aux (@falseAux)
					{
							my ($gerund) = $aux->findnodes('child::CHUNK[NODE[@mi="VMG0000"]][1]');
							if($gerund)
							{
								my ($gerundnode) = $gerund->findnodes('child::NODE[@mi="VMG0000"][1]');
						 		my ($auxnode) = $aux->findnodes('child::NODE[@lem="estar" or @lem="ser"]');
						 		my $parent = $aux->parentNode();
						 		$parent->appendChild($gerund);
						 		my @auxchildren = $aux->childNodes();
						 		$parent->removeChild($aux);
						 		
						 		foreach my $child(@auxchildren){
					 				$gerund->appendChild($child);
					 			}
						 		$gerundnode->appendChild($auxnode);	
						 		$auxnode->setAttribute('rel', 'v');
						 		$gerund->setAttribute('si', $aux->getAttribute('si'));
					 		}
					}

				}
				# ir a +infinitive 
#				<CHUNK type="grup-verb" si="top" ord="1">
#			      <NODE ord="1" form="Van" lem="ir" pos="vm" cpos="v" rel="sentence" mi="VMIP3P0"/>
#			      <CHUNK type="grup-verb" si="S" ord="3">
#			        <NODE ord="3" form="pensarlo" lem="pensar" pos="vm" cpos="v" rel="S" mi="VMN0000">
#			          <NODE ord="2" form="a" lem="a" pos="sp" cpos="s" head="3" rel="s" mi="SPS00"/>
#			        </NODE>
				my @irAinf = $sentence->findnodes('descendant::CHUNK[(@type="grup-verb" or @type="coor-v") and NODE[@lem="ir"] and CHUNK[(@type="grup-verb" or @type="coor-v") and NODE[@mi="VMN0000" and NODE[@lem="a"]  ]  ] ]');
				if(scalar(@irAinf)>0){
					print STDERR "jssfsdfsdfsfhsfhdf\n";
					foreach my $ir (@irAinf){
						my ($inf) = $ir->findnodes('child::CHUNK[(@type="grup-verb" or @type="coor-v") and NODE[@mi="VMN0000" and NODE[@lem="a"]] ]');
						if($inf){
							my $parent = $ir->parentNode();
							my ($irnode) = $ir->findnodes('child::NODE[@lem="ir"][1]');
							my ($infnode) = $inf->findnodes('child::NODE[@mi="VMN0000"][1]');
							
							$parent->appendChild($inf);
							my @irchildren = $ir->childNodes();
							$parent->removeChild($ir);
							foreach my $irchild (@irchildren){
								$infnode->appendChild($irchild);
								
							}
							$infnode->appendChild($irnode);
							
						} 

						
					}
				}
		
		
		# check if main verb is in fact a subordinated clause, if so, make second grup-verb head
		# if coordinated vp: don't take first child grup-verb (this is the coordinated vp), take the last
		# note: if parser made something else head of sentence, the top verb might not have si=top
		my $topverbchunk = @{$sentence->findnodes('child::CHUNK[(@type="grup-verb" or @type="coor-v") and @si="top"][1]')}[0];
		#my $topverbchunk = @{$sentence->findnodes('child::CHUNK[(@type="grup-verb" or @type="coor-v")][1]')}[0];
		if($topverbchunk && $topverbchunk->exists('child::NODE[@cpos="v"]/descendant::NODE[@pos="cs"]'))
		{ print STDERR "in sentence $sentenceId, top chunk is".$topverbchunk->getAttribute('ord')."\n" if $verbose;
				my $realMain = @{$topverbchunk->findnodes('child::CHUNK[@type="grup-verb" or @type="coor-v"]/NODE[@cpos="v" and not(child::NODE[@pos="cs"])]')}[-1];
				if($realMain)
				{
					print STDERR "real main verb: ".$realMain->toString() if $verbose;
					$topverbchunk->parentNode->appendChild($realMain->parentNode());
					$realMain->parentNode()->appendChild($topverbchunk);			
					$topverbchunk->setAttribute('si', 'S');
					$realMain->parentNode->setAttribute('si', 'top');
				}
		}
		my @verbchunks = $sentence->findnodes('descendant::CHUNK[@type="grup-verb" or @type="coor-v"]');
		foreach my $verbchunk (@verbchunks)
		{
				 	# check if one of the verbs in this sentence has more than one subject (can happen with statistical parsers!), if only one is congruent with the verb, make this the subject 
					# and the other 'cd-a', if more than one is congruent, make the first one the subject (the one that precedes the verb)
					# simpler: check if first subject is congruent, if not, check next etc
					my @subjectNodes = $verbchunk->findnodes('child::CHUNK[@si="suj"]/NODE[@rel="suj"]');
				    if(scalar(@subjectNodes) > 1)
					{  
						#print STDERR "verb chunk ord: ".$verbchunk->getAttribute('ord'). "\n" if $verbose;
					 	my %subjs =();
					 	foreach my $subjCand (@subjectNodes)
					 	{
					 		my $ord = $subjCand->getAttribute('ord');
					 		$subjs{$ord} = $subjCand;
					 		print STDERR "to many subjects: ".$subjCand->getAttribute('lem')." ord: ".$ord."\n" if $verbose;
					 	}
					 	
					 	my $candIsSubj = 0;
					 	foreach my $ord (sort {$a<=>$b} (keys (%subjs))) 
					 	{
					 		my $subjCand = $subjs{$ord};
					 		if(&isCongruent($subjCand,$verbchunk) && $candIsSubj == 0)
					 		{
					 			print STDERR "correct subj: ".$subjCand->getAttribute('lem')."\n" if $verbose;
					 			$candIsSubj =1;
					 		}
					 		else
					 		{
					 			$subjCand->parentNode->setAttribute('si', 'cd-a');
					 			$subjCand->setAttribute('rel', 'cd-a');
					 		}
					 		#print STDERR "sorted lemma subj: ".$subjCand->getAttribute('lem')." ord: ".$ord."\n" if $verbose;
					 	}
					 	
					 }
		}
		# check if all chunks are children of chunks (if nodes have child chunks, the lexical transfer module is not amused)
		foreach my $chunk ($sentence->getElementsByTagName('CHUNK'))
		{
			if($chunk->parentNode->nodeName eq 'NODE')
			{
				my $realparent = @{$chunk->findnodes('ancestor::CHUNK[1]')}[0];
				if($realparent){
					$realparent->appendChild($chunk);
				}
				else{
					$sentence->appendChild($chunk);
				}
			}
		}
		# make sure no chunk has a sibling node, lexical transfer module doesn't like that either
		my @nodesWithChunkSiblings = $sentence->findnodes('descendant::NODE[preceding-sibling::CHUNK]');			
		foreach my $node (@nodesWithChunkSiblings)
		{		# print STDERR "node sibl: ".$node->toString()."\n" if $verbose;
				# if CC or CS -> try to attach it to the following verb chunk, if that fails to the preceding
				# if there's no verb chunk, attach it to the next higher chunk (probably an error by the tagger, but let's try to avoid 
				# making the lexical transfer fail)
				# NOTE: no need to copy children of sibling, as NODE with child CHUNKS have already been taken care of above
				my $possibleHead = @{$node->findnodes('ancestor::CHUNK[@type="grup-verb" or @type="coor-v"]/NODE/descendant-or-self::NODE')}[0];
				my $possibleHead2 = @{$node->findnodes('descendant::CHUNK[@type="grup-verb" or @type="coor-v"]/NODE/descendant-or-self::NODE')}[0];					
				if($possibleHead){
					$possibleHead->appendChild($node);
				}
				elsif($possibleHead2){
					$possibleHead->appendChild($node);
				}
				else{
					$possibleHead = @{$node->findnodes('ancestor::SENTENCE/CHUNK[@si="top"]/NODE/descendant-or-self::NODE')}[0];
					#print $possibleHead->toString()."\n\n";
					if($possibleHead){
						$possibleHead->appendChild($node);
					}
				}
		}
		
		# make sure nodes have no (node) siblings, again, lexical transfer module will crash
		# solution: attach second sibling as (last) child of first
		my @nodesWithNodeSiblings = $sentence->findnodes('descendant::NODE[preceding-sibling::NODE]');
		foreach my $node (@nodesWithNodeSiblings){
			my $prevsibling = $node->previousSibling();
			if($prevsibling){
				if ($prevsibling->getAttribute('mi') =~ /V...[1-3][SP]./) {	# finite
					$node->appendChild($prevsibling);
				} else {
					$prevsibling->appendChild($node);
				}
			}
		}	
		# delete chunks that have only chunk children, but no node children (otherwise lexical transfer crashes)
		# -> those are probably leftovers from changes to the tree, should not occur
		my @chunksWithNoNODEchildren = $sentence->findnodes('descendant::CHUNK[count(child::NODE)=0]');
		foreach my $chunk (@chunksWithNoNODEchildren){
			my $parentchunk = $chunk->parentNode();
			if($parentchunk && $parentchunk->nodeName eq 'CHUNK'){
				# attach this chunks' chunk children to its parent chunk, then delete it
				my @childChunks = $chunk->childNodes();
				foreach my $child (@childChunks){
					$parentchunk->appendChild($child);
				}
				$parentchunk->removeChild($chunk);
			}
		}
		
		# make sure final punctuation (.!?) is child of top chunk, if not, append to top chunk
		# -> otherwise punctuation will appear in some random position in the translated output!
		# TODO: ! and ? -> direct speech!!
		# my @finalPunc = $sentence->findnodes('descendant::NODE[@lem="." or @lem="!" or @lem="?"]');
		my @finalPunc = $sentence->findnodes('descendant::NODE[@lem="."]');
		foreach my $punc (@finalPunc){
				if(isLastNode($punc,$sentence) && !$punc->exists('parent::CHUNK/parent::SENTENCE') ){
					 my $topchunk = @{$sentence->findnodes('child::CHUNK[1]')}[0];
					 my $puncChunk = $punc->parentNode();
					 if($topchunk && $puncChunk){
					 	$topchunk->appendChild($puncChunk);
					 }
				 }
		}
		# if there's a sólo/solamente -> find right head
		# parser ALWAYS attaches this to the verb, but that may not be correct, 
		# e.g. 'Sólo Juan sabe lo que ha hecho.' TODO: nomás!
		if( $sentence->exists('descendant::NODE[@lem="sólo" or @lem="sólamente"]') )
		{
			my @solos = $sentence->findnodes('descendant::NODE[@lem="sólo" or @lem="sólamente"]');
			my $nodeHashref = &nodesIntoSortedHash($sentence);
			foreach my $solo (@solos){
				 my $soloOrd = $solo->getAttribute('ord');
				 my $chunk = @{$solo->findnodes('ancestor::CHUNK[1]')}[0];
				 my $parent = $chunk->parentNode();
				 my $nodeAfterSolo = $nodeHashref->{$soloOrd+1};
				 # if next node is a noun, sólo probably refers to that
				 if($nodeAfterSolo && $nodeAfterSolo->getAttribute('mi') =~ /^N/ ){
				 	 my $nodeAfterSoloParentChunk = @{$nodeAfterSolo->findnodes('ancestor::CHUNK[1]')}[0];
				 	 if($nodeAfterSoloParentChunk && $chunk && $parent)
				 	 {
				 	 	$parent->removeChild($chunk);
				 	 	# if $nodeAfterSoloParentChunk is descendant of solo -> attach this chunk first to parent,
				 	 	# then attach chunk to $nodeAfterSoloParentChunk to avoid hierarchy request errors
				 	 	if(&isAncestor($nodeAfterSoloParentChunk, $chunk)){
				 	 		$parent->appendChild($nodeAfterSoloParentChunk);
				 	 	}
				 	 	$nodeAfterSoloParentChunk->appendChild($chunk);
				 	 }
				 }
			}
		}
		my ($speechverb) = $sentence->findnodes('descendant::CHUNK[count(descendant::CHUNK[@si="suj"] )=0]/NODE[@lem="hablar" or @lem="contestar" or @lem="decir"]');
		# X le habla/contesta/dice -> parser NEVER labels X as suj, but instead as cc or cd.. if no complement clause with que -> automatically make suj
		if($speechverb){
			my @potentialsubjs = $speechverb->findnodes('parent::CHUNK/CHUNK[(@type="sn" or @type="coor-n")  and (@si="cc" or @si="cd")]');
			if(scalar(@potentialsubjs)>0){
				# find le/les
				my ($clitic) = $speechverb->findnodes('parent::CHUNK/CHUNK[@type="sn"]/NODE[@lem="le" and @pos="pp"]');
				if($clitic){
					my $cliticOrd = $clitic->getAttribute('ord');
					foreach my $potsub (@potentialsubjs){
						my $subjOrd= $potsub->getAttribute('ord');
						if($cliticOrd-1 == $subjOrd){
							$potsub->setAttribute('si', 'suj-a');
							last;
						}
					} 
				}
			}
		}
		# very rare, but possible: sentence has 2 top chunks (e.g. Autor: Braddy Romero Ricalde)
#		  <SENTENCE ord="1">
#			    <CHUNK type="sn" si="top" ord="1">
#			      <NODE ord="1" form="Autor" lem="autor" pos="nc" cpos="n" rel="sentence" mi="NCMS000"/>
#			      <CHUNK type="F-term" si="term" ord="2">
#			        <NODE ord="2" form=":" lem=":" pos="Fd" cpos="F" mi="FD"/>
#			      </CHUNK>
#			    </CHUNK>
#			    <CHUNK type="sn" si="top" ord="3">
#			      <NODE ord="3" form="Braddy_romero_ricalde" lem="braddy_romero_ricalde" pos="np" cpos="n" rel="sentence" mi="NP00SP0"/>
#			    </CHUNK>
#			  </SENTENCE>
# 			---> attach second top chunk as child of first top chunk: otherwise, ordering will make them both ord=0 
		my @topChunks = $sentence->findnodes('child::CHUNK');
		if(scalar(@topChunks)>1){
			my $firstTopChunk = @topChunks[0];
			for(my $i=1;$i<scalar(@topChunks);$i++){
				my $chunk = @topChunks[$i];
				$firstTopChunk->appendChild($chunk);
			}
		}
		
		
		# check if this sentence contains a verb chunk with more than one finite verb in it
		# -> make two chunks 
		my @verbchunksWithTwoFiniteVerbs =  $sentence->findnodes('descendant::CHUNK[@type="grup-verb" or @type="coor-v" and child::NODE/descendant-or-self::NODE[@cpos="v" and ( contains(@mi,"1") or contains(@mi,"2") or contains(@mi,"3") )]/descendant::NODE[@cpos="v" and ( contains(@mi,"1") or contains(@mi,"2") or contains(@mi,"3"))] ]' );
		
		if(scalar(@verbchunksWithTwoFiniteVerbs)>0)
		{ 
			foreach my $doubleVerbChunk (@verbchunksWithTwoFiniteVerbs)
			{
				#get both finite verbs
				my $topFiniteVerb = @{$doubleVerbChunk->findnodes('child::NODE/descendant-or-self::NODE[@cpos="v" and ( contains(@mi,"1") or contains(@mi,"2") or contains(@mi,"3") )][1]')}[0];
				if($topFiniteVerb)
				{
					my @dependendFiniteVerbs = $topFiniteVerb->findnodes('descendant::NODE[@cpos="v" and ( contains(@mi,"1") or contains(@mi,"2") or contains(@mi,"3") )]');
					# make new chunks and attach the chunks to verb chunk
					foreach my $finiteVerb (@dependendFiniteVerbs)
					{
						my $newVerbChunk = XML::LibXML::Element->new( 'CHUNK' );
					 	$newVerbChunk->setAttribute('type', 'grup-verb');
						$newVerbChunk->setAttribute('si', $finiteVerb->getAttribute('rel'));
					 	$newVerbChunk->setAttribute('ord', $finiteVerb->getAttribute('ord')); 
						$finiteVerb->removeAttribute('rel');
						$finiteVerb->removeAttribute('head');
					 	$newVerbChunk->appendChild($finiteVerb);
					 	$doubleVerbChunk->appendChild($newVerbChunk);
						
					}
				}
			
			}
		}
		

				
	}
	## print new xml to stdout
	#my $docstring = $dom->toString(3);
	#print STDOUT $docstring;

	return $dom;
}



sub isCongruent{
	my $subjNode =$_[0];
	my $parentNode = $_[1];
	
	if($parentNode && $subjNode)
	{
		#if parent is verb chunk, get the finite verb
		if($parentNode->nodeName() eq 'CHUNK')
		{
			$parentNode = &getFiniteVerb($parentNode);
			if($parentNode == -1)
			{
				return -1;
			}
		}
		# if this is not a finite verb, get finite verb! (wrong analysis, may happen)
		elsif($parentNode->getAttribute('mi') !~ /1|2|3/)
		{
			my $parentNodeCand = &getFiniteVerb($parentNode);
			if($parentNodeCand != -1)
			{
				$parentNode = $parentNodeCand;
				$parentNodeCand->toString()."\n\n";
			}
			#if no finite verb found, don't change anything
			else
			{
				return 1;
			}
		}
		#print STDERR "parentnode: ".$parentNode->toString."\n" if $verbose;
		my $verbMI = $parentNode->getAttribute('mi');
		my $verbPerson = substr ($verbMI, 4, 1);
		my $verbNumber = substr ($verbMI, 5, 1);
	
		my $subjMI = $subjNode->getAttribute('mi');
		my $nounPerson;
		my $nounNumber;
	
		# no need to disambiguate false 1/2 person subjects (parser gets those right, as they are marked with 'a' if cd)
		# but sometimes 'me, te, nos..' are labeled as 'suj' -> cd-a
		if($subjNode->getAttribute('pos') eq 'pp')
		{
			my $prs = $subjNode->getAttribute('mi');
			if($subjNode->exists('child::NODE[@lem="ni" or @rel="coord"]'))
			{
				my @coordElems = $subjNode->childNodes();
				foreach my $coordnode (@coordElems)
				{
					$coordnode = $coordnode->toString(); 
				}
				# if head is 2 prs sg/pl -> always 2pl or 3pl , except with 1 sg/pl-> 1pl
				# tú y el, vosotros y ellos,-> 3pl, but tú y yo, vosotros y nosotros -> 1pl
				if( $prs =~ /^PP2/)
				{
					#tú y yo/nosotros/as -> 1pl
					if(grep {$_ =~ /mi="PP1/} @coordElems)
					{
						$nounPerson = '1';
						$nounNumber = 'P';
					}
					#tú y Manuel, tú y el padre... -> 2pl
					else
					{
						$nounPerson = '23';
						$nounNumber = 'P';			
					}
				}
				# if head is 1 sg/pl -> coordination always 1pl (yo y tú/yo y él/yo y ustedes..vamos al cine)
				# nosotros y él, nosotros y tú, etc
				elsif($prs =~ /^PP1/)
				{
					$nounPerson = '1';
					$nounNumber = 'P';
				}
				# if PP3
				else
				{
					# él y yo, ellos y nosostros -> 1pl
					if(grep {$_ =~ /mi="PP1/} @coordElems)
					{
						$nounPerson = '1';
						$nounNumber = 'P';
					}
					# él y tú, ellos y vosostros -> 2pl
					elsif(grep {$_ =~ /mi="PP2/} @coordElems)
					{
						$nounPerson = '2';
						$nounNumber = 'P';
					}
					else
					{
						$nounPerson = '3';
						$nounNumber = 'P';
					}		
				}
			}
			# if 'me,te,se,nos,vos,os' as suj -> change to cd-a
			elsif($subjNode->exists('self::NODE[@lem="me" or @lem="te" or @lem="se" or @lem="nos" or @lem="vos" or @lem="os" or @lem="le" or @lem="lo"]'))
			{
				return 0;
			}
			#no coordination
			else
			{
				$nounPerson = substr ($subjMI, 2, 1);
				$nounNumber = substr ($subjMI, 4, 1);
				
				# if yo,él,ella and not congruent and verb is ambiguous 3rd/1st form 
				# cantaba (pasado imperfecto), cantaría (condicional), cante (subjuntivo presente),  cantara (subjuntivo imperfecto),cantare (subjuntivo futuro) 
				# -> change tag of verb!
				if($subjNode->exists('self::NODE[@lem="él" or @lem="ella"]') && $verbMI =~ /V.II1S0|V.IC1S0|V.SP1S0|V.SI1S0|V.SF1S0/ )
				{
					$verbMI =~ s/1/3/;
					$parentNode->setAttribute('mi', $verbMI);
					return 1;
				}
				elsif($subjNode->exists('self::NODE[@lem="yo"]') && $verbMI =~ /V.II3S0|V.IC3S0|V.SP1S0|V.SI3S0|V.SF3S0/ ){
					$verbMI =~ s/3/1/;
					$parentNode->setAttribute('mi', $verbMI);
					return 1;
				}
			}
		}
		#interrogative pronouns: no person (quién eres, quién soy..)
		elsif($subjMI =~ /^PT/){
			return 1;
		}
		else
		{
			$nounPerson = '3';
		
			# plural if coordinated subjects
			if($subjNode->exists('child::NODE[@lem="ni" or @rel="coord"]') )
			{
				$nounNumber = 'P';
			}
			#  exception with 'parte' -> 'una buena parte de ellos radican en países pobres..' -> ignore number
			elsif( $subjNode->getAttribute('lem') =~ /parte|n.mero/ || $subjNode->exists('child::NODE[@lem="%"]') || $subjNode->exists('child::CHUNK/NODE[@lem="%"]'))
			{
				return 1;
			}
			else
			{
				# if subject is a demonstrative or an indefinite pronoun (pd/pi), number is the 5th letter
				if($subjNode->getAttribute('cpos') eq 'p')
				{
					$nounNumber = $nounNumber = substr ($subjMI, 4, 1);
				}
				elsif($subjNode->getAttribute('pos') eq 'Z' && ($subjNode->getAttribute('lem') eq '1' || $subjNode->getAttribute('lem') eq 'uno' ))
				{
					$nounNumber = 'S';
				}
				elsif($subjNode->getAttribute('pos') eq 'Z' && ($subjNode->getAttribute('lem') ne '1' || $subjNode->getAttribute('lem') ne 'uno' ))
				{
					$nounNumber = 'P';
				}
				else
				{
					$nounNumber = substr ($subjMI, 3, 1);
					# proper names have no number, assume singular
					if($nounNumber eq '0')
					{
						#if number unknown, leave as is
						return 1;
						#$nounNumber = 'S';
					}
				}
			}
		}
	
#	my $verbform = $parentNode->getAttribute('form');
#	my $nounform = $subjNode->getAttribute('form');
#	my $nounmi = $subjNode->getAttribute('mi');
#	print STDERR "$nounform:$verbform  verbprs:$verbPerson, verbnmb:$verbNumber, nounPrs:$nounPerson, nounNumb:$nounNumber, nounMI: $nounmi\n" if $verbose;
	
		return ($nounPerson =~ $verbPerson && $nounNumber eq $verbNumber);
	}
	# if subject node or parent node doees not exist, don't change anything (this should not happen)
	else
	{
		return 1;
	}
}

sub getFiniteVerb{
	my $verbchunk = $_[0];
	
	#print STDERR "verbchunk: ".$verbchunk->toString() if $verbose;
	# finite verb is the one with a person marking (1,2,3)
	# case: only finite verb in chunk
	my @verb = $verbchunk->findnodes('child::NODE[starts-with(@mi,"V") and (contains(@mi,"3") or contains(@mi,"2") or contains(@mi,"1"))][1]');
	if(scalar(@verb)>0)
	{
		return @verb[0];
	}
	else
	{
		@verb = $verbchunk->findnodes('NODE/NODE[starts-with(@mi,"V") and (contains(@mi,"3") or contains(@mi,"2") or contains(@mi,"1")) ][1]');
		if(scalar(@verb)>0)
		{
			return @verb[0];
		}
		else
		{
		#get sentence id
		my $sentenceID = $verbchunk->findvalue('ancestor::SENTENCE/@ord');
		print STDERR "finite verb not found in sentence nr. $sentenceID: \n " if $verbose;
		print STDERR $verbchunk->toString() if $verbose;
		print STDERR "\n" if $verbose;
			return -1;
		}
	}
}

sub correctCoord{
	my $prsprn = $_[0];
	my $sentenceId = $_[1];
	if($prsprn)
	{
		my $coord = @{$prsprn->findnodes('child::NODE[@lem="ni" or @rel="coord"][1]')}[0];
		my @children = $prsprn->childNodes();

		# if no coordinated element attached, children =1 (only coord, 'y', 'o')
		# with ni: 2 childs ('ni tú ni yo vamos al cine')
		if(( $coord && scalar(@children) < 2 )|| ($prsprn->exists('child::NODE[@lem="ni"]') && scalar(@children) < 3 ) )
		{ 
			# if 'y'/'o' has a child, this is the coordinated element
			if($coord->hasChildNodes())
			{
				my @coordElems =  $coord->childNodes();
				foreach my $coordElem (@coordElems)
				{
					#attach to prsprn
					$prsprn->appendChild($coordElem);
					my $ord = $coordElem->getAttribute('ord');
					my $head = $prsprn->getAttribute('ord');
					$coordElem->setAttribute('head', $head);
					my $idKey = "$sentenceId:$ord";
					$docHash{$idKey}= $prsprn;
				}
			}
			else
			{
				#get coordinated element, probably first following sibling of prsprn
		 		my $coordElem = @{$prsprn->findnodes('following-sibling::NODE[1]')}[0];
				if($coordElem)
				{
					#attach coordinated element to coordination ('y', 'o'..)
					$prsprn->appendChild($coordElem);
					my $ord = $coordElem->getAttribute('ord');
					my $head = $prsprn->getAttribute('ord');
					$coordElem->setAttribute('head', $head);
					my $idKey = "$sentenceId:$ord";
					$docHash{$idKey}= $prsprn;
				}
			}
		}
	}
}

sub getHeadNoun{
	my $verbNode= $_[0];

	if($verbNode)
	{
		my $parentchunk = @{$verbNode->findnodes('../../self::CHUNK[@type="sn"][1]')}[0];
		my $headNoun;
		
		if($parentchunk)
		{
			#if preceded by single noun
			if($parentchunk->exists('self::CHUNK[@type="sn"]'))
			{
				# if head noun is a demonstrative pronoun (doesn't ocurr? TODO: check)
				$headNoun = @{$parentchunk->findnodes('child::NODE[starts-with(@mi,"N") or starts-with(@mi,"PP")][1]')}[-1];
			}

			#if head noun is defined, return 
			if($headNoun)
			{
				return $headNoun;
			}
			else
			{   #get sentence id
				print STDERR "Head noun not found in: \n" if $verbose;
				print STDERR $parentchunk->toString()."\n" if $verbose;
				return 0;
			}
		}
	}
}

sub hasRealSubj{
	my $verb = $_[0];
	
	my $subj = @{$verb->findnodes('child::NODE[@rel="suj"][1]')}[0];
	
	if($verb && $subj && &isCongruent($subj,$verb))
	{
		# check if 'real' subject (not 'me','te,'se' etc, check if really congruent!)
		# -> if prsprn and congruent: check case of prs-prn, if accusative-> this can't be a subject
		my $mi= $subj->getAttribute('mi');
		if($mi =~ /^PP/)
		{
			my $case = substr($mi,5,1);
			return ($case =~ /N|0/);	
		}
		return 1;
	}
	return 0;
}

sub nodesIntoSortedHash{
	my $sentence = $_[0];
	my %nodeHash =();

			# read sentence into hash, key is 'ord'
			foreach my $node ($sentence->getElementsByTagName('NODE'))
			{
				my $key = $node->getAttribute('ord');
				$nodeHash{$key} = $node;
			}
			my @sequence = sort {$a<=>$b} keys %nodeHash;
	return \%nodeHash;
}

sub attachCSToCorrectHead{
	my $cs = $_[0];
	my $sentence = $_[1];
	
	if($cs)
	{
		my $currentParent = $cs->parentNode;
	
		#if parent of subjunction is verb -> check if it's the right verb
		if($currentParent && $currentParent->getAttribute('cpos') eq 'v')
		{
			my %nodeHash =();
			my $followingMainVerb;
			# read sentence into hash, key is 'ord'
			foreach my $node ($sentence->getElementsByTagName('NODE'))
			{
				my $key = $node->getAttribute('ord');
				$nodeHash{$key} = $node;
			}
			my $csord = $cs->getAttribute('ord');
			my $parentord = $currentParent->getAttribute('ord');
		
			my @sequence = sort {$a<=>$b} keys %nodeHash;
			#print STDERR "@sequence\n length ".scalar(@sequence)."\n" if $verbose;
			my $isRelClause=0;
			
			for (my $i=$csord+1; $i<=scalar(@sequence);$i++)
			{
				my $node = $nodeHash{$i};
				#print STDERR "i: $i ".$node->getAttribute('form')."\n" if $verbose;
				if($node && $node->getAttribute('pos') eq 'pr'){
					$isRelClause =1;
				}
				if($node && $node->getAttribute('pos') eq 'vm' && (!$nodeHash{$i+1} ||  $nodeHash{$i+1}->getAttribute('pos') ne 'vm' ) )
				#if($node && $nodeHash{$i+1} && $node->getAttribute('pos') eq 'vm'  && $nodeHash{$i+1}->getAttribute('pos') ne 'vm' )
				{ 
					if($isRelClause){
						# if this is a relative Clause, skip, but set isRelClause to 0
						$isRelClause =0;
					}
					else{
						$followingMainVerb = $node;
						last;
					}
				}
			}
			#print STDERR  "foll verb: ".$followingMainVerb->getAttribute('form')."\n" if $verbose;
			#print STDERR  "current verb: ".$currentParent->getAttribute('form')."\n" if $verbose;
			if($followingMainVerb && !$followingMainVerb->isSameNode($currentParent))
			{
				#print STDERR "foll verb: ".$followingMainVerb->toString() if $verbose;
				#if verb is descendant of cs, first attach verb to head of cs, then attach cs to verb 
				# otherwise we get a hierarchy request err
				if(&isAncestor($followingMainVerb,$cs))
				{
					
					$currentParent->appendChild($followingMainVerb);
					$followingMainVerb->setAttribute('head', $currentParent->getAttribute('ord'));
				}
				$followingMainVerb->appendChild($cs);
				$cs->setAttribute('head', $followingMainVerb->getAttribute('ord'));
				# if cs has child nodes -> attach them to head of cs
#				my @csChildren = $cs->childNodes();
#				foreach my $child (@csChildren){
#					$followingMainVerb->appendChild($child);
#					$child->setAttribute('head', $followingMainVerb->getAttribute('ord'));
#				}
			}
			#TODO: check linear sequence, subjunction belongs to next following verb chunk (no verb in between!)
		}
		# if parent is not a verb, subjunction is probably the head of the clause.. look for verb in children!
#    <NODE ord="6" form="para_que" lem="para_que" pos="cs" cpos="c" head="5" rel="CONCAT" mi="CS">
#            <CHUNK type="sn" si="cd" ord="7">
#              <NODE ord="7" form="lo" lem="lo" pos="pp" cpos="p" rel="cd" mi="PP3MSA00">
#                <NODE ord="8" form="lean" lem="leer" pos="vm" cpos="v" head="7" rel="CONCAT" mi="VMSP3P0"/>

		else
		{
			my $headverb = @{$cs->findnodes('descendant::NODE[@pos="vm"][1]')}[0];
			if($headverb)
			{
				$currentParent->appendChild($headverb);
				$headverb->appendChild($cs);
				$cs->setAttribute('head', $headverb->getAttribute('ord'));
				$headverb->setAttribute('head', $currentParent->getAttribute('ord'));
		
				#append other children of cs to verb
				my @otherChildren = $cs->childNodes();
				foreach my $child (@otherChildren)
				{
					$headverb->appendChild($child);
					$child->setAttribute('head', $headverb->getAttribute('ord'));	
				}
			}
		}
	}
}

sub isAncestor{
	my $node = $_[0];
	my $maybeAncestor = $_[1];
	
	if($node && $maybeAncestor)
	{
		my $maybeAncestorOrd = $maybeAncestor->getAttribute('ord');
		my $xpath = 'ancestor::*[@ord="'.$maybeAncestorOrd.'"]';
	
		return($node->exists($xpath));
	}
	# this should not happen
	else
	{
		return 0;
	}
}


sub attachNewChunkUnderChunk{
	my $newChunk = $_[0];
	my $parent = $_[1];
	my $sentence = $_[2];

    if($newChunk && $parent)
    {
		#print STDERR "parent node before ". $parent->toString() . "\n" if $verbose;
		#print STDERR "parent nodeName before ". $parent->nodeName . "\n" if $verbose;
		if ($parent->nodeName eq 'NODE') {
			#print STDERR "new chunk" . $newChunk->toString(). " within NODE ". $parent->toString() ." has to be appended to a higher CHUNK\n" if $verbose;
			$parent = @{$parent->findnodes('ancestor::CHUNK[1]')}[0];
		}
		#print STDERR "parent node after ". $parent->toString() . "\n" if $verbose;
		if($parent)
		{
			$parent->appendChild($newChunk);
			return $parent;
		}
		# no parent chunk, attach to sentence
		else
		{
			$sentence->appendChild($newChunk);
			return $sentence;
		}
    }
    #this should not happen
    else
    {
    	print STDERR "failed to attach node to new chunk \n";
    }
}

# clitics stuff
# freeling could retokenize the enclitics but we don't split the verb forms before parsing
# because desr parser was apparently not trained on data with separate clitics
sub getCliticRelation{
	my $cltag = $_[0];

	my $rel;
	if ($cltag =~ /^PP...A/)
	{
		$rel = "cd";
	}
	elsif ($cltag =~ /^PP...D/)
	{
		$rel = "ci";
	}
	else
	{
		$rel = "cd/ci";
	}
	return $rel;
}

sub splitCliticsFromVerb{
	my $word = $_[0];
	my $vtag = $_[1];
	my $vlem = $_[2];

	my @vfcl;	# TODO change the verb form in the verb node? currently not...
	# gerund
	if ($vtag =~ /V.G/ and $word =~ /(.*ndo)([^d]+)/)
	{
		$vfcl[0] = $1;
		$vfcl[1] = $2;
		print STDERR "verb gerund $vfcl[0] ; clitics $vfcl[1]\n" if $verbose;
	}
	# infinitive
	elsif ($vtag =~ /V.N/ and $word =~ /(.*r)([^r]+)/)
	{
		$vfcl[0] = $1;
		$vfcl[1] = $2;
		print STDERR "verb infinitive $vfcl[0] ; clitics $vfcl[1]\n" if $verbose;
	}
	# imperative
	elsif ($vtag =~ /V.M/)
	{
		my $vend = "";
		# some imperative forms may end on "me|te|se|la|le" and not contain any clitic
		if ($vtag =~ /V.M02S0/ and $vlem =~ /([mst][ei]|la)r$/)	# cómetelas => come-telas (comer) ; vístete => viste-te (vestir) 
		{
			$vend = $1;
		}
		elsif ($vtag =~ /V.M03S/)
		{
			if ($vlem =~ /([mst]a)r$/)	# mátelo => mate-lo (matar)
			{
				$vend = $1;
				$vend =~ s/a/e/;
			}
			elsif ($vlem =~ /ler$/)	# demuélala => demuela-la (demoler)
			{
				$vend = "la";
			}
		}
		elsif ($vtag =~ /V.M01P0/) {
			$vend = "mos";
		}
		print STDERR "$vtag verb $vlem form ends in $vend\n" if $verbose;
		if ($word =~ /(.*?$vend)((me|te|nos|os|se|la|las|lo|los|le|les)+)$/)
		{
			$vfcl[0] = $1;
			$vfcl[1] = $2;
		}
		else
		{
			$vfcl[0] = $word;
			$vfcl[1] = "";
		}		
		print STDERR "verb imperative $vfcl[0] ; clitics $vfcl[1]\n" if $verbose;
	}
	return $vfcl[1];	# only return a single variable, the clitic string
}

sub getClitics{
	my $clstr = $_[0];
	
	my $cl = $clstr;
	my @clitics;
	while ($cl !~ /^$/) {
		if ($cl =~ /(.*)(la|las|lo|los|le|les)$/)
		{
			$cl = $1;
			unshift(@clitics,$2);
		}
		elsif ($cl =~ /(.*)(me|te|se|nos)$/)
		{
			$cl = $1;
			unshift(@clitics,$2);
		}
		elsif ($cl =~ /(.*)(os)$/)
		{
			$cl = $1;
			unshift(@clitics,$2);
		}
	}
	return \@clitics;
}

sub createAppendCliticNodes{
	my $sentence = $_[0];
	my $scount = $_[1];
	my $verbid = $_[2];
	my $clstr = $_[3];

	my $clid = int($verbid) + 0.1;
	my $clitics = &getClitics($clstr);
	foreach my $c (@{$clitics})
	{
		print STDERR "$c\n" if $verbose;
		my $cliticNode = XML::LibXML::Element->new( 'NODE' );
		$sentence->appendChild($cliticNode);
		$cliticNode->setAttribute( 'ord', $clid ); # TODO new id...
		$cliticNode->setAttribute( 'form', $c );
		$cliticNode->setAttribute( 'lem', $mapCliticFormToLemma{$c} );
		$cliticNode->setAttribute( 'pos', "pp" );
		$cliticNode->setAttribute( 'cpos', "p" );
		$cliticNode->setAttribute( 'head', $verbid );	# head of clitics is the verb itself
		my $cleaglesTag = $mapCliticToEaglesTag{$c};
		print STDERR "eagles tag for clitic $c : $cleaglesTag\n" if $verbose;
		my $clrel = &getCliticRelation($cleaglesTag);
		$cliticNode->setAttribute( 'rel', $clrel );	# TODO rel = cd|ci|creg? refl?
		print STDERR "possible relation for clitic $c : $clrel\n" if $verbose;
		$cliticNode->setAttribute( 'mi', $cleaglesTag );
		my $clkey = "$scount:$clid";
		$docHash{$clkey}= $cliticNode;
		$clid += 0.1;
	}
}

sub isLastNode{
	my $node = $_[0];
	my $sentence = $_[1];
	
	my %nodeHash =();

	# read sentence into hash, key is 'ord'
	foreach my $node ($sentence->findnodes('descendant::NODE'))
			{
				my $key = $node->getAttribute('ord');
				#print STDERR $node->getAttribute('form')."key: $key\n" if $verbose;
				$nodeHash{$key} = $node;
			}
			my $nodeord = $node->getAttribute('ord');
		
			my @sequence = sort {$a<=>$b} keys %nodeHash;			
			#print STDERR "last node: ".@sequence[0]."n" if $verbose;
			return ( scalar(@sequence)>1 && $nodeHash{@sequence[-1]}->isSameNode($node) );
			
}


sub moveTopNodeUnderChunk{
	my $sentence = $_[0];
	my $sentenceId = $sentence->getAttribute('ord');
	# wrong analysis, head of sentence is a node instead of chunk -> get first verb chunk and make this the head
	# if there is no verb chunk -> take the first child that a chunk (any type) and make this the head
	 my $topnode = @{$sentence->findnodes('child::NODE[1]')}[0];
	 my $firstverbchunk = @{$sentence->findnodes('descendant::CHUNK[@type="grup-verb" or @type="coor-v"][1]')}[0];
 	 if($firstverbchunk && $topnode)
	 {
		$sentence->appendChild($firstverbchunk);
		$firstverbchunk->appendChild($topnode);
		$firstverbchunk->setAttribute('si', 'top');
		print STDERR "moved verb chunk to top in sentence: $sentenceId\n" if $verbose;
	}
	else	
	{
		my $firstAnyChunk = @{$sentence->findnodes('descendant::CHUNK[1]')}[0];
		if($firstAnyChunk && $topnode)
		{
			$sentence->appendChild($firstAnyChunk);
			# attach original topnode as child to child node of new top node 
			# note: node must be attached to child NODE of top chunk, otherwise we have node siblings and the lexical transfer module is not happy
			my $newtopnode = @{$firstAnyChunk->findnodes('child::NODE[1]')}[0];
			$newtopnode->appendChild($topnode);
			$firstAnyChunk->setAttribute('si', 'top');
			print STDERR "moved non-verbal chunk to top in sentence: $sentenceId\n" if $verbose;
		}
		# if no chunk: create an artificial chunk (otherwise lexical module will crash!)
		elsif($topnode)
		{
			my $dummyChunk =  XML::LibXML::Element->new( 'CHUNK' );
			$dummyChunk->setAttribute('si', 'top');
			$dummyChunk->setAttribute('type', 'dummy');
			$dummyChunk->setAttribute('ord', $topnode->getAttribute('ord'));
			$sentence->appendChild($dummyChunk);
			$dummyChunk->appendChild($topnode);
			print STDERR "inserted dummy chunk as head in sentence: $sentenceId\n" if $verbose;
		}
	}
	# check if topnode is now chunk, if not, repeat
	if($sentence->findnodes('child::NODE')){
		&moveTopNodeUnderChunk($sentence);
	}
	
}

sub preceedNoVerbinBetween{
	my $nodeleft = $_[0];
	my $noderight = $_[1];
	
	my $ordleft = $nodeleft->getAttribute('ord');
	my $ordright = $noderight->getAttribute('ord');
	
	my $foundverb=1;
	
	for (my $i=$ordleft;$i< $ordright;$i++){
		my $xpath = 'ancestor::SENTENCE/descendant::NODE[@ord="'.$i.'" and starts-with(@pos,"v")]';
		if($nodeleft->findnodes($xpath) ){
			$foundverb=0;
			last;
		}
	}
	print STDERR "returning no verb in between = $foundverb\n";
	return $foundverb;
}

# el 12 de diciembre -> 12 own chunk
sub numberIsPartOfDate{
	my $number = $_[0];
	my $ord = $number->getAttribute('ord');
	
	my $de_xpath = 'ancestor::SENTENCE/descendant::NODE[@ord="'.($ord+1).'"]';
	my $month_xpath = 'ancestor::SENTENCE/descendant::NODE[@ord="'.($ord+2).'"]';
	
	my ($de) = $number->findnodes($de_xpath);
	my ($month) = $number->findnodes($month_xpath);
	
	my $isDate=0;
	if($de && $month){
		#print STDERR "node de: ".$de->toString()."\n" if $verbose;
		#print STDERR "node month: ".$month->toString()."\n" if $verbose;
		if(lc($month->getAttribute('form')) =~ /enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre/  &&  $de->getAttribute('lem') eq 'de'  ){
			$isDate =1;
		}
	}
	return $isDate;
}
1;
