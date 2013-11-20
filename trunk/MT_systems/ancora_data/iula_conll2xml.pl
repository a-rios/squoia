#!/usr/bin/perl

# iula_conll2xml
# possible syntactical categories
# ROOT: Root 
# DO: Direct Object 
# IO: Indirect Object
# OBLC: Oblique Object 
# BYAG: By agent complement
# ATR: Attribute 
# PRD: Predicative complement
# OPRD: Object predicative complement
# PP-LOC: Locative prepositional complement
# PP-DIR: Directional prepositional complement
# SUBJ-GAP: Subject in a gapping construction
# COMP-GAP: Complement in a gapping construction
# MOD-GAP: Modifier in a gapping construction
# VOC: Vocative
# IMPM: Impersonal marker
# PASSM: Passive marker
# PRNM: Pronominal marker
# COMP: Complement (of N, ADJ, ADV, PREP)
# MOD: Modifier 
# NEG: Negation 
# SPEC: Specifier
# COORD: Coordination
# CONJ: Conjunction 
# PUNCT: Punctuation

# cut -f8 IULA_Spanish_LSP_Treebank.conll |sort -u
my %maprel = (
	"ADV"	=> "cc",
	"ATR"	=> "atr",
	"AUX"	=> "v",
	"BYAG"	=> "cag",
	"COMP"	=> "COMP",	# COMP with V => S? COMP with SP => sp; COMP with N => sn
	"COMP-GAP"	=> "COMP",
	"COMPL"	=> "COMPL",	# IUAL: COMPL seemed to be for light verb constructions like "hacer referencia/uso", "formar parte", etc.
	"CONJ"	=> "CONJ",	# IULA: CONJ for the head of second element of coordination; CONJ with N => sn/grup.nom; CONJ with A => ?;
	"COORD"	=> "coord",	# IULA: y as COORD; DeSR as coord; Ancora: y as conj!
	"DO"	=> "cd",
	"IO"	=> "ci",
	"MIMPERS"	=> "impers",
	"MOD"	=> "MOD",	# cc? MOD with AQ => s.a/cn?
	"MOD-GAP"	=> "mod",
	"MPAS"	=> "pass",
	"MPRON"	=> "morfema.pronominal",
	#"NEG"	=> "neg",	# no neg in iula? in ancora only "mod"?
	"OBLC"	=> "creg",
	"OPRD"	=> "cpred",
	"PP-DIR"	=> "cc",
	"PP-LOC"	=> "cc",
	"PRD"	=> "cpred",
	"PRDC"	=> "cc",	# only 2 examples "quedan por" in IULA
	"punct"	=> "f",	# Fp and Fc are punct in IULA; in Ancora f
	"ROOT"	=> "sentence",
	"SPEC"	=> "spec",
	"SUBJ"	=> "suj",
	"SUBJ-GAP"	=> "suj"
	);

my %mapCOMP = (
	"a"	=> "cn",
	"n"	=> "sn",
	"s"	=> "sp",
	"v"	=> "S"
	);

#my %mapCOMPL = (
#	);

my %mapCONJ = (
	"a"	=> "s.a",
	"n"	=> "sn",	# grup.nom?
	"s"	=> "sp",
	"v"	=> "S"
	);

my %mapMOD = (
	"a"	=> "s.a",
	#"c"	=> "conj",	# CS like porque but exchange later
	"s"	=> "sp",	# or "cn" ?
	"v"	=> "S"		# or "cn" ?
	);


#use utf8;                  # Source code is UTF-8

use strict;
use XML::LibXML;
binmode STDIN, ':utf8';


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
     my ($id, $word, $lem, $cpos, $mi, $info, $head, $rel, $phead, $prel) = split (/\t|\s/);	 
     
     my $pos = lc(substr($mi,0,2));
     
     $wordNode->setAttribute( 'ord', $id );
     $wordNode->setAttribute( 'form', $word );
	# some proper name have lemma = NP, so we set the lemma to the word
	if ($lem eq $mi) {
		$lem = $word;
	}
     $wordNode->setAttribute( 'lem', $lem );
     $wordNode->setAttribute( 'mi', $mi );
     $wordNode->setAttribute( 'cpos', $cpos );
     $wordNode->setAttribute( 'head', $head );
	# map the relation from IULA to "Ancora-style"
	$rel = $maprel{$rel};
	# TODO : special treatment for COMP, COMPL, CONJ, and MOD
	if ($rel eq "COMP" and exists($mapCOMP{$cpos})) {
		$rel = $mapCOMP{$cpos};
	}
