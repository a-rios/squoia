/*
 *  Copyright (C) 2005 IXA Research Group / IXA Ikerkuntza Taldea.
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 
 *  02110-1301  USA
 */

/*
 * This file has been adapted for SQUOIA.
 */

#include <lttoolbox/fst_processor.h>
#include <lttoolbox/ltstr.h>

#include <string>
#include <iostream>
#include <sstream>
#include <locale>

#include <getopt.h>
#include <libgen.h>

#include "matxin_string_utils.h"
#include "string_utils.h"

#include <data_manager.h>
#include <XML_reader.h>

using namespace std;

// Method prototypes
wstring upper_type(wstring form, wstring mi, wstring ord);
wstring lema(wstring const &full);
wstring get_dict_attributes(const wstring full);
wstring getsyn(vector<wstring> translations);
void order_ordainak(vector<wstring> &ordainak);
vector<wstring> disambiguate(wstring &full);
vector<wstring> get_translation(wstring lem, wstring mi, bool &unknown);
wstring multiNodes (xmlTextReaderPtr reader, wstring &full, wstring attributes);
std::pair<wstring,wstring> procNODE_notAS(xmlTextReaderPtr reader, bool head, wstring parent_attribs, wstring& attributes);
wstring procNODE_AS(xmlTextReaderPtr reader, bool head, wstring& attributes);
wstring procCHUNK(xmlTextReaderPtr reader, wstring parent_attribs);
wstring procSENTENCE (xmlTextReaderPtr reader);
void endProgram(char *name);

FSTProcessor fstp; // Transducer with bilingual dictionary
FSTProcessor fstp_sem_info; // Transducer with semantic dictionary

wstring upper_type(wstring form, wstring mi, wstring ord)
{
  wstring case_type = L"none";
  size_t form_begin, form_end;
  int upper_case, lower_case;

  form_begin = 0;
  if (form.find(L"_", form_begin + 1) == wstring::npos)
    form_end = form.size();
  else
    form_end = form.find(L"_", form_begin + 1);

  upper_case = lower_case = 0;
  while (form_begin != form.size())
  {
    if (tolower(form[form_begin]) != form[form_begin] and
        (ord != L"1" or mi.substr(0, 2) == L"NP"))
    {
      if (form_begin == 0)
        case_type = L"first";
      else
        case_type = L"title";
    }

    for (size_t i = form_begin; i < form_end; i++)
    {
      if (form[i] != tolower(form[i]))
        upper_case++;
      else
        lower_case++;
    }

    if (form.size() > form_end)
      form_begin = form_end + 1;
    else
      form_begin = form.size();

    if (form.find(L"_", form_begin + 1) == wstring::npos)
      form_end = form.size();
    else
      form_end = form.find(L"_", form_begin + 1);
  }

  if (upper_case > lower_case)
    case_type = L"all";

  return case_type;
}

// Hiztegi elebidunaren euskarazko ordainetik lema lortzen du.
// IN:  Euskarazko ordain bat ( lema<key1>VALUE1<key2>VALUE2 )
// OUT: lema                  ( lema                         )
wstring lema(wstring const &full)
{
  return full.substr(0, full.find(L'<'));
}


/*
 * Gets attributes from the bilingual dictionary
 * input: "lemma<key1>value1<key2>value2...<keyn>valueN"
 * output: "lem='lemma' key1='value1' ... keyN='valueN'"
 */
wstring get_dict_attributes(const wstring full)
{
  vector<wstring> tokens;
  wstring result = L"";
  bool empty_lemma = false;

  Tokenize(full, tokens, L"<");

  // Special case, empty lemma
  if (full.substr(0, 1) == L"<")
  {
    result += L"lem=''";
    empty_lemma = true;
  }

  for (size_t i = 0; i < tokens.size(); i ++)
  {
    if (i == 0 && !empty_lemma)
    {
      result += L"lem='" + write_xml(tokens[i]) + L"'";
    }
    else
    {
      vector<wstring> attribs;

      Tokenize(tokens[i], attribs, L">");
      result += L" " + attribs[0] + L"='" + write_xml(attribs[1]) + L"'";
    }
  }

  return result;
}

wstring getsyn2lems(vector<wstring> translations, wstring slem)
{
  wstring output;

  for (size_t i = 0; i < translations.size(); i++)
    output += L"<SYN " + translations[i] + L" slem='" + slem + L"' />\n";

  return output;
}

wstring getsyn(vector<wstring> translations)
{
  wstring output;

  for (size_t i = 0; i < translations.size(); i++)
    output += L"<SYN " + translations[i] + L"/>\n";

  return output;
}

