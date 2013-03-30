#!/usr/bin/perl

#use utf8;                  # Source code is UTF-8

use strict;
use XML::LibXML;
binmode STDIN, ':utf8';
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
        'las'		=> 'los',
        'lo'		=> 'lo',
        'los'		=> 'los',
        'le'		=> 'le',
        'les'		=> 'les',
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

while (<>) 
  {
    #skip empty line
    if(/^\s*$/)
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
     my ($id, $word, $lem, $cpos, $pos, $info, $head, $rel, $phead, $prel) = split (/\t|\s/);	 
     
     # special case with estar (needs to be vm for desr and form instead of lemma -> set lemma back to 'estar')
     if(($pos eq 'vm' || $pos eq 'va') && $lem =~ /^est/ && $lem !~ /r$/)
     {
     	$lem = "estar";
     }
     
     my $eaglesTag = &toEaglesTag($pos, $info);
     # if verb (gerund,infinitve or imperative form) has clitic(s) then make new node(s)
     if($eaglesTag =~ /^V.[GNM]/ and $word =~ /(me|te|nos|os|se|la|las|lo|los|le|les)$/ and $word !~ /parte|frente|adelante|base|menos$/)
     {
	print STDERR "clitics in verb $lem: $word\n";
	my $clstr = splitCliticsFromVerb($word,$eaglesTag,$lem);
	if ($clstr !~ /^$/)	# some imperative forms may end on "me|te|se|la|le" and not contain any clitic
	{
		&createAppendCliticNodes($sentence,$scount,$id,$clstr);
	}
     }
     if($eaglesTag =~ /^NP/)
     {
     	$pos="np";
     }
     # set rel of 'y' and 'o' to coord
     if($lem eq 'y' || $lem eq 'o')
     {
     	$rel = 'coord';
     }
     $wordNode->setAttribute( 'ord', $id );
     $wordNode->setAttribute( 'form', $word );
     $wordNode->setAttribute( 'lem', $lem );
     $wordNode->setAttribute( 'pos', $pos );
     $wordNode->setAttribute( 'cpos', $cpos );
     $wordNode->setAttribute( 'head', $head );
     $wordNode->setAttribute( 'rel', $rel );
     $wordNode->setAttribute( 'mi', $eaglesTag );

    # print "$eaglesTag\n";
     # store node in hash, key sentenceId:wordId, in order to resolve dependencies
     my $key = "$scount:$id";
     $docHash{$key}= $wordNode;
     
     $conllHash{$scount} =  $conllHash{$scount}."$_";
     }
  }

#my $docstring = $dom->toString(3);
#print STDERR $docstring;
#print "------------------------------------------------\n";

## adjust dependencies (word level), 
my @sentences = $dom->getElementsByTagName('SENTENCE');
#foreach my $sentence  ( $dom->getElementsByTagName('SENTENCE'))
my $model2 =0;
for(my $i = 0; $i < scalar(@sentences); $i++)
{  
	if($model2 == 1)
	{
		my $sentence = @sentences[$i];
		my $sentenceId = $sentence->getAttribute('ord');
		print STDERR "model2 in sentence: $sentenceId\n";
		my @nodes = $sentence->getElementsByTagName('NODE');
	
		foreach my $node (@nodes)
		{
			my $head = $node->getAttribute('head');
			if ($head ne '0')
			{
				my $headKey = "$sentenceId:$head";
				my $word = $node->getAttribute('form');
				#print "$word= $headKey\n";
				my $parent = $docHash{$headKey};
				$parent->appendChild($node);
			}
		}
		$model2=0;
	}
	else
	{
		my $sentence = @sentences[$i];
		my $sentenceId = $sentence->getAttribute('ord');
		print STDERR "adjusting dependencies in sentence: ".$sentence->getAttribute('ord')."\n";
		my @nodes = $sentence->getElementsByTagName('NODE');
	
		foreach my $node (@nodes)
		{
			#print STDERR $node->getAttribute('ord')."\n";
			my $head = $node->getAttribute('head');
			if ($head ne '0')
			{
				my $headKey = "$sentenceId:$head";
				#print STDERR "Head key: $headKey\n";
				my $word = $node->getAttribute('form');
				#print "$word= $headKey\n";
				my $parent = $docHash{$headKey};
				eval
				{
					$parent->appendChild($node);
				}
				or do
				{
					&model2($sentence);
					print STDERR "loop detected in sentence: ".$sentence->getAttribute('ord')."\n";
					$model2 = 1;
					$i--;
					last;
				}
			}
			# if this is the head, check if it's a good head (should not be a funcion word!), and if not, 
			# check if there are >3 words in this sentence (otherwise it might be a title)
			else
			{
				my $pos = $node->getAttribute('pos');
			
				if($pos =~ /d.|s.|p[^I]|c.|n./ && scalar(@nodes) > 4)
				{
					&model2($sentence);
					$model2 = 1;
					$i--;
					last;
				}
			}
		}
	}
}


#my $docstring = $dom->toString(3);
#print STDERR $docstring;
#print "------------------------------------------------\n";
#print "------------------------------------------------\n";

# insert chunks

