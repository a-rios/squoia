#!/usr/bin/perl


use strict;
use utf8;
use open ':utf8';
binmode STDERR, ':utf8';
use XML::LibXML;

my $num_args = $#ARGV + 1;
if ($num_args != 2) {
  print "\nUsage: perl FLtagged2xml.pl es_FL.tagged book_id \n";
  exit;
  }

my $file = $ARGV[0];
my $bookID = $ARGV[1];
open (TAGGED, "<", $file)  or die "Can't open input file \"$file\": $!\n";
;

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

while(<TAGGED>){
	#if(/^[XIV]+\t/){ # for chapters in gregorio..
	if(/newChapter/){ # other texts
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
	# empty line = sentence end
	elsif(/^\s*$/ ){
		 # append prev sentence
	      $article->appendChild($sentence);
	      $sentence->setAttribute('n', $article_count."-".$sentence_count);
	      $sentence->setAttribute('Intertext_id', '1:'.$abs_sentence_count);
	      $sentence->setAttribute('lang', 'es');
	      # reset $sentence
	      undef $sentence;
	      $sentence = XML::LibXML::Element->new( 's' );
	      $sentence_count++;
	      $abs_sentence_count++;
	      $token_count=0;
	      
	}
	else{
		$token_count++;
		my ($form, $lem, $pos, $prob) = split('\s');
		my $t = XML::LibXML::Element->new( 't' );
		$t->setAttribute('n', $article_count."-".$sentence_count."-".$token_count);
		$t->setAttribute('pos', $pos);
		$t->setAttribute('lemma', $lem);
		$t->appendText($form);
		$sentence->appendChild($t);
		
		# if end of file: append sentence
		if(eof){
		  $article->appendChild($sentence);
	      $sentence->setAttribute('n', $article_count."-".$sentence_count);
	      $sentence->setAttribute('lang', 'es');
		}
		
	}
}

close(TAGGED);
my $docstring = $dom->toString(3);
print STDOUT $docstring;