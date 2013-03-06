#!/bin/bash

export PROJECT_DIR="insert-path-to-project"
export XFST_DIR=$PROJECT_DIR/trunk/morphology/analyzer_xfst


perl tokenize_withsentPerLine.pl | lookup -flags cKv29TT $XFST_DIR/quechua-web-db.fst | perl truecase_xfst2.pl | perl xfst2pml_v2.pl | perl preAnotate.pl

