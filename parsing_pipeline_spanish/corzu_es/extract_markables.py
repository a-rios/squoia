# -*- coding: utf-8 -*-

"""
Makrable extraction for Spanish coreference resolution with CorZu.
Extract markables from automatically preprocessed data from Annette's pipeline
author: don.tuggener@gmail.com
"""

import os
import pdb
import re
import sys
from collections import defaultdict

# ========================settings&resources========================== #

# Current path
path=os.path.dirname(sys.argv[0])
if path.startswith('..'): path+='/'
elif not path=='': path='/'+path

# First names, used for gender disambiguation of named entities
male_names = eval(open(path+'data/male_names.txt','r').read())
female_names = eval(open(path+'data/female_names.txt','r').read())
# List of animate nouns
person = eval(open(path+'person.txt','r').read())


# Column indices of annotations
pos_index = 4
regens_index = 6
tokid_index = 0
lemma_index = 2
lexem_index = 1
morph_index = 5
gf_index = 7
coref_index = -1
# ne_index = 12 # Ne info is stored in morph. column

# PoS mapping
eagles_pos = {
'proper': 'NP', 
'common': 'NC', 
'qualificative': 'NC',
'demonstrative': 'PD',
'indefinite': 'PI',
'interrogative': 'PT',
'numeral': 'PN',
'personal': 'PP',
'possessive': 'PX',
'relative': 'PR'
}

# List of relevant PoS tags of markables
relevant_pos = ['NP', 'NC', 'PX', 'PP', 'PR', 'PD', 'PE', 'DP'] # PE for pronoun elliptic

# Dicts for storing determiners, possessed objects of possessive pronouns
determiners, pposat_heads = {}, {}

# Align mention boundaries with gold boundaries
align_boundaries = True

# ========================functions========================== #

def get_extension(tok,ext,sent):
    ''' Return NP boundaries; gather all depending tokens recursively '''
    for t in sent:
        if t[regens_index] == tok[tokid_index]:
            ext.append(t)
            get_extension(t,ext,sent)
    return ext

def get_gen(tok):
    gen = re.search('gen=([^|])+', tok[morph_index]).group(1)
    if gen == 'f': gen = 'FEM'
    elif gen == 'm': gen = 'MASC'
    elif gen == 'n': gen = 'NEUT'
    elif gen == 'c': gen = '*'
    return gen 

def get_morph(tok, sent):
    ''' Return morphological properties of a markable '''

    # Person
    if 'person=' in tok[morph_index]:
        per = int(re.search('person=(\d+)', tok[morph_index]).group(1))
        if per == 0: per = 3#'*'
    else: per = 3

    # Gender
    gen = '*'
    if 'ne=person' in tok[morph_index]:
        # Try to find first name in list of male or female names
        name = re.search('[^_]+', tok[lemma_index]).group() if '_' in tok[lemma_index] and not tok[lemma_index] == '_' else tok[lemma_index]
        if name.title() in male_names: gen = 'MASC'
        elif name.title() in female_names: gen = 'FEM'
        else: gen = '*'
    elif 'ne=' in tok[morph_index]: # check for a determiner with gender/number
        try:
            det = next(t for t in sent if t[regens_index] == tok[tokid_index] and t[pos_index] == 'DA')
            gen = get_gen(det)
        except StopIteration: gen = '*' # Assume all non-person named entities are neuter; dangerous? TODO: check this
    elif 'gen=' in tok[morph_index] and not 'gen=c' in tok[morph_index]: gen = get_gen(tok)
    elif tok[pos_index] == 'VM' and re.match('.*mood=(gerund|imperative|infinitive).*', tok[morph_index]) and re.match('.*l[aoe]s?$', tok[lexem_index]):
        if tok[lexem_index][-1] == 'o': gen = 'MASC'
        elif tok[lexem_index][-1] == 'a': gen = 'FEM'
        else: gen = '*'
    else:   # Look for a determiner
        try:
            det = next(t for t in sent if t[regens_index] == tok[tokid_index] and t[pos_index] in ['DA', 'DI'])
            gen = get_gen(det)
        except: pass

    # Number
    if 'num=' in tok[morph_index]:
        num = re.search('num=([^|])+', tok[morph_index]).group(1)
        if num == 's': num = 'SG'
        elif num == 'p': num = 'PL'
        elif num == 'c': num = '*'
        else: pdb.set_trace()
    elif 'ne=' in tok[morph_index]: num = 'SG'    # Fallback: all named entities are singular; dangerous? TODO: check this
    elif tok[pos_index] == 'VM' and re.match('.*mood=(gerund|imperative|infinitive).*', tok[morph_index]) and re.match('.*l[aoe]s?$', tok[lexem_index]):
        if tok[lexem_index][-1] == 's': num = 'PL'
        else: num = 'SG'
    else: num = '*'

    return [per, gen, num]

