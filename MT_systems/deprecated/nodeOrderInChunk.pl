#!/usr/bin/perl
						
use utf8;
use strict;
use Storable;    # to retrieve hash from disk
use open ':utf8';
#binmode STDIN, ':utf8';
use XML::LibXML;
use List::MoreUtils qw(uniq);
require "util.pl";

# retrieve hash with config parameters from disk, get path to file with semantic information
eval {
	my $hashref = retrieve('parameters');
} or die "No parameters defined. Run readConfig.pl first!";

my %hash    = %{ retrieve("parameters") };
my $nodeOrderFile = $hash{"NodeOrderFile"}
  or die "Intra-Chunk node order file not specified in config!";
open NODEORDERFILE, "< $nodeOrderFile" or die "Can't open $nodeOrderFile : $!";



my %rules = ();
#read information from file into a hash (head, childnode(s),  order)
while (<NODEORDERFILE>) {
	chomp;
	s/#.*//;     # no comments
	s/^\s+//;    # no leading white
	s/\s+$//;    # no trailing white
	next if /^$/;	# skip if empty line
	my ($head, $childnodes, $order ) = split( /\s*\t+\s*/, $_, 3 );

	$head =~ s/\s//g;	# no whitespace within condition
	$childnodes =~ s/\s//g;	# no whitespace within condition

	# split childnodes into array and remove empty fields resulted from split
	my @childsWithEmptyFields = split( ',', $childnodes);
	my @childs = grep {$_} @childsWithEmptyFields; 
	
	#print STDERR @childs[0];
	# fill hash, key is head condition(s)
	my @value = ( \@childs, $order);
	$rules{$head} = \@value;

}


# read ordering information from rules file into a hash, keys are the defined 
# variable names: e.g. x1-xn and 'head'. For every key, store ordering information in an array, at
# element [0] -> position relativ to head (integer) (head is at position 0)
# rest of elements [1-n] -> will be filled with pointers to the node(s) the condition applies to

my $parser = XML::LibXML->new("utf8");
my $dom    = XML::LibXML->load_xml( IO => *STDIN );
my @allHeadConditions = keys(%rules);
# get all SENTENCE nodes, iterate over childnodes
#foreach my $node ( $dom->getElementsByTagName('*'))
foreach my $sentence  ( $dom->getElementsByTagName('SENTENCE'))
{
	#print STDERR $sentence->toString;
	#get all NODES within SENTENCE
	my @sentenceNODES = $sentence->findnodes('descendant::NODE');
	
	foreach my $node (@sentenceNODES)
	{
		if ($node->hasChildNodes())
		{
			foreach my $headCond (@allHeadConditions)
			{								  
				my @headConditions = &splitConditionsIntoArray($headCond);

				# evaluate all head condition(s), if true for this node, check if the childnode conditions apply
				if(&evalConditions(\@headConditions,$node))
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
							my @singleChildNodeConditionsforEvaluation = &splitConditionsIntoArray($childNodeCondition);

							if(&evalConditions(\@singleChildNodeConditionsforEvaluation,$child))
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
#					print STDERR "sentence nr:";
#					print STDERR $sentence->getAttribute('ref');
#					print STDERR "\n";
						
					# @inputSequence = original sequence of nodes (by variables),
					# @variablesWithNewPositions = new sequence of nodes as defined in grammar file
					# print STDERR "input sequence: @inputSequence\n"; print STDERR scalar(@inputSequence);	
					# print STDERR "variables with node pos: @variablesWithNewPositions\n";		print STDERR scalar(@variablesWithNewPositions);	
									
					my $outputSequence = &mergeArrays(\@inputSequence,\@variablesWithNewPositions);
					
					#print STDERR "output sequence: @{$outputSequence}\n";
					
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
							#print STDERR "i:$orderIndex\n";
							$node->setAttribute('ord', $orderIndex);
							#print STDERR "------------------\n$node\n------------------------\n";
							$orderIndex++;
						}
					}
					
				}
			}
		}
	}
}
# print new xml to stdout
my $docstring = $dom->toString;
print STDOUT $docstring;