void order_ordainak(vector<wstring> &ordainak)
{
  vector<wstring> ordered_ordain;
  int sense;
  bool zero_sense = false;

  vector<wstring>::iterator it;
  for (it = ordainak.begin(); it != ordainak.end(); it++)
  {
    sense = 0;
    size_t pos, pos2;
    if ((pos = (*it).find(L" sense='")) != wstring::npos)
    {
      if ((pos2 = (*it).find(L"'", pos+8)) != wstring::npos)
        sense = watoi((*it).substr(pos+8, pos2-pos-8).c_str());
    }

    if (sense == 0)
    {
      zero_sense = true;
      ordered_ordain.insert(ordered_ordain.begin(), *it);
    }
    else
    {
      if (!zero_sense)
        sense--;
      if (ordered_ordain.size() < sense+1)
        ordered_ordain.resize(sense+1);
      ordered_ordain[sense] = *it;
    }
  }

  ordainak = ordered_ordain;
}


// Hiztegi elebidunaren euskarazko ordainetik lehenengoa lortzen du.
// IN:  Euskarazko ordainak ( ordain1[/ordain2]* )
// note: segfaults if full has no mi
// OUT: lehenengoa          ( oradin1            )
vector<wstring> disambiguate(wstring &full)
{
  wstring output = full;
  vector<wstring> ordainak;

  // Això no és precisament disambiguació, és més aviat dit 
  // 'selecció de la primera opció'
  for (size_t i = 0; i < output.size(); i++)
  {
    if (output[i] == L'/')
    {
      ordainak.push_back(get_dict_attributes(output.substr(0, i)));
      output = output.substr(i + 1);
      i = 0;
    }

    if (output[i] == L'\\')
      output.erase(i, 1);
  }
  ordainak.push_back(get_dict_attributes(output));
  order_ordainak(ordainak);

  return ordainak;
}


vector<wstring> get_translation(wstring lem, wstring mi,
                                bool &unknown)
{
  vector<wstring> translation;
  wstring trad = L"";
  wstring input = L"";

  input = L"^" + lem + L"<parol>" + mi + L"$";
  trad = fstp.biltrans(input);
  trad = trad.substr(1, trad.size() - 2);

  unknown = false;
  if (trad[0] == L'@' || trad.find(L">") < trad.find(L"<"))
  {
    unknown = true;
    return translation;
    // Used to be that unknown words would still get tried in the
    // bidix, using different tags, but still marked as unknown:
//     input = L"^" + lem + L"<parol>noKAT$";
//     trad = fstp.biltrans(input);
//     trad = trad.substr(1, trad.size() - 2);

//     if (mi != L"" && (trad[0] == L'@' || trad.find(L">") < trad.find(L"<")))
//     {
//       input = L"^@" + lem + L"<parol>" + mi + L"$";
//       trad = fstp.biltrans(input);
//       trad = trad.substr(3, trad.size() - 4);
//       if (trad[0] == L'@')
//         trad.erase(0, 1);

//       if (trad[0] == L'@' || trad.find(L">") < trad.find(L"<"))
//       {
//         trad = lem + L"<pos>" + mi.substr(0, 2);
//       }
//     }
  }

  translation = disambiguate(trad); 
  return translation;
}


// Hiztegi elebidunaren euskarazko ordaina NODO bat baino gehiagoz osaturik badago.
// Adb. oso<ADB><ADOARR><+><MG><+>\eskas<ADB><ADJ><+><MG><+>.
// Azken NODOa ezik besteak tratatzen ditu
// IN:  Euskarazko ordain bat, NODO bat baino gehiago izan ditzake.
// OUT: Lehen NODOei dagokien XML zuhaitza.
wstring multiNodes (xmlTextReaderPtr reader, wstring &full, wstring attributes)
{
  wstring output = L"";
  vector<wstring> tmp;

  tmp = split_multiattrib(full);

  for (size_t i = 1; i < tmp.size(); i++)
  {
    output += L"<NODE " + attributes;
    output += L" " + tmp[i] + L" />\n";
  }

  return output;
}