foreach my $sentence  ( $dom->getElementsByTagName('SENTENCE'))
{
	
	my $sentenceId = $sentence->getAttribute('ord');
	print STDERR "insert chunks in sentence: $sentenceId\n";
	#my $chunkCount = 1;
	my $parent;
	my @nodes =  $sentence->getElementsByTagName('NODE');
	
	for(my $i=0; $i<scalar(@nodes); $i++)
	{ #print "\n ord chunk: $chunkCount\n";
		#my $docstring = $dom->toString(3);
		my $node = @nodes[$i];
		my $head = $node->getAttribute('head');
		my $headKey = "$sentenceId:$head";
		my $word = $node->getAttribute('form');
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
		
#my $docstring = $dom->toString(3);
#print STDERR $docstring;
###print STDERR  $node->toString;
#print STDERR "\n---------------------------------\n";
#print STDERR  $node->getAttribute('lem');
#print STDERR "\n---------------------------------\n";
#		
			#if this is a main verb or auxiliary used as main verb 
			# (as auxiliary rel=v, auxilaries don't get their own chunk, they should live inside the main verbs' chunk)
			if ($node->exists('self::NODE[starts-with(@mi,"V")] and not(self::NODE[@rel="v"])'))
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
				 	print STDERR "change mi to $eaglesTag\n";
				 }
				 
				 # if relative clause with preposition preceding relative pronoun-> desr makes wrong analysis:
				 #(la mujer a quien dejaron):
#<corpus>
#  <SENTENCE ord="1">
#    <CHUNK type="grup-verb" si="top">
#      <NODE ord="5" form="dejaron" lem="dejar" pos="vm" cpos="v" rel="sentence" mi="VMIS3P0"/>
#      <CHUNK type="sn" si="suj"> 
#        <NODE ord="2" form="mujer" lem="mujer" pos="nc" cpos="n" rel="cd-a" mi="NCFS000">
#          <NODE ord="1" form="la" lem="el" pos="da" cpos="d" head="2" rel="spec" mi="DA0FS0"/>
#        </NODE>
#      </CHUNK>
#      <CHUNK type="grup-sp" si="cd">
#        <NODE ord="3" form="a" lem="a" pos="sp" cpos="s" rel="cd" mi="SPS00">
#          <NODE ord="4" form="quien" lem="quien" pos="pr" cpos="p" head="3" rel="sn" mi="PR00S000"/>
#        </NODE>
#      </CHUNK>
#    </CHUNK>
#  </SENTENCE>
#</corpus>

#my $docstring = $dom->toString(3);
#print STDERR $docstring;
#print STDERR  $node->getAttribute('lem');
#print STDERR "\n---------------------------------\n";

				 # find rel-prn within PP
				 my $relprn = ${$node->findnodes('NODE[@pos="sp"]/NODE[starts-with(@mi,"PR")]')}[-1];
				 my $subj =  ${$node->findnodes('../descendant::*[(@rel="suj" or @rel="cd-a") and @cpos="n"][1]')}[0];
				 # find subj within rel-clause with cual, see below
#				 my $relcual = ${$node->findnodes('child::NODE[@lem="cual"]')}[-1];
#				 my $cualsubj =  ${$node->findnodes('child::*[(@rel="suj" or @rel="cd-a") and @cpos="n"][1]')}[0];
				 
				 # in case we have to insert a subject chunk
				 my $snchunk;
				 my $clitic2;
				 my $clitic;
				 my $LO;
				 my $QUE;
				 
				 #check if subj should be the head of the rel-clause (head preceeds rel-prn)
				 if($relprn && $subj && ( $relprn->getAttribute('ord') > $subj->getAttribute('ord') ))
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

# La mujer la cual baila se fue.			 
# <SENTENCE ord="1">
#    <CHUNK type="grup-verb" si="top" idref="7">
#      <NODE ord="7" form="fue" lem="ir" pos="vm" cpos="v" rel="sentence" mi="VMIS3S0">
#        <NODE ord="5" form="baila" lem="bailar" pos="vm" cpos="v" head="7" rel="suj" mi="VMIP3S0">
#          <NODE ord="2" form="mujer" lem="mujer" pos="nc" cpos="n" head="5" rel="suj" mi="NCFS000">
#            <NODE ord="1" form="La" lem="el" pos="da" cpos="d" head="2" rel="spec" mi="DA0FS0"/>
#          </NODE>
#          <NODE ord="4" form="cual" lem="cual" pos="pr" cpos="p" head="5" rel="cc" mi="PR00S000">
#            <NODE ord="3" form="la" lem="el" pos="da" cpos="d" head="4" rel="d" mi="DA0FS0"/>
#          </NODE>
#          <NODE ord="6" form="se" lem="se" pos="pp" cpos="p" head="5" rel="suj" mi="PP30C000"/>
#        </NODE>
#        <NODE ord="8" form="." lem="." pos="Fp" cpos="F" head="7" rel="f" mi="FP"/>
#      </NODE>
#    </CHUNK>
#  </SENTENCE>
#	 			elsif($relcual && $cualsubj && ( $relcual->getAttribute('ord') > $cualsubj->getAttribute('ord') ))
#	 			{
#	 				print STDERR "cualsubj:".$cualsubj->toString."\n";
#	 					$node->setAttribute('head', $cualsubj->getAttribute('ord'));
#				 	 	$head = $cualsubj->getAttribute('ord');
#				 	 	$node->setAttribute('rel', 'S');
#				 	 	$parent->appendChild($cualsubj);
#				 	 	$cualsubj->appendChild($node);
#				 	
#				 	 	if($parent->nodeName() eq 'SENTENCE')
#				 	 	{
#				 	 		$cualsubj->setAttribute('si', 'top');
#				 	 		$cualsubj->setAttribute('head', '0');
#				 	 	}
#				 	 	else
#				 	 	{
#				 	 		if($parent->nodeName() eq 'NODE')
#				 	 		{
#				 	 			$cualsubj->setAttribute('head', $parent->getAttribute('ord'));
#				 	 		}
#				 	 		else
#				 	 		{
#				 	 			$cualsubj->setAttribute('head', $parent->getAttribute('idref'));
#				 	 		}
#				 	 	}
#				 	 	$parent=$cualsubj;
#	 			}				 
				 
#  Vi al hombre a quien dejaron. ->  'a quien dejaron'->grup-sp, cc/sp, depends on verb (only if simple np/pp, with complex nps/pps not a problem)
# attach this relative-clause to preceeding noun
#  <SENTENCE ord="1">
#    <CHUNK type="grup-verb" si="top">
#      <NODE ord="1" form="Vi" lem="ver" pos="vm" cpos="v" rel="sentence" mi="VMIS1S0"/>
#      <CHUNK type="grup-sp" si="cd">
#        <NODE ord="2" form="al" lem="al" pos="sp" cpos="s" rel="cd" mi="SPCMS"/>
#        <CHUNK type="sn" si="sn">
#          <NODE ord="3" form="hombre" lem="hombre" pos="nc" cpos="n" rel="sn" mi="NCMS000"/>
#        </CHUNK>
#      </CHUNK>
#      <CHUNK type="grup-sp" si="cc">
#        <NODE ord="4" form="a" lem="a" pos="sp" cpos="s" rel="cc" mi="SPS00"/>
#        <CHUNK type="grup-verb" si="S">
#          <NODE ord="6" form="dejaron" lem="dejar" pos="vm" cpos="v" rel="S" mi="VMIS3P0">
#            <NODE ord="5" form="quien" lem="quien" pos="pr" cpos="p" head="6" rel="suj" mi="PR00S000"/>
#          </NODE>
#        </CHUNK>
#      </CHUNK>
#      <CHUNK type="F-term" si="term">
#        <NODE ord="7" form="." lem="." pos="Fp" cpos="F" mi="FP"/>
#      </CHUNK>
#    </CHUNK>
#  </SENTENCE>

				 elsif($node->exists('child::NODE[@pos="pr"]') && ( ($parent->getAttribute('type') eq 'grup-sp') || ($parent->getAttribute('pos') eq 'sp') ) )
				 { 
				 	# if rel-pron is set to 'suj'-> correct that, if there's a preceding preposition, this can't be subject
				 	$relprn = @{$node->findnodes('child::NODE[@pos="pr"]')}[-1];
				 	my $prep = @{$parent->findnodes('descendant-or-self::NODE[@pos="sp"]')}[-1];
				 	if($relprn && $prep && $relprn->getAttribute('rel') eq 'suj')
				 	{
				 		if($prep->getAttribute('lem') eq 'a' ||$prep->getAttribute('lem') eq 'al')
				 		{
				 			$relprn->setAttribute('rel', 'cd/ci');
				 		}
				 		else
				 		{
				 			$relprn->setAttribute('rel', 'cc');
				 		}
				 	}
				 	my $headOfRelPP = $parent->parentNode();
				 	if($headOfRelPP && $headOfRelPP->nodeName() ne 'SENTENCE' && $headOfRelPP->exists('self::*[@type="grup-verb" or @cpos="v"]'))
				 	{
				 		my $nominalHead = @{$parent->findnodes('preceding-sibling::CHUNK[@type="grup-sp" or @type="sn"]/descendant-or-self::CHUNK[@type="sn"]')}[-1];
				 		# if there is a candidate for the nominal head of this rel clause, attach it there
				 		if($nominalHead)
				 		{
				 			$nominalHead->appendChild($parent);	
				 			$parent->setAttribute('head', $nominalHead->getAttribute('ord'));
				 		}
				 	}
				 }
		# problem re-clauses with 'ART+cual':
#  <SENTENCE ord="1">
#    <CHUNK type="grup-verb" si="top">
#      <NODE ord="6" form="fue" lem="ir" pos="vm" cpos="v" rel="sentence" mi="VMIS3S0">
#        <NODE ord="5" form="se" lem="se" pos="pp" cpos="p" head="6" rel="ci" mi="PP30C000"/>
#      </NODE>
#      <CHUNK type="sn" si="suj">
#        <NODE ord="2" form="mujer" lem="mujer" pos="nc" cpos="n" rel="suj" mi="NCFS000">
#          <NODE ord="1" form="la" lem="el" pos="da" cpos="d" head="2" rel="spec" mi="DA0FS0"/>
#          <NODE ord="4" form="cual" lem="cual" pos="pr" cpos="p" head="2" rel="sn" mi="PR00S000">
#            <NODE ord="3" form="la" lem="el" pos="da" cpos="d" head="4" rel="spec" mi="DA0FS0"/>
#          </NODE>
#        </NODE>
#      </CHUNK>
#    </CHUNK>
#  </SENTENCE>
					elsif($subj && $node->exists('child::*[(@si="suj" and @type="sn")or (@rel="suj" and @cpos="n")]/descendant::NODE[@lem="cual"]') )
					{
						my $subjnoun = @{$node->findnodes('child::*[(@si="suj" and @type="sn") or (@rel="suj" and @cpos="n")][1]')}[-1];
						#print STDERR "subjnoun: ".$subjnoun->toString;
						my $cual = @{$subjnoun->findnodes('child::NODE[@lem="cual"][1]')}[-1];
						if($cual && $subjnoun)
						{
							# attach cual to verb instead of subject noun, set rel=suj
							$cual->setAttribute('head', $node->getAttribute('ord'));
							$cual->setAttribute('rel', 'suj');
							$node->appendChild($cual);
						
							# attach node(verb) to head noun and set rel=S
							$node->setAttribute('head', $subjnoun->getAttribute('ord'));
				 	 		$head = $subjnoun->getAttribute('ord');
				 	 		$node->setAttribute('rel', 'S');
				 	 		$parent->appendChild($subjnoun);
				 	 		$subjnoun->appendChild($node);
				 	
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
				 	 		$parent=$subjnoun;
						}
					}
					# TODO ist das wirklich sinnvoll?
					# if analyzed as relative clause but no rel-prn & head noun not part of prep.phrase
					# -> head noun is part of sentence, if no other subject & congruent, insert as subject, 
					# this seems to happen particularly with clitic object ( los pobladores LA llaman sirena..etc)
					elsif($node->getAttribute('rel') =~ /S|sn/ && $node->exists('parent::NODE/parent::CHUNK[@type="sn"]/NODE[@cpos="n"]') && !$node->exists('ancestor::CHUNK[@type="grup-sp"]') && !$node->exists('descendant::NODE[@pos="pr"]')  && !&hasRealSubj($node) && $node->exists('child::NODE[@lem="lo" or @lem="le"]'))
					{
						my $headnoun = &getHeadNoun($node);
						if($headnoun && &isCongruent($headnoun, $node))
						{ 
							print STDERR "suj inserted in sentence: $sentenceId\n";
							#parent node = noun, parent of that = sn-chunk
							# new head of this verb will be the head of this sn-chunk
							$snchunk = $headnoun->parentNode;
							my $newhead = $snchunk->parentNode;
							if($snchunk && $newhead)
							{
								$newhead->appendChild($verbchunk);
								#insert after node, see below
								#$verbchunk->appendChild($snchunk);
							
								$snchunk->setAttribute('head', $node->getAttribute('ord'));
								$node->setAttribute('head', $newhead->getAttribute('ord'));
							
								$parent = $newhead;

								$snchunk->setAttribute('si', 'suj-a');
								$headnoun->setAttribute('rel', 'suj-a');
							}

						}
						
					}
					# Problem with clitic pronouns la sirena SE LO comerá, SE LO diré cuando llegue)-> head se--concat--lo--concat--verb 
					# edit: same problem with 'me lo, te la, etc', -> adapted regex, note that $clitic2 contains also 'me,te,no,vos,os' now
				 	elsif($node->getAttribute('rel') eq 'CONCAT' && $node->exists('parent::NODE[@pos="pp" and (@lem="lo" or @lem="le" or @lem="te" or @lem="me" or @lem="nos" or @lem="vos" or @lem="os")]'))
				 	{
				 		#print STDERR "abzweigung erwischt\n";
				 		$clitic = $node->parentNode();
				 		$clitic2 = @{$clitic->parentNode()->findnodes('parent::CHUNK[@type="sn"]/NODE[@lem="se" or @lem="te" or @lem="me" or @lem="nos" or @lem="vos" or @lem="os"][1]')}[0];
				 		# if 'se lo'
				 		if($clitic && $clitic2)
				 		{
				 			#attach verb to current head of 'se' and 'la'/'lo' (se and lo/la already in sn-chunks!)
				 			$parent = $clitic2->parentNode->parentNode;
				 			#print STDERR "parent of se : ".$parent->toString();
				 			$node->setAttribute('head', $parent->getAttribute('ord'));
				 			# add 'se' and 'lo/la' to verb with their chunks
				 			# should be attached AFTER verb, else sequence gets mixed up
#				 			$verbchunk->appendChild($clitic2->parentNode);
#				 			$verbchunk->appendChild($clitic->parentNode);
				 			
				 			$clitic2->setAttribute('head', $node->getAttribute('ord'));
				 			$clitic->setAttribute('head', $node->getAttribute('ord'));
				 			#$clitic2->parentNode->setAttribute('ord', $node->getAttribute('ord'));
				 			#$clitic->parentNode->setAttribute('ord', $node->getAttribute('ord'));
				 			$clitic2->parentNode->setAttribute('si', 'ci');
				 			$clitic2->setAttribute('rel', 'ci');
				 			$clitic->setAttribute('rel', 'cd');
				 			$clitic->parentNode->setAttribute('si', 'cd');				 			
				 			print STDERR "changed verb clitics in sentence $sentenceId\n";
				 		}
				 		# if only one clitc ('Cuando vine, le dije./Cuando vine, la vi.')
				 		elsif ($clitic && !$clitic2)
				 		{
				 			$parent = $clitic->parentNode->parentNode;
				 			$node->setAttribute('head', $parent->getAttribute('ord'));
				 			$clitic->setAttribute('head', $node->getAttribute('ord'));
				 			#$clitic->parentNode->setAttribute('ord', $node->getAttribute('ord'));
				 			print STDERR "changed CONCAT in verb clitics in sentence $sentenceId\n";
				 			
				 			if($clitic->getAttribute('lem') eq 'lo')
				 			{
				 				$clitic->setAttribute('rel', 'cd');
				 				$clitic->parentNode->setAttribute('si', 'cd');
				 			}
				 			elsif($clitic->getAttribute('lem') eq 'le')
				 			{
				 				$clitic->setAttribute('rel', 'ci');
				 				$clitic->parentNode->setAttribute('si', 'ci');
				 			}
				 			else
				 			{
				 				$clitic->setAttribute('rel', 'cd-a');
				 				$clitic->parentNode->setAttribute('si', 'cd-a');
				 			}
				 		}
				 		
				 	}
				 	elsif($node->exists('parent::NODE[@lem="que"]/parent::NODE[@form="lo" or @form="Lo" or @form="los" or @form="Los"]') )
				 	{
				 		# que
				 		$QUE = $node->parentNode;
				 		if($QUE)
				 		{
				 			$QUE->setAttribute('rel', 'cd-a');
				 			# lo
				 			$LO = $QUE->parentNode;
				 			if($LO)
				 			{
				 				$LO->setAttribute('rel', 'spec');
				 				$parent = $LO->parentNode;
				 				$node->setAttribute('rel', 'S');
				 			}
				 		}
				 	}
				 	# if this verb is labeled as 'suj', but is local person -> change label to 'S'
				 	elsif($node->getAttribute('rel') eq 'suj' && $node->getAttribute('mi') =~ /1|2/ )
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
				 if($snchunk)
				 {
				 	$verbchunk->appendChild($snchunk);
				 }
				 elsif($clitic2 && $clitic)
				 {
				 	$verbchunk->appendChild($clitic2->parentNode);
		 			$verbchunk->appendChild($clitic->parentNode);
				 }
				 elsif($clitic && !$clitic2)
				 {
				 	$verbchunk->appendChild($clitic->parentNode);
				 }
				 elsif($LO && $QUE)
				 {
				 	$verbchunk->appendChild($QUE);
				 	#print STDERR $LO->toString;
		 			$verbchunk->appendChild($LO);
				 }
				 
				 eval{$parent->appendChild($verbchunk);};
				 warn  "could not attach verbchunk".$node->getAttribute('ord')."to head in sentence: $sentenceId" if $@;
				 
				 # the key in hash should point now to the chunk instead of the node
				 my $ord = $node->getAttribute('ord');
				 my $idKey = "$sentenceId:$ord";
				 $docHash{$idKey}= $verbchunk;
			}
			# if this is a noun, a personal or a demonstrative pronoun, or a number, make a nominal chunk (sn)
			elsif ($node->exists('self::NODE[@cpos="n" or @pos="pp" or @pos="pd" or @pos="pi" or @pos="Z" ]'))
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
				 #print STDERR "node: ".$node->getAttribute('lem')." ,parent: ".$parent->toString."\n";
				 # if this is suj -> check if congruent with finite verb, check also if parent is a verbchunk
				 if($node->getAttribute('rel') eq 'suj' && $parent->exists('self::*[@type="grup-verb" or @cpos="v"]') && &isCongruent($node, $parent) == 0)
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
				 $nounchunk->setAttribute('si', $node->getAttribute('rel'));
				 $nounchunk->setAttribute('ord', $node->getAttribute('ord'));
				 #$node->removeAttribute('rel');
				 $node->removeAttribute('head');
				 $nounchunk->appendChild($node);
				 $parent = &attachNewChunkUnderChunk($nounchunk,$parent); # $parent->appendChild($nounchunk);
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
				 #print STDERR "parent of prep: \n".$parent->toString."\n";
				 #if head is an infinitive (para hacer, voy a hacer, de hacer etc)-> don't create a chunk, preposition just hangs below verb
				 if($parent->exists('self::CHUNK/NODE[@mi="VMN0000" or @mi="VSN0000"]'))
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
					 $ppchunk->setAttribute('si', $node->getAttribute('rel'));
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
				$parent = &attachNewChunkUnderChunk($sachunk,$parent);
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
				$parent = &attachNewChunkUnderChunk($sadvchunk,$parent);
				#if ($parent->nodeName eq 'NODE') {
				#	print STDERR "adverb chunk" . $sadvchunk->toString(). " within NODE ". $parent->toString() ." has to be appended to a higher CHUNK\n";
				#	$parent = @{$parent->findnodes('ancestor::CHUNK[1]')}[0];
				#}
				 #$parent->appendChild($sadvchunk);
				  # the key in hash should point now to the chunk instead of the node
				 my $ord = $node->getAttribute('ord');
				 my $idKey = "$sentenceId:$ord";
				 $docHash{$idKey}= $sadvchunk;
			}
			# if this is a subordination (CS), check if attached to correct verb (gets often attached to main clause instead of subordinated verb)
			elsif($node->getAttribute('pos') eq 'cs')
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
				 	# else: sentence consists only of punctuation marks? leave as is..
				 	else
				 	{
				 		last;
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
				 warn  "could not punctuation chunk to parent chunk".$node->getAttribute('ord')." in sentence: $sentenceId" if $@;
			     # the key in hash should point now to the chunk instead of the node
				 my $ord = $node->getAttribute('ord');
				 my $idKey = "$sentenceId:$ord";
				 $docHash{$idKey}= $fpchunk;
			}
			# if this is a date
			elsif ($node->exists('self::NODE[@mi="W"]'))
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
		# if this is the last node, sentence complete
		if($i == scalar(@nodes)-1)
		{ 
			my $topverbchunk = @{$node->findnodes('ancestor::SENTENCE/CHUNK[(@type="grup-verb" or @type="coor-v")and @si="top"][1]')}[0];
			# check if main verb is in fact a subordinated clause, if so, make second grup-verb head
			# if coordinated vp: don't take first child grup-verb (this is the coordinated vp), take the last
			if($topverbchunk && $topverbchunk->exists('child::NODE[@cpos="v"]/NODE[@pos="cs"]'))
			{ #print STDERR $topverbchunk->toString;
				my $realMain = @{$topverbchunk->findnodes('child::CHUNK[@type="grup-verb" or @type="coor-v"]/NODE[@cpos="v" and not(child::NODE[@pos="cs"])]')}[-1];
				if($realMain)
				{
					print STDERR "real main verb: ".$realMain->toString();
					$topverbchunk->parentNode->appendChild($realMain->parentNode());
					$realMain->parentNode()->appendChild($topverbchunk);
					
					$topverbchunk->setAttribute('si', 'S');
					$realMain->parentNode->setAttribute('si', 'top');
				}
			}
			elsif(!$sentence->exists('child::CHUNK'))
			{
			# wrong analysis, head of sentence is a node instead of chunk -> get first verb chunk and make this the head
			# if there is no verb chunk -> take the first child that a chunk (any type) and make this the head
			    my $topnode = @{$sentence->findnodes('child::NODE[1]')}[0];
				my $firstverbchunk = @{$sentence->findnodes('descendant::CHUNK[@type="grup-verb" or @type="coor-v"][1]')}[0];
				if($firstverbchunk && $topnode)
				{
					$sentence->appendChild($firstverbchunk);
					$firstverbchunk->appendChild($topnode);
					$firstverbchunk->setAttribute('si', 'top');
					print STDERR "moved verb chunk to top in sentence: $sentenceId\n";
					
				}
				else
				{
					my $firstAnyChunk = @{$sentence->findnodes('descendant::CHUNK[1]')}[0];
					if($firstAnyChunk && $topnode)
					{
						$sentence->appendChild($firstAnyChunk);
						$firstAnyChunk->appendChild($topnode);
						$firstAnyChunk->setAttribute('si', 'top');
						print STDERR "moved non-verbal chunk to top in sentence: $sentenceId\n";
					}
					# if no chunk: create an artificial chunk (otherwise lexical module will crash!)
					elsif($topnode)
					{
						my $dummyChunk =  XML::LibXML::Element->new( 'CHUNK' );
						$dummyChunk->setAttribute('si', 'top');
						$dummyChunk->setAttribute('type', 'dummy');
						$dummyChunk->setAttribute('ord', $node->getAttribute('ord'));
						$sentence->appendChild($dummyChunk);
						$dummyChunk->appendChild($topnode);
						print STDERR "inserted dummy chunk as head in sentence: $sentenceId\n";
					}
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
					#print STDERR "verb chunk ord: ".$verbchunk->getAttribute('ord'). "\n";
				 	my %subjs =();
				 	foreach my $subjCand (@subjectNodes)
				 	{
				 		my $ord = $subjCand->getAttribute('ord');
				 		$subjs{$ord} = $subjCand;
				 		print STDERR "to many subjects: ".$subjCand->getAttribute('lem')." ord: ".$ord."\n";
				 	}
				 	
				 	my $candIsSubj = 0;
				 	foreach my $ord (sort {$a<=>$b} (keys (%subjs))) 
				 	{
				 		my $subjCand = $subjs{$ord};
				 		if(&isCongruent($subjCand,$verbchunk) && $candIsSubj == 0)
				 		{
				 			print STDERR "correct subj: ".$subjCand->getAttribute('lem')."\n";
				 			$candIsSubj =1;
				 		}
				 		else
				 		{
				 			$subjCand->parentNode->setAttribute('si', 'cd-a');
				 			$subjCand->setAttribute('rel', 'cd-a');
				 		}
				 		#print STDERR "sorted lemma subj: ".$subjCand->getAttribute('lem')." ord: ".$ord."\n";
				 	}
				 	
				 }
			}
			# check if all chunks are children of chunks (if nodes have child chunks, the lexical transfer module is not amused)
			foreach my $chunk ($sentence->getElementsByTagName('CHUNK'))
			{
				if($chunk->parentNode->nodeName eq 'NODE')
				{
					my $realparent = @{$chunk->findnodes('ancestor::CHUNK[1]')}[0];
					if($realparent)
					{
						$realparent->appendChild($chunk);
					}
					else
					{
						$sentence->appendChild($chunk);
					}
				}
			}
			
		}
	}
}


			
#				 # if this is marked as subject, check if morph of verb matches
#				 if($node->getAttribute('rel') eq 'suj' && &notCongruent($node,$parent))
#				 {
#				 	$node->setAttribute('rel', 'cd-a')
#				 }


