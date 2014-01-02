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


//////////////////////////////////////////////////////////
///  Auxiliary functions to print several analysis results
//////////////////////////////////////////////////////////
#include <boost/algorithm/string.hpp>

#include "output_squoia.h"

using namespace std;


//---------------------------------------------
// Constructor
//---------------------------------------------

output::output(config *c) {
  cfg=c;
}

//---------------------------------------------
// Print senses information for an analysis
//---------------------------------------------

wstring output::outputSenses (const analysis & a) {

  wstring res;
  list<pair<wstring,double> > ls = a.get_senses ();
  if (ls.size () > 0) {
    if (cfg->SENSE_WSD_which == MFS)
      res = L" " + ls.begin()->first;
    else  // ALL or UKB specified
      res = L" " + util::pairlist2wstring (ls, L":", L"/");
  }
  else
    res = L" -";

  return res;
}


//---------------------------------------------
// print parse tree
//--------------------------------------------

void output::PrintTree (wostream &sout, parse_tree::const_iterator n, int depth, const document &doc) {

  parse_tree::const_sibling_iterator d;

  sout << wstring (depth * 2, ' ');  
  if (n->num_children () == 0) {
    if (n->info.is_head ()) sout << L"+";
    word w = n->info.get_word ();
    sout << L"(" << w.get_form() << L" " << w.get_lemma() << L" " << w.get_tag ();
    sout << outputSenses ((*w.selected_begin ()));
    sout << L")" << endl;
  }
  else {
    if (n->info.is_head ()) sout << L"+";

    sout<<n->info.get_label();
    if (cfg->COREF_CoreferenceResolution) {
      // Print coreference group, if needed.
      int ref = doc.get_coref_group(n->info.get_node_id());
      if (ref != -1 and n->info.get_label() == L"sn") sout<<L"(REF:" << ref <<L")";
    }
    sout << L"_[" << endl;

    for (d = n->sibling_begin (); d != n->sibling_end (); ++d) 
      PrintTree (sout, d, depth + 1, doc);
    sout << wstring (depth * 2, ' ') << L"]" << endl;
  }
}


//---------------------------------------------
// print dependency tree
//---------------------------------------------

void output::PrintDepTree (wostream &sout, dep_tree::const_iterator n, int depth, const document &doc) {
  dep_tree::const_sibling_iterator d, dm;
  int last, min, ref;
  bool trob;

  sout << wstring (depth*2, ' ');

  parse_tree::const_iterator pn = n->info.get_link();
  sout<<pn->info.get_label(); 
  ref = (cfg->COREF_CoreferenceResolution ? doc.get_coref_group(pn->info.get_node_id()) : -1);
  if (ref != -1 and pn->info.get_label() == L"sn") {
    sout<<L"(REF:" << ref <<L")";
  }
  sout<<L"/" << n->info.get_label() << L"/";

  word w = n->info.get_word();
  sout << L"(" << w.get_form() << L" " << w.get_lemma() << L" " << w.get_tag ();
  sout << outputSenses ((*w.selected_begin()));
  sout << L")";
  
  if (n->num_children () > 0) {
    sout << L" [" << endl;
    
    // Print Nodes
    for (d = n->sibling_begin (); d != n->sibling_end (); ++d)
      if (!d->info.is_chunk ())
        PrintDepTree (sout, d, depth + 1, doc);
    
    // print CHUNKS (in order)
    last = 0;
    trob = true;
    while (trob) {
      // while an unprinted chunk is found look, for the one with lower chunk_ord value
      trob = false;
      min = 9999;
      for (d = n->sibling_begin (); d != n->sibling_end (); ++d) {
        if (d->info.is_chunk ()) {
          if (d->info.get_chunk_ord () > last
              and d->info.get_chunk_ord () < min) {
            min = d->info.get_chunk_ord ();
            dm = d;
            trob = true;
          }
        }
      }
      if (trob)
        PrintDepTree (sout, dm, depth + 1, doc);
      last = min;
    }
    
    sout << wstring (depth * 2, ' ') << L"]";
  }
  sout << endl;
}


