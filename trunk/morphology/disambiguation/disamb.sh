#!/bin/bash

#XFST_DIR=/home/clsquoia/google_squoia/morphology/analyzer_xfst
#XFST_BIN=$XFST_DIR/quechua-web-db.fst

export XFST_DIR=/home/clsquoia/google_squoia/morphology/normalizer
#XFST_BIN=$XFST_DIR/normalizer.fst
export TOKENIZER=$XFST_DIR/tokenize.pl
#export GUESS=$XFST_DIR/ 
#export LOOKUP=$XFST_DIR/lookup.script

# POS_MODEL=wapiti/model1/model_lbfgs_nowordforms
# MORPH1_MODEL=wapiti/model2/model_lbfgs_lc
# MORPH2_MODEL=wapiti/model3/model_lc_bigrammLemmas
# MORPH3_MODEL=wapiti/model4/model_lc_bigrammLemmas

# with inforesources
# POS_MODEL=wapiti/model1/model_lbfgs_nowordforms_w_inforesources
# MORPH1_MODEL=wapiti/model2/model_lbfgs_lc_with_inforesources 
# MORPH2_MODEL=wapiti/model3/model_lc_bigrammLemmas_with_inforesources
# MORPH3_MODEL=wapiti/model4/model_lc_bigrammLemmas_with_inforesources

# with ahk
# POS_MODEL=wapiti/model1/model_w_ahk
# MORPH1_MODEL=wapiti/model2/model_w_ahk 
# MORPH2_MODEL=wapiti/model3/model_w_ahk
# MORPH3_MODEL=wapiti/model4/model_w_ahk

# with inforesources +ahk
POS_MODEL=wapiti/model1/model_w_inforesources_ahk
MORPH1_MODEL=wapiti/model2/model_w_inforesources_ahk
MORPH2_MODEL=wapiti/model3/model_w_inforesources_ahk
MORPH3_MODEL=wapiti/model4/model_w_inforesources_ahk



XFST_FILE=$1

#perl splitSentences.pl  | perl $TOKENIZER | lookup -f lookup.script -flags cKv29TT > tmp/test.xfst

#cat tmp/test.xfst | perl cleanGuessedRoots.pl > tmp/test_clean.xfst
#cat tmp/test_clean.xfst | perl xfstToCrf_pos.pl -test > tmp/pos.test

cat $XFST_FILE | perl wapiti/xfst2wapiti_pos.pl -test > tmp/pos.test

wapiti label -m $POS_MODEL tmp/pos.test > tmp/pos.result

perl disambiguateRoots.pl tmp/pos.result $XFST_FILE > tmp/pos.disamb

perl wapiti/xfst2wapiti_morphTest.pl -1 tmp/pos.disamb > tmp/morph1.test

wapiti label -m $MORPH1_MODEL tmp/morph1.test > tmp/morph1.result

perl wapiti/xfst2wapiti_morphTest.pl -2 tmp/morph1.result > tmp/morph2.test

wapiti label -m $MORPH2_MODEL tmp/morph2.test > tmp/morph2.result

perl wapiti/xfst2wapiti_morphTest.pl -3 tmp/morph2.result > tmp/morph3.test

wapiti label -m $MORPH3_MODEL tmp/morph3.test > tmp/morph3.result

perl wapiti/xfst2wapiti_morphTest.pl -4 tmp/morph3.result > tmp/disamb.xfst

cat tmp/disamb.xfst | perl printWords.pl