"""
Usage: python scorer_mentions.py key_file.conll response_file.conll
"""

import re,sys,pdb,copy
from collections import defaultdict

# ======================================================================= #
""" SETTINGS """

#noun_pos_tags,pronoun_pos_tags=['NN','NE'],['PPER','PPOSAT','PRELS']    #German; TuebaD/Z
#pos_index,lexem_index=4,6 #list index of the POS tag and lexeme
#noun_pos_tags,pronoun_pos_tags=['NN','NNS','NNP','NNPS'],['PRP','PRP$']    #English; OntoNotes
#pos_index,lexem_index=4,3 #list index of the POS tag and lexeme

# Semeval
#noun_pos_tags,pronoun_pos_tags=['NC','NP'],['PE','v','d']
# Annette
noun_pos_tags,pronoun_pos_tags=['NC','NP'],['PP','PR', 'PX']
pos_index,lexem_index=4, 2

evaluation=defaultdict(lambda:defaultdict(int)) #global evaluation dictionary
evaluation_prp=defaultdict(lambda:defaultdict(lambda:defaultdict(int))) #global pronoun evaluation dictionary
doc_ids=[]  #document names
docs={'key':{},'res':{}}
non_nominal_sets,sets,cataphora=0,0,0   #counters

# ======================================================================= #
""" DOCUMENT SEGMENTATION """

all_key=re.split('#end document[^\n]*',open(sys.argv[1],'r').read())    #split documents at lines starting with "#end document", consume everything except newline
all_res=re.split('#end document[^\n]*',open(sys.argv[2],'r').read())
if re.match('\n+',all_key[-1]): del all_key[-1]                         #splitting artefacts
if re.match('\n+',all_res[-1]): del all_res[-1]

if len(all_key)!=len(all_res): 
    print 'Key and response file do not have the same number of documents.'
    pdb.set_trace()

for doc in all_key:
    if not doc.lstrip().startswith('#begin'):
        print "No '#begin document...' at key document beginning"       #every doc should start with this
        pdb.set_trace()
    else:
        key=re.sub('\n{3,}','\n\n',doc)                                 #normalize multiple newlines
        key=key.lstrip().split('\n')                                    #lstrip to remove newlines at document beginning    
        docid=re.search('#begin document ([^\n]+)',key[0]).group(1)
        docs['key'][docid]=key
        doc_ids.append(docid)

for doc in all_res:
    if not doc.lstrip().startswith('#begin'):
        print "No '#begin document...' at response document beginning"
        pdb.set_trace()
    else:
        res=re.sub('\n{3,}','\n\n',doc)
        res=res.lstrip().split('\n')
        docid=re.search('#begin document ([^\n]+)',res[0]).group(1)
        docs['res'][docid]=res


# ======================================================================= #
""" FUNCTIONS """

def get_coref(key):
    """
    Return dict of coreference sets. 
    Mentions are lists; pronoun mentions are of length 5, noun mentions of length 3.
    Store line number, mention token start and end id, PoS tag and lexem for each mention.
    PoS tag and lexem only for single word terms, 
    multi-word terms are considered nouns and their lexem is not stored.
    """
    key_sets=defaultdict(list)
    line_nr=0
    for line in key:
        line_nr+=1
        if line.startswith('#') or line=='': token_nr=1 # New document / sentence                       
        elif not line.endswith('-') and not line.endswith('_'): # Coreference annotation
            line=re.split(' +|\t',line)
            ids=line[-1].strip().split('|')
            for id_str in ids:            
                id_int=re.search('\d+',id_str).group()  # Numeric coref id                
                if id_str.startswith('(') and id_str.endswith(')'): # Single word term                    
                    key_sets[id_int].append([line_nr,token_nr,token_nr,line[pos_index],line[lexem_index]])
                elif id_str.startswith('('):    # Start of multiple word term
                    # Add an incomplete mention, i.e. only sentence number and token start id
                    key_sets[id_int].append([line_nr,token_nr])
                elif id_str.endswith(')'):  # End of multi word term
                    # Find the open mention in the chain
                    for m in key_sets[id_int]:  
                        if len(m)==2: 
                            m.append(token_nr)   # Append token end id
                            break                        
            token_nr+=1            
        else: token_nr+=1
    # Sanity check: all mentions close
    for k, cset in key_sets.iteritems():
        try:
            err_m = next(m for m in cset if len(m) <3)
            print 'Mention not closing:'
            print 'Coref set:', cset
            print 'Mention:', err_m
        except: pass
    return key_sets