# print new xml to stdout
my $docstring = $dom->toString(3);
print STDOUT $docstring;


sub toEaglesTag{
	my $pos= $_[0];
	my $info=$_[1];
	my $eaglesTag;
	
	#adjectives
	# 0: A
	# 1: Q,O,0 (type)
	# 2: 0 (grade, Spanish always 0)
	# 3: M,F,C (gender)
	# 4: S,P (number)
	# 5: P,0 (function, participe/zero)
	if($pos=~ /^a/)
	{
		my ($gen, $num) = ($info =~ m/gen=(.)\|num=(.)/ );
		my $fun ="0";
		if($info =~ /fun=/)
		{
			my @fun = ($info =~ m/fun=(.)/ );
			$fun = @fun[0];
		}
		
		$eaglesTag = $pos."0"."$gen$num$fun";	
		#print STDERR "feat: $eaglesTag\n";
	}
	
	#determiners
	# 0: D
	# 1: D,P,T,E,I,A+N (numeral) -> type
	# 2: 1,2,3 (person)
	# 3: M,F,C,N (gender)
	# 4: S,P,N (number)
	# 5: S,P (possessor number)
	elsif ($pos=~/^d/)
	{ 
		my ($gen, $num)= ($info =~ m/gen=(.)\|num=(.)/ );
		my $per = "0";
		my $pno = "0";
		if($info =~ /per=/)
		{
			($per) = ($info =~ m/per=(.)/ );
			
		}
		if($info =~ /pno=/)
		{
			($pno) = ($info =~ m/pno=(.)/ );
		}
	    $eaglesTag = "$pos$per$gen$num$pno";	
	    #print STDERR "feat: $eaglesTag\n";		
	}
	
	# nouns
	# 0: N
	# 1: C,P (type)
	# 2: M,F,C (gender)
	# 3: S,P,N (number)
	# 4-5: semantics (NP): SP, G0, O0, V0 (not present atm...)
	# 6: A,D (grade, augmentative, diminutive) -> always zero from freeling
	elsif ($pos=~/^n/)
	{ 
		my ($gen, $num)= ($info =~ m/gen=(.)\|num=(.)/ );
		my ($nptype) = ($info =~ m/np=(..)/ );
		 #print STDERR "feat: $gen, $num, $info\n";	
		if($gen eq 'c')
		{
			$gen = '0';
		}
		if($num eq 'c')
		{
			$num = '0';
		}
		#if proper noun
		if($nptype ne '')
		{
			$pos = "np";
			$eaglesTag = "$pos$gen$num$nptype"."0";	
		}
		else
		{
			 $eaglesTag = "$pos$gen$num"."000";	
		}
	    #print STDERR "feat: $eaglesTag, $info\n";		
	}

	# verbs
	# 0: V
	# 1: M,A,S (type)
	# 2: I,S,M,N,G,P (mode)
	# 3: P,I,F,S,C,0 (tense)
	# 4: 1,2,3 (person)
	# 5: S,P (number)
	# 6: M,F (gender, participles)
	#gen=c|num=p|per=3|mod=i|ten=s , per,mod,ten optional
	elsif ($pos=~/^v/)
	{ 
		my $per = "0";
		my $mod = "0";
		my $ten = "0";
		my ($gen, $num) = ($info =~ m/gen=(.)\|num=(.)/);
		if($gen eq 'c')
		{
			$gen = '0';
		}
		if($num eq 'c')
		{
			$num = '0';
		}
		if($info =~ /per=/)
		{
			($per) = ($info =~ m/per=(.)/ );
		}
		if($info =~ /mod=/)
		{
		  ($mod) = ($info =~ m/mod=(.)/ );
		}
		if($info =~ /ten=/)
		{
		  ($ten) = ($info =~ m/ten=(.)/ );;
		}
		
	   $eaglesTag = "$pos$mod$ten$per$num$gen";	
	   #print STDERR "feat: $eaglesTag\n";		
	}
	
	#pronouns que PR0CN000 
	# 0: P
	# 1: P,D,X,I,T,R,E (type)
	# 2: 1,2,3 (person)
	# 3: M,F,C (gender)
	# 4: S,P,N (number)
	# 5: N,A,D,O (case)
	# 6: S,P (possessor number)
	# 7: Politeness (P,0)
	# gen+num oblig, rest optional
	elsif ($pos=~/^p/)
	{ 
		my $per = "0";
		my $cas = "0";
		my $pno = "0";
		my $polite = "0"; # atm, always zero
		my ($gen, $num) = ($info =~ m/gen=(.)\|num=(.)/);
		
		if($gen eq 'c')
		{
			$gen = 'C';
		}
		if($num eq 'c')
		{
			$num = 'N';
		}
		if($info =~ /cas=/)
		{
			 ($cas) = ($info =~ m/cas=(.)/ );
		}
		if($info =~ /per=/)
		{
			($per) = ($info =~ m/per=(.)/ );
		}
		if($info =~ /pno=/)
		{
			($pno) = ($info =~ m/pno=(.)/ );
		}
		
		$eaglesTag = "$pos$per$gen$num$cas$pno$polite";
		#print STDERR "feat pronoun: $eaglesTag\n";		
	}
	
    #prepositions
	# 0: S
	# 1: P (type)
	# 2: S,C (form -> simple, contracted)
	# 3: M (gender -> only for al+del)
	# 4: S (number -> al+del)
	elsif ($pos=~/^s/)
	{ 
		my ($gen, $num, $form) = ($info =~ m/gen=(.)\|num=(.)\|for=(.)/);
		if($num eq 'c')
		{
			$num = "0";
		}
		if($gen eq 'c')
		{
			$gen = "0";
		}
		$eaglesTag = "$pos$form$gen$num";
		#print STDERR "feat: $eaglesTag\n";	
	}
	# other cases
	else
	{ 
		$eaglesTag = $pos;
	}
	
	return uc($eaglesTag);
	
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
		#print STDERR "parentnode: ".$parentNode->toString."\n";
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
			}
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
			elsif( $subjNode->getAttribute('lem') =~ /parte|n.mero/)
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
				elsif($subjNode->getAttribute('cpos') eq 'Z' && $subjNode->getAttribute('lem') eq '1')
				{
					$nounNumber = 'S';
				}
				elsif($subjNode->getAttribute('cpos') eq 'Z' && $subjNode->getAttribute('lem') ne '1')
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
#	print STDERR "$nounform:$verbform  verbprs:$verbPerson, verbnmb:$verbNumber, nounPrs:$nounPerson, nounNumb:$nounNumber, nounMI: $nounmi\n";
	
		if($nounPerson =~ $verbPerson && $nounNumber eq $verbNumber)
		{
			return 1;
		}
		else
		{
			return 0;
		}
	}
	# if subject node or parent node doees not exist, don't change anything (this should not happen)
	else
	{
		return 1;
	}
}

