//////////////////////////////////////////////////////////////////
//
//    FreeLing - Open Source Language Analyzers
//
//    Copyright (C) 2014   TALP Research Center
//                         Universitat Politecnica de Catalunya
//
//    This library is free software; you can redistribute it and/or
//    modify it under the terms of the GNU Affero General Public
//    License as published by the Free Software Foundation; either
//    version 3 of the License, or (at your option) any later version.
//
//    This library is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
//    Affero General Public License for more details.
//
//    You should have received a copy of the GNU Affero General Public
//    License along with this library; if not, write to the Free Software
//    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
//
//    contact: Lluis Padro (padro@lsi.upc.es)
//             TALP Research Center
//             despatx C6.212 - Campus Nord UPC
//             08034 Barcelona.  SPAIN
//
////////////////////////////////////////////////////////////////

/// Author:  Annette Rios
/// adapted from fl2_tagger.cc  by F.Tyers

#include <sstream>
#include <iostream>

#include <map>
#include <vector>

/// headers to call freeling library
#include "freeling.h"

using namespace std;
using namespace freeling;

//una     lc      uno     DI0FS0  uno     PI0FS000        1       Z       uno     Z       unir    VMM03S0 ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     1       DI0FS0

void PrintResults (list<sentence> &ls, vector<wstring> &lc_sent,  vector< vector<wstring> > &features_sent) {
  word::const_iterator ait;
  sentence::const_iterator w;
  list < sentence >::iterator is;
  int nsentence = 0;

  for (is = ls.begin (); is != ls.end (); is++, ++nsentence) {

      for (w = is->begin (); w != is->end (); w++) {
	wcout << w->get_form () << L"\t" << lc_sent[w->get_position()];
	
	  for (ait = w->selected_begin (); ait != w->selected_end (); ait++) {
	      wcout << L"\t" << ait->get_lemma (); 
	    for (int j = 0; j < features_sent[w->get_position()].size(); j++)
	    {
		wcout << L"\t" << features_sent[w->get_position()][j];
	    }
	    wcout << L"\t" << ait->get_tag ();
	  }
	wcout << endl;	
      }
    // sentence separator: blank line.
    wcout << endl;
  }
}

///---------------------------------------------
///
///   The following program reads from stdin a tagged text in wapiti crf format, 
///   and applies NE classification to it. Output in same wapiti crf format.
///
///  
///---------------------------------------------
int main (int argc, char **argv) {
  nec *neclass=NULL;

  /// set locale to an UTF8 compatible locale
  util::init_locale(L"default");

  if(argc < 2) { 
    wcerr << L"nec" << endl;
    wcerr << L"Usage: nec nec-cfg (e.g. /opt/matxin/local/share/freeling/es/nerc/nec/nec-ab-rich.dat), input stdin" << endl;
    wcerr << endl; 
    return 1;
  }
 
  // /opt/matxin/local/share/freeling/es/nerc/nec/nec-ab-rich.dat
  neclass = new nec(util::string2wstring(argv[1]));
  
  
// eso     lc      ese     PD0NS000        ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     0       PD0NS000        PD0NS000                                                                                  
// es      lc      ser     VSIP3S0 ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     0       VSIP3S0 VSIP3S0                                                                                                   
// una     lc      uno     DI0FS0  uno     PI0FS000        1       Z       uno     Z       unir    VMM03S0 ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     1       DI0FS0                                                                                                    
// prueba  lc      prueba  NCFS000 probar  VMIP3S0 probar  VMM02S0 ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     1       NCFS000                                                                                                           
// para    lc      para    SPS00   parar   VMIP3S0 parar   VMM02S0 ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     1       SPS00                                                                                                             
// maria   uc      maria   NP00000 ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     ZZZ     0       NP00000 NP00000



  /// read and tag input
  wstring text, form, lc, lemma, feat, tag;
  vector< vector<wstring> > features_sent;
  vector<wstring> lc_sent;
      
  sentence av;
  list < sentence > ls;
  unsigned long totlen = 0;


  while (std::getline (std::wcin, text)) {
    if (text != L"")  {	// got a word line
      wistringstream sin;
      sin.str (text);
      vector<wstring> features;

      sin >> form >> lc >> lemma;
      lc_sent.push_back(lc);
      for(int n=0; n<16; n++){
	  sin >> feat;
	  features.push_back(feat);
      }
      features_sent.push_back(features);
      sin >> tag;
      
       // build new word
       word w (form);
       w.set_span (totlen, totlen + form.size ());
       totlen += text.size () + 1;
       
       // process word line, according to input format.
       // add all analysis in line to the word.
       w.clear ();

        analysis an (lemma, tag);
        w.add_analysis (an);

       
       av.push_back (w);   // append new word to sentence

     }
     else {  // blank line, sentence end.
       totlen += 2;
       
       ls.push_back (av);
       neclass->analyze(ls); 
       PrintResults (ls, lc_sent, features_sent);
       
       av.clear ();		// clear list of words for next use
       ls.clear ();		// clear list of sentences for next use
       features_sent.clear();	// clear features
       lc_sent.clear();		// clear lc
     }
   }
   
  // process last sentence in buffer (if any)
  ls.push_back (av);		// last sentence (may not have blank line after it)
  neclass->analyze (ls);
  PrintResults (ls, lc_sent, features_sent);
  
  // clean up. 
     delete neclass;
  
  return 0;
}