# ======================================================================= #
""" MAIN LOOP """
        
for doc in doc_ids:

    print doc

    if not doc in  docs['key'] or not doc in docs['res']: 
        print doc,'either not in key or in response. Enter c to continue ommiting the document or q to quit...'
        pdb.set_trace()
        continue    #ommit documents not in key/res
        
    key=docs['key'][doc]
    res=docs['res'][doc]
    if len(key)!=len(res): 
        print 'Key and response document have not the same number of lines.'
        pdb.set_trace()
    
    key_sets=get_coref(key)
    res_sets=get_coref(res)
    key_sets=sorted(key_sets.values())  #turn key and response dicts into sorted list of lists
    res_sets=sorted(res_sets.values())
    
    evaluation_doc=defaultdict(lambda:defaultdict(int))
    evaluation_prp_doc=defaultdict(lambda:defaultdict(lambda:defaultdict(int)))


    # ======================================================================= #    
    """ RECALL: Compare key to response mentions """
    
    for cset in key_sets:
        if len(cset)==1: continue   #singleton, ommit
        sets+=1        

        try:
            next(m for m in cset if len(m)==3 or m[3] in noun_pos_tags)
            pass
        except StopIteration:
            non_nominal_sets+=1
            continue    #no nouns, ommit
            
        for key_m in cset[1:]: #ommit set-initial mentions, not anaphoric
            
            pos=key_m[3] if len(key_m)==5 and not key_m[3] in noun_pos_tags else 'NOUN'

            #no nominal ante for key_m -> cataphora
            if [m for m in cset[:cset.index(key_m)] if len(m)==3 or m[3] in noun_pos_tags]==[] and pos in pronoun_pos_tags:
                cataphora+=1
                continue
            evaluation_doc[pos]['true mentions']+=1
            if pos in pronoun_pos_tags:
                lemma=re.search('[^|]+',key_m[-1].lower()).group()
                evaluation_prp_doc[pos][lemma]['true mentions']+=1
            
            res_set=[c for c in res_sets if key_m in c] #response set(s) containing the mention
          
            if len(res_set)>1:  #key mention is in multiple response sets
                print 'Mention in multiple chains. Mention:',key_m
                for tok in range(key_m[0]-1,key_m[0]+(key_m[2]-key_m[1])): print key[tok]
                print 'Response chains:'
                for c in res_set: print c
                sys.exit(1)
            elif res_set==[]: #key mention is not in the reponse -> false negative
                mention_class='fn'
            else:
                #the mention is the chain starter in the response, but not in the key 
                #-> recall error, it is anaphoric in the key, but not in the response -> false negative
                if res_set[0].index(key_m)==0:
                    mention_class='fn'
                else:
                    #find the closest preceding nominal antecedent
                    nominal_antes=[m for m in res_set[0][:res_set[0].index(key_m)] if len(m)==3 or m[3] in noun_pos_tags]
                    if nominal_antes==[]:
                        mention_class='fn'
                    else:
                        if nominal_antes[-1] in cset[:cset.index(key_m)]:
                            mention_class='tp'
                        else:                          
                            mention_class='wl'            

            evaluation_doc[pos][mention_class]+=1
            if pos in pronoun_pos_tags: evaluation_prp_doc[pos][lemma][mention_class]+=1          

    
    # ======================================================================= #
    """ PRECISION: Find spurious mentions in the reponse """
    """ I.e. response mentions with a noun ante which are either not in the key or do not have a noun ante in the key. """
    
    if not res_sets==[]:    
        for cset in res_sets:
        
            if len(cset)==1: continue   #singleton or no noun, ommit
            try:
                next(m for m in cset if len(m)==3 or m[3] in noun_pos_tags)
                pass
            except StopIteration: continue  #no noun in set, ommit
            
            for res_m in cset[1:]:
            
                pos=res_m[3] if len(res_m)==5 and not res_m[3] in noun_pos_tags else 'NOUN'    
                key_set=[c for c in key_sets if res_m in c] #key chain of the mention
                
                if key_set==[] or key_set[0].index(res_m)==0:   #not in any key chain or chain starter in key
                    evaluation_doc[pos]['fp']+=1 
                    if pos in pronoun_pos_tags: evaluation_prp_doc[pos][re.search('[^|]+',res_m[-1].lower()).group()]['fp']+=1
                                
                #Mentions that have a nominal antecedent in the response but not in the key
                #count as wl, as they wrongfuly link to nominal ante, or count as fp?
                elif [m for m in key_set[0][:key_set[0].index(res_m)] if len(m)==3 or m[3] in noun_pos_tags]==[]:
                    #TODO: decide how to treat this. We go for fp, as it should NOT affect Recall!
                    evaluation_doc[pos]['fp']+=1 
                    if pos in pronoun_pos_tags: evaluation_prp_doc[pos][re.search('[^|]+',res_m[-1].lower()).group()]['fp']+=1

    # ======================================================================= #
    """ DOC-LEVEL EVALUATION """

    #update global dicts
    for pos,classes in evaluation_doc.items():
        for c in classes:
            evaluation[pos][c]+=classes[c]

    for pos,lemmata in evaluation_prp_doc.items():
        for lemma,classes in lemmata.items():
            for c in classes:
                evaluation_prp[pos][lemma][c]+=classes[c]
                
    doc_tp=sum([evaluation_doc[pos]['tp'] for pos in evaluation_doc])
    doc_fn=sum([evaluation_doc[pos]['fn'] for pos in evaluation_doc])
    doc_fp=sum([evaluation_doc[pos]['fp'] for pos in evaluation_doc])
    doc_wl=sum([evaluation_doc[pos]['wl'] for pos in evaluation_doc])  

    #Recall
    if doc_tp+doc_wl+doc_fn==0: 
        if doc_tp+doc_fn==0: recall=0.0                                  #no coref annotation
        else: pdb.set_trace()
    else: recall=float(doc_tp)/(doc_tp+doc_wl+doc_fn)
    #Precision    
    if doc_tp+doc_wl+doc_fp==0:
        if doc_tp+doc_fp==0: precision=0.0                               #no coref annotation, no incorrectly resolved marable
        else:pdb.set_trace()
    else: precision=float(doc_tp)/(doc_tp+doc_wl+doc_fp)
    #Accuracy
    if doc_tp+doc_wl==0: acc=0.0
    else: acc=float(doc_tp)/(doc_tp+doc_wl)
    #F1
    if precision+recall==0: f1=0
    else:f1=(2 * ((precision*recall)/(precision+recall)))
    
    true_mentions=sum([evaluation_doc[pos]['true mentions'] for pos in evaluation_doc])
    
    print 'Overall\t',
    print 'R:', "%.2f" % (recall*100),'\t',
    print 'P:', "%.2f" % (precision*100),'\t',
    print 'F1:', "%.2f" % (f1*100),'\t',
    print 'Acc:',"%.2f" % (acc*100),'\t','(tp:',doc_tp,'| wl:',doc_wl,'| fn:',doc_fn,'| fp:',doc_fp,'| true mentions:',str(true_mentions)+')'
    print '-----------------------------------------------------------------------------------------------------------------------------'
    for pos_tag in evaluation_doc:
        print pos_tag,'\t',
        doc_tp=evaluation_doc[pos_tag]['tp']
        doc_wl=evaluation_doc[pos_tag]['wl']
        doc_fn=evaluation_doc[pos_tag]['fn']
        doc_fp=evaluation_doc[pos_tag]['fp']
        true_mentions=evaluation_doc[pos_tag]['true mentions']
        #Recall
        if doc_tp+doc_wl+doc_fn==0: recall=0.0
        else: recall=float(doc_tp)/(doc_tp+doc_wl+doc_fn)
        #Precision    
        if doc_tp+doc_wl+doc_fp==0: precision=0.0
        else: precision=float(doc_tp)/(doc_tp+doc_wl+doc_fp)
        #Accuracy
        if doc_tp+doc_wl==0: acc=0.0
        else: acc=float(doc_tp)/(doc_tp+doc_wl)
        #F1
        if precision+recall==0: f1=0.0
        else:f1=(2 * ((precision*recall)/(precision+recall)))
        
        print 'R:', "%.2f" % (recall*100),'\t',
        print 'P:', "%.2f" % (precision*100),'\t',
        print 'F1:', "%.2f" % (f1*100),'\t',
        print 'Acc:',"%.2f" % (acc*100),'\t','(tp:',doc_tp,'| wl:',doc_wl,'| fn:',doc_fn,'| fp:',doc_fp,'| true mentions:',str(true_mentions)+')'
    print ''
    

    for pos in evaluation_prp_doc:
        print pos   
        sorted_lexem=sorted([(evaluation_prp_doc[pos][lexem]['true mentions'],lexem) for lexem in evaluation_prp_doc[pos]],reverse=True)
        sorted_lexem=[lexem[1] for lexem in sorted_lexem]
        for lexem in sorted_lexem:
            print lexem,'\t',
            tp=evaluation_prp_doc[pos][lexem]['tp']
            wl=evaluation_prp_doc[pos][lexem]['wl']
            fn=evaluation_prp_doc[pos][lexem]['fn']
            fp=evaluation_prp_doc[pos][lexem]['fp']
            true_mentions=evaluation_prp_doc[pos][lexem]['true mentions']
            #Recall
            if tp+wl+fn==0: recall=0.0                                  #no coref annotation
            else: recall=float(tp)/(tp+wl+fn)
            #Precision    
            if tp+wl+fp==0: precision=0.0                               #no coref annotation, no incorrectly resolved markables
            else: precision=float(tp)/(tp+wl+fp)
            #Accuracy
            if tp+wl==0: acc=0.0
            else: acc=float(tp)/(tp+wl)
            #F1
            if precision+recall==0: f1=0
            else:f1=(2 * ((precision*recall)/(precision+recall)))
            
            print 'R:', "%.2f" % (recall*100),'\t',
            print 'P:', "%.2f" % (precision*100),'\t',
            print 'F1:', "%.2f" % (f1*100),'\t',
            print 'Acc:',"%.2f" % (acc*100),'\t','(tp:',tp,'| wl:',wl,'| fn:',fn,'| fp:',fp,'| true mentions:',str(true_mentions)+')'
        print ''