sub getFiniteVerb{
	my $verbchunk = $_[0];
	
	#print STDERR "verbchunk: ".$verbchunk->toString();
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
		print STDERR "finite verb not found in sentence nr. $sentenceID: \n ";
		print STDERR $verbchunk->toString();
		print STDERR "\n";
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
				print STDERR "Head noun not found in: \n";
				print STDERR $parentchunk->toString()."\n";
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
			#print STDERR "@sequence\n length ".scalar(@sequence)."\n";
		
			for (my $i=$csord+1; $i<=scalar(@sequence);$i++)
			{
				my $node = $nodeHash{$i};
				#print STDERR "i: $i ".$node->getAttribute('form')."\n";
				if($node->getAttribute('pos') eq 'vm' && $i<scalar(@sequence) && $nodeHash{$i+1}->getAttribute('pos') ne 'vm' )
				{
					$followingMainVerb = $node;
					last;
				}
			}
			if($followingMainVerb && !$followingMainVerb->isSameNode($currentParent))
			{
				#print STDERR "foll verb: ".$followingMainVerb->toString();
				#if verb is descendant of cs, first attach verb to head of cs, then attach cs to verb 
				# otherwise we get a hierarchy request err
				if(&isAncestor($followingMainVerb,$cs))
				{
					
					$currentParent->appendChild($followingMainVerb);
					$followingMainVerb->setAttribute('head', $currentParent->getAttribute('ord'));
				}
				$followingMainVerb->appendChild($cs);
				$cs->setAttribute('head', $followingMainVerb->getAttribute('ord'));
			}
		
			#TODO: check linear sequence, subjunction belong to next following verb chunk (no verb in between!)
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

    if($newChunk && $parent)
    {
		#print STDERR "parent node before ". $parent->toString() . "\n";
		#print STDERR "parent nodeName before ". $parent->nodeName . "\n";
		if ($parent->nodeName eq 'NODE') {
			print STDERR "new chunk" . $newChunk->toString(). " within NODE ". $parent->toString() ." has to be appended to a higher CHUNK\n";
			$parent = @{$parent->findnodes('ancestor::CHUNK[1]')}[0];
		}
		#print STDERR "parent node after ". $parent->toString() . "\n";
		if($parent)
		{
			$parent->appendChild($newChunk);
			return $parent;
		}
    }
    #this should not happen
    else
    {
    	print STDERR "failed to attach node to new chunk \n";
    }
}