// NODE etiketa irakurri eta prozesatzen du, NODE hori AS motakoa ez den CHUNK baten barruan dagoela:
// - ord -> ref : ord atributuan dagoen balioa, ref atributuan idazten du (helmugak jatorrizkoaren erreferentzia izateko postedizioan)
// - (S) preposizioen eta (F) puntuazio ikurren kasuan ez da transferentzia egiten.
// - Beste kasuetan:
//    - Transferentzia lexikoa egiten da, lem, pos, mi, cas eta sub attributuak sortuz.
//    - Hitz horren semantika begiratzen da
// - NODEaren azpian dauden NODEak irakurri eta prozesatzen ditu.
std::pair<wstring,wstring> procNODE_notAS(xmlTextReaderPtr reader, bool head,
                       wstring parent_attribs, wstring& attributes)
{
  wstring nodes, pos;
  wstring subnodes;
  wstring synonyms;
  wstring synonyms2;
  wstring child_attributes;
  wstring tagName = getTagName(reader);
  vector<wstring> trad;
  // squoia: ambiguos lemmas-> need 2nd trad
  vector<wstring> trad2;
  wstring lem1, lem2;
  vector<wstring> select;
  int tagType = xmlTextReaderNodeType(reader);
  bool head_child = false;
  bool unknown = false;
  bool ambilem = false;

  // ord -> ref : ord atributuan dagoen balioa, ref atributuan idazten du
  // alloc atributua mantentzen da
  if (tagName == L"NODE" and tagType != XML_READER_TYPE_END_ELEMENT)
  {
    nodes = L"<NODE ";
    attributes = L"ref='" + write_xml(attrib(reader, "ord")) + L"'" +
                 L" alloc='" + write_xml(attrib(reader, "alloc")) + L"'" +
                 L" slem='" + write_xml(attrib(reader, "lem")) + L"'" +
                 L" smi='" + write_xml(attrib(reader, "mi")) + L"'" +
		 L" sform='" + write_xml(attrib(reader, "form")) + L"'" +
                 L" UpCase='" + write_xml(upper_type(attrib(reader, "form"),
                                                     attrib(reader, "mi"),
                                                     attrib(reader, "ord"))) +
                 L"'";

    if (attrib(reader, "unknown") != L"")
    {
      attributes += L" unknown='" + write_xml(attrib(reader, "unknown")) + L"'";
    }
    // TODO: LANGUAGE INDEPENDENCE
//     else if (attrib(reader,"mi") != L"" &&
// 	     attrib(reader, "mi").substr(0,1) == L"W" or
// 	     attrib(reader, "mi").substr(0,1) == L"Z")
//     {
//       // Daten (W) eta zenbakien (Z) kasuan ez da transferentzia egiten.
//       // lem eta mi mantentzen dira
//       attributes += L" lem='" + write_xml(attrib(reader, "lem")) + L"'" +
//                     L" pos='[" + write_xml(attrib(reader, "mi")) + L"]'";
//     }
    else
    {
      // Beste kasuetan:
      // Transferentzia lexikoa egiten da, lem, pos, mi, cas eta sub attributuak sortuz.
      // trad = get_translation(attrib(reader, "lem"), attrib(reader, "mi"), unknown);

     // changed squoia: if number 'Z' or 'DN' ->  use word form for lookup, not lemma

     if(attrib(reader, "mi").substr(0,1) == L"Z" or attrib(reader, "mi").substr(0,2) == L"DN"){
    	 trad = get_translation(attrib(reader, "form"), attrib(reader, "mi"), unknown);
     }
     else{
    	 // squoia: split ambiguous lemmas from tagging (e.g. asiento: asentir/asentar) and lookup both
    	 // TODO: insert some attribute to know which slem belongs to which lem!
    	 int split =attrib(reader, "lem").find(L"#");
    	 if(split != wstring::npos){
		ambilem = true;
    		// wcerr << attrib(reader, "lem") << L"1 split at: " << split << L"\n";
    		 lem1 = attrib(reader, "lem").substr(0,split);
    		 lem2 = attrib(reader, "lem").substr(split+2,wstring::npos);
    		 //wcerr << L"lemma 1" << lem1 << L" lemma 2: " << lem2 << L"\n";

		bool unknown1 = false;
    		 trad = get_translation(lem1, attrib(reader, "mi"), unknown1);
		bool unknown2 = false;
    		 trad2 = get_translation(lem2, attrib(reader, "mi"), unknown2);
		unknown = unknown1 and unknown2;
    		 //wcerr << L"trad size lem1 " <<trad.size() << L" trad size lem2:" << trad2[0] << L"\n";

    	 }
    	 else{
             trad = get_translation(attrib(reader, "lem"),attrib(reader, "mi"), unknown);
    	 }
     }
      
      if (unknown) {
        attributes += L" unknown='transfer'";
      }
      else // either trad or trad2 has at least one translation
      {
	if (trad.size() > 1 ) {
	  select = lexical_selection(parent_attribs, attributes, trad); 
	} else if (trad.size() > 0) {
	  select = trad;
	} else if (trad2.size() > 1) {
	  select = lexical_selection(parent_attribs, attributes, trad2);
	} else {
	  select = trad2;
	}

	if (trad.size() > 1 and not ambilem) {
	  synonyms = getsyn(trad);
	}
	// if there was a second lemma translated: add slem to synonyms to avoid confusion
	else if (trad.size() > 1 or (trad.size() > 0 and trad2.size() > 0)) {
		  synonyms = getsyn2lems(trad, lem1);
	}

	if (trad2.size() > 1 or (trad2.size() > 0 and trad.size() > 0)) {
		  synonyms2 = getsyn2lems(trad2,lem2);
	}

	if (ambilem) {
		if (trad.size() > 0) {
			//  add tradlem='lem1' to node, so that we know which lemma belongs to the first translation
			attributes += L" tradlem='" + lem1 + L"' ";
		} else {
			attributes += L" tradlem='" + lem2 + L"' ";
		}
	}

	if (select[0].find(L"\\") != wstring::npos) {
	  subnodes = multiNodes(reader, select[0], attributes);
	}
	attributes += L" " + select[0];
      
	// Hitz horren semantika begiratzen da

	// Look up a lemma and its POS in the semantic information 
	// transducer. 
	//   In format: ^euskara[IZE][ARR]$ 
	//   Out format: ^<BIZ->$
	pos = text_attrib(select[0], L"pos");

	if (head) {
	  wstring lem = text_attrib(select[0], L"lem");
	  wstring sem_search = L'^' + lem + pos + L'$';
	  wstring sem_info = fstp_sem_info.biltrans(sem_search);
	  if(sem_info[1] != L'@' && sem_info != L"" && sem_info != L"$") {
	    wstring sem = StringUtils::substitute(sem_info, L"<", L"["); 
	    sem = StringUtils::substitute(sem, L">", L"]"); 
	    attributes += L" sem='" + write_xml(sem.substr(1, sem.size() - 2)) + L"'";
	  }
	}
     
	head_child = head && (text_attrib(select[0], L"lem") == L"");
      }
    }

    if (xmlTextReaderIsEmptyElement(reader) == 1 and
        subnodes == L"" && synonyms == L""  && synonyms2 == L"")
    {
      // NODE hutsa bada (<NODE .../>), NODE hutsa sortzen da eta
      // momentuko NODEarekin bukatzen dugu.
    	// empty nodes (?)
      nodes += attributes + L"/>\n";
      return std::make_pair(nodes,pos);
    }
    else if (xmlTextReaderIsEmptyElement(reader) == 1)
    {
      // NODE hutsa bada (<NODE .../>), NODE hutsa sortzen da eta
      // momentuko NODEarekin bukatzen dugu.
      nodes += attributes + L">\n" + synonyms +synonyms2 + subnodes + L"</NODE>\n";
      return std::make_pair(nodes,pos);
    }
    else
    {
      // bestela NODE hasiera etiketaren bukaera idatzi eta
      // etiketa barrukoa tratatzera pasatzen gara.
      nodes += attributes + L">\n" + synonyms + synonyms2 + subnodes;
    }
  }
  else
  {
    wcerr << L"ERROR: invalid tag: <" << tagName << allAttrib(reader)
          << L"> when <NODE> was expected..." << endl; 
    exit(-1);
  }

  int ret = nextTag(reader);
  tagName = getTagName(reader);
  tagType = xmlTextReaderNodeType(reader);

  wstring attribs = attributes;
  if (text_attrib(attributes, L"lem") == L"")
    attribs = parent_attribs;

  // NODEaren azpian dauden NODE guztietarako
  while (ret == 1 and tagName == L"NODE" and
         tagType == XML_READER_TYPE_ELEMENT)
  {
    // NODEa irakurri eta prozesatzen du.
    //nodes += procNODE_notAS(reader, head_child, attributes, cfg);

    std::pair<wstring,wstring> pr = procNODE_notAS(reader, head_child, attribs,
                                   child_attributes);
    wstring NODOA = pr.first;
    
    nodes += NODOA;

    ret = nextTag(reader);
    tagName = getTagName(reader);
    tagType = xmlTextReaderNodeType(reader);
  }

  if (text_attrib(attributes, L"lem") == L"")
    attributes = child_attributes;

  // NODE bukaera etiketa tratatzen da.
  if (tagName == L"NODE" and tagType == XML_READER_TYPE_END_ELEMENT)
  {
    nodes += L"</NODE>\n";
  }
  else
  {
    wcerr << L"ERROR: invalid document: found <" << tagName << allAttrib(reader)
          << L"> when </NODE> was expected..." << endl;
    exit(-1);
  }

  return std::make_pair(nodes,pos);
}


