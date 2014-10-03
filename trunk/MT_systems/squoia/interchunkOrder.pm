#!/usr/bin/perl

package squoia::interchunkOrder;				
use utf8;
use strict;
use List::MoreUtils qw(uniq);


# read ordering information from rules file into a hash, keys are the defined 
# variable names: e.g. x1-xn and 'head'. For every key, store ordering information in an array, at
# element [0] -> position relativ to head (integer) (head is at position 0)
# rest of elements [1-n] -> will be filled with pointers to the chunk(s) the condition applies to

sub main{
	my $dom = ${$_[0]};
	my %rules = %{$_[1]};
	my $verbose = $_[2];
	print STDERR "#VERBOSE ". (caller(0))[3]."\n" if $verbose;
	my @allHeadConditions = keys(%rules);
	# get all SENTENCE chunks, iterate over childchunks
	foreach my $sentence  ( $dom->getElementsByTagName('SENTENCE'))
	{
		#print STDERR $sentence->toString if $verbose;
		#get all CHUNKS within SENTENCE
		my @sentenceCHUNKS = $sentence->findnodes('descendant::CHUNK');
	
		foreach my $chunk (@sentenceCHUNKS)
		{
			if ($chunk->hasChildNodes())
			{
				foreach my $headCond (@allHeadConditions)
				{								  
					my @headConditions = squoia::util::splitConditionsIntoArray($headCond);
	
					# evaluate all head condition(s), if true for this chunk, check if the childchunk conditions apply
					if(squoia::util::evalConditions(\@headConditions,$chunk))
					{
						my $order = @{ $rules{$headCond} }[1];
						my @variablesWithNewPositions = split(/\s/,$order);
						my %variablesWithChunkRefs =();
						push(@{$variablesWithChunkRefs{'head'}},$chunk);
						
						my %chunksNotCoveredByConditions =();
	
						my %originalPositions =();
						#my $ref = $chunk->getAttribute('ref');	# TODO: what does happen when two chunks have the same ref?
						#$originalPositions{$ref} = $chunk;								
						my $p_ord = $chunk->getAttribute('p_ord');
						$originalPositions{$p_ord} = $chunk;								
						
						my $dummyIndex = 0;
						my $childCondref = @{ $rules{$headCond} }[0];
														
						my @children = $chunk->childNodes();
	
						# for every child of chunk, check if one of the conditions applies
						foreach my $child (@children)
						{	
							# get all childs that are CHUNKs
							if($child->nodeName eq 'CHUNK')										
							{
								#my $ref = $child->getAttribute('ref');	# TODO: what does happen when two chunks have the same ref?
								#$originalPositions{$ref} = $child;
								my $c_ord = $child->getAttribute('c_ord');
								$originalPositions{$c_ord} = $child;
						
								foreach my $childCond (@$childCondref)
								{
									# split the conditions on the child chunks into variable and actual conditions (e.g. x1:my.func=attributive)
									#replace double colon within xpath with special string so it will not get split
									#$childCond =~ s/(xpath{[^}]+)::([^}]+})/\1XPATHDOUBLECOLON\2/g;
									$childCond =~ s/::/XPATHDOUBLECOLON/g;
									print STDERR "child chunk with ref ".$child->getAttribute('ref')." escaped cond: $childCond\n" if $verbose;
									my ($variable, $childChunkCondition) =  split( ':', $childCond);
									#put the double colon back
									$childChunkCondition =~ s/XPATHDOUBLECOLON/::/g;
									print STDERR "child chunk cond: $childChunkCondition \n" if $verbose;
									my @singleChildChunkConditionsforEvaluation = squoia::util::splitConditionsIntoArray($childChunkCondition);
									#print STDERR "single child chunk cond: @singleChildChunkConditionsforEvaluation \n" if $verbose;
									if(squoia::util::evalConditions(\@singleChildChunkConditionsforEvaluation,$child))
									{
										#print STDERR "matched child $variable:".$child->toString()."\n" if $verbose;
										push(@{$variablesWithChunkRefs{$variable}},$child);
										if (exists($chunksNotCoveredByConditions{$c_ord})) 
										{
											delete($chunksNotCoveredByConditions{$c_ord});
										}
										last;
									}
									else
									{
										$chunksNotCoveredByConditions{$c_ord} = $child;
									}
								}
							}
						}
						my @originalPositionArray = sort {$a<=>$b} (keys (%originalPositions));
						for (my $i=0;$i<scalar(@originalPositionArray);$i++)
						{
							$originalPositions{$originalPositionArray[$i]}=$i;
						}
	
						foreach my $chunkNotCoveredref (keys %chunksNotCoveredByConditions)
						{
							my $dummyVariable = "y".$dummyIndex;
							push(@{$variablesWithChunkRefs{$dummyVariable}},$chunksNotCoveredByConditions{$chunkNotCoveredref});
						}
						
						# fill an array with the variables from the input sequence
						my @inputSequenceFull= ();
						my $parentChunk = $chunk;	# 
						foreach my $key (keys %variablesWithChunkRefs)
						{	
							foreach my $chunk (@{$variablesWithChunkRefs{$key}})
							{
								my $ord;
							 	if ($chunk->isSameNode($parentChunk)) {
									$ord=$chunk->getAttribute('p_ord');
								}
								else {
									$ord = $chunk->getAttribute('c_ord');
								}
								 my $oldPosition = $originalPositions{$ord};
								 $inputSequenceFull[$oldPosition] = $key;
							}
						}
						my @inputSequence = uniq(@inputSequenceFull);

						print STDERR "sentence nr:" if $verbose;
						print STDERR $sentence->getAttribute('ref')."\n" if $verbose;
						
						# @inputSequence = original sequence of chunks (by variables),
						# @variablesWithNewPositions = new sequence of chunks as defined in grammar file
						print STDERR "input sequence: @inputSequence\n" if $verbose;	
						print STDERR "variables with chunk position: @variablesWithNewPositions\n" if $verbose;
										
						my $outputSequence = squoia::util::mergeArrays(\@inputSequence,\@variablesWithNewPositions);
						
						print STDERR "output sequence: @{$outputSequence}\n" if $verbose;
						
						# insert attribute ord (order) into xml of all the chunks,
						# order is defined by the index of the variable @outputSequence
						# (can be different from actual index though, as one variable might)
						# refer to more than one chunk (if the condition evaluated to true for more
						# than one chunk)
						# retrieve the chunks from the hash (by variablename)
						my $orderIndex = 0;
							
						foreach my $orderedVariable (@{$outputSequence})
						{
							#get corresponding chunk(s)
							foreach my $chunk (@ {$variablesWithChunkRefs{$orderedVariable}})
							{
							 	if ($chunk->isSameNode($parentChunk)) {
									$chunk->setAttribute('p_ord', $orderIndex);
								}
								else {
									$chunk->setAttribute('c_ord', $orderIndex);
								}
								print STDERR "i:$orderIndex\n" if $verbose;
								$chunk->setAttribute('ord', $orderIndex);
								print STDERR "------------------\n$chunk\n------------------------\n" if $verbose;
								$orderIndex++;
							}
						}
						
					}
				}
			}
		}
	}
	
	# print new xml to stdout
	#my $docstring = $dom->toString;
	#print STDOUT $docstring if $verbose;
}

1;
