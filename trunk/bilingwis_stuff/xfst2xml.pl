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
my $allInOneChapter =1;


while(<XFST>){
	#if(/^[XIV]+\t/){ # for chapters in gregorio..
	#if(/^newChapter/){ # other texts
	if($allInOneChapter){ # texts with no chapter
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
		};
		$sentence_count=1;
		$allInOneChapter =0; # texts without chapters -> treat all as same chapter
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
			my $t = XML::LibXML::Element->new( 't' );
			$t->setAttribute('n', $article_count."-".$sentence_count."-".$token_count);
			$sentence->appendChild($t);
			# root + derivational suffixes = one token (for lexical alignment), all the rest of the morphemes: 1 morpheme = 1 token
			my ($word, $analysis) = split('\t');
			my $w = XML::LibXML::Element->new( 'w' );
			$w->appendText($word);
			$t->appendChild($w);
			
			my ($wroot, $rest) = split('\[\^DB\]',$analysis);
			$analysis =~ s/\Q$wroot\E//;
			$analysis =~ s/\[\^DB\]//;
			my ($empty, @morphs) = split('\[--\]' , $analysis);
			
			my $morph_count =1;
			
			
			# root
			my $root = XML::LibXML::Element->new( 'root' );
			my @rootMorphs = split('\[--\]' , $wroot);
			my @rootforms = ($wroot =~ m/([A-Za-zñéóúíáüäöÑ']+?)\[/g) ;
			my ($root_only) = ($wroot =~ m/^([A-Za-zñéóúíáüäöÑ']+?)\[/) ;
			my $rootform; 
			foreach my $r (@rootforms){
				$rootform .= $r;
			}
			$root->appendText($rootform);
			$root->setAttribute('root', $root_only);
			
			my $rootmorph_count =1;
			foreach my $m (@rootMorphs){
				my $morpheme = XML::LibXML::Element->new( 'rootmorph' );
				$morpheme->setAttribute('n', $article_count."-".$sentence_count."-".$token_count."-".$morph_count."-".$rootmorph_count);
				$root->appendChild($morpheme);
				my ($form) = ($m =~ /^([^\[]+)/) ;
				#$rootform .= $form;
				$morpheme->appendText($form);
				my ($translation) = ($m =~ /=([^\]]+)/) ;
				if($translation){
					$morpheme->setAttribute('translation',$translation);
#					my $trans = XML::LibXML::Element->new( 'trans' );
#					$trans->appendText($translation);
#					$morpheme->appendChild($trans);
				}
				my ($postag) = ($m =~ /\[([^\]\+]+)\]/) ;
				if($postag){
					$morpheme->setAttribute('pos',$postag);
#					my $pos = XML::LibXML::Element->new( 'pos' );
#					$pos->appendText($postag);
#					$morpheme->appendChild($pos);
				}
				my ($mtag) =($m =~ /(\+[^\]]+)/) ;
				if($mtag){
					$morpheme->setAttribute('tag',$mtag);
#					my $tag = XML::LibXML::Element->new( 'tag' );
#					$tag->appendText($mtag);
#					$morpheme->appendChild($tag);
				}
			
				$rootmorph_count++;
				#print "f: $form, t: $trans, p: $pos, t: $tag\t";
			}
			#print" rootform: $rootform \n";
			
			$t->appendChild($root);
			$root->setAttribute('n', $article_count."-".$sentence_count."-".$token_count."-".$morph_count);
			$morph_count++;
			
			# morphs 
			#print $analysis."\n";
			foreach my $m (@morphs){
				my $morpheme = XML::LibXML::Element->new( 'morph' );
				$morpheme->setAttribute('n', $article_count."-".$sentence_count."-".$token_count."-".$morph_count);
				$t->appendChild($morpheme);
				
				my ($form) = ($m =~ /^([^\[]+)/) ;
				#$rootform .= $form;
				$morpheme->appendText("-".$form);
				
				my ($postag) = ($m =~ /\[([^\]\+]+)\]/) ;
				if($postag){
					$morpheme->setAttribute('pos',$postag);
#					my $pos = XML::LibXML::Element->new( 'pos' );
#					$pos->appendText($postag);
#					$morpheme->appendChild($pos);
				}
				my ($mtag) =($m =~ /(\+[^\]]+)/) ;
				if($mtag){
					$morpheme->setAttribute('tag',$mtag);
#					my $tag = XML::LibXML::Element->new( 'tag' );
#					$tag->appendText($mtag);
#					$morpheme->appendChild($tag);
				}
			
				$morph_count++;
			}
			#print "root: $wroot, tags: @rootPosTags, morphs: @rootMorphs \n";
		}
		
		
	}
	
}
close(XFST);
my $docstring = $dom->toString(3);
print STDOUT $docstring;