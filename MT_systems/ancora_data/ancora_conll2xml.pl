#!/usr/bin/perl

#use utf8;                  # Source code is UTF-8

use strict;
use XML::LibXML;
binmode STDIN, ':utf8';
binmode STDERR, ':utf8';

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
     $wordNode->setAttribute( 'lem', $lem );
     $wordNode->setAttribute( 'mi', $mi );
     $wordNode->setAttribute( 'cpos', $cpos );
     $wordNode->setAttribute( 'head', $head );
     $wordNode->setAttribute( 'rel', $rel );
     $wordNode->setAttribute( 'pos', $pos );

    # print "$eaglesTag\n";
     # store node in hash, key sentenceId:wordId, in order to resolve dependencies
     my $key = "$scount:$id";
     $docHash{$key}= $wordNode;
     
     $conllHash{$scount} =  $conllHash{$scount}."$_";
     }
  }

#my $docstring = $dom->toString(3);
#print STDERR $docstring;
#print STDERR "------------------------------------------------\n";

## adjust dependencies (word level), 
my @sentences = $dom->getElementsByTagName('SENTENCE');
#foreach my $sentence  ( $dom->getElementsByTagName('SENTENCE'))

for(my $i = 0; $i < scalar(@sentences); $i++)
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
					print STDERR "loop detected in sentence: ".$sentence->getAttribute('ord')."\n";
					last;
				}
			}
	}
}
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
		
 #print STDERR $node->getAttribute('lem')."\n";
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
		        elsif($node->getAttribute('mi') =~ /elliptic/)
			{
			    my @children = $node->childNodes();
			    foreach my $child (@children)
			    {
				$parent->appendChild($child);
				$child->setAttribute('head',$parent->getAttribute('ord'));
			    }
			    $parent->removeChild($node);
			    $node->unbindNode();
			}
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
				 my $fpchunk = XML::LibXML::Element->new( 'CHUNK' );
				 $fpchunk->setAttribute('type', 'F-term');
				 $fpchunk->setAttribute('si', 'term');
				 $fpchunk->setAttribute('ord', $node->getAttribute('ord'));
				 $node->removeAttribute('rel');
				 $node->removeAttribute('head');
				 $fpchunk->appendChild($node);

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
#	
#	#print STDERR $sentence->toString()."\n";
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
