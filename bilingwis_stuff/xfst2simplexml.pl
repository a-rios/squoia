#!/usr/bin/perl

use strict;
use utf8;
use open ':utf8';
binmode STDERR, ':utf8';

use XML::LibXML;

my $num_args = $#ARGV + 1;
if ($num_args != 2) {
  print "\nUsage: perl xfst2xml.pl quz.xfst book_id \n";
  exit;
  }

my $file = $ARGV[0];
my $bookID = $ARGV[1];
open (XFST, "<", $file)  or die "Can't open input file \"$file\": $!\n";

my $abs_sentence_count=1; # absolute sentence number, needed because of Intertext..
my $sentence_count = 1;
my $article_count = 0;
my $token_count =1;
my $sentence = XML::LibXML::Element->new( 's' ); # actual sentence
my $article; # actual chapter

my $dom = XML::LibXML->createDocument ('1.0', 'UTF-8');
my $book = $dom->createElementNS( "", "book" );
$book->setAttribute('id', $bookID);
$dom->setDocumentElement( $book );



while(<XFST>){
	#if(/^[XIV]+\t/){ # for chapters in gregorio..
	if(/^newChapter/){ # other texts
		$article = XML::LibXML::Element->new( 'article' );
		$book->appendChild($article);
		#undef $article;
		$article_count++;
		$article->setAttribute('n',$article_count);
		my $tocEntry = XML::LibXML::Element->new( 'tocEntry' );
		my ($toc) = ($_ =~ /^([XIV]+)/);
		if($toc){
			$tocEntry->setAttribute('title', $toc);
			$article->appendChild($tocEntry);
		}
		$sentence_count=1;
		
	}
	elsif(/#EOS/){
		 # append prev sentence
	      $article->appendChild($sentence);
	      $sentence->setAttribute('n', $article_count."-".$sentence_count);
	      $sentence->setAttribute('Intertext_id', '1:'.$abs_sentence_count);
	      $sentence->setAttribute('lang', 'quz');
	      # reset $sentence
	      undef $sentence;
	      $sentence = XML::LibXML::Element->new( 's' );
	      $sentence_count++;
	      $abs_sentence_count++;
	      $token_count=0;
	      
	}
	else{
		unless(/^\s*$/){
			$token_count++;
			# root + derivational suffixes = one token (for lexical alignment), all the rest of the morphemes: 1 morpheme = 1 token
			my ($word, $analysis) = split('\t');
			
			my ($wroot, $rest) = split('\[\^DB\]',$analysis);
			$analysis =~ s/\Q$wroot\E//;
			$analysis =~ s/\[\^DB\]//;
			my ($empty, @morphs) = split('\[--\]' , $analysis);
			
			# root
			my $t = XML::LibXML::Element->new( 't' );
			$t->setAttribute('n', $article_count."-".$sentence_count."-".$token_count);
			$sentence->appendChild($t);
			
			my @rootMorphs = split('\[--\]' , $wroot);
			my @rootforms = ($wroot =~ m/([A-Za-zñéóúíáüäöÑ']+?)\[/g) ;
			my $rootform; 
			foreach my $r (@rootforms){
				$rootform .= $r;
			}
			# rootform empty: punctuation
			if($rootform eq ''){
				($rootform) = ($wroot =~ m/^([^\[]+)\[/) ;
			}
			$t->appendText($rootform);
			my ($translation) = ($wroot =~ /=([^\]]+)/) ;
			
			my @postags = ($wroot =~ /\[([^\]\+\=\-]+?)\]/g) ;
			my $pos="";
			for(my $i=0; $i<scalar(@postags);$i++){
				my $p = @postags[$i];
				if($i==scalar(@postags)-1){
					$pos .= $p;
				}
				else{
					$pos .= $p."_";
				}
			}
			my @mtags  =($wroot =~ /(\+[^\]]+)/g) ;
			my $mtag="";
			for(my $i=0; $i<scalar(@mtags);$i++){
				my $mt = @mtags[$i];
				if($i==scalar(@mtags)-1){
					$mtag .= $mt;
				}
				else{
					$mtag .= $mt."_";
				}
			}
			$t->setAttribute('pos', $pos);
			if($mtag){$t->setAttribute('tag', $mtag);}
			if($translation){$t->setAttribute('translation', $translation);}
			if($rootform){$t->setAttribute('lemma', $rootform);}
			
			#print" rootform: $rootform \n";
			
			
			# morphs 
			#print $analysis."\n";
			foreach my $m (@morphs){
				$token_count++;
				my $t = XML::LibXML::Element->new( 't' );
				$t->setAttribute('n', $article_count."-".$sentence_count."-".$token_count);
				$sentence->appendChild($t);
				
				my ($form) = ($m =~ /^([^\[]+)/) ;
				#$rootform .= $form;
				$t->appendText("-".$form);
				
				my ($postag) = ($m =~ /\[([^\]\+]+)\]/) ;
				if($postag){
					$t->setAttribute('pos',$postag);
#					my $pos = XML::LibXML::Element->new( 'pos' );
#					$pos->appendText($postag);
#					$morpheme->appendChild($pos);
				}
				my ($mtag) =($m =~ /(\+[^\]]+)/) ;
				if($mtag){
					$t->setAttribute('tag',$mtag);
#					my $tag = XML::LibXML::Element->new( 'tag' );
#					$tag->appendText($mtag);
#					$morpheme->appendChild($tag);
				}
			}
			#print "root: $wroot, tags: @rootPosTags, morphs: @rootMorphs \n";
		}
		
		
	}
	
}
close(XFST);
my $docstring = $dom->toString(3);
print STDOUT $docstring;