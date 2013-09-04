#!/bin/sh


SPELLCHECK_DIR=path-to-your-spellChecker-folder/
TOKENIZER=$SPELLCHECK_DIR/tokenizer/tokenize.pl
ANALYZER_BIN=$SPELLCHECK_DIR/analyzer/
NORMALIZER_BIN=$SPELLCHECK_DIR/normalizer/
TMP=$SPELLCHECK_DIR/tmp/

INFILE=$(readlink -f $1)

perl $TOKENIZER < $INFILE | flookup $ANALYZER_BIN/analyzeUnificado.fst  | perl listwrongspellings.pl | flookup -a $NORMALIZER_BIN/chain.bin | perl getSuggestions.pl -1 | fmed -c 7 -l 5 $ANALYZER_BIN/spellcheckUnificado.fst | perl getSuggestions.pl -2 > $TMP/text.out


if [ -s $TMP/text.out ] ; then
cat $TMP/text.out
else
echo "no spellings errors found"
fi ;