//---------------------------------------------
// print retokenization combinations for a word
//---------------------------------------------

list<analysis> output::printRetokenizable(wostream &sout, const list<word> &rtk, list<word>::const_iterator w, const wstring &lem, const wstring &tag) {
  
  list<analysis> s;
  if (w==rtk.end()) 
    s.push_back(analysis(lem.substr(1),tag.substr(1)));
      
  else {
    list<analysis> s1;
    list<word>::const_iterator w1=w; w1++;
    for (word::const_iterator a=w->begin(); a!=w->end(); a++) {
      s1=printRetokenizable(sout, rtk, w1, lem+L"+"+a->get_lemma(), tag+L"+"+a->get_tag());
      s.splice(s.end(),s1);
    }
  }
  return s;
}  


//---------------------------------------------
// print analysis for a word
//---------------------------------------------

void output::PrintWord (wostream &sout, const word &w, bool only_sel, bool probs) {
  word::const_iterator ait;

  word::const_iterator a_beg,a_end;
  if (only_sel) {
    a_beg = w.selected_begin();
    a_end = w.selected_end();
  }
  else {
    a_beg = w.analysis_begin();
    a_end = w.analysis_end();
  }

  for (ait = a_beg; ait != a_end; ait++) {
    if (ait->is_retokenizable ()) {
      list <word> rtk = ait->get_retokenizable ();
      list <analysis> la=printRetokenizable(sout, rtk, rtk.begin(), L"", L"");
      for (list<analysis>::iterator x=la.begin(); x!=la.end(); x++) {
        sout << L" " << x->get_lemma() << L" " << x->get_tag();
        if (probs) sout << L" " << ait->get_prob()/la.size();
      }
    }
    else {
      sout << L" " << ait->get_lemma() << L" " << ait->get_tag ();
      if (probs) sout << L" " << ait->get_prob ();
    }

    if (cfg->SENSE_WSD_which != NONE)
      sout << outputSenses (*ait);
  }
}

//---------------------------------------------
// print desr morpho tag in conll format
//---------------------------------------------