#	elsif ($rel eq "COMPL") {
#		$rel = $mapCOMPL{$cpos};
#	}
	elsif ($rel eq "CONJ" and exists($mapCONJ{$cpos})) {
		#print STDERR "rel $rel for cpos $cpos\n";
		$rel = $mapCONJ{$cpos};
	}
	elsif ($rel eq "MOD" and exists($mapMOD{$cpos})) {
		$rel = $mapMOD{$cpos};
	}
     $wordNode->setAttribute( 'rel', $rel );
     $wordNode->setAttribute( 'pos', $pos );

    # print "$eaglesTag\n";
     # store node in hash, key sentenceId:wordId, in order to resolve dependencies
     my $key = "$scount:$id";
     $docHash{$key}= $wordNode;
     
     $conllHash{$scount} =  $conllHash{$scount}."$_";
     }
  }

my $docstring = $dom->toString(3);
print STDERR $docstring;
print STDERR "------------------------------------------------\n";
#exit;

## adjust dependencies (word level), 
my @sentences = $dom->getElementsByTagName('SENTENCE');
#foreach my $sentence  ( $dom->getElementsByTagName('SENTENCE'))

for(my $i = 0; $i < scalar(@sentences); $i++)
{  

		my $sentence = @sentences[$i];
		my $sentenceId = $sentence->getAttribute('ord');
		#print STDERR "adjusting dependencies in sentence: ".$sentence->getAttribute('ord')."\n";
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
					print STDERR "loop detected in sentence: ".$sentence->getAttribute('ord')."\n";
					last;
				}
			}
	}
}

my $docstring = $dom->toString(3);
print STDERR $docstring;
print STDERR "------------------------------------------------\n";
#exit;

