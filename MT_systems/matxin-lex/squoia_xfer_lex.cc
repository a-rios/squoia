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
#include <lttoolbox/xml_parse_util.h>

#include <string>
#include <iostream>
#include <sstream>
#include <fstream>
#include <locale>

#include <getopt.h>
#include <libgen.h>

#include <wctype.h>

using namespace std;

// Method prototypes
// from string_utils: tolower
wstring tolower(wstring const &s);
// from data_manager: init_lexInfo, get_lexInfo, lexical_selection
void init_lexInfo(wstring name, string fitxName);
wstring get_lexInfo(wstring name, wstring type_es);
vector<wstring> lexical_selection(wstring parent_attributes, wstring common_attributes, vector<wstring> child_attributes);
// from matxin_string_utils
void Tokenize(const wstring& str, vector<wstring>& tokens, const wstring& delimiter = L" ");
void Tokenize2(const wstring& str, wstring& tokens, const wstring& delimiter = L" ");
/*
 * Splits multi-attribute text from a elment into
 * attributes from separate elements.
 *
 * For example, having this input string:
 * str = L"lem='beste\bat' pos='[DET][DZG]\[DET][DZH]' pos='4'"
 * it will return a vector with these elements:
 * v = {L"lem='beste' pos='[DET][DZG]' pos='4'" ,
 *      L"lem='bat' pos='[DET][DZH]' pos='4'"}
 */
vector<wstring> split_multiattrib(wstring str);
wstring v2s(vector<wstring> vector, wstring delimiter = L" ");

// from XML_reader
string xmlc2s(xmlChar const * entrada);
wstring write_xml(wstring input);
wstring getTagName(xmlTextReaderPtr reader);
int nextTag(xmlTextReaderPtr reader);
wstring attrib(xmlTextReaderPtr reader, string const &nombre);
wstring allAttrib(xmlTextReaderPtr reader);
wstring allAttrib_except(xmlTextReaderPtr reader, wstring attrib_no);
wstring text_attrib(wstring attributes, wstring const &nombre);
wstring text_allAttrib_except(wstring attributes, const wstring &nombre);

// original matxin_xfer_lex
wstring upper_type(wstring form, wstring mi, wstring ord);
wstring get_dict_attributes(const wstring full);
wstring getsyn(vector<wstring> translations);
void order_ordainak(vector<wstring> &ordainak);
vector<wstring> disambiguate(wstring &full);
vector<wstring> get_translation(wstring lem, wstring mi, bool &unknown);
wstring multiNodes (wstring &full, wstring attributes);
std::pair<wstring,wstring> procNODE(xmlTextReaderPtr reader, bool head, wstring parent_attribs, wstring& attributes);
wstring procCHUNK(xmlTextReaderPtr reader, wstring parent_attribs);
wstring procSENTENCE (xmlTextReaderPtr reader);
void endProgram(char *name);

FSTProcessor fstp; // Transducer with bilingual dictionary

// from string_utils
wstring tolower(wstring const &s)
{
  wstring l=s;
  for(unsigned i=0; i<s.length(); i++)
  {
    l[i] = (wchar_t) towlower(s[i]);
  }
  return l;
}

// from data_manager
struct lexInfo {
  wstring name;
  map<wstring,wstring> info;
};

static vector<lexInfo> lexical_information;

void init_lexInfo(wstring name, string fitxName)
{
  wifstream fitx;

  lexInfo lex;
  lex.name = name;

  fitx.open(fitxName.c_str());

  wstring lerro;
  while (getline(fitx, lerro))
  {
    // Remove comments
    if (lerro.find(L'#') != wstring::npos)
      lerro = lerro.substr(0, lerro.find(L'#'));

    // Remove whitespace and so...
    for (int i = 0; i < int(lerro.size()); i++)
    {
      if (lerro[i] == L' ' and (lerro[i+1] == L' ' or lerro[i+1] == L'\t'))
        lerro[i] = L'\t';
      if ((lerro[i] == L' ' or lerro[i] == L'\t') and
          (i == 0 or lerro[i-1] == L'\t'))
      {
        lerro.erase(i,1);
        i--;
      }
    }
    if (lerro[lerro.size()-1] == L' ' or lerro[lerro.size()-1] == L'\t')
      lerro.erase(lerro.size()-1,1);

    size_t pos = lerro.find(L"\t");
    if (pos == wstring::npos)
      continue;

    wstring key = lerro.substr(0,pos);
    wstring value = lerro.substr(pos+1);

    lex.info[key] = value;
  }

  fitx.close();
  lexical_information.push_back(lex);
}


