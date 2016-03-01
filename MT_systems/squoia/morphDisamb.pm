#!/usr/bin/perl

# disambiguate morphologically ambigous translations
# path to morphologic/pos disambiguation file is expected to be included in the config file
# format of morphologic disambigution file, tab separated:
# source-lemma target-morph/pos	condition (optional) probability (between 0-1, in case condition is not met or not given)
# example (Spanish lemma 'ebrio' can be translated into Quechua as 'machaq' (a drinker) or 'machasqa' (drunk))
# ebrio	my.mi=VRoot+Ag	my.smi=/NC/	0.3
# ebrio	my.mi=VRoot+Perf	my.smi=/AQ/ 0.7

package squoia::morphDisamb;
use utf8;
use strict;

sub main{
	my $dom = ${$_[0]};
	my %morphSel = %{$_[1]};
	my $verbose = $_[2];

	print STDERR "#VERBOSE ". (caller(0))[3]."\n" if $verbose;

	my @allNodeConditions = keys(%morphSel);

	# get all nodes (NODE) with ambigous translations (SYN)
	foreach my $node ( $dom->getElementsByTagName('NODE')) 
	{
		my @SYNnodes = $node->getChildrenByLocalName('SYN');
		
		# create hash to store values of synonyms of this particular node
		my %nodehash =();
		
		# if this node has SYN nodes,
		# check if one of the node conditions apply to this node
		if(scalar(@SYNnodes)>0)
		{
			#print STDERR "Disambiguating morphological translation options in sentence: ".$node->findvalue('ancestor::SENTENCE/@ref')."\n" if $verbose;
			foreach my $ruleskey (@allNodeConditions)
				{				
					#print STDERR "rules key: $ruleskey\n";
					my ($nodeCond, $trgtMI) = split('---',$ruleskey);		  
					my @nodeConditions = squoia::util::splitConditionsIntoArray($nodeCond);

					# evaluate all head condition(s), if true for this node, check if the childnode conditions apply
					if(squoia::util::evalConditions(\@nodeConditions,$node))
					{ 
							# check for each target conditions if one of the matching rules applies
							# if yes, check if k=keep or d=delete 
							# -> if keep, keep all matching SYN nodes and delete all the other SYN nodes
							# -> if delete, delete all matching SYN nodes
							
							# get target conditions
							my $trgtConds = @{ $morphSel{$ruleskey}}[0];
							my @trgtConditions = squoia::util::splitConditionsIntoArray($trgtConds);
							print STDERR "target conds: @trgtConditions\n" if $verbose;
							
							if(squoia::util::evalConditions(\@trgtConditions,$node))
							{
								print STDERR "\n node lem:".$node->getAttribute('slem')."\n" if $verbose;
								#keep or delete?
								my $keepOrDelete = @{ $morphSel{$ruleskey}}[1];
								my @targetMIs = split(',',$trgtMI);
								my @matchingSyns=();
								foreach my $trgt (@targetMIs)
								{
										# create xpath string to find matching synonyms:
										# NOTE: if already a rule with 'k' matched: SYN will still be there, no need to check contents of NODE itself, just match SYNs
										my $xpathstring;
										my $selfXpathString;
										if($trgt !~ /=/)
										{ 
											$xpathstring= 'child::SYN[@mi="'.$trgt.'"]';
											#$selfXpathString = 'self::NODE[@mi="'.$trgt.'"]';
										}
										#if other attribute than mi should be used for disambiguation
										else
										{ 
											my ($attr,$value) = split('=',$trgt);
											$xpathstring= 'child::SYN[@'.$attr.'="'.$value.'"]';
											#$selfXpathString= 'self::NODE[@'.$attr.'="'.$value.'"]';
										}
										print STDERR "xpath: $xpathstring\n" if $verbose;
										# find synnode with this 'mi', can be more than one
										my @matchingSynsCand = $node->findnodes($xpathstring);
										#my @matchingSynsCand2 = $node->findnodes($selfXpathString);
										push(@matchingSyns,@matchingSynsCand);
										#push(@matchingSyns,@matchingSynsCand2);
										
									}
									if(scalar(@matchingSyns)>0)
									{ 
											my $matchingtranslation = @matchingSyns[0];
											my @matchingtranslationAttributes = $matchingtranslation->attributes();
											foreach my $m (@matchingSyns){print STDERR "match for $ruleskey:".$m->toString()."\n" if $verbose;}
									
								 		   	if($keepOrDelete eq 'k')
								   			{
								    			# delete the attributes of the first SYN child that have been "copied" into the parent NODE
												#my $firstsyn = $SYNnodes[0];
												my @synattrlist = $node->attributes();
												foreach my $synattr (@synattrlist)
												{
													unless($synattr->nodeName =~ /ref|slem|smi|sform|UpCase|sem/)
													{
														$node->removeAttribute($synattr->nodeName);
													}
												}
												# fill in attributes of best translation
												@SYNnodes = $node->getChildrenByLocalName('SYN');
								    			foreach my $bestattr (@matchingtranslationAttributes)
								    			{
								    				my $value = $bestattr->value;
								    				my $attr = $bestattr->nodeName;
								    				$node->setAttribute($attr, $value);
								    				
								    				
								    			}
								    			#delete all SYN nodes that did not match
								    			foreach my $syn (@SYNnodes)
								    			{
								    				unless( grep( $_ == $syn, @matchingSyns ))
								    				{   
								    					$node->removeChild($syn);
								    				}
								    			}
								    			#print STDERR "after keep : ".$dom->toString()."\n";
								    			#delete SYN node whose attributes have been copied to node
								    			#$node->removeChild($matchingtranslation);
								   			}
								   			elsif($keepOrDelete eq 'd')
								   			{
								   				# get all syn nodes, copy attributes of first syn that is NOT in matching translations
								   				# to NODE, delete all that are in @matchingtranslations, unless there is non left
								   				# in this case: keep last syn and print warning to STDERR
								   				# note: this is the morphological disambiuation -> keep sem attribute (no lexical differences in SYN's disambiguated here!)
													my @synattrlist = $node->attributes();
													foreach my $synattr (@synattrlist)
													{ #print STDERR "attribute to remove in node ".$synattr->nodeName."\n";
														unless($synattr->nodeName =~ /^ref|slem|smi|sform|UpCase|sem/)
														{#print STDERR "removed attribute ".$synattr->nodeName."\n";
															$node->removeAttribute($synattr->nodeName);
														}
													}
													# fill in attributes of first SYN that is not in matchingtranslations
													my @SYNnodes = $node->getChildrenByLocalName('SYN');
								    				foreach my $syn (@SYNnodes)
								    				{
								    					if(!grep( $_ == $syn, @matchingSyns ) or $syn == @SYNnodes[-1])
								    					{ #print STDERR "inserted in node:".$syn->toString."\n" if $verbose;
								    						#print STDERR "mnbr matching syns: ".scalar(@matchingSyns)."\n";
								    						my @Attributes = $syn->attributes();
								    						foreach my $synattr (@Attributes)
								    						{
								    							my $value = $synattr->value;
								    							my $attr =	$synattr->nodeName;
								    							$node->setAttribute($attr, $value);
								    						}
								    						#print STDERR "new node: ".$node->toString()."\n";
								    						last;
								    					}
								    				}
								    				# if ALL syn nodes match: do not remove them! 
								    				unless(scalar(@matchingSyns) >= scalar(@SYNnodes)){
										   				#remove all matching translations:
										   				foreach my $matchingtranslation (@matchingSyns)
										   				{	#print STDERR "delete: ".$matchingtranslation->toString()."\n" if $verbose;
										   					#my $docstring = $dom->toString;
															#print STDERR $docstring if $verbose;
										   					$node->removeChild($matchingtranslation);
										   				}
								    				}
								    				#print  STDERR "xml: ".$dom->toString()."\n";
								    		}
								   			else
								   			{
								    			print STDERR "error: invalid option $keepOrDelete! Valid options are: k (keep) or d (delete). Won't disambiguate.";
								   			 }
								   			 
										}
										
									}
							}
						
					}
			}
			# if this node has only one SYN child left (when all other SYNs have been deleted)
			# -> delete, as SYN is already contained in NODE
			# TODO: check if there's a SYN that is already in NODE -> delete
			my @remainingSYNs = $node->findnodes('child::SYN');
			if(scalar(@remainingSYNs) == 1 && @remainingSYNs[0]->getAttribute('lem') eq $node->getAttribute('lem') && @remainingSYNs[0]->getAttribute('mi') eq $node->getAttribute('mi') )
			{
				$node->removeChild(@remainingSYNs[0]);
			}
	}

	# print new xml to stdout
	#my $docstring = $dom->toString;
	#print STDOUT $docstring;
}
1;
