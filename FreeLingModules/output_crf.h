//////////////////////////////////////////////////////////////////
//
//    based on FreeLing - Open Source Language Analyzers
//    created project SQUOIA November 2015
//    http://ariosquoia.github.io/squoia/
//
////////////////////////////////////////////////////////////////

#ifndef _OUTPUT_CRF
#define _OUTPUT_CRF

#include <iostream> 
#include "freeling/output/output_handler.h"

using namespace std;
using namespace freeling;

class output_crf : public output_handler {

 public:   
   // empty constructor. 
   output_crf ();
   // constructor from cfg file
   //output_crf (const std::wstring &cfgFile);
   // destructor. 
   ~output_crf ();

   /// Fill conll_sentence from freeling::sentence
   void freeling2crf(std::wostream &sout, const freeling::sentence &s) const;
   
   void PrintResults(std::wostream &sout, const list<freeling::sentence> &ls) const;
   
   /// print given a document to sout in appropriate format
   void PrintResults(std::wostream &sout, const freeling::document &doc) const;
   
  // std::list<analysis> output_crf::printRetokenizable(std::wostream &sout, const list<word> &rtk, list<word>::const_iterator w, const wstring &lem, const wstring &tag) const;
   
   /// inherit other methods
   using output_handler::PrintResults;
 
};

#endif
