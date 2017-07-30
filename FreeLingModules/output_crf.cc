//////////////////////////////////////////////////////////////////
//
//    based on FreeLing - Open Source Language Analyzers
//    created project SQUOIA November 2015
//    http://ariosquoia.github.io/squoia/
//
////////////////////////////////////////////////////////////////


//////////////////////////////////////////////////////////
///  Auxiliary functions to print several analysis results
//////////////////////////////////////////////////////////

#include "freeling/morfo/util.h"
#include "freeling/morfo/configfile.h"
//#include "freeling/output/output_crf.h"
#include "output_crf.h"

using namespace std;
using namespace freeling;
using namespace freeling::io;

#undef MOD_TRACENAME
#undef MOD_TRACECODE
#define MOD_TRACENAME L"OUTPUT_CONLL"
#define MOD_TRACECODE OUTPUT_TRACE

//---------------------------------------------
// empty constructor
//---------------------------------------------

output_crf::output_crf()  {}

//---------------------------------------------
// Constructor from config file
//---------------------------------------------

// output_crf::output_crf(const wstring &cfgFile) {
// 
//   enum sections {OUTPUT_TYPE,TAGSET,OPTIONS};
// 
//   config_file cfg(true);
//   cfg.add_section(L"Type",OUTPUT_TYPE);
//   cfg.add_section(L"TagsetFile",TAGSET);
//   cfg.add_section(L"Options",OPTIONS);
//   
//   if (not cfg.open(cfgFile))
//     ERROR_CRASH(L"Error opening file "+cfgFile);
//   
// 
//   wstring line; 
//   while (cfg.get_content_line(line)) {
//     
//     // process each content line according to the section where it is found
//     switch (cfg.get_section()) {
//       
//     case OUTPUT_TYPE: {
//       if (util::lowercase(line)!=L"crf")
//         ERROR_CRASH(L"Invalid configuration file for 'crf' output handler, "+cfgFile);
//       break;
//     }
// 
//     case TAGSET: { 
//       wstring path = cfgFile.substr(0,cfgFile.find_last_of(L"/\\")+1);
//       Tags = new tagset(util::absolute(line,path));
//       break;
//     }
// 
//     case OPTIONS: { 
//       wistringstream sin; sin.str(line);
//       wstring key,val;
//       sin >> key >> val;
//       val = util::lowercase(val);
//       bool b = (val==L"true" or val==L"yes" or val==L"y" or val==L"on");
//       break;
//     }
//       
//     default: break;
//     }
//   }
//   
//   cfg.close(); 
// }


//---------------------------------------------
// Destructor
//---------------------------------------------

output_crf::~output_crf() {}





//---------------------------------------------
// print the morfo-analysis in crf format
//---------------------------------------------
/* Spalten:
0:lowercased word
1:case(lc/uc),
2-3: lem/tag1
4-5: lemma/tag2
6-7: lemma/tag3
8-9:lemma/tag4
10-11:lemma/tag5
12-13:lemma/tag6
14-15:lemma/tag7
16-17:lemma/tag8
18: disambiguate yes/no
19: class
*/