// NODE etiketa irakurri eta prozesatzen du, NODE hori AS motako CHUNK baten barruan dagoela:
// IN: head ( NODEa CHUNKaren burua den ala ez )
// - ord -> ref : ord atributuan dagoen balioa, ref atributuan idazten du (helmugak jatorrizkoaren erreferentzia izateko postedizioan)
// - CHUNKaren burua bada:
//    - Transferentzia lexikoa egiten da. (lem eta pos atributuen balio berriak sortuz)
// - Burua ez bada jatorrizko hizkuntzaren lem puntuen artean markatuko da (.lem.) eta mi atributua mantentzen da.
// NODEaren azpian dauden NODEak irakurri eta prozesatzen ditu. NODE horiek ez dira CHUNKaren burua izango (head=false)
wstring procNODE_AS(xmlTextReaderPtr reader, bool head, wstring& attributes)
{
  wstring nodes, synonyms, synonyms2, child_attributes;
  wstring lem1, lem2;
  wstring tagName = getTagName(reader);
  int tagType = xmlTextReaderNodeType(reader);
  bool unknown = false;
  bool ambilem = false;

  if (tagName == L"NODE" and tagType != XML_READER_TYPE_END_ELEMENT)
  {
    // ord -> ref : ord atributuan dagoen balioa, ref atributuan idazten du
    // alloc atributua mantentzen da
    nodes = L"<NODE";
    attributes = L" ref='" + write_xml(attrib(reader, "ord")) + L"'" +
                 L" alloc='" + write_xml(attrib(reader, "alloc")) + L"'" +
                 L" UpCase='" + write_xml(upper_type(attrib(reader, "form"),
                                                     attrib(reader, "mi"),
                                                     attrib(reader, "ord"))) + L"'" +
                 L" slem='" + attrib(reader, "lem") + L"'" +
                 L" smi='" + attrib(reader, "mi") + L"'";

    if (attrib(reader, "unknown") != L"")
    {
      attributes += L" unknown='" + write_xml(attrib(reader, "unknown")) + L"'";
    }
    // CHUNKaren burua bada:
    else if (head)
    {
      // Transferentzia lexikoa egiten da,
      // lem eta pos atributuen balio berriak sortuz
//      vector<wstring> trad = get_translation(attrib(reader, "lem"),
//                                             attrib(reader, "mi"),
//                                             unknown);
     // changed squoia: if number 'Z' or 'DN' ->  use word form for lookup, not lemma
      vector<wstring> trad;
      vector<wstring> trad2;
      if(attrib(reader, "mi").substr(0,1) == L"Z" or attrib(reader, "mi").substr(0,2) == L"DN"){
        	 trad = get_translation(attrib(reader, "form"),
        	                              attrib(reader, "mi"), unknown);

      }
      else{
    	  // squoia: split ambiguous lemmas from tagging (e.g. asiento: asentir/asentar) and lookup both
    	     	 int split =attrib(reader, "lem").find(L"#");
    	     	 if(split != wstring::npos){
			ambilem = true;
    	     		//wcerr << attrib(reader, "lem") << L"2 split at: " << split << L"\n";
    	     		 lem1 = attrib(reader, "lem").substr(0,split);
    	     		 lem2 = attrib(reader, "lem").substr(split+2,wstring::npos);
    	     		// wcerr << L"lemma 1" << lem1 << L" lemma 2: " << lem2 << L"\n";
			bool unknown1 = false;
    	     		 trad = get_translation(lem1, attrib(reader, "mi"), unknown1);
			bool unknown2 = false;
    	     		 trad2 = get_translation(lem2, attrib(reader, "mi"), unknown2);
			unknown = unknown1 and unknown2;
    	     	 }
    	     	 else{
    	              trad = get_translation(attrib(reader, "lem"),attrib(reader, "mi"), unknown);
    	     	 }
       }

      if (trad.size() > 1 and trad2.size() ==0 ) {
        synonyms = getsyn(trad);
      }
      // if there was a second lemma translated: add slem to synonyms to avoid confusion
      else if (trad.size() > 1 && trad2.size() > 0) {
             synonyms = getsyn2lems(trad, lem1);
       }
      if (trad2.size() > 1) {
    	  synonyms2 = getsyn2lems(trad2,lem2);
      }
      else if (trad2.size() == 1) {
    	  // add translation of 2nd lemma to synonyms
    	  wstring trad2_str = L"<SYN " + trad2[0] +  L" slem='" + lem2 + L"' />\n";
    	  synonyms2 += trad2_str;
      	}
	if (ambilem) {
		if (trad.size() > 0) {
			//  add tradlem='lem1' to node, so that we know which lemma belongs to the first translation
			attributes += L" tradlem='" + lem1 + L"' ";
		} else {
			attributes += L" tradlem='" + lem2 + L"' ";
		}
	}
      attributes += L" " + text_allAttrib_except(text_allAttrib_except(trad[0], L"mi"), L"lem");
      attributes += L" lem='_" + text_attrib(trad[0], L"lem") + L"_'";
      attributes += L" mi='" + attrib(reader, "mi") + L"'";

      if (unknown) {
        attributes += L" unknown='transfer'";
      }
    }
    else
    {
      // Burua ez bada jatorrizko hizkuntzaren lem puntuen artean markatuko da
      // (.lem.) eta mi atributua mantentzen da.
      attributes += L" lem='." + write_xml(attrib(reader, "lem")) + L".' mi='" +
                    write_xml(attrib(reader, "mi")) + L"'";
    }

    if (xmlTextReaderIsEmptyElement(reader) == 1 && synonyms == L"" && synonyms2 == L"")
    {
      //Elementu hutsa bada (<NODE .../>) NODE hutsa sortzen da eta NODE honetkin bukatu dugu.
      nodes += attributes + L"/>\n";
      return nodes;
    }
    else
    {
      //Ez bada NODE hutsa hasiera etiketa ixten da.
      nodes += attributes + L">\n" + synonyms + synonyms2;
    }
  }
  else
  {
    wcerr << L"ERROR: invalid tag: <" << tagName << allAttrib(reader)
          << L"> when <NODE> was expected..." << endl;
    exit(-1);
  }

  int ret = nextTag(reader);
  tagName = getTagName(reader);
  tagType = xmlTextReaderNodeType(reader);

  // NODEaren azpian dauden NODE guztietarako:
  while (ret == 1 and tagName == L"NODE" and tagType == XML_READER_TYPE_ELEMENT)
  {
    // NODEa irakurri eta prozesatzen du.
    // NODE hori ez da CHUNKaren burua izango (head=false)
    nodes += procNODE_AS(reader, false, child_attributes);

    ret = nextTag(reader);
    tagName = getTagName(reader);
    tagType = xmlTextReaderNodeType(reader);
  }

  //NODE bukaera etiketaren tratamendua.
  if (tagName == L"NODE" and tagType == XML_READER_TYPE_END_ELEMENT)
  {
    nodes += L"</NODE>\n";
  }
  else
  {
    wcerr << L"ERROR: invalid document: found <" << tagName << allAttrib(reader)
          << L"> when </NODE> was expected..." << endl;
    exit(-1);
  }

  return nodes;
}


