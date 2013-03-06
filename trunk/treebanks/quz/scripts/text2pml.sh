#!/bin/bash


export OZLI="/home/ozli"
export XFST_DIR=$OZLI/mount/xfst_tools/web_analyzer_v2
export SCRIPT_DIR=$OZLI/squoia/annotation/quechua/scripts
#export FOMA_DIR=$OZLI/mount/foma_tools/quechua_tools_distributable/spellcheckUnificado_foma



perl $SCRIPT_DIR/tokenize_withsentPerLine.pl | lookup -flags cKv29TT $XFST_DIR/quechua-web-db.fst | perl $SCRIPT_DIR/truecase_xfst2.pl | perl $SCRIPT_DIR/xfst2pml_v2.pl | perl $SCRIPT_DIR/preAnotate.pl