# ======================================================================= #

""" OVERALL EVALUATION """
    
print 'TOTAL'        
tp=sum([evaluation[pos]['tp'] for pos in evaluation])
fn=sum([evaluation[pos]['fn'] for pos in evaluation])
fp=sum([evaluation[pos]['fp'] for pos in evaluation])
wl=sum([evaluation[pos]['wl'] for pos in evaluation])  
#Recall
if tp+wl+fn==0: recall=0.0                                  #no coref annotation
else: recall=float(tp)/(tp+wl+fn)
#Precision    
if tp+wl+fp==0: precision=0.0                               #no coref annotation, no incorrectly resolved marable
else: precision=float(tp)/(tp+wl+fp)
#Accuracy
if tp+wl==0: acc=0.0
else: acc=float(tp)/(tp+wl)
#F1
if precision+recall==0: f1=0
else:f1=(2 * ((precision*recall)/(precision+recall)))

true_mentions=sum([evaluation[pos]['true mentions'] for pos in evaluation.keys()])

#sort pos tags by frequency
sorted_pos=sorted([(evaluation[pos]['true mentions'],pos) for pos in evaluation.keys()],reverse=True)
sorted_pos=[pos[1] for pos in sorted_pos]

print 'Overall\t',
print 'R:', "%.2f" % (recall*100),'\t',
print 'P:', "%.2f" % (precision*100),'\t',
print 'F1:', "%.2f" % (f1*100),'\t',
print 'Acc:',"%.2f" % (acc*100),'\t','(tp:',tp,'| wl:',wl,'| fn:',fn,'| fp:',fp,'| true mentions:',str(true_mentions)+')'
print '-----------------------------------------------------------------------------------------------------------------------------'
for pos_tag in sorted_pos:
    print pos_tag,'\t',
    tp=evaluation[pos_tag]['tp']
    wl=evaluation[pos_tag]['wl']
    fn=evaluation[pos_tag]['fn']
    fp=evaluation[pos_tag]['fp']
    true_mentions=evaluation[pos_tag]['true mentions']
    #Recall
    if tp+wl+fn==0: 
        if tp+fn==0: recall=0.0                                  #no coref annotation
        else: pdb.set_trace()
    else: recall=float(tp)/(tp+wl+fn)
    #Precision    
    if tp+wl+fp==0:
        if tp+fp==0: precision=0.0                               #no coref annotation, no incorrectly resolved markables
        else:pdb.set_trace()
    else: precision=float(tp)/(tp+wl+fp)
    #Accuracy
    if tp+wl==0: acc=0.0
    else: acc=float(tp)/(tp+wl)
    #F1
    if precision+recall==0: f1=0
    else:f1=(2 * ((precision*recall)/(precision+recall)))
    
    print 'R:', "%.2f" % (recall*100),'\t',
    print 'P:', "%.2f" % (precision*100),'\t',
    print 'F1:', "%.2f" % (f1*100),'\t',
    print 'Acc:',"%.2f" % (acc*100),'\t','(tp:',tp,'| wl:',wl,'| fn:',fn,'| fp:',fp,'| true mentions:',str(true_mentions)+')'