wstring MapEagleTagMorphoFeat(wstring s) { // s: eagletag already in lowercase
  wostringstream features;

  wstring cpos = s.substr(0,1);
  wstring gen;
  wstring num;
  wstring form;
  wstring per;
  wstring mod;
  wstring ten;
  wstring pno;
  wstring fun;
  wstring cas;
  wstring type;
  wstring semclass;
  
  if (cpos == L"a") // Adjectives => 4:gen,5:num[,6:fun]
  {
    gen = s.substr(3,1);
    num = s.substr(4,1);
    fun = s.substr(5,1);
    features<<L"gen="<<gen<<L"|num="<<num;
    if (fun == L"p")
    {
      features<<L"|fun="<<fun;
    }
  }
  else if (cpos == L"d")		// Determiners => 4:gen,5:num[,3:per[,6:pno]]
  {
    gen = s.substr(3,1);
    num = s.substr(4,1);
    per = s.substr(2,1);
    pno = s.substr(5,1);
    features<<L"gen="<<gen<<L"|num="<<num;
    if (per != L"0")
    {
      features<<L"|per="<<per;
      if (pno != L"0")
      {
        features<<L"|pno="<<pno;
      }
    }
  }
  else if (cpos == L"n")	// Nouns => 3:gen,4:num, special case, proper nouns: give them pos=nc, but mark as np in morph column (np=SP,O0,G0,V0)-> delete, desr can't handle this
  {
    gen = s.substr(2,1);
    if (gen == L"0")
    {
      gen = L"c";
    }
    num = s.substr(3,1);
    if (num == L"0")
    {
      num = L"c";
    }
    type = s.substr(1,1);
    //if proper noun, add type to morph
    if(type == L"p")
    {
       semclass = s.substr(4,2);
       features<<L"gen="<<gen<<L"|num="<<num<<L"|np="<<semclass;
       
    }
    else
    {
      features<<L"gen="<<gen<<L"|num="<<num;
    }
  }
  else if (cpos == L"v")	// Verbs => 7:gen,6:num[,5:per],3:mod[,4:ten]
  {
    gen = s.substr(6,1);
    if (gen == L"0")
    {
      gen = L"c";
    }
    num = s.substr(5,1);
    if (num == L"0")
    {
      num = L"c";
    }
    features<<L"gen="<<gen<<L"|num="<<num;
    per = s.substr(4,1);
    mod = s.substr(2,1);
    ten = s.substr(3,1);
    if (per != L"0")
    {
      features<<L"|per="<<per;
    }
    features<<L"|mod="<<mod;
    if (ten != L"0")
    {
      features<<L"|ten="<<ten;
    }
  }
  else if (cpos == L"p")	// Pronouns => 4:gen,5:num[,3:per][,6:cas]
  {	// TODO: desr ignores the number of the possessor (position 7) in possessive pronouns!?!  and politeness (position 8) in general?!?
    // possessive FL: PX PX1MS0P0=> px1ms000 nuestro	nuestro	p	px	gen=m|num=s|per=1
    // interrogative FL: PT000000 => Dónde	Dónde	p	pt	gen=c|num=c
    gen = s.substr(3,1);
    num = s.substr(4,1);
    // relative pronouns
    // que: FL: PR0CN000 => que	que	p	pr	gen=0|num=c
    // donde: FL PR000000 => donde	donde	p	pr	gen=0|num=0
    if (boost::iequals(s.substr(0,2),L"pr"))
    {
      gen = L"0";
      if (num == L"n")
      {
        num = L"c";
      }
    }
    else
    { 
      if (gen == L"0")
      {
        gen = L"c";
      }
      if (num == L"0" || num == L"n")
      {
        num = L"c";
      }
    }
    features<<L"gen="<<gen<<L"|num="<<num;
    // special case 'se' FL: P00CN000, should be -> gen=c|num=c|per=3 (not p0!, per=3)
    per = s.substr(2,1);
    if(per == L"0" && boost::iequals(s.substr(0,2),L"p0") )
    {
      features<<L"|per="<<L"3";
    }
    else if (per != L"0")
    {
      features<<L"|per="<<per;
    }
    cas = s.substr(5,1);
    if (cas != L"0")
    {
      features<<L"|cas="<<cas;
    }
  }
  else if (cpos == L"s")	// Prepositions => 4:gen,5:num,3:for
  {
    gen = s.substr(3,1);
    if (gen == L"0")
    {
	gen = L"c";
    }
    num = s.substr(4,1);
    if (num == L"0")
    {
      num = L"c";
    }
    form = s.substr(2,1);
    features<<L"gen="<<gen<<L"|num="<<num<<L"|for="<<form;
  }  
  else// if (cpos == L"r") c|f|i|r|y|w|z
  {
    features<<L"_";
  }
  features<<L"\t_\t_\t_\t_";
  return features.str();
}

void PrintNumber(wostream &sout, sentence::const_iterator &w, int c)
{
		sout<<c;				//ID
		sout<<L"\t"<<w->get_form();			//FORM
		sout<<L"\t"<<w->get_form();			//LEMMA take the form as lemma
		sout<<L"\tz";			//CPOS
		sout<<L"\tZ";			//POS
		sout<<L"\t"<<MapEagleTagMorphoFeat(w->get_tag());	//MORPH
		sout<<endl;
}

