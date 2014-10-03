#!/usr/bin/perl
	
package squoia::intrachunkOrder;					
use utf8;
use strict;
use List::MoreUtils qw(uniq);



# read ordering information from rules file into a hash, keys are the defined 
# variable names: e.g. x1-xn and 'head'. For every key, store ordering information in an array, at
# element [0] -> position relativ to head (integer) (head is at position 0)
# rest of elements [1-n] -> will be filled with pointers to the node(s) the condition applies to

sub main{
	my $dom = ${$_[0]};
	my %rules = %{$_[1]};
	my $verbose = $_[2];
	
	print STDERR "#VERBOSE ". (caller(0))[3]."\n" if $verbose;

	my @allHeadConditions = keys(%rules);
	# get all SENTENCE nodes, iterate over childnodes
	#foreach my $node ( $dom->getElementsByTagName('*'))
	foreach my $sentence  ( $dom->getElementsByTagName('SENTENCE'))
	{
		#print STDERR $sentence->toString if $verbose;
		#get all NODES within SENTENCE
		my @sentenceNODES = $sentence->findnodes('descendant::NODE');
		
		foreach my $node (@sentenceNODES)
		{
			if ($node->hasChildNodes())
			{
				foreach my $headCond (@allHeadConditions)
				{								  
					my @headConditions = squoia::util::splitConditionsIntoArray($headCond);
	
					# evaluate all head condition(s), if true for this node, check if the childnode conditions apply
					if(squoia::util::evalConditions(\@headConditions,$node))
					{ 
						my $order = @{ $rules{$headCond} }[1];
						my @variablesWithNewPositions = split(/\s+/,$order);
						my %variablesWithNodeRefs =();
						push(@{$variablesWithNodeRefs{'head'}},$node);
						
						my %nodesNotCoveredByConditions =();
	
						my %originalPositions =();
						my $ref = $node->getAttribute('ref');
						$originalPositions{$ref} = $node;								
						
						my $dummyIndex = 0;
						my $childCondref = @{ $rules{$headCond} }[0];
														
						#my @children = $node->childNodes();
						my @children = $node->findnodes('descendant::NODE');
	
						# for every childnode of node, check if one of the conditions applies
						foreach my $child (@children)
						{	
							my $ref = $child->getAttribute('ref');
							$originalPositions{$ref} = $child;
					
							foreach my $childCond (@$childCondref)
							{
								# split the conditions on the child nodes into variable and actual conditions (e.g. x1:my.func=attributive)
								my ($variable, $childNodeCondition) =  split( ':', $childCond);	
								my @singleChildNodeConditionsforEvaluation = squoia::util::splitConditionsIntoArray($childNodeCondition);
	
								if(squoia::util::evalConditions(\@singleChildNodeConditionsforEvaluation,$child))
								{ 
									push(@{$variablesWithNodeRefs{$variable}},$child);
									if (exists($nodesNotCoveredByConditions{$ref})) 
									{
										delete($nodesNotCoveredByConditions{$ref});
									}
									last;
								}
								else
								{
									$nodesNotCoveredByConditions{$ref} = $child;
								}
							}
						}
						my @originalPositionArray = sort {$a<=>$b} (keys (%originalPositions));
						for (my $i=0;$i<scalar(@originalPositionArray);$i++)
						{
							$originalPositions{$originalPositionArray[$i]}=$i;
						}
							
						foreach my $nodeNotCoveredref (keys %nodesNotCoveredByConditions)
						{
								my $dummyVariable = "y".$dummyIndex;
								push(@{$variablesWithNodeRefs{$dummyVariable}},$nodesNotCoveredByConditions{$nodeNotCoveredref});
						}
							
						# fill an array with the variables from the input sequence
						my @inputSequenceFull= ();
						foreach my $key (keys %variablesWithNodeRefs)
						{	
							foreach my $node (@{$variablesWithNodeRefs{$key}})
							{
							 my $ref=$node->getAttribute('ref');
							 my $oldPosition = $originalPositions{$ref};
							 $inputSequenceFull[$oldPosition] = $key;
							}
						}
						my @inputSequence = uniq(@inputSequenceFull);
						print STDERR " sentence nr:" . $sentence->getAttribute('ref') ."\n" if $verbose;
							
						# @inputSequence = original sequence of nodes (by variables),
						# @variablesWithNewPositions = new sequence of nodes as defined in grammar file
						print STDERR "input sequence: @inputSequence\n" if $verbose;
						#print STDERR scalar(@inputSequence) if $verbose;	
						print STDERR "variables with node pos: @variablesWithNewPositions\n" if $verbose;
						#print STDERR scalar(@variablesWithNewPositions) if $verbose;	
										
						my $outputSequence = squoia::util::mergeArrays(\@inputSequence,\@variablesWithNewPositions);
						
						print STDERR "output sequence: @{$outputSequence}\n" if $verbose;
						
						# insert attribute ord (order) into xml of all the nodes,
						# order is defined by the index of the variable @outputSequence
						# (can be different from actual index though, as one variable might)
						# refer to more than one node (if the condition evaluated to true for more
						# than one node)
						# retrieve the nodes from the hash (by variablename)
						my $orderIndex = 0;
						
						foreach my $orderedVariable (@{$outputSequence})
						{
							#get corresponding node(s)
							foreach my $node (@ {$variablesWithNodeRefs{$orderedVariable}})
							{
								#print STDERR "i:$orderIndex\n" if $verbose;
								$node->setAttribute('ord', $orderIndex);
								#print STDERR "------------------\n$node\n------------------------\n" if $verbose;
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