// CHUNK etiketa irakurri eta prozesatzen du:
// - ord -> ref : ord atributuan dagoen balioa, ref atributuan idazten du (helmugak jatorrizkoaren erreferentzia izateko postedizioan)
// - type : CHUNKaren type atributua itzultzen da
// - CHUNK motaren arabera tratamendu desberdina egiten da (procNODE_AS edo procNODE_notAS)
// - CHUNK honen barruan dauden beste CHUNKak irakurri eta prozesatzen ditu.
wstring procCHUNK(xmlTextReaderPtr reader, wstring parent_attribs)
{
  wstring tagName = getTagName(reader);
  int tagType = xmlTextReaderNodeType(reader);
  wstring tree, chunk_type, head_attribs;
  wstring old_type, si, ref, other_attribs, nodes;
  
  if (tagName == L"CHUNK" and tagType == XML_READER_TYPE_ELEMENT)
  {
    // ord -> ref : ord atributuan dagoen balioa, ref atributuan idazten du
    // type : CHUNKaren type atributua itzultzen da
    // si atributua mantentzen da
    old_type = attrib(reader, "type");
    chunk_type = get_lexInfo(L"chunkType", old_type); // might change below
    si = attrib(reader, "si");
    ref = attrib(reader, "ord");
    other_attribs = text_allAttrib_except(allAttrib_except(reader, L"ord"), L"type");
    // Store CHUNK attribs before call to nextTag(reader). These are
    // written to the tree after the call to procNODE_notAS in case
    // chunk_type has to be based on the pos attrib of the first NODE
  }
  else
  {
    wcerr << L"ERROR: invalid tag: <" << tagName << allAttrib(reader)
          << L"> when <CHUNK> was expected..." << endl;
    exit(-1);
  }

  int ret = nextTag(reader);
  tagName = getTagName(reader);
  tagType = xmlTextReaderNodeType(reader);

  // CHUNK motaren arabera tratamendu desberdina egiten da
  // (procNODE_AS edo procNODE_notAS)
  // TODO: LANGUAGE INDEPENDENCE
  if (chunk_type.substr(0, 4) == L"adi-" || chunk_type.substr(0, 7) == L"grup-ve") // This was broken, should work now? TODO
  {
    // NODEa irakurri eta prozesatzen du, CHUNKaren burua izango da (head=true)
    nodes = procNODE_AS(reader, true, head_attribs);
  }
  else
  {
    // NODEa irakurri eta prozesatzen du
    std::pair<wstring,wstring> pr = procNODE_notAS(reader, true, parent_attribs, head_attribs);
    nodes = pr.first;

    if (old_type == L"") {
      wstring pos = pr.second;
      chunk_type = get_lexInfo(L"chunkType", si + pos);
      if (chunk_type == L"") {
	      // if syntactic function wasn't in chunktype_file, or no chunktype_file given:
	      chunk_type = si + pos;
      }
    }
    else { 
      chunk_type = get_lexInfo(L"chunkType", old_type);
      if (chunk_type == L"") {
        chunk_type = old_type;
      }
    }
  }
  tree = L"<CHUNK ref='" + write_xml(ref) +
	  L"' type='" + write_xml(chunk_type) + L"'" +
	  write_xml(other_attribs) + L">\n" +
	  nodes;

  ret = nextTag(reader);
  tagName = getTagName(reader);
  tagType = xmlTextReaderNodeType(reader);

  // CHUNK honen barruan dauden CHUNK guztietarako
  while (ret == 1 and tagName == L"CHUNK" and tagType == XML_READER_TYPE_ELEMENT)
  {
    // CHUNK irakurri eta prozesatzen du.
    tree += procCHUNK(reader, head_attribs);

    ret = nextTag(reader);
    tagName = getTagName(reader);
    tagType = xmlTextReaderNodeType(reader);
  }

  if (tagName == L"CHUNK" and tagType == XML_READER_TYPE_END_ELEMENT)
  {
    tree += L"</CHUNK>\n";
  }
  else
  {
    wcerr << L"ERROR: invalid document: found <" << tagName << allAttrib(reader)
          << L"> when </CHUNK> was expected..." << endl;
    exit(-1);
  }

  return tree;
}


