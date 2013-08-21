#!/bin/bash

export PROJECT_DIR=/home/ozli/squoia/google_squoia
export XFST_DIR=$PROJECT_DIR/morphology/analyzer_xfst


perl truecase_xfst2.pl | perl xfst2pml_v2.pl | perl preAnotate.pl

