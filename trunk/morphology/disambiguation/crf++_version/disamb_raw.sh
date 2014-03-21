#!/bin/bash

#XFST_DIR=/home/clsquoia/google_squoia/morphology/analyzer_xfst
#XFST_BIN=$XFST_DIR/quechua-web-db.fst

export XFST_DIR=/home/clsquoia/google_squoia/morphology/normalizer
#XFST_BIN=$XFST_DIR/normalizer.fst
export TOKENIZER=$XFST_DIR/tokenize.pl
#export GUESS=$XFST_DIR/ 
#export LOOKUP=$XFST_DIR/lookup.script

#POS_MODEL=pos/sicuani_greg_c_5
POS_MODEL=pos/sicuani_greg_c2

MORPH1_MODEL=morph1/sicuani_greg_c2
MORPH2_MODEL=morph2/sicuani_greg_c1
MORPH3_MODEL=morph3/sicuani_greg_c0.5

TMP_DIR=tmp3
EVID="aya"
PISPAS="pas"
#XFST_FILE=$1
RAW_FILE=$1

cat $RAW_FILE | perl splitSentences.pl | perl $TOKENIZER | lookup -f lookup.script -flags cKv29TT > $TMP_DIR/test.xfst
#cat $TOK_FILE | lookup -f lookup.script -flags cKv29TT > $TMP_DIR/test.xfst
cat $TMP_DIR/test.xfst | perl cleanGuessedRoots.pl -$EVID -$PISPAS > $TMP_DIR/test_clean.xfst
cat $TMP_DIR/test_clean.xfst | perl xfstToCrf_pos.pl -test > $TMP_DIR/pos.test

#cat $XFST_FILE | perl xfstToCrf_pos.pl -test > $TMP_DIR/pos.test

crf_test -m $POS_MODEL $TMP_DIR/pos.test > $TMP_DIR/pos.result

perl disambiguateRoots.pl $TMP_DIR/pos.result $TMP_DIR/test_clean.xfst > $TMP_DIR/pos.disamb

perl xfstToCrf_morphTest.pl -1 $TMP_DIR/pos.disamb > $TMP_DIR/morph1.test

crf_test -m $MORPH1_MODEL $TMP_DIR/morph1.test > $TMP_DIR/morph1.result

perl xfstToCrf_morphTest.pl -2 $TMP_DIR/morph1.result > $TMP_DIR/morph2.test

crf_test -m $MORPH2_MODEL $TMP_DIR/morph2.test > $TMP_DIR/morph2.result

perl xfstToCrf_morphTest.pl -3 $TMP_DIR/morph2.result > $TMP_DIR/morph3.test

crf_test -m $MORPH3_MODEL $TMP_DIR/morph3.test > $TMP_DIR/morph3.result

perl xfstToCrf_morphTest.pl -4 $TMP_DIR/morph3.result > $TMP_DIR/disamb.xfst

cat $TMP_DIR/disamb.xfst | perl printWords.pl