// SENTENCE etiketa irakurri eta prozesatzen du:
// - ord -> ref : ord atributuan dagoen balioa, ref atributuan idazten du (helmugak jatorrizkoaren erreferentzia izateko postedizioan)
// - SENTENCE barruan dauden CHUNKak irakurri eta prozesatzen ditu.
wstring procSENTENCE (xmlTextReaderPtr reader)
{
  wstring tree;
  wstring tagName = getTagName(reader);
  int tagType = xmlTextReaderNodeType(reader);

  if (tagName == L"SENTENCE" and tagType != XML_READER_TYPE_END_ELEMENT)
  {
    // ord -> ref : ord atributuan dagoen balioa, ref atributuan gordetzen du
    tree = L"<SENTENCE ref='" + write_xml(attrib(reader, "ord")) + L"'"
                              + write_xml(allAttrib_except(reader, L"ord"))
                              + L">\n";
  }
  else
  {
    wcerr << L"ERROR: invalid document: found <" << tagName << allAttrib(reader)
          << L"> when <SENTENCE> was expected..." << endl;
    exit(-1);
  }

  int ret = nextTag(reader);
  tagName = getTagName(reader);
  tagType = xmlTextReaderNodeType(reader);

  // SENTENCE barruan dauden CHUNK guztietarako
  while (ret == 1 and tagName == L"CHUNK")
  {
    // CHUNKa irakurri eta prozesatzen du.
    tree += procCHUNK(reader, L"");

    ret = nextTag(reader);
    tagName = getTagName(reader);
    tagType = xmlTextReaderNodeType(reader);
  }

  if (ret == 1 and tagName == L"SENTENCE" and
      tagType == XML_READER_TYPE_END_ELEMENT)
  {
    tree += L"</SENTENCE>\n";
  }
  else
  {
    wcerr << L"ERROR: invalid document: found <" << tagName << allAttrib(reader)
          << L"> when </SENTENCE> was expected..." << endl;
    exit(-1);
  }

  return tree;
}