def get_pos(tok):
    ''' Return PoS tag of token '''
    if 'postype' in tok[morph_index]:
        pos = re.search('postype=([^|]+)',tok[morph_index]).group(1)
        try:return eagles_pos[pos]
        except: return '*'
    elif tok[pos_index] == 'p':
        if tok[lemma_index] == '_': return 'PE' # PE for pronoun elliptic
        elif tok[lexem_index].lower() in ['se', 'te', 'me']:  return 'PRF'  # Reflexive
        elif tok[lemma_index].lower() == 'yo': return 'PP'
        else: return '*'
    elif tok[pos_index] in ['Z', 'Zp', 'W']: return 'NC'
    else: return '*'

def get_verb(tok, sent):
    ''' Return verb governing a token '''
    regens = sent[int(tok[regens_index])-1]
    if regens[pos_index].startswith('V'): return regens
    elif regens[regens_index] == '0': return
    else: return get_verb(regens, sent)

# ========================main========================== #

doc_counter = 0
for line in open(sys.argv[1], 'r'):
    
    if line.startswith('#end document'):

        # Check if gold mentions are represented as markables
        if align_boundaries:
            for id,cset in coref.items():
                for tm in cset:
                    try: next(m for m in mables if m[1:4] == tm)
                    except:
                        if tm[1] == tm[2]: continue # single word mention
                        try:
                            closest_mable = next( m for m in mables if m[1:3] == tm[:2])
                            closest_mable[3] = tm[2]
                        except: 
                            try:
                                closest_mable = next( m for m in mables if m[1] == tm[0] and m[3] == tm[2]) # Same end
                                if abs(closest_mable[2]-tm[1])<3:
                                    closest_mable[2] = tm[1]
                            except: 
                                pass

        print 'docid=', docid
        print 'mables=',mables
        coref = { entity: mentions for entity,mentions in coref.items() if not len(mentions) == 1 } # Filter singletons
        print 'coref=',dict(coref)
        print 'determiners=',determiners
        print 'pposat_heads=',pposat_heads     
        print '####'

    elif line.startswith('#begin'):
        docid = line.strip().replace('#begin document ','')
        doc_counter += 1
        sys.stderr.write('\r'+str(doc_counter)+' '+docid)
        sys.stderr.flush()
        sent, coref, mables = [], [], []
        sent_cnt, mable_cnt = 1, 1
        coref = defaultdict(list)
        aggr = []
        
    elif line == '\n':
        for tok in sent:
        
            # Extract coreference annotation
            if not tok[coref_index] == '_':
                for id in tok[coref_index].split('|'):
                    cid = int(re.search('\d+',id).group())
                    if not cid in coref: coref[cid] = []

                    # Single word mention
                    if re.match('\(\d+\)',id):  
                        coref[cid].append([sent_cnt,int(tok[tokid_index]),int(tok[tokid_index])])
                        coref[cid].sort()
                    
                    # Mention start; store coref ID, sentence number, mention start token ID
                    elif re.match('\(\d+',id): aggr.insert(0,[cid,sent_cnt,int(tok[tokid_index])])

                    # Mention end
                    elif re.match('\d+\)',id):
                        for ext in aggr:
                            if ext[0]==cid: # Matching coref ID
                                aggr.remove(ext)    # Pop
                                ext=ext[1:] # Remove coref ID
                                ext.append(int(tok[tokid_index])) # Mention end token ID
                                break
                        coref[cid].append(ext)
                        coref[cid].sort()

            mable = []

            if tok[pos_index] in ['NC','NP'] or (tok[pos_index] in ['Zp','Z','W'] and not tok[gf_index] in ['spec' ,'z', 'atr']) :  # Nouns
                ext = get_extension(tok,[tok],sent) # Get extension
                ext_border=sorted(ext, key=lambda x: int(x[tokid_index]))
                while True: # Trim mention extension left and right
                    if ext_border[-1][lexem_index] in [')','(','.',',',':','-']: ext_border = ext_border[:-1]
                    elif ext_border[0][lexem_index] in [')','(','.',',',':','-']: ext_border = ext_border[1:] 
                    elif ext_border[0][pos_index] in ['RG', 'CS']: ext_border = ext_border[1:] 
                    else: break
                mable = [mable_cnt, sent_cnt, int(ext_border[0][tokid_index]), int(ext_border[-1][tokid_index])]
                determiners[mable_cnt] = ext_border[0][lemma_index] if ext_border[0][pos_index] in ['DA', 'DI'] else '*'

                # Check if head is also a nouns, i.e. we have a potential apposition
                if not mables == []:    # Need previous mentions
                    if tok[gf_index] == 'grup.nom': pass    # TODO handle conjunctions                        
                    else:
                        head = sent[int(tok[regens_index])-1]
                        if tok[pos_index] == 'NP' and head[pos_index] in ['NC', 'NP']:  # NE apposition -> shift head?
                            #pdb.set_trace() # some problematic cases here, definitely
                            if int(head[tokid_index]) in range(mables[-1][2], mables[-1][3]):
                                if 'ne=person' in tok[morph_index]:
                                    # don't shift heads for plurals
                                    if 'ne=person' in tok[morph_index] and mables[-1][7] == 'PL': pass
                                    # don't shift head if head is non-animate noun
                                    elif head[pos_index] == 'NC' and not head[lemma_index] in person: pass
                                    else:
                                        mables[-1][9] = 'ANIM'
                                        if mables[-1][6] == '*': mables[-1][6] = get_morph(tok, sent)[1]
                                        mables[-1][-1] = tok[lemma_index]
                                        ne_class = re.search('ne=([^|]+)', tok[morph_index]).group(1) if 'ne=' in tok[morph_index] else '-'
                                        if not ne_class == '-': mables[-1][12] = ne_class
                                        mables[-1][4] = 'NP'
                                        continue
                                else:
                                    mables[-1][-1] = tok[lemma_index]
                                    ne_class = re.search('ne=([^|]+)', tok[morph_index]).group(1) if 'ne=' in tok[morph_index] else '-'
                                    if not ne_class == '-': mables[-1][12] = ne_class
                                    mables[-1][4] = 'NP'
                                    continue
                        elif tok[pos_index] == 'NC' and head[pos_index] in ['NP', 'NC']:
                            if int(tok[tokid_index]) - int(head[tokid_index]) < 3:
                                mable = []  # delete the markable, don't shift the head

            elif tok[pos_index] in relevant_pos: # Pronouns
                if tok[lexem_index] == 'se': continue
                mable = [mable_cnt, sent_cnt, int(tok[tokid_index]), int(tok[tokid_index])]
                if tok[pos_index] in ['PX', 'DP']:
                    try: pposat_heads[mable_cnt] = sent[int(tok[regens_index])-1]
                    except: pdb.set_trace()                

            elif tok[pos_index].startswith('V'):    # Check for (elliptic) subject heuristically
                if tok[pos_index][0]== 'V' and tok[lexem_index] in ['hacer','ser'] and 'mood=infinitive' in tok[morph_index]: pass
                elif tok[pos_index] == 'VM' and re.match('.*mood=(gerund|imperative|infinitive).*', tok[morph_index]):
                    if re.match('.*l[aoe]s?$', tok[lexem_index]): mable = [mable_cnt, sent_cnt, int(tok[tokid_index]), int(tok[tokid_index])]
                elif tok[pos_index] == 'VM' and not 'person=' in tok[morph_index]: pass   # infinite main verb
                else:
                    try: next(t for t in sent if t[regens_index]==tok[tokid_index] and t[gf_index] == 'suj')    # has an explicit subject
                    except:
                        if tok[pos_index] in ['VA', 'VS'] or (tok[pos_index] == 'VM' and tok[gf_index] == 'v'):  # aux verb, check for subject of main verb
                            main_verb = get_verb(tok, sent)
                            if not main_verb is None:
                                try: next(t for t in sent if t[regens_index]==main_verb[tokid_index] and t[gf_index] == 'suj')
                                except: mable = [mable_cnt, sent_cnt, int(tok[tokid_index]), int(tok[tokid_index])]
                            else:   # look for main verb attached to it
                                try: 
                                    main_verb = next(t for t in sent if t[regens_index]==tok[tokid_index] and t[pos_index] == 'VM')
                                    if 'person=' in main_verb[morph_index]:
                                        try: next(t for t in sent if t[regens_index]==main_verb[tokid_index] and t[gf_index] == 'suj')
                                        except: mable = [mable_cnt, sent_cnt, int(tok[tokid_index]), int(tok[tokid_index])]
                                    else: pass
                                except: mable = [mable_cnt, sent_cnt, int(tok[tokid_index]), int(tok[tokid_index])]
                        else: mable = [mable_cnt, sent_cnt, int(tok[tokid_index]), int(tok[tokid_index])]
                #if '(' in tok[-1] and mable == []: pdb.set_trace() # trace false negatives

            if not mable == []:

                pos = tok[pos_index]
                if pos.startswith('V'): mable.append('PE') # Assuming it has an eliptic subject
                else: mable.append(get_pos(tok))

                # Add morphological properties
                mable.extend(get_morph(tok, sent))

                # Gram. funct.
                if pos.startswith('V'): 
                    #pdb.set_trace()    # TODO: adapt to ci/cd if lexeme ends with l[aeo]s?
                    if re.match('.*l[aoe]s?$', tok[lexem_index]): mable.append('cd')
                    else: mable.append('suj')
                else:
                    if not tok[gf_index] == 'sn': mable.append(tok[gf_index])
                    else:
                        head = sent[int(tok[regens_index])-1]
                        if not head[pos_index] == 'n': mable.append(head[gf_index])
                        else: mable.append('app')   # Appositions                

                # NE class
                ne_class = re.search('ne=([^|]+)', tok[morph_index]).group(1) if tok[pos_index] == 'NP' and 'ne=' in tok[morph_index] else '-'

                # Animacy
                if pos == 'NC' and tok[lemma_index] in person:  # Common nouns
                    mable.append('ANIM')
                    ne_class = 'person'
                elif pos in ['NP', 'NC']:
                    #name = re.search('[^_]+', tok[lemma_index]).group() if '_' in tok[lemma_index] and not tok[lemma_index] == '_' else tok[lemma_index]
                    if ne_class == 'person': mable.append('ANIM')
                    else: mable.append('*')
                else: mable.append('*')

                # Governing verb
                if pos.startswith('V'): mable.extend([ int(tok[tokid_index]), tok[lexem_index]])
                else:
                    verb = get_verb(tok, sent)
                    if not verb is None: 
                        mable.extend([ int(tok[regens_index]), verb[lemma_index] ])  # Keep regens ID of token
                    else: mable.extend(['*','*'])                    

                mable.append(ne_class)  # NE class

                mable.append('*')   # TODO Connector
                if pos.startswith('V'): mable.append('él')
                else: 
                    # TODO Head string
                    if pos in ['NP', 'NC'] and ne_class == 'person':
                        #if tok[lemma_index].count('_')>1:print '\n',tok;pdb.set_trace()
                        last_name = re.search('[^_]+$', tok[lemma_index]).group().title() if '_' in tok[lemma_index] and not tok[lemma_index] == '_' else tok[lemma_index]
                        mable.append(last_name)
                    else: mable.append(tok[lemma_index])  
                mables.append(mable)                
                mable_cnt += 1

        sent = []
        sent_cnt += 1 
        
    else: sent.append(line.strip().split('\t')) # Aggregate tokens per sentence