print ''

print 'Pronouns detailed'
print '-----------------------------------------------------------------------------------------------------------------------------'


for pos in evaluation_prp:
    print pos   
    sorted_lexem=sorted([(evaluation_prp[pos][lexem]['true mentions'],lexem) for lexem in evaluation_prp[pos]],reverse=True)
    sorted_lexem=[lexem[1] for lexem in sorted_lexem]
    for lexem in sorted_lexem:
        print lexem,'\t',
        tp=evaluation_prp[pos][lexem]['tp']
        wl=evaluation_prp[pos][lexem]['wl']
        fn=evaluation_prp[pos][lexem]['fn']
        fp=evaluation_prp[pos][lexem]['fp']
        true_mentions=evaluation_prp[pos][lexem]['true mentions']
        #Recall
        if tp+wl+fn==0: recall=0.0                                  #no coref annotation
        else: recall=float(tp)/(tp+wl+fn)
        #Precision    
        if tp+wl+fp==0: precision=0.0                               #no coref annotation, no incorrectly resolved markables
        else: precision=float(tp)/(tp+wl+fp)
        #Accuracy
        if tp+wl==0: acc=0.0
        else: acc=float(tp)/(tp+wl)
        #F1
        if precision+recall==0: f1=0
        else:f1=(2 * ((precision*recall)/(precision+recall)))
        
        print 'R:', "%.2f" % (recall*100),'\t',
        print 'P:', "%.2f" % (precision*100),'\t',
        print 'F1:', "%.2f" % (f1*100),'\t',
        print 'Acc:',"%.2f" % (acc*100),'\t','(tp:',tp,'| wl:',wl,'| fn:',fn,'| fp:',fp,'| true mentions:',str(true_mentions)+')'
print ''


print 'total chains',sets
print 'key sets without nouns:',non_nominal_sets
print 'cataphora',cataphora