//void PrintMorfo(wostream &sout, list<sentence> &ls, analyzer &anlz) {
void PrintMorfo(wostream &sout, list<sentence>::iterator &is, analyzer &anlz) {
  sentence::const_iterator w;
  sentence::const_iterator next_w;
  sentence::const_iterator prior_w;
  //list<sentence>::iterator is;

  //for (is=ls.begin(); is!=ls.end(); is++) {

    
    // for each word in sentence
    int c = 1;
    for (w=is->begin(); w!=is->end(); w++) 
    {
      
      wstring eagletag = w->get_tag();
      std::transform(eagletag.begin(), eagletag.end(), eagletag.begin(), ::tolower);
      wstring pos = eagletag.substr(0,2);
      if(boost::iequals(pos,L"p0"))
      {
	pos = L"pp";
      }
      else if(boost::iequals(pos,L"np"))
      {
	pos = L"nc";
      }
      wstring cpos = eagletag.substr(0,1);
      wstring form = w->get_form();
       
      if (cpos == L"w")
	// dates: 24_de_junio     [??:24/6/??:??.??:??] -> 
	// 6	24	24	w	w	_	3	cc	_	_
	// 7	de	de	s	sp	gen=c|num=c|for=s	6	CONCAT	_	_
	// 8	junio	junio	n	nc	gen=m|num=s	7	CONCAT	_	_
	{
	  vector<wstring> tokens;
	  split(tokens,form,boost::is_any_of("_"));
	  
	  for(vector<wstring>::const_iterator p=tokens.begin();p!=tokens.end();p++)
	  {

 	    word wd = word(*p);
	  //  sout<<wd.get_form();
  	    list<word> l (1,wd);  
  	    list<sentence> s;
	  //  sout<<s.words_begin()->get_form();
	    //morfo2->analyze(s);
  	    //tagger->analyze(s);
	    anlz.AnalyzeTokens(l, s, true);
	    sout<<c;
	    sout<<L"\t"<<s.begin()->words_begin()->get_form();
	    sout<<L"\t"<<s.begin()->words_begin()->get_lemma();
	    wstring eagletag2 = s.begin()->words_begin()->get_tag();
	    std::transform(eagletag2.begin(), eagletag2.end(), eagletag2.begin(), ::tolower);
	    wstring pos2 = eagletag2.substr(0,2);
	    //punctuation, should not occur here (?)
	    if (pos2.find(L"f") ==0)
	    {
	    pos2.replace(0,1,L"F");
	    }
	    //number in a date -> change tag from 'z' to 'w' (not very regular done in Tanl!!)
	    else if (pos2.find(L"z") ==0)
	    {
	    pos2.replace(0,1,L"w");
	    }
	    sout<<L"\t"<<pos2.substr(0,1);	//CPOS

	    sout<<L"\t"<<pos2;		//POS
	    sout<<L"\t"<<MapEagleTagMorphoFeat(eagletag2);	//MORPH
	    sout<<endl;
	    c++;
	  }
	}
      // change tag of numbers to dn if they modify a noun
      else if(cpos == L"z" && boost::next(w)!=is->end())
      {
	  //save iterator at this point, then go to the next token
	  next_w =boost::next(w);
	  wstring next_tag = next_w->get_tag();
	  if( boost::iequals(next_tag.substr(0,2),L"NC") ||next_tag.find(L"A") ==0 )
	  {
	    wstring next_pos_n = next_tag.substr(0,2);
	    wstring next_pos_a = next_tag.substr(0,1);
	    wstring next_number_n = next_tag.substr(3,1);
	    wstring next_number_a = next_tag.substr(4,1);
	   
	    if((boost::iequals(next_pos_n,L"NC") && boost::iequals(next_number_n,L"P"))|| (boost::iequals(next_pos_a,L"A") && boost::iequals(next_number_a,L"P"))  )
	    {
	      eagletag = L"dn0cp0";
	      sout<<c;				//ID
	      sout<<L"\t"<<w->get_form();	//FORM
	      sout<<L"\t"<<w->get_form();	//LEMMA
	      sout<<L"\t"<<L"d";			//CPOS
	      sout<<L"\t"<<L"dn";		//POS
	      sout<<L"\t"<<MapEagleTagMorphoFeat(eagletag);	//MORPH
	      sout<<endl;
	    }
	    else
	    {
	      PrintNumber(sout,w,c);
	    }
	    
	  }
	  else
	  {
	    // change tag of year numbers 'en el 2008' (freeling fails here) from 'z' to 'w'
	    if(boost::prior(w)!=is->begin())
	    {
	      prior_w = boost::prior(w);
	      if(boost::iequals(prior_w->get_form(),L"el"))
	      {
		sout<<c;				//ID
		sout<<L"\t"<<form;			//FORM
		sout<<L"\t"<<form;			//LEMMA take the form as lemma
		sout<<L"\tw";			//CPOS
		sout<<L"\tw";			//POS
		sout<<L"\t"<<MapEagleTagMorphoFeat(eagletag);	//MORPH
		sout<<endl;
	      }
	      else
	      { 
		PrintNumber(sout,w,c);
	      }
	    } 
	    else
	    {
	      PrintNumber(sout,w,c);
	    }
	  }
	  c++;
      }
      else
      {
	sout<<c;			//ID
	sout<<L"\t"<<w->get_form();	//FORM
	// special case lemma: lemma for forms of estar are the word forms (desr expects that).. also set VA to VM
	wstring lemma = w->get_lemma();
	if(boost::iequals(lemma, L"estar"))
	{
	  sout<<L"\t"<<w->get_form();	
	}
	else
	{
	  sout<<L"\t"<<lemma;	//LEMMA
	}
	if (pos.find(L"f") ==0)
	{
	  pos = eagletag;
	  pos.replace(0,1,L"F"); 
	}
	else if (pos.find(L"z") ==0)
	{
	  pos.replace(0,1,L"Z");
	}
	sout<<L"\t"<<pos.substr(0,1);	//CPOS
	sout<<L"\t"<<pos;		//POS
	sout<<L"\t"<<MapEagleTagMorphoFeat(eagletag);	//MORPH
	sout<<endl;
	c++;
      }
    }
  //}
}

