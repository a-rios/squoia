#!/bin/sh
#cat "$1" | perl spellcheck.pl

TOKENIZER=tokenizer/tokenize.pl
ANALYZER_BIN=analyzer/
NORMALIZER_BIN=normalizer/



perl $TOKENIZER < "$1" | flookup $ANALYZER_BIN/analyzeUnificado.fst | perl listwrongspellings.pl | flookup -a $NORMALIZER_BIN/chain.foma | perl getSuggestions.pl -1 | fmed2 -c 7 -l 5 $ANALYZER_BIN/spellcheckUnificado.fst | perl getSuggestions.pl -2 > "$1".out


# | perl formatspellcheckoutput.pl > "$1".out
# if [ -s  "$1"]; 
# then  cat "$1" #
# else
# # -n tests to see if the argument is non empty
# echo "everything correct"
# fi

if [ -s "$1".out ] ; then
cat "$1".out
else
echo "no spellings errors found"
fi ;
