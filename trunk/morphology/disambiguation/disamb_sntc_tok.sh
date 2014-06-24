#!/bin/bash

export XFST_DIR=/home/clsquoia/google_squoia/morphology/normalizer

export TOKENIZER=$XFST_DIR/tokenize.pl


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
MORPH1_MODEL=wapiti/model2/model_w_inforesources_ahk_WAQ
MORPH2_MODEL=wapiti/model3/model_w_inforesources_ahk
MORPH3_MODEL=wapiti/model4/model_w_inforesources_ahk

TMP_DIR=tmp4
EVID="cuz"
PISPAS="pis"
RAW_FILE=$1

cat $RAW_FILE | perl $TOKENIZER | lookup -f lookup.script -flags cKv29TT > $TMP_DIR/test.xfst

cat $TMP_DIR/test.xfst | perl cleanGuessedRoots.pl -$EVID -$PISPAS > $TMP_DIR/test_clean.xfst

cat $TMP_DIR/test_clean.xfst | perl wapiti/xfst2wapiti_pos.pl -test > $TMP_DIR/pos.test

wapiti label -m $POS_MODEL $TMP_DIR/pos.test > $TMP_DIR/pos.result

perl disambiguateRoots.pl $TMP_DIR/pos.result $TMP_DIR/test_clean.xfst > $TMP_DIR/pos.disamb

perl wapiti/xfst2wapiti_morphTest.pl -1 $TMP_DIR/pos.disamb > $TMP_DIR/morph1.test

wapiti label -m $MORPH1_MODEL $TMP_DIR/morph1.test > $TMP_DIR/morph1.result

perl wapiti/xfst2wapiti_morphTest.pl -2 $TMP_DIR/morph1.result > $TMP_DIR/morph2.test

wapiti label -m $MORPH2_MODEL $TMP_DIR/morph2.test > $TMP_DIR/morph2.result

perl wapiti/xfst2wapiti_morphTest.pl -3 $TMP_DIR/morph2.result > $TMP_DIR/morph3.test

wapiti label -m $MORPH3_MODEL $TMP_DIR/morph3.test > $TMP_DIR/morph3.result

perl wapiti/xfst2wapiti_morphTest.pl -4 $TMP_DIR/morph3.result > $TMP_DIR/disamb.xfst

cat $TMP_DIR/disamb.xfst | perl printWords.pl