wstring get_lexInfo(wstring name, wstring key)
{
  for (size_t i = 0; i < lexical_information.size(); i++)
  {
    if (lexical_information[i].name == name) {
        return lexical_information[i].info[key];
    }
  }
  return L"";
}

vector<wstring> lexical_selection(wstring parent_attributes, wstring common_attribs,
                  vector<wstring> child_attributes)
{
  wstring src_lemma;
  wstring trgt_lemma;
  wstring attributes;
  vector<wstring> default_case;

  src_lemma = text_attrib(common_attribs, L"slem");

  // Save the first value just in case there's no default set in the rules
  if (child_attributes.size() > 0)
    default_case.push_back(child_attributes[0]);

  for (size_t i = 0; i < child_attributes.size(); i++)
  {
    attributes = common_attribs + L" " + child_attributes[i];

    trgt_lemma = text_attrib(attributes, L"lem");
  }

  return default_case;
}

// from matxin_string_utils
void Tokenize(const wstring& str,
              vector<wstring>& tokens,
              const wstring& delimiters)
{
    // Skip delimiters at beginning
    size_t lastPos = str.find_first_not_of(delimiters, 0);
    // Find first "non-delimiter"
    size_t pos = str.find_first_of(delimiters, lastPos);

    while (pos != wstring::npos || lastPos != wstring::npos)
    {
        // Found a token, add it to the vector
        tokens.push_back(str.substr(lastPos, pos - lastPos));
        // Skip delimiters
        lastPos = str.find_first_not_of(delimiters, pos);
        // Find next "non-delimiter"
        pos = str.find_first_of(delimiters, lastPos);
    }
}

void Tokenize2(const wstring& str,
               wstring& tokens,
               const wstring& delimiters)
{
    // Skip delimiters at beginning
    size_t lastPos = str.find_first_not_of(delimiters, 0);
    // Find first "non-delimiter"
    size_t pos = str.find_first_of(delimiters, lastPos);

    while (pos != wstring::npos || lastPos != wstring::npos)
    {
        // Found a token, add it to the resulting string
        tokens += str.substr(lastPos, pos - lastPos);
        // Skip delimiters
        lastPos = str.find_first_not_of(delimiters, pos);
        // Find next "non-delimiter"
        pos = str.find_first_of(delimiters, lastPos);
    }
}

vector<wstring> split_multiattrib(wstring str)
{
  vector<wstring> tokens;
  vector<wstring> result;
  wstring resultStr;

  Tokenize(str, tokens);
  for (size_t i = 0; i < tokens.size(); i++)
  {
    vector<wstring> attribs;
    vector<wstring> valueparts;
    wstring values;

    Tokenize(tokens[i], attribs, L"=");
    Tokenize2(attribs[1], values, L"'");
    Tokenize(values, valueparts, L"\\");

    for (size_t j = 0; j < valueparts.size(); j++)
    {
      resultStr = attribs[0] + L"='" + valueparts[j] + L"' ";
      if (result.size() > j)
        result[j].append(resultStr);
      else {
        result.resize(valueparts.size());
        result[j] = resultStr;
      }
    }
  }

  return result;
}

wstring v2s(vector<wstring> vector, wstring delimiter)
{
  wstring result = L"";

  for (size_t i = 0; i < vector.size(); i++)
    result += delimiter + vector[i];

  return result;
}

// from XML_reader
// Converts xmlChar strings used by libxml2 to ordinary strings
string xmlc2s(xmlChar const *entrada)
{
  if (entrada == NULL)
    return "";

  return reinterpret_cast<char const *>(entrada);
}

wstring getTagName(xmlTextReaderPtr reader)
{
  xmlChar const *xname = xmlTextReaderConstName(reader);
  wstring tagName = XMLParseUtil::stows(xmlc2s(xname));
  return tagName;
}

int nextTag(xmlTextReaderPtr reader)
{
  int ret = xmlTextReaderRead(reader);
  wstring tagName = getTagName(reader);
  int tagType = xmlTextReaderNodeType(reader);

  while (ret == 1 and (tagType == XML_READER_TYPE_DOCUMENT_TYPE or tagName == L"#text"))
  {
    ret = xmlTextReaderRead(reader);
    tagName = getTagName(reader);
    tagType = xmlTextReaderNodeType(reader);
  }

  return ret;
}

wstring attrib(xmlTextReaderPtr reader, string const &nombre)
{
  if (nombre[0] == '\'' && nombre[nombre.size() - 1] == '\'')
    return XMLParseUtil::stows(nombre.substr(1, nombre.size() - 2));

  xmlChar *nomatrib = xmlCharStrdup(nombre.c_str());
  xmlChar *atrib = xmlTextReaderGetAttribute(reader,nomatrib);

  wstring result = XMLParseUtil::stows(xmlc2s(atrib));
  
  xmlFree(atrib);
  xmlFree(nomatrib);
  
  return result;
}

wstring allAttrib(xmlTextReaderPtr reader)
{
  wstring output = L"";

  for (int hasAttrib = xmlTextReaderMoveToFirstAttribute(reader);
       hasAttrib > 0;
       hasAttrib = xmlTextReaderMoveToNextAttribute(reader))
  {
    xmlChar const *xname = xmlTextReaderConstName(reader);
    xmlChar const *xvalue = xmlTextReaderConstValue(reader);
    output += L" " + XMLParseUtil::stows(xmlc2s(xname)) + L"='" +
              XMLParseUtil::stows(xmlc2s(xvalue)) + L"'";
  }

  xmlTextReaderMoveToElement(reader);
  return output;
}

wstring allAttrib_except(xmlTextReaderPtr reader, wstring attrib_no)
{
  wstring output = L"";

  for (int hasAttrib=xmlTextReaderMoveToFirstAttribute(reader);
       hasAttrib > 0;
       hasAttrib = xmlTextReaderMoveToNextAttribute(reader))
  {
    xmlChar const *xname = xmlTextReaderConstName(reader);
    xmlChar const *xvalue = xmlTextReaderConstValue(reader);
    if (XMLParseUtil::stows(xmlc2s(xname)) != attrib_no)
      output += L" " + XMLParseUtil::stows(xmlc2s(xname)) + L"='" +
                XMLParseUtil::stows(xmlc2s(xvalue)) + L"'";
  }

  xmlTextReaderMoveToElement(reader);
  return output;
}

wstring text_allAttrib_except(wstring attributes, const wstring &nombre)
{
  vector<wstring> tokens;

  Tokenize(attributes, tokens);
  for (size_t i = 0; i < tokens.size(); i++)
  {
    vector<wstring> attribs;

    Tokenize(tokens[i], attribs, L"=");
    if (attribs[0] == nombre)
    {
      tokens.erase(tokens.begin() + i);
      break;
    }
  }
  return v2s(tokens);
}

wstring write_xml(wstring s)
{
  size_t pos = 0;
  while ((pos = s.find(L"&", pos)) != wstring::npos)
  {
    s.replace(pos, 1, L"&amp;");
    pos += 4;
  }

  while ((pos = s.find(L'"')) != wstring::npos)
  {
    s.replace(pos, 1, L"&quot;");
  }

  pos = 0;
  while ((pos = s.find(L'\'', pos)) != wstring::npos)
  {
    if (s[pos - 1] != L'=' && s[pos + 1] != L' ' && pos != (s.size() - 1))
      s.replace(pos, 1, L"&apos;");
    else
      pos++;
  }

  while ((pos = s.find(L"<")) != wstring::npos)
  {
    s.replace(pos, 1, L"&lt;");
  }

  while ((pos = s.find(L">")) != wstring::npos)
  {
    s.replace(pos, 1, L"&gt;");
  }
  return s;
}

wstring text_attrib(wstring attributes, const wstring& nombre)
{
  vector<wstring> tokens;
  wstring value = L"";

  Tokenize(attributes, tokens);
  for (size_t i = 0; i < tokens.size(); i++)
  {
    vector<wstring> attribs;

    Tokenize(tokens[i], attribs, L"=");
    if (attribs[0] == nombre)
    {
      Tokenize2(attribs[1], value, L"'");
      break;
    }
  }

  return value;
}

// original matxin_xfer_lex
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
        sense = wcstol((*it).substr(pos+8, pos2-pos-8).c_str(), NULL, 10);
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
  }

  translation = disambiguate(trad); 
  return translation;
}


// Hiztegi elebidunaren euskarazko ordaina NODO bat baino gehiagoz osaturik badago.
// Adb. oso<ADB><ADOARR><+><MG><+>\eskas<ADB><ADJ><+><MG><+>.
// Azken NODOa ezik besteak tratatzen ditu
// IN:  Euskarazko ordain bat, NODO bat baino gehiago izan ditzake.
// OUT: Lehen NODOei dagokien XML zuhaitza.
//wstring multiNodes (xmlTextReaderPtr reader, wstring &full, wstring attributes)
wstring multiNodes (wstring &full, wstring attributes)
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
std::pair<wstring,wstring> procNODE(xmlTextReaderPtr reader, bool head,
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
	  subnodes = multiNodes(select[0], attributes);
	}
	attributes += L" " + select[0];
      
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
    //nodes += procNODE(reader, head_child, attributes, cfg);

    std::pair<wstring,wstring> pr = procNODE(reader, head_child, attribs,
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

// CHUNK etiketa irakurri eta prozesatzen du:
// - ord -> ref : ord atributuan dagoen balioa, ref atributuan idazten du (helmugak jatorrizkoaren erreferentzia izateko postedizioan)
// - type : CHUNKaren type atributua itzultzen da
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
    // written to the tree after the call to procNODE in case
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

  std::pair<wstring,wstring> pr = procNODE(reader, true, parent_attribs, head_attribs);
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

  tree = L"<CHUNK ref='" + write_xml(ref) +
	  L"' type='" + write_xml(chunk_type) + L"'" +
	  write_xml(other_attribs) + L">\n" +
	  nodes;

  ret = nextTag(reader);
  tagName = getTagName(reader);
  tagType = xmlTextReaderNodeType(reader);

  while (ret == 1 and tagName == L"CHUNK" and tagType == XML_READER_TYPE_ELEMENT)
  {
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
  cout << "USAGE: " << basename(name) << " [-c chunktype_file] fst_file" << endl;
  cout << "Options:" << endl;
#if HAVE_GETOPT_LONG
  cout << "  -c, --chunktype-file:  give a file listing chunk types" << endl;
#else
  cout << "  -c:  give a file listing chunk types" << endl;
#endif
  exit(EXIT_FAILURE);
}

int main(int argc, char *argv[])
{
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

  if(argc < 2) {
     endProgram(argv[0]);
  }

#if HAVE_GETOPT_LONG
  static struct option long_options[]=
    {
      {"chunk-file",      0, 0, 'c'},
    };
#endif

  while(true)
  {
#if HAVE_GETOPT_LONG
    int option_index;
    int c = getopt_long(argc, argv, "c:", long_options, &option_index);
#else
    int c = getopt(argc, argv, "c:");
#endif

    if(c == -1)
    {
      break;
    }

    switch(c)
    {
    case 'c':
      //check if the file exists and is readable
      init_lexInfo(L"chunkType", optarg);
      break;

    default:
      endProgram(argv[0]);
      break;
    }
  }

  FILE *transducer = 0;
  transducer = fopen(argv[optind], "r");
  fstp.load(transducer);
  fclose(transducer);
  fstp.initBiltrans();

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