sub model2{
	my $sentence =  $_[0];
	if($sentence)
	{
		$sentence->removeChildNodes();
		my $sentenceId = $sentence->getAttribute('ord');
		my $path = dirname(rel2abs($0));
		my $tmp = $path."/tmp.conll";
		my $shellscript = $path."/model2_desr.sh";
		open (TMP, ">:encoding(UTF-8)", $tmp);
		print TMP $conllHash{$sentenceId};
		open(DESR,"-|" ,"cat $tmp |$shellscript 2>/dev/null") || die "desr failed: $!\n";

		while (<DESR>)
		{
			#print $_;
			unless(/^\s*$/)
			{
	   			# create a new word node and attach it to sentence
   				my $wordNode = XML::LibXML::Element->new( 'NODE' );
  				$sentence->appendChild($wordNode);
  				my ($id, $word, $lem, $cpos, $pos, $info, $head, $rel, $phead, $prel) = split (/\t|\s/);	 
     
   			 	# special case with estar (needs to be vm for desr and form instead of lemma -> set lemma back to 'estar')
  				 if($pos eq 'vm' && $lem =~ /^est/ && $lem !~ /r$/)
 			 	 {
 				 	  $lem = "estar";
     				  $pos = "va";
    		 	 }
 			 	my $eaglesTag = &toEaglesTag($pos, $info);
				# if verb (gerund,infinitve or imperative form) has clitic(s) then make new node(s)
				# exclude certain words that may occur at the end of the lemma in locutions (e.g. echar_de_menos) -> we don't want to split -os in this case!
				if($eaglesTag =~ /^V.[GNM]/ and $word !~ /parte|frente|adelante|base|menos$/ and $word =~ /(me|te|nos|os|se|la|las|lo|los|le|les)$/)
				{
					print STDERR "clitics in verb $lem: $word\n";
					my $clstr = splitCliticsFromVerb($word,$eaglesTag,$lem);
					if ($clstr !~ /^$/)	# some imperative forms may end on "me|te|se|la|le" and not contain any clitic
					{
						&createAppendCliticNodes($sentence,$sentenceId,$id,$clstr);
					}
				}
   				 if($eaglesTag =~ /^NP/)
   				 {
  		 	 		$pos="np";
 				 }
				   	 $wordNode->setAttribute( 'ord', $id );
 					 $wordNode->setAttribute( 'form', $word );
 	   				 $wordNode->setAttribute( 'lem', $lem );
				  	 $wordNode->setAttribute( 'pos', $pos );
				  	 $wordNode->setAttribute( 'cpos', $cpos );
				  	 $wordNode->setAttribute( 'head', $head );
  				     $wordNode->setAttribute( 'rel', $rel );
 				     $wordNode->setAttribute( 'mi', $eaglesTag );
					 # print "$eaglesTag\n";
  					 # store node in hash, key sentenceId:wordId, in order to resolve dependencies
    				 my $key = "$sentenceId:$id";
    				 $docHash{$key}= $wordNode;
    				 # print $sentence->toString();
    				  # print "\n\n";
				}
			}
		close TMP;
		close DESR;
		unlink("tmp.conll");
	}
	# this should not happen!
	else
	{
		print STDERR "failed to parse sentence!\n";
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
		print STDERR "verb gerund $vfcl[0] ; clitics $vfcl[1]\n";
	}
	# infinitive
	elsif ($vtag =~ /V.N/ and $word =~ /(.*r)([^r]+)/)
	{
		$vfcl[0] = $1;
		$vfcl[1] = $2;
		print STDERR "verb infinitive $vfcl[0] ; clitics $vfcl[1]\n";
	}
	# imperative
	elsif ($vtag =~ /V.M/)
	{
		my $vend = "";
		# some imperative forms may end on "me|te|se|la|le" and not contain any clitic
		if ($vtag =~ /V.M02S0/ and $vlem =~ /([mst][ei])r$/)	# cómetelas => come-telas (comer) ; vístete => viste-te (vestir) TODO Spanish verb ending in "ler" (not "ller") ?
		{
			$vend = $1;
		}
		elsif ($vtag =~ /V.M03S/ and $vlem =~ /([mst]a)r$/)	# mátelo => mate-lo (matar)	TODO Spanish verb ending in "lar" (not "llar") ?
		{
			$vend = $1;
			$vend =~ s/a/e/;
		}
		print STDERR "$vtag verb $vlem form ends in $vend\n";
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
		print STDERR "verb imperative $vfcl[0] ; clitics $vfcl[1]\n";
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
		print STDERR "$c\n";
		my $cliticNode = XML::LibXML::Element->new( 'NODE' );
		$sentence->appendChild($cliticNode);
		$cliticNode->setAttribute( 'ord', $clid ); # TODO new id...
		$cliticNode->setAttribute( 'form', $c );
		$cliticNode->setAttribute( 'lem', $mapCliticFormToLemma{$c} );
		$cliticNode->setAttribute( 'pos', "pp" );
		$cliticNode->setAttribute( 'cpos', "p" );
		$cliticNode->setAttribute( 'head', $verbid );	# head of clitics is the verb itself
		my $cleaglesTag = $mapCliticToEaglesTag{$c};
		print STDERR "eagles tag for clitic $c : $cleaglesTag\n";
		my $clrel = &getCliticRelation($cleaglesTag);
		$cliticNode->setAttribute( 'rel', $clrel );	# TODO rel = cd|ci|creg? refl?
		print STDERR "possible relation for clitic $c : $clrel\n";
		$cliticNode->setAttribute( 'mi', $cleaglesTag );
		my $clkey = "$scount:$clid";
		$docHash{$clkey}= $cliticNode;
		$clid += 0.1;
	}
}