//void output::PrintWordCRFMorf (wostream &sout, const word &w, bool first_nonpunct_word) {
void output_crf::freeling2crf(wostream &sout,  const freeling::sentence &s) const {
   
  
  const wchar_t* sep = L"\t";
  const wchar_t* dummy = L"ZZZ";
  const wchar_t* NPtag = L"NP";
  const wchar_t* VGtag = L"G0000";
  const wchar_t* VarGform = L"ando";
  const wchar_t* VarGform2 = L"ándo";
  const wchar_t* VierGform = L"endo";
  const wchar_t* VierGform2 = L"éndo";
  const wchar_t* ViMperative = L"VMM";
  
  bool first_nonpunct_word = false, found = false;
  for (sentence::const_iterator w = s.begin (); w != s.end (); w++) {
            if (found) {
              first_nonpunct_word = false;
            } else {
              first_nonpunct_word = (w->selected_begin()->get_tag().find(L"F")!=0);
              found = first_nonpunct_word;
         }
  }
  
  //wstring tags = L"";


  for (sentence::const_iterator w=s.begin(); w!=s.end(); w++) {
    
      wstring NPstr = L"";
      wstring notNPtag = L"";
            
      sout << w->get_lc_form(); // lowercased word form

      if (std::iswupper(w->get_form().c_str()[0])) {
	sout << sep  << L"uc";
      }
      else {
	sout << sep  << L"lc";
      }

      word::const_iterator ait;

      word::const_iterator a_beg,a_end;
      a_beg = w->selected_begin();
      a_end = w->selected_end();

      int i = 0;
      const int MAXTAG = 8;
      int nptag = 0;
      for (ait = a_beg; ait != a_end; ait++) {

	  //tags += sep + ait->get_tag();*/
	  std::size_t gerundtag = ait->get_tag().find(VGtag);
	  std::size_t gerundform1 = w->get_form().find(VarGform);
	  std::size_t gerundform2 = w->get_form().find(VarGform2);
	  std::size_t gerundform3 = w->get_form().find(VierGform);
	  std::size_t gerundform4 = w->get_form().find(VierGform2);
	  if ((gerundtag==2) and 
	      (gerundform1 != std::string::npos or gerundform2 != std::string::npos or gerundform3 != std::string::npos or gerundform4 != std::string::npos)) {
	    //wcerr << ait->get_lemma() << L" is a gerund form\n";
	    sout << sep << ait->get_lemma() << sep << ait->get_tag();
	    i++;
	    break;
	  }
	  // do we really want this? always assume that imperative > subjuncitve?
// 	  std::size_t imperative = ait->get_tag().find(ViMperative);
// 	  if ((imperative == 0)) {
// 	  //if (imperative!= std::string::npos) {
// 	 //   wcerr << ait->get_lemma() << L" is an imperative form found at position"<< imperative << L"\n";
// 	    sout << sep << ait->get_lemma() << sep << ait->get_tag();
// 	    i++;
// 	    break;
// 	  }
	  std::size_t found = ait->get_tag().find(NPtag);
	  if ( first_nonpunct_word and (found==0) ) {	// found "NP" at beginning of tag
	    nptag++;
	    NPstr += sep + ait->get_lemma() + sep + ait->get_tag();
	  } else {
	    notNPtag = ait->get_tag();
	    sout << sep << ait->get_lemma() << sep << notNPtag;
	  }
	//}
	//tag_i++;
	i++;
      }
      if (nptag == i) {	// only NP tags...
	sout << NPstr;
      }
      else {	// other tags as NP tags
	if (nptag > 0)
	  i -= nptag;	// discard the NP tags
      }
    /*  while (lem_i < MAXLEM) {
	sout << sep << dummy;
	tags += sep; tags += dummy;
	lem_i++;
      }
      while (tag_i < MAXTAG) {
	tags += sep; tags += dummy;
	tag_i++;
      }*/
      while (i < MAXTAG) {
	sout << sep << dummy << sep << dummy;
	i++;
      }
      //sout << tags;
      sout << sep << bool(w->get_n_selected() > 1);
    //  wcerr << w->get_form() << L"  has tags: " << w->get_n_selected() << L"\n";
      if (a_beg->get_tag().compare(L"Z") != 0) {	// don't print tag "Z", don't force it because maybe it's a "DN"
	if (w->get_n_selected() == 1) {
	  sout << sep << a_beg->get_tag();
	}
	else if ((w->get_n_selected()-nptag) == 1) {	// after discarding NP tags there is one other tag left, the notNPtag
	  sout << sep << notNPtag;
	}
      }
      sout << endl;
  }
}


// ----------------------------------------------------------
// print document in crf format
// ----------------------------------------------------------

void output_crf::PrintResults(wostream &sout, const document &doc) const {


  
  // convert and print each sentence in the document
  for (document::const_iterator p=doc.begin(); p!=doc.end(); p++) {
    if (p->empty()) continue;

    for (list<sentence>::const_iterator s=p->begin(); s!=p->end(); s++) {      
      if (s->empty()) continue;

      freeling2crf(sout,*s);
       sout << endl;
     // cs.print_conll_sentence(sout, WordSpans, N_user);
    }
  }
}

//----------------------------------------------------------
// print list of sentences in crf format
//---------------------------------------------------------

void output_crf::PrintResults (std::wostream &sout, const list<freeling::sentence> &ls) const {

  for (list<freeling::sentence>::const_iterator s=ls.begin(); s!=ls.end(); s++) {
    if (s->empty()) continue;
    
    freeling2crf(sout,*s);
     sout << endl;
  }

}