void endProgram(char *name)
{
  cout << basename(name) << ": run lexical transfer on a Matxin input stream" << endl;
  cout << "USAGE: " << basename(name) << " [-s sem_file] [-c chunktype_file] [-l lex_file] fst_file" << endl;
  cout << "Options:" << endl;
#if HAVE_GETOPT_LONG
  cout << "  -s, --sem-file:        use a semantic file for nouns" << endl;
  cout << "  -c, --chunktype-file:  give a file listing chunk types" << endl;
  cout << "  -l, --lex-selec-file:  perform rudimentary lexical selection" << endl;
#else
  cout << "  -s:  use a semantic file for nouns" << endl;
  cout << "  -c:  give a file listing chunk types" << endl;
  cout << "  -l:  perform rudimentary lexical selection" << endl;
#endif
  exit(EXIT_FAILURE);
}

int main(int argc, char *argv[])
{
  string sem_info_file = "";
//  config cfg(argv);

  // This sets the C++ locale and affects to C and C++ locales.
  // wcout.imbue doesn't have any effect but the in/out streams use the proper encoding.
#ifndef NeXTBSD
#ifdef __APPLE__
  setlocale(LC_ALL, "");
  // locale("") doesn't work on mac, except with C/POSIX
#else
  locale::global(locale(""));
#endif
#else
  setlocale(LC_ALL, "");
#endif
  
  // Hiztegi elebidunaren hasieraketa.
  // Parametro moduan jasotzen den fitxagia erabiltzen da hasieraketarako.

  if(argc < 2) {
     endProgram(argv[0]);
  }

#if HAVE_GETOPT_LONG
  static struct option long_options[]=
    {
      {"sem-file",        0, 0, 's'},
      {"chunk-file",      0, 0, 'c'},
      {"lex-selec-file",  0, 0, 'l'},
    };
#endif

  while(true)
  {
#if HAVE_GETOPT_LONG
    int option_index;
    int c = getopt_long(argc, argv, "s:c:l:", long_options, &option_index);
#else
    int c = getopt(argc, argv, "s:c:l:");
#endif

    if(c == -1)
    {
      break;
    }

    switch(c)
    {
    case 's':
      sem_info_file = string(optarg);  
      break;

    case 'c':
      //check if the file exists and is readable
      init_lexInfo(L"chunkType", optarg);
      break;
    case 'l':
      //check if the file exists and is readable
      init_lexical_selection(optarg);
      break;

    default:
      endProgram(argv[0]);
      break;
    }
  }

  if(sem_info_file != "") {
      FILE *in = fopen(sem_info_file.c_str(), "rb");
      if(in) {
        fstp_sem_info.load(in);
        fstp_sem_info.initBiltrans();
        fclose(in);
      } else {
        wcerr << "Semantic information file `" << sem_info_file.c_str() << "' cannot be loaded." << endl;
	exit(-1);
      }
  }
  
  FILE *transducer = 0;
  transducer = fopen(argv[optind], "r");
  fstp.load(transducer);
  fclose(transducer);
  fstp.initBiltrans();

  // Hasieraketa hauek konfigurazio fitxategi batetik irakurri beharko lirateke.
//  init_lexInfo(L"nounSem", cfg.Noun_SemanticFile);
//  init_lexInfo(L"chunkType", cfg.ChunkType_DictFile);
  // Init lexical selection reading the rules file
//  init_lexical_selection(cfg.LexSelFile);

  // libXml liburutegiko reader hasieratzen da, sarrera estandarreko fitxategia irakurtzeko.
  xmlTextReaderPtr reader;
  reader = xmlReaderForFd(0, "", NULL, 0);

  int ret = nextTag(reader);
  wstring tagName = getTagName(reader);
  int tagType = xmlTextReaderNodeType(reader);

  if(tagName == L"corpus" and tagType != XML_READER_TYPE_END_ELEMENT)
  {
    wcout << L"<?xml version='1.0' encoding='UTF-8'?>" << endl;
    wcout << L"<corpus " << write_xml(allAttrib(reader)) << ">" << endl;
  }
  else
  {
    wcerr << L"ERROR: invalid document: found <" << tagName << allAttrib(reader)
          << L"> when <corpus> was expected..." << endl;
    exit(-1);
  }

  ret = nextTag(reader);
  tagName = getTagName(reader);
  tagType = xmlTextReaderNodeType(reader);

  int i = 0;
  // corpus barruan dauden SENTENCE guztietarako
  while (ret == 1 and tagName == L"SENTENCE")
  {
    //SENTENCE irakurri eta prozesatzen du.
    wstring tree = procSENTENCE(reader);
    wcout << tree << endl;
    wcout.flush();

    ret = nextTag(reader);
    tagName = getTagName(reader);
    tagType = xmlTextReaderNodeType(reader);
  }
  xmlFreeTextReader(reader);
  xmlCleanupParser();

  if(ret == 1 and tagName == L"corpus" and
     tagType == XML_READER_TYPE_END_ELEMENT)
  {
    wcout << L"</corpus>\n";
  }
  else
  {
    wcerr << L"ERROR: invalid document: found <" << tagName << allAttrib(reader)
          << L"> when </corpus> was expected..." << endl;
    exit(-1);
  }

}

