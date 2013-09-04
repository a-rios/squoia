#!/bin/sh
#cat "$1" | perl spellcheck.pl

SPELLCHECK_DIR=/home/clsquoia/google_squoia/morphology/spellChecker/
TOKENIZER=$SPELLCHECK_DIR/tokenizer/tokenize.pl
ANALYZER_BIN=$SPELLCHECK_DIR/analyzer/
NORMALIZER_BIN=$SPELLCHECK_DIR/normalizer/
TMP=$SPELLCHECK_DIR/tmp

INFILE=$(readlink -f $1)

perl $TOKENIZER < $INFILE | flookup $ANALYZER_BIN/analyzeUnificado.bin  | perl listwrongspellings.pl | flookup -a $NORMALIZER_BIN/chain.bin | perl getSuggestions.pl -1 | fmed -c 7 -l 5 $ANALYZER_BIN/spellcheckUnificado.bin | perl getSuggestions.pl -2 > $TMP/text.out


# | perl formatspellcheckoutput.pl > "$1".out
# if [ -s  "$1"]; 
# then  cat "$1" #
# else
# # -n tests to see if the argument is non empty
# echo "everything correct"
# fi

if [ -s $TMP/text.out ] ; then
cat $TMP/text.out
else
echo "no spellings errors found"
fi ;
