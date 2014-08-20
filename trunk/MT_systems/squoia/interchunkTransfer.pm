#!/usr/bin/perl

# syntactic transfer between chunks
# inter_transfer file format:
# 1. Reference chunk condition:
#	Selects the reference (my) chunk to transfer information from(up) or to(down)
# 2. Reference chunk attribute:
#	Which attribute to transfer(up) or to add/update(down).
# 3. Related chunk condition:
#	Restricts the related chunk to transfer information from(down) or to(up).
# 4. Related chunk attribute:
#	Which attribute to transfer(down) or to add/update(up).
# 5. Direction:
#	In which direction the information is propagated, i.e.
#	down or up the tree
# 6. Write mode:
#	Can be one of three, either:
#	no-overwrite (do not overwrite previous information),
#	overwrite (overwrite previous information),
#	concat (concatenate information to any previously existing).

# 1			2		3		4		5		6
# descendantCond	descendantAttr	ancestorCond	ancestorAttr	direction	writeMode

package squoia::interchunkTransfer;
use strict;
use utf8;


sub main{
	my $dom = ${$_[0]};
	my %interConditions = %{$_[1]};
	my $verbose = $_[2];
	
	print STDERR "#VERBOSE ". (caller(0))[3]."\n" if $verbose;

	foreach my $chunk ( $dom->getElementsByTagName('CHUNK') ) {
		#print STDERR "chunk ". $chunk->getAttribute('ref'). " of type " . $chunk->getAttribute('type')."\n" if $verbose;
		foreach my $condpair (keys %interConditions) {
			my ($chunk1Cond,$chunk2Cond,$path1to2) = split( /\t/, $condpair);
	#		print STDERR "$chunk1Cond ++ $chunk2Cond\n" if $verbose;
			#check chunk 1 conditions
			my @chunk1Conditions = squoia::util::splitConditionsIntoArray($chunk1Cond);
	#		print STDERR "$chunk1Cond\n" if $verbose;
			my $result = squoia::util::evalConditions(\@chunk1Conditions,$chunk);
	#		print STDERR "result $result\n" if $verbose;
			if ($result) {
				# find chunk candidates related to the current chunk
				my @candidates = squoia::util::getRelatedChunks($chunk,$path1to2);
				#print STDERR scalar(@candidates). " candidates\n" if $verbose;
				if (scalar(@candidates)) {
				#	print STDERR "first chunk candidate ". $candidates[0]->getAttribute('ref')."\n" if $verbose;
					my @chunk2Conditions = squoia::util::splitConditionsIntoArray($chunk2Cond);
					#print STDERR "conditions: @chunk2Conditions\n" if $verbose;
					# find the first candidate related chunk that satisfies the conditions
					foreach my $cand (@candidates) {
						my $result = squoia::util::evalConditions(\@chunk2Conditions,$cand);
						#print STDERR "result $result for candidate ". $cand->getAttribute('ref')."\n" if $verbose;
						if ($result) {
						#	print STDERR "found\n" if $verbose;
							my $configline = $interConditions{$condpair};
							&transferSyntInformation($configline,$chunk,$cand,$verbose);
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

sub transferSyntInformation{
	my $configline = $_[0];
	my $chunk1 = $_[1];
	my $chunk2   = $_[2];
	my $verbose = $_[3];

	my ($chunk1Attr,$chunk2Attr,$direction,$wmode) = split(/\t/,$configline);
	print STDERR "$configline\n" if $verbose;
	if ($direction eq "1to2") {
		&propagateAttr($chunk1,$chunk1Attr,$chunk2,$chunk2Attr,$wmode,$verbose);
	}
	elsif ($direction eq "2to1") {
		&propagateAttr($chunk2,$chunk2Attr,$chunk1,$chunk1Attr,$wmode,$verbose);	# switch src and trg
	}
	else {
		die "wrong propagation direction \"$direction\"";
	}
}

sub propagateAttr{
	my $srcNode = $_[0];
	my $srcAttr = $_[1];
	my $trgNode = $_[2];
	my $trgAttr = $_[3];
	my $wmode = $_[4];
	my $verbose = $_[5];

	my $srcVal = $srcNode->getAttribute($srcAttr);
	if ($srcVal eq '') {
		$srcVal = $srcAttr;
	}
	$srcVal =~ s/["]//g;
	if ($wmode eq "concat") {
		my $newVal = $trgNode->getAttribute($trgAttr).",".$srcVal;
		$trgNode->setAttribute($trgAttr,$newVal);
	}
	elsif ($wmode eq "overwrite") {
		$trgNode->setAttribute($trgAttr,$srcVal);
	}
	elsif ($wmode eq "no-overwrite") {
		if ($trgNode->getAttribute($trgAttr)) {
			print STDERR "target node already has a value for the attribute ".$trgAttr."\n" if $verbose;
		}
		else {
#			print STDERR "$srcAttr => $trgAttr = $srcVal\n" if $verbose;
			$trgNode->setAttribute($trgAttr,$srcVal);
		}
	}
	else {
		die "wrong write mode \"$wmode\"";
	}
}

1;
