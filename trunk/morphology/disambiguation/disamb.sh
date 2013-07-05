#!/bin/bash

#XFST_DIR=/home/clsquoia/google_squoia/morphology/analyzer_xfst
#XFST_BIN=$XFST_DIR/quechua-web-db.fst

XFST_DIR=/home/clsquoia/google_squoia/morphology/normalizer
XFST_BIN=$XFST_DIR/normalizer.fst
TOKENIZER=$XFST_DIR/tokenize.pl

POS_MODEL=pos/sicuani_greg_c_5

MORPH1_MODEL=morph1/sicuani_greg_model_c_1
MORPH2_MODEL=morph2/sicuani_greg_model_c0.5
MORPH3_MODEL=morph3/sicuani_greg_model_c0.5

XFST_FILE=$1

#perl splitSentences.pl  |
#perl $TOKENIZER | lookup -f ../normalizer/lookup.script -flags cKv29TT  > tmp/test.xfst

#cat tmp/test.xfst | perl cleanGuessedRoots.pl > tmp/test_clean.xfst
#cat tmp/test.xfst | perl xfstToCrf_pos.pl -test > tmp/pos.test

cat $XFST_FILE | perl xfstToCrf_pos.pl -test > tmp/pos.test

crf_test -m $POS_MODEL tmp/pos.test > tmp/pos.result

perl disambiguateRoots.pl tmp/pos.result $XFST_FILE > tmp/pos.disamb

perl xfstToCrf_morphTest.pl -1 tmp/pos.disamb > tmp/morph1.test

crf_test -m $MORPH1_MODEL tmp/morph1.test > tmp/morph1.result

perl xfstToCrf_morphTest.pl -2 tmp/morph1.result > tmp/morph2.test

crf_test -m $MORPH2_MODEL tmp/morph2.test > tmp/morph2.result

perl xfstToCrf_morphTest.pl -3 tmp/morph2.result > tmp/morph3.test

crf_test -m $MORPH3_MODEL tmp/morph3.test > tmp/morph3.result

perl xfstToCrf_morphTest.pl -4 tmp/morph3.result > tmp/disamb.xfst

cat tmp/disamb.xfst | perl printWords.pl