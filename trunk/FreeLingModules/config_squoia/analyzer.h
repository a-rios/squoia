//////////////////////////////////////////////////////////////////
//
//    FreeLing - Open Source Language Analyzers
//
//    Copyright (C) 2004   TALP Research Center
//                         Universitat Politecnica de Catalunya
//
//    This library is free software; you can redistribute it and/or
//    modify it under the terms of the GNU General Public
//    License as published by the Free Software Foundation; either
//    version 3 of the License, or (at your option) any later version.
//
//    This library is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
//    General Public License for more details.
//
//    You should have received a copy of the GNU General Public
//    License along with this library; if not, write to the Free Software
//    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
//
//    contact: Lluis Padro (padro@lsi.upc.es)
//             TALP Research Center
//             despatx C6.212 - Campus Nord UPC
//             08034 Barcelona.  SPAIN
//
////////////////////////////////////////////////////////////////

#ifndef _ANALYZER
#define _ANALYZER

#include <iostream> 
#include <list>

/// headers to call freeling library
#include "freeling.h"

/// config file/options handler for this particular sample application
#include "config.h"

using namespace freeling;

class analyzer {

 private:
   // we use pointers to the analyzers, so we
   // can create only those strictly necessary.
   lang_ident *iden;
   tokenizer *tk;
   tagset *tags;
   splitter *sp;
   maco *morfo;
   nec *neclass;
   senses *sens;
   ukb *dsb;
   POS_tagger *tagger;
   phonetics *phon;
   chart_parser *parser;
   dependency_parser *dep;
   coref *corfc;
  
   // store configuration options
   config *cfg;

   // remember token offsets in plain text input
   unsigned long offs;
   // number of sentences processed (used to generate sentence id's)
   unsigned long nsentence;
  
 public: 
   analyzer(config *c);
   ~analyzer();
   void AnalyzeSentences(std::list<sentence> &ls);

   // Receive plain text, return token list.
   void TokenizeText(const std::wstring &text, std::list<word> &av);
 
   // Split list of tokens into sentences
   void SplitSentences(const std::list<word> &av, std::list<sentence> &ls);
   void SplitSentences(const std::list<word> &av, std::list<sentence> &ls, bool flush);

   // Receive plain text, return it tokenized and splitted (and maybe more).
   void AnalyzeText(const std::wstring &text, std::list<sentence> &ls);
   void AnalyzeText(const std::wstring &text, std::list<sentence> &ls, bool flush);

   // Receive list of tokens, return it splitted (and maybe more)
   void AnalyzeTokens(const std::list<word> &av, std::list<sentence> &ls);
   void AnalyzeTokens(const std::list<word> &av, std::list<sentence> &ls, bool flush);

   // Identifiy language if given text
   std::wstring IdentifyLanguage(const std::wstring &text);

   // Solve coreferences in given document
   void SolveCoreferences(document &doc);

   void ResetOffset();
};

#endif