//---------------------------------------------
// print obtained analysis.
//---------------------------------------------

void output::PrintResults (wostream &sout, list<sentence > &ls, analyzer &anlz, const document &doc) {
  sentence::const_iterator w;
  list<sentence>::iterator is;
    
  for (is = ls.begin (); is != ls.end (); is++) {
    if (cfg->OutputFormat >= SHALLOW) {
      /// obtain parse tree and draw it at will
      switch (cfg->OutputFormat) {

        case SHALLOW:
        case PARSED: {
          parse_tree & tr = is->get_parse_tree ();
          PrintTree (sout, tr.begin (), 0, doc);
          sout << endl;
        }
        break;
   
        case DEP: {
          dep_tree & dep = is->get_dep_tree ();
          PrintDepTree (sout, dep.begin (), 0, doc);
        }
        break;
   
        case DESRTAG: {
          //PrintMorfo (sout, ls, anlz);
          PrintMorfo (sout, is, anlz);
        }
        break;
   
        default:   // should never happen
        break;
      }
    }
    else {
      for (w = is->begin (); w != is->end (); w++) {
        sout << w->get_form();
        if (cfg->PHON_Phonetics) sout<<L" "<<w->get_ph_form();
   
        if (cfg->OutputFormat == MORFO or cfg->OutputFormat == TAGGED) {
          if (cfg->TrainingOutput) {
            /// Trainig output: selected analysis (no prob) + all analysis (with probs)
            PrintWord(sout,*w,true,false);
            sout<<L" #";
            PrintWord(sout,*w,false,true);
          }
          else {
            /// Normal output: selected analysis (with probs)
            PrintWord(sout,*w,true,true);  
          }
        }

        sout << endl;   
      }
    }
    // sentence separator: blank line.
    sout << endl;
  }
}