#insert chunks
foreach my $sentence  ( $dom->getElementsByTagName('SENTENCE'))
{
	
	my $sentenceId = $sentence->getAttribute('ord');
	print STDERR "insert chunks in sentence: $sentenceId\n";
	#my $chunkCount = 1;
	my $parent;
	my @nodes =  $sentence->getElementsByTagName('NODE');
	my $nonewChunk = 0;
	
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
		
			my $currlem = $node->getAttribute('lem');
			print STDERR "current node $currlem in sentence $sentenceId\n";
			#if this is a main verb or auxiliary used as main verb 
			# (as auxiliary rel=v, auxilaries don't get their own chunk, they should live inside the main verbs' chunk)
			if ($node->exists('self::NODE[@cpos="v"] and not(self::NODE[@rel="v"])'))
			{
				 my $verbchunk = XML::LibXML::Element->new( 'CHUNK' );
				  #if this node is parent of a coordination
				 if ($node->exists('child::NODE[@mi="CC" and @rel="conj"]'))
				 {
				 	$verbchunk->setAttribute('type', 'coor-v');
				 }
				 # no coordination
				 else
				 {
				 	$verbchunk->setAttribute('type', 'grup-verb');
				 }
 
				 $parent->appendChild($verbchunk);
				 $verbchunk->setAttribute('ord', $node->getAttribute('ord'));
				 $verbchunk->setAttribute('si', $node->getAttribute('rel'));
			
				#$node->removeAttribute('rel');
				$node->removeAttribute('head');
				$verbchunk->appendChild($node);
				 
				 # the key in hash should point now to the chunk instead of the node
				 my $ord = $node->getAttribute('ord');
				 my $idKey = "$sentenceId:$ord";
				 $docHash{$idKey}= $verbchunk;
				 
# 				 my $docstring = $dom->toString(3);
# 				print STDERR $docstring;

			}
			# if this is a subordinating conjunction, switch the dependencies
#			elsif($node->getAttribute('mi') eq "CS") {
#			elsif($node->exists('self::NODE[@mi="CS"] and not(self::NODE[@lem="como"])')) {
#				print STDERR "subord conjunction $currlem\n";
#				my @children = $node->childNodes();
#				print STDERR scalar(@children) . " children\n";
#				foreach my $child (@children) {
#					$parent->appendChild($child);
#					$child->setAttribute('head',$node->getAttribute('head'));
#				}
#				$parent->removeChild($node);
#				my $grandchild = $children[0]->firstChild;
#				print STDERR "\n";
#				$children[0]->insertBefore($node,$grandchild);
#				$node->removeAttribute('head');
#				$node->setAttribute('rel','conj');			
#			}
# Ancora special case?
#		        elsif($node->getAttribute('mi') =~ /elliptic/)
#			{
#			    my @children = $node->childNodes();
#			    foreach my $child (@children)
#			    {
#				$parent->appendChild($child);
#				$child->setAttribute('head',$parent->getAttribute('ord'));
#			    }
#			    $parent->removeChild($node);
#			    $node->unbindNode();
#			}
			# if this is a noun, a personal or a demonstrative pronoun, or a number, make a nominal chunk (sn)
			elsif ($node->exists('self::NODE[@cpos="n" or @pos="pp" or @pos="pd" or @pos="pi" or @pos="Z" or starts-with(@mi,"P0")]'))
			{
				 my $nounchunk = XML::LibXML::Element->new( 'CHUNK' );
				 #if this node is parent of a coordination
				 if ($node->exists('child::NODE[@lem="ni" or @rel="coord"]'))
				 {
				 	$nounchunk->setAttribute('type', 'coor-n');
				 }
				 # no coordination
				 else
				 {
				 	$nounchunk->setAttribute('type', 'sn');
				 }
				 #print STDERR "node: ".$node->getAttribute('lem')." ,parent: ".$parent->toString."\n";
				
				 if($node->getAttribute('mi') =~ /^P0/ && $node->getAttribute('rel') eq 'pass')
				 {
				    $nounchunk->setAttribute('si', 'impers');
				 }
				 else
				 {
				    $nounchunk->setAttribute('si', $node->getAttribute('rel'));
				 }
				 $nounchunk->setAttribute('ord', $node->getAttribute('ord'));
				 #$node->removeAttribute('rel');
				 $node->removeAttribute('head');
				 $nounchunk->appendChild($node);
				 $parent = &attachNewChunkUnderChunk($nounchunk,$parent); # $parent->appendChild($nounchunk);
				 # the key in hash should point now to the chunk instead of the node
				 my $ord = $node->getAttribute('ord');
				 my $idKey = "$sentenceId:$ord";
				 $docHash{$idKey}= $nounchunk;
				 
			}
			# if this is a preposition, make a prepositional chunk (grup-sp)
			elsif ($node->exists('self::NODE[starts-with(@mi,"SP")]'))
			{
				 #print STDERR "parent of prep: \n".$parent->toString."\n";
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
			# if this is punctuation mark 
			elsif ($node->exists('self::NODE[starts-with(@mi,"F")]'))
			{
				 my $ord = $node->getAttribute('ord');
				print STDERR "punctuation mark " . $node->getAttribute('mi') . " ($ord) in sentence $sentenceId\n";
				 my $fpchunk = XML::LibXML::Element->new( 'CHUNK' );
				 $fpchunk->setAttribute('type', 'F-term');
				 $fpchunk->setAttribute('si', 'term');
				 $fpchunk->setAttribute('ord', $node->getAttribute('ord'));
				 $node->removeAttribute('rel');
				 $node->removeAttribute('head');
				 $fpchunk->appendChild($node);
				$parent->appendChild($fpchunk);

			     # the key in hash should point now to the chunk instead of the node
				 my $idKey = "$sentenceId:$ord";
				#print STDERR "chunk under idkey $idKey " . $docHash{$idKey} . "\n";
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
}

# try to switch the main verb and the modal verb

my @modals = $dom->findnodes('//CHUNK/NODE[(@lem="poder" or @lem="deber") and @cpos="v" and ../CHUNK/NODE[@mi="VMN0000" and @rel="cd"]]');
print STDERR scalar(@modals) ." modal verbs\n";
foreach my $modv (@modals) {
	my $parentChunk = $modv->parentNode();
	my $vmchild = @{$modv->findnodes('../CHUNK/NODE[@mi="VMN0000" and @rel="cd"]')}[0];
	my $vmparent = $vmchild->parentNode();
	$parentChunk->insertBefore($vmchild,$modv);
	$vmchild->appendChild($modv);
	$vmchild->setAttribute('rel',$modv->getAttribute('rel'));
	$modv->setAttribute('rel','v');
	#children of main verb chunk
	my @vmchildren = $vmparent->childNodes();
	foreach my $child (@vmchildren) {
		$parentChunk->insertAfter($child,$vmparent);
	}
	$parentChunk->removeChild($vmparent);
}
# add a dummy chunk between SENTENCE and NODE
my @chunklessnodes = $dom->findnodes('//SENTENCE/NODE');
print STDERR scalar(@chunklessnodes) ." nodes directly under SENTENCE\n";
foreach my $node (@chunklessnodes) {
	my $sent = $node->parentNode();
	my $topchunk = XML::LibXML::Element->new( 'CHUNK' );
	$topchunk->setAttribute('ord',$node->getAttribute('ord'));
	$topchunk->setAttribute('rel',$node->getAttribute('rel'));
	$topchunk->setAttribute('si','top');
	$topchunk->setAttribute('comment','dummy chunk from iula conversion');
	$sent->insertBefore($topchunk,$node);
	$topchunk->appendChild($node);
}

# coordinations are cascading
# in general: upgrade the chunks that are under nodes to be attached under the first chunk ancestor
my @underchunks = $dom->findnodes('//NODE/CHUNK');
print STDERR scalar(@underchunks) ." chunks under node\n";
foreach my $uchunk (@underchunks) {
	my $parentChunk = @{$uchunk->findnodes('ancestor::CHUNK[1]')}[0];
	if ($parentChunk) {
		my $headnode = $parentChunk->firstChild;
		$parentChunk->insertAfter($uchunk,$headnode);
	}
	else {
		print STDERR "I don't know what to do here!\n";
		print STDERR $uchunk->toString(3);
		print STDERR "\n" . $uchunk->nodePath() . "\n";
	}
}

my $docstring = $dom->toString(3);
print STDOUT $docstring;

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
