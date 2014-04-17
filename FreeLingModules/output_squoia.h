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

#ifndef _OUTPUT
#define _OUTPUT

#include <sstream>
#include <iostream> 
#include "freeling.h"
#include "config.h"
#include "analyzer.h"

class output {

 private:
   config *cfg;

   std::wstring outputSenses (const analysis & a);
   std::list<analysis> printRetokenizable(std::wostream &sout, const std::list<word> &rtk, 
                                          std::list<word>::const_iterator w, const std::wstring &lem, 
                                          const std::wstring &tag);
 public:   
   output(config *c);
   ~output() {};
   void PrintTree (std::wostream &sout, parse_tree::const_iterator n, int depth, const document &doc=document());
   void PrintDepTree (std::wostream &sout, dep_tree::const_iterator n, int depth, const document &doc=document());
   void PrintWord (std::wostream &sout, const word &w, bool only_sel=true, bool probs=true);
   void PrintWordCRFMorf (std::wostream &sout, const word &w, bool first_nonpunct_word=false);
   void PrintResults (std::wostream &sout, std::list<sentence > &ls,
                      analyzer &anlz, const document &doc=document());
};


#endif
