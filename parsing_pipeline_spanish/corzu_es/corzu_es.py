# -*- coding: utf-8 -*-

"""
# ================================================================ #

CorZu ES - Incremental Entity-mention Coreference Resolution for Spanish
Author: don.tuggener@gmail.com

# ================================================================ #

Usage:

train:
python incr_main.py ../tueba_files/train.mables.parzu       #real preprocessing
python incr_main.py ../tueba_files/train_gold_prep.mables   #gold preprocessing

test:
python incr_main.py ../tueba_files/test.mables.parzu ../tueba_files/test_9.1.conll main.res

when loaded as module main:
train:
main.main('../tueba_files/train_ner.mables.parzu')
test:
main.main('../tueba_files/dev_ner.mables.parzu','../tueba_files/dev_9.1.conll','mle_dev_tmp.res')   #real preprocessing
main.main('../tueba_files/dev_gold_prep.mables','../tueba_files/dev_9.1.conll','mle_dev_tmp.res')   #gold preprocessing

"""

# ============================================= #

''' IMPORTS '''

import copy, cPickle, operator, re, sys, pdb, os
from collections import defaultdict, Counter
from itertools import combinations
import random

# ============================================= #

''' SETTINGS '''

global mode, output_format
mode='test'             #train or test
output_format='semeval'   #semeval or annette
output_coref_chains = True 	#write coref chains into separate file

global reprocessing
preprocessing='real'    # gold or real

global classifier
classifier='mle'        #mle, thebeast, wapiti
if classifier=='mle':
    global ante_counts, pronouns_counts
    ante_counts, pronouns_counts = defaultdict(int), defaultdict(int)

global avg_ante_counts
avg_ante_counts = defaultdict(list)

global output_pronoun_eval, trace_errors, trace_nouns
trace_errors=False  #trace pronoun resolution errors
trace_nouns=False
output_pronoun_eval=False    #print pronoun classifier accuracy for cases where the true antecedent is actually available (i.e. among the candidates)
if mode=='train': trace_errors, trace_nouns = False, False

# Column indices of annotations
input_format = 'test_set'   # 'test_set' for Annette's CoNLL from pipeline; 'ancora' for Semeval's Ancora format; 'train_set' for Annette's CoNLL of Ancora

# Ante candidates and their scores
global ante_scores
ante_scores = ''

if input_format == 'test_set':
    #output_pronoun_eval=False
    pos_index = 4
    regens_index = 6
    tokid_index = 0
    lemma_index = 2
    lexem_index = 1
    morph_index = 5
    gf_index = 7
    coref_index = -1

elif input_format == 'train_set':
    pos_index = 6
    regens_index = 8
    tokid_index = 2
    lemma_index = 4
    lexem_index = 3
    morph_index = 7
    gf_index = 9
    coref_index = -1

elif input_format == 'ancora':
    pos_index = 4
    regens_index = 8
    tokid_index = 0
    lemma_index = 2
    lexem_index = 1
    morph_index = 6
    gf_index = 10
    coref_index = -1
    ne_index = 12    

  
# ============================================= #        

''' FUNCTION DEFINITIONS '''

def morph_comp(m1,m2):  #m1=[person,number,gender]
    """compare morphology values"""
    if m1[1]==m2[1] and m1[2]==m2[2]: return 1  #exact match
    if m1[1]=='*' and m1[2]=='*': return 1  #ante underspecified
    if m2[1]=='*' and m2[2]=='*': return 1  #anaph underspecified
    if m1[1]=='*' and m1[2]==m2[2]: return 1
    if m2[1]=='*' and m1[2]==m2[2]: return 1
    if m1[2]=='*' and m1[1]==m2[1]: return 1
    if m2[2]=='*' and m1[1]==m2[1]: return 1
    
def pper_comp(ante,pper):
    """morphological compatibility check for personal and relative pronouns"""
    if pper[1]-ante[1] >3: return 0 #sentence distance    
    if pper[5]!=ante[5]: return 0   #Person agreement
    if not ante[4] == 'PX' and pper[1]==ante[1] and pper[10]==ante[10] and pper[11]==ante[11]!='*': return 0    # Binding constraint
    if morph_comp(ante[5:8],pper[5:8]): return 1
    
def pposat_comp(ante,pper):
    """morphological compatibility check for possessive pronouns"""  
    # 'su' can refer to anything, appearantly...
    if pper[1]-ante[1] >3: return 0 #sentence distance    
    if pper[5]!=ante[5]: return 0   #Person agreement    
    return 1

def update_csets(ante,mable):
    """disambiguate pronoun and update coreference partition"""
    if mable[4]=='PRF': mable[5:10]=ante[5:10]      #override morpho and gf of reflexives by ante
        
    #mable[9]=ante[9]                                #animacy projection of ante to mable
    #mable[12]=ante[12]                              #ne_type    

    if ante[9]!='*' and mable[9]=='*': mable[9]=ante[9] # Animacy and NE class propagation
    elif ante[9]=='*' and mable[9]!='*': ante[9]=mable[9]
    if ante[12] == 'person': mable[12] = 'person'; mable[9] = 'ANIM'
    elif mable[12] == 'person': ante[12] = 'person'; ante[9] = 'ANIM'
    elif ante[12]!='*' and mable[12]=='*': mable[12]=ante[12]
    elif ante[12]=='*' and mable[12]!='*': ante[12]=mable[12]


    if ante[6]!='*' and mable[6]=='*': mable[6]=ante[6] # Morhology propagation
    elif ante[6]=='*' and mable[6]!='*': ante[6]=mable[6]
    if ante[7]!='*' and mable[7]=='*': mable[7]=ante[7]              
    elif ante[7]=='*' and mable[7]!='*': ante[7]=mable[7]

    if mable[4]=='PX':
        if ante[1]==mable[1]: mable[8]=ante[8]      # Same sentence: keep gf/salience of ante
        mable[6:8]=ante[6:8]
            
    if ante in wl:  #ante is from wl: open new cset
        csets.append([ante,mable])
        wl.remove(ante) 
    else:           #ante is from cset: append to set
        for cset in csets:
            if ante in cset:
                cset.append(mable)
                cset.sort()
                break
                
def get_true_ante(mable,ante_cands_wl,ante_cands_csets): 
    """return true antecedent if amongst antecedent candidates"""   
    try:
        #find cset containing the markable. markable is not the first mention in the cset (otherwise no antecedent)
        coref_id_anaphor=next(x for x,y in coref.items() if mable[1:4] in y and sorted(y).index(mable[1:4])!=0)
        all_antes=ante_cands_wl+ante_cands_csets
        all_antes.sort(reverse=True)    #reverse sort to find most recent ante
        true_ante=next(a for a in all_antes if a[1:4] in coref[coref_id_anaphor])         
    except: true_ante=[]    
    return true_ante

def get_mable(tm):
    try: return next(m for m in mables if m[1:4]==tm)
    except StopIteration: return tm
        
# ============================================= #        

''' ANTECEDENT SELECTION '''
      
def get_best(ante_cands,ante_cands_csets,mable,docid):
    ''' Antecedent selection: return best of the candidates. '''
    
    ante=[]
    all_antes=ante_cands+ante_cands_csets    
    if all_antes==[]: return ante
    all_antes.sort(reverse=True)
    ante_cands.sort(reverse=True)
    ante_cands_csets.sort(reverse=True)    

    """
    # for elliptic subjects: limit antes to current sentence, if available canidates
    if mable[4] == 'PE': 
        antes_in_sent = [a for a in all_antes if a[1] == mable[1]]
        if not antes_in_sent == []: all_antes = antes_in_sent
    """

    if mode=='train':

        if classifier=='mle':
            pronouns_counts[mable[4]]+=1
            ante_counts[mable[4]]+=len(all_antes)
            # Lexeme-based
            #pronouns_counts[mable[-1]]+=1
            #ante_counts[mable[-1]]+=len(all_antes)

        ante=get_true_ante(mable,ante_cands,ante_cands_csets)
        if ante==[]: return ante    #don't learn on cases where there is no true ante
            

    if mode=='test':
        
        if len(all_antes)==1: return all_antes[0]

        #random baseline
        #return all_antes[random.randint(0,len(all_antes)-1)]
        
        #most recent baseline
        #return all_antes[0]
        
        #most recent subject baseline
        #try: return next(m for m in all_antes if m[8]=='suj')
        #except StopIteration: return all_antes[0]
        
        #upper bound
        #true_ante=get_true_ante(mable,ante_cands,ante_cands_csets)     
        #if not true_ante==[]: return true_ante
                
        if classifier=='mle':    
            weighted_antes=[]          
            avg_ante_counts[mable[4]].append(len(all_antes))

    if classifier=='mle':
        ante_features={}
                
        for a in all_antes:    
            features={}            

            # ================================================================ #
            ''' GET FEATURES '''
            
            """ DISTANCE """

            #sentence distance
            if mable[4] not in ['PR']: features['sent_dist']=mable[1]-a[1]
                
            #markable distance in the same sentence
            if mable[1]==a[1]: features['mable_dist']=mable[0]-a[0]

            #candidate index
            cand_index=all_antes.index(a)
            features['cand_index']=cand_index  

            """ SYNTAX """
            
            #grammatical function of the antecedent 
            features['gf_ante']=a[8]        

            #gf_seq: sent. dist., gf ante, gf pronoun, PoS ante
            gf_seq=str(mable[1]-a[1])+'_'+a[8]+'_'+mable[8]+'_'+a[4]
            features['gf_seq']=gf_seq
         

            #PPOSAT specific features:
            if mable[4]=='PX':
                # PPOSAT is governed by same verb as ante
                same_head='same_head' if a[1]==mable[1] and a[10]==mable[10] else 'not_same_head'
                # TODO; extract pposat_heads in markable extraction
                if mable[0] in pposat_heads:
                    pposat_head=pposat_heads[mable[0]]
                    try:
                        features['head_gf_seq']='_'.join([str(mable[1]-a[1]),a[8],pposat_head[gf_index].upper(),a[4]])
                        if same_head=='same_head': features['same_head_gf_seq']='_'.join([a[8],pposat_head[gf_index].upper(),a[4]])
                    except: pdb.set_trace()

            """
            #(sub)clause type, i.e. gf of verb governing the candidate
            if (a[1],a[10]) in verbs:
                features['subclause']=verbs[a[1],a[10]]['verb'][7]
            else:
                features['subclause']='*'
                
            #(sub)clause type seq
            sent_dist='0' if mable[1]==a[1] else '1'
            if (mable[1],mable[10]) in verbs:
                features['subclause_seq']=sent_dist+'_'+features['subclause']+'_'+verbs[mable[1],mable[10]]['verb'][7]
            else:                
                features['subclause_seq']=sent_dist+'_'+features['subclause']+'_*' 
            """

            """ ANTE PROPERTIES """    

            #pos of ante
            #features['pos_ante']=a[4]	# really bad!

            #animacy of the antecedent; condition on gen+num also? mln has gen atleast             
            #features['anim_num_gen']=a[9]+'_'+a[6]+'_'+a[7]
            features['anim_num_gen']=a[9]

            #ne_type fo the antecedent
            if not a[12]=='-': features['ne_type']=a[12] 

            #gender of ante
            features['gen']=a[6]            
                        
            #number of ante
            features['num']=a[7]

            """ DISCOURSE """

            #discourse status: old/new
            if a in ante_cands_csets: discourse_status='old'
            else: discourse_status='new'
            features['discourse_status']=discourse_status

            #cset candidate: how old is the entity, i.e. in which sentence was it introduced
            if a in ante_cands_csets:
                ante_cset=next(c for c in csets if a in c)
                features['entity_introduction_sentence']=ante_cset[0][1]-mables[0][1]
            
            ante_features[a[0]]=features
            if mode=='test': weight={}
            
            pos=mable[4]    
            #pos=mable[-1]

            # Generate feature conjunctions autimatically
            #for i in range(1,len(features)+1): #all feature combinations
            #for i in range(1,4):    #up to three features                  
            for i in range(1,2):    #only unary features
                for c in combinations(features,i):
                    combined_feature_name='/'.join([x for x in c])               
                    combined_feature_values='/'.join([str(features[x]) for x in c])       
                    if mode=='train':            
                        #dict housekeeping
                        if not combined_feature_name in raw_counts[pos]:
                            raw_counts[pos][combined_feature_name]={}
                        if not combined_feature_values in raw_counts[pos][combined_feature_name]:
                            raw_counts[pos][combined_feature_name][combined_feature_values]={'pos':0,'neg':0}
                        #add feature counts to pos/neg raw_counts depending whether a is the true_ante or not
                        if a!=ante:
                            raw_counts[pos][combined_feature_name][combined_feature_values]['neg']+=1
                        else:
                            raw_counts[pos][combined_feature_name][combined_feature_values]['pos']+=1
                    if mode=='test':
                        if pos in weights_global and combined_feature_name in weights_global[pos]:
                            if combined_feature_values in weights_global[pos][combined_feature_name]:
                                weight[combined_feature_name]=weights_global[pos][combined_feature_name][combined_feature_values]
            if mode=='test':
                if weight != {}: weighted_antes.append([reduce(operator.mul,weight.values()),a,weight])  #product of the weights
                else: weighted_antes.append([0,a,[]])
                                         
        if mode=='test':
            
            if not weighted_antes==[]:
                weighted_antes.sort(reverse=True)
                ante=weighted_antes[0][1]
                # store antes and their scores
                global ante_scores
                ante_scores += '\npronoun:\t'+str(mable)+'\n'
                ante_scores += 'ante_candidates:\n'
                for a in weighted_antes:
		  ante_scores += str(a[0])+'\t'+str(a[1])+'\n'
                                  
        if trace_errors:            
            if mable[4] == 'PE':
                try:
                    next( (e,ms) for e,ms in coref.items() if mable[1:4] in ms )	# gold mentions only
                    true_ante=get_true_ante(mable,ante_cands,ante_cands_csets)  
                    #if true_ante == []:
                    if not ante==true_ante:
                        print ''
                        print mable
                        print 'true:\t',true_ante            
                        print 'sel:\t',ante
                        for x in all_antes:
                            print x
                        for x in weighted_antes[:2]:
                            print x                        
                        print ''
                        pdb.set_trace()
                except: pass
    return ante
    
# ============================================= # 

''' MAIN LOOP '''
      
def main(file1,file2='',file3=''): 
    """
    Main loop
    train:
    main('../tueba_files/train_ner.mables.parzu')
    test:
    main('../tueba_files/dev_ner.mables.parzu','../tueba_files/dev_9.1.conll','mle_dev_tmp.res')   #real preprocessing
    main('../tueba_files/dev_gold_prep.mables','../tueba_files/dev_9.1.conll','mle_dev_tmp.res')   #gold preprocessing
    """
    
    if mode=='train':
        if not os.path.isfile(file1):
            print >>sys.stderr,file1,'does not exist'
            return
    else:
        if not os.path.isfile(file1):
            print >>sys.stderr,file1,'does not exist'
            return
        
        if not os.path.isfile(file2):
            print >>sys.stderr,file2,'does not exist'
            return               
    
    with open(file1,'r') as f: docs=f.read()
    docs=docs.split('####')
    del docs[-1]

    if mode=='train':
        if classifier=='mle':
            global raw_counts,weights
            raw_counts = defaultdict(lambda: defaultdict(dict)) 
            weights={}

    if mode=='test':
        global res
        res={}
        
        if classifier=='mle':
            global weights_global
            if preprocessing=='gold': weights_global=eval(open('mle_weights_tmp','r').read())
            if preprocessing=='real': weights_global=eval(open('mle_weights_real','r').read())
            
    eval_all=defaultdict(lambda: defaultdict(lambda:defaultdict(int)))      
    
    if mode=='train': print >> sys.stderr,'Training on file',file1
    if mode=='test': print >> sys.stderr,'Testing on file',file1
    
    doc_counter=1
                
    for doc in docs:

        #load information from preprocessing
        docid=re.search('docid= ?(.*)',doc).group(1)       
        global mables, coref, determiners, pposat_heads
        mables=eval(re.search('mables=(.*)',doc).group(1))
        coref=eval(re.search('coref=(.*)',doc).group(1))
        determiners=eval(re.search('determiners=(.*)',doc).group(1))        
        pposat_heads=eval(re.search('pposat_heads=(.*)',doc).group(1))

        global wl,csets
        wl,csets=[],[]

        sys.stderr.write('\r'+'doc name: '+str(docid)+'\tdoc counter: '+str(doc_counter))
        sys.stderr.flush()
        doc_counter+=1
            
                # Ante scores
        global ante_scores
        ante_scores += '#'+docid
            
        for mable in mables:
        
            matched=0
            global ante_cands_csets, ante_cands,ante
            ante_cands_csets, ante_cands, ante = [], [], []

            if mable[4] == 'NP':                
                try:
                    # Head string match
                    ante = next( m for m in reversed(mables[:mables.index(mable)]) if \
                        m[0] < mable[0] and m[-1].lower() == mable[-1].lower() )
                    update_csets(ante,mable)
                    matched = 1
                except: 
                    try:
                        ante = next( m for m in reversed(mables[:mables.index(mable)]) if \
                            m[0] < mable[0] and '_' in m[-1] and m[-1].lower().endswith(mable[-1].lower()) )
                        update_csets(ante,mable)
                        matched = 1                        
                    except: pass
                    """
                        # doesn't really help; slightly more recall, but precision is worse
                        if '_' in mable[-1]:    # ante is shorter
                            try:
                                ante = next( m for m in reversed(mables[:mables.index(mable)]) if \
                                    m[0] < mable[0] and mable[-1].lower().endswith(m[-1].lower()) )
                                update_csets(ante,mable)
                                matched = 1         
                            except:
                                if trace_nouns:
                                    try:ent=next( (e,ms) for e,ms in coref.items() if \
                                    mable[1:4] in ms and not ms.index(mable[1:4])==0);pdb.set_trace()    # gold mentions only
                                    except: pass
                                else: pass
                        else:
                            if trace_nouns:
                                try:ent=next( (e,ms) for e,ms in coref.items() if \
                                mable[1:4] in ms and not ms.index(mable[1:4])==0);pdb.set_trace()    # gold mentions only
                                except: pass
                            else: pass
                    """

            elif mable[4] == 'NC':
                # Filter indefinite NPs
                if mable[0] in determiners and re.match('^(un|otr|dos|todo|siete)',determiners[mable[0]]): pass
                # Only singular NPs; better Precision, lower Recall
                #elif mable[7] == 'PL': pass
                else:
                    for m in reversed(mables[:mables.index(mable)]):
                        # Head string match, number match
                        if m[0] < mable[0] and m[-1] == mable[-1] and m[7] == mable[7]: 
                            # ante NP is at least as mable; better Precision, lower Recall
                            #if mable[3]-mable[2] <= m[3]-m[2]: continue
                            ante = m
                            update_csets(ante,mable)
                            matched = 1
                            break 
                            
            elif mable[4]=='PR':    # Relative pronouns
                ante_cands=[m for m in wl if m[1]==mable[1] and m[4]!='PX' and pper_comp(m,mable)] # and mable[0]-m[0]<5]               
                for cset in csets: 
                    if cset[-1][1]==mable[1] and cset[-1][4]!='PX' and pper_comp(cset[-1],mable):# and mable[0]-cset[-1][0]<5:
                        ante_cands_csets.append(cset[-1]) #most recent from cset
                ante=get_best(ante_cands,ante_cands_csets,mable,docid)
                if not ante==[]:
                    update_csets(ante,mable)
                    matched=1
                        
            elif mable[4]=='PP':    # Personal pronouns
                ante_cands=[m for m in wl if pper_comp(m,mable)]
                for cset in csets: 
                    if pper_comp(cset[-1],mable): 
                        ante_cands_csets.append(cset[-1]) #most recent from cset
                ante=get_best(ante_cands,ante_cands_csets,mable,docid)              
                if not ante==[]:                
                    update_csets(ante,mable)
                    matched=1

            elif mable[4]=='PE':    # Verbs with elliptic subjects
                ante_cands=[m for m in wl if mable[1]-m[1] < 3 and pper_comp(m,mable)]
                for cset in csets: 
                    if mable[1]-cset[-1][1] < 3 and pper_comp(cset[-1],mable): 
                        ante_cands_csets.append(cset[-1]) #most recent from cset
                ante=get_best(ante_cands,ante_cands_csets,mable,docid)
                if not ante==[]:                
                    update_csets(ante,mable)
                    matched=1                    

            elif mable[4]=='PD':    # Demonstrative pronouns
                ante_cands=[m for m in wl if mable[1]-m[1]<2 and pper_comp(m,mable)]     
                for cset in csets: 
                    if mable[1]-cset[-1][1]<2 and pper_comp(cset[-1],mable):    #restrict ante cands to previous sentence
                        ante_cands_csets.append(cset[-1]) #most recent from cset                                        
                ante=get_best(ante_cands,ante_cands_csets,mable,docid)              
                if not ante==[]:                
                    update_csets(ante,mable)
                    matched=1
            
            elif mable[4]=='PX':    # Possessive pronouns
                ante_cands=[m for m in wl if pposat_comp(m,mable)]   
                for cset in csets: 
                    if pposat_comp(cset[-1],mable): 
                        ante_cands_csets.append(cset[-1]) #most recent from cset
                ante=get_best(ante_cands,ante_cands_csets,mable,docid)              
                if not ante==[]:
                    update_csets(ante,mable)
                    matched=1
                        
            if matched==0: 
                if not mable[4] == 'PE':    # Verbs cannot be antecedents if they have not been resolved
                    wl.append(mable)        

            all_antes=ante_cands+ante_cands_csets

            # Some debugging / evaluation code
            if not mable[4] in ['NC','NP']: # don't consider noun mentions
                lexem=re.search('[^|]+',mable[-1].lower()).group()
                eval_all[mable[4]][lexem]['instances']+=1
                try:    # only count true mentions, i.e. anaphoric pronouns
                    next(c for c in coref if mable[1:4] in coref[c] and not coref[c].index(mable[1:4])==0) # also filter out cataphors
                    eval_all[mable[4]][lexem]['true_mention']+=1
                except StopIteration: pass
                # TODO: Problem: if ante is a non-anaphoric verb but has the right ante, it is wl
                # However, the inferred antecedent is correct...
                true_ante=get_true_ante(mable,ante_cands,ante_cands_csets)
                if not true_ante==[]:
                    eval_all[mable[4]][lexem]['true_ante_present']+=1
                    if ante[:4]==true_ante[:4]:
                        eval_all[mable[4]][lexem]['tp']+=1
                    else:
                        eval_all[mable[4]][lexem]['wl']+=1
                """                        
                else:   #trace missing true antecedent
                    try:
                        next(c for c in coref if mable[1:4] in coref[c] and not coref[c].index(mable[1:4])==0) #it's a gold mention
                        print >>sys.stderr,'\ntrue ante not present\n',mable
                        print >>sys.stderr,ante_cands
                        print >>sys.stderr,ante_cands_csets                        
                        if mable[-1]=='sie': pdb.set_trace()
                    except StopIteration:
                        pass
                """
            elif mable[4] in ['NC','NP']:
                try:
                    cs_gold=next(c for c in coref if mable[1:4] in coref[c] and not coref[c].index(mable[1:4])==0 )
                    eval_all[mable[4]]['ALL']['true_mention']+=1
                    eval_all[mable[4]]['ALL']['instances']+=1                        
                    if matched==1:
                        if ante[1:4] in coref[cs_gold]:
                            eval_all[mable[4]]['ALL']['true_ante_present']+=1
                            eval_all[mable[4]]['ALL']['tp']+=1
                        else: eval_all[mable[4]]['ALL']['wl']+=1
                except StopIteration:
                    if matched==1:  
                        eval_all[mable[4]]['ALL']['instances']+=1
                        #if mable[4] == 'NC': print '\n',ante,mable; pdb.set_trace()                        
                        
        """
        # TODO:                  
        #Try to append first person pronoun csets to 3rd person entities
        for cset in csets:
            if cset[0][5]==1 and cset[0][7]=='SG': #first person coreference set #TODO also allow plural pronouns
                try:
                    #find a markable that is max. 1 sentence away, has number singular, has not neutral gender, is a subject, 3rd person, before the first mention of the 1st person cset and its verb is a communication verb
                    ante=next(m for m in mables if cset[0][1]-m[1]<=1 and m[7]=='SG' and m[6] in ['MASC','FEM','*'] and m[8]=='SUBJ' and m[5]==3 and m[0]<cset[0][0] and m[11] in vdic)
                    if ante in wl:                                          #the antecedent is from the waiting list
                        cset.insert(0,ante)                                 #insert the antecedent at the begining of the coreference set
                    else:
                        ante_set=next(c for c in csets if ante in c)        #the antecedent is from the coreference partition
                        ante_set+=cset                                      #merge the sets
                        csets.remove(cset)                                  #and remove the 1st person pronoun set
                except StopIteration: True

        #try to resolve remaining first person pronouns
        for p in wl:
            if p[4]=='PPER' and p[5]==1 and p[7]=='SG': #first person pronouns
                try:
                    #find a markable that is max. 1 sentence away, has number singular, has not neutral gender, is a subject, 3rd person, before the 1st person pronoun and its verb is a communication verb
                    ante=next(m for m in mables if p[1]-m[1]<=1 and m[7]=='SG' and m[6] in ['MASC','FEM','*'] and m[8]=='SUBJ' and m[5]==3 and m[0]<p[0] and m[11] in vdic)
                    if ante in wl:
                        csets.append([ante,p])
                        wl.remove(p)
                        wl.remove(ante)                
                    else:
                        ante_set=next(c for c in csets if ante in c)
                        ante_set+=[p]
                        wl.remove(p)
                except StopIteration: True
        """
       
        if mode=='test': res[docid]=[mables,csets]
            
    if mode=='train':
        
        # calculate the biased MLE weights
        if classifier=='mle':
            weights={}
            for pos in raw_counts:
                ratio=ante_counts[pos]/float(pronouns_counts[pos])  #class bias: antecedent candidates / pronoun ratio (how many candidates on avg?)   
                for feat in raw_counts[pos]:
                    card_feat=len(raw_counts[pos][feat])    #number of different feature values, needed for smoothing
                    for val in raw_counts[pos][feat]:
                        weight=ratio * (raw_counts[pos][feat][val]['pos']+.1) / (raw_counts[pos][feat][val]['pos']+raw_counts[pos][feat][val]['neg']+.2)
                        if not pos in weights: weights[pos] = {}
                        if not feat in weights[pos]:  weights[pos][feat] = {}
                        weights[pos][feat][val]=weight
            if preprocessing=='gold':                        
                with open('mle_weights_tmp','w') as f: 
                    f.write(str(dict(weights))+'\n')        
                with open('mle_weights_tmp_raw_counts','w') as f: 
                    f.write(str(dict(raw_counts))+'\n')                    
            if preprocessing=='real':                        
                with open('mle_weights_real','w') as f: 
                    f.write(str(dict(weights))+'\n')
                                           
    if mode=='test':
      
       # Ante scores
        with open(sys.argv[1]+'.ante_scores','w') as f: f.write(ante_scores) 
    
        #Output            
        f=open(file3,'w')
        docnr=0
        sent=1       

        if output_coref_chains:
            coref_file = sys.argv[1]+'.chains'
            fc=open(coref_file,'w')

        for line in open(file2,'r').readlines():
            if line.startswith('#begin'):
                sent=1
                docid=re.search('#begin document (.+)',line).group(1)
                csets_orig=res[docid][1]
                if output_coref_chains:
                    fc.write(line)
                    for c in csets_orig:
                        fc.write(str(csets_orig.index(c))+':')
                        for m in c: fc.write(str(m))
                        fc.write('\n')
                docnr+=1
                csets={}
                for cset in csets_orig: #convert system response for faster output
                    cset_id=csets_orig.index(cset)
                    for m in cset:
                        if m[2]==m[3]:
                            csets[(str(m[1]),str(m[2]),'oc')]=cset_id  #'oc' for open-close cset, swt mentions
                        else:
                            if not (str(m[1]),str(m[2]),'o') in csets:
                                csets[(str(m[1]),str(m[2]),'o')]=[cset_id]  #'o' for open cset, multiple mwt mentions can start at a given token, store list of cset ids
                            else:
                                csets[(str(m[1]),str(m[2]),'o')].append(cset_id)
                            if not (str(m[1]),str(m[3]),'c') in csets: #'c' for close cset; multiple mwt mentions can close at a given token, store list of cset ids
                                csets[(str(m[1]),str(m[3]),'c')]=[cset_id]  
                            else:
                                csets[(str(m[1]),str(m[3]),'c')].append(cset_id)  #'c' for close cset                                                     
                mables=res[docid][0]    #make same conversion as above, if singletons are wanted in the output, otherwise it's painfully slow
                f.write(line)
            elif line.startswith('#end'): 
                f.write(line)
            elif line=='\n':
                sent+=1
                f.write(line)
            else:
                csets_out=[]
                line=line.strip().split('\t')       
                if output_format=='semeval':
                    if (str(sent),line[0],'oc') in csets:
                        csets_out.append('('+str(csets[(str(sent),line[0],'oc')])+')')  
                    if (str(sent),line[0],'o') in csets:
                        for cid in csets[(str(sent),line[0],'o')]:
                            csets_out.append('('+str(cid))                
                    if (str(sent),line[0],'c') in csets:
                        for cid in csets[(str(sent),line[0],'c')]:
                            csets_out.append(str(cid)+')')     

                elif output_format=='annette':
                    if (str(sent),line[2],'oc') in csets:
                        csets_out.append('('+str(csets[(str(sent),line[2],'oc')])+')')  
                    if (str(sent),line[2],'o') in csets:
                        for cid in csets[(str(sent),line[2],'o')]:
                            csets_out.append('('+str(cid))                
                    if (str(sent),line[2],'c') in csets:
                        for cid in csets[(str(sent),line[2],'c')]:
                            csets_out.append(str(cid)+')')                       

                mables_out=[]                
                #this is for singleton output, i.e. for SemEval
                """        
                for m in mables:
                    if len([x for x in csets if m in x])==0:    #das dauert... besser loesen
                        if m[1]==int(line[0]) and m[2]==int(line[0]) and m[3]==int(line[1]): 
                            mables_out.append('('+str(m[0]+10000)+')')                    
                        elif m[1]==int(line[0]) and m[2]==line[0]: 
                            mables_out.append('('+str(m[0]+10000))
                        elif m[1]==int(line[0]) and m[3]==line[0]: 
                            mables_out.append(str(m[0]+10000)+')')
                """
                if csets_out==[] and mables_out==[]:
                    f.write('\t'.join(line[0:-1])+'\t_\n')
                elif csets_out==[] and mables_out!=[]:
                    f.write('\t'.join(line[0:-1])+'\t'+'|'.join(mables_out))
                    f.write('\n')
                elif csets_out!=[] and mables_out==[]:
                    f.write('\t'.join(line[0:-1])+'\t'+'|'.join(csets_out))
                    f.write('\n')
                else:
                    f.write('\t'.join(line[0:-1])+'\t'+'|'.join(csets_out)+'|'+'|'.join(mables_out))
                    f.write('\n')

    sys.stderr.write('\n')
    
    if mode=='test' and output_pronoun_eval:
    
        print >> sys.stderr,'\nPronoun resolution accuracy when true ante is among the candidates\n'
        
        all_tp,all_true_ante_present,all_cases,all_true_mentions=0,0,0,0            

        accuracies=defaultdict(float)
        
        for pos in eval_all:
            if not pos in ['NC','NP']:  
                print >> sys.stderr,pos
                pos_tp,pos_true_ante_present,pos_cases,pos_true_mentions=0,0,0,0    # PoS-wide counts
                for lemma,c in eval_all[pos].items():
                    pos_tp+=c['tp']
                    pos_true_ante_present+=c['true_ante_present']
                    pos_cases+=c['instances']
                    pos_true_mentions+=c['true_mention']                        
                    
                acc=(100*float(pos_tp)/pos_true_ante_present) if not pos_true_ante_present==0 else 0.
                accuracies[pos]=acc                            
                print >>sys.stderr,'ALL:\t',"%.2f" % (acc),'% ('+str(pos_tp)+')\t\t',
                print >>sys.stderr,'true ante present in '+str(pos_true_ante_present)+' of '+str(pos_cases)+' cases ('+"%.2f" % (100*float(pos_true_ante_present)/pos_cases)+'%),',
                acc2=100*float(pos_true_ante_present)/pos_true_mentions if not pos_true_mentions==0 else 0
                print >>sys.stderr,pos_true_mentions,'true mentions ('+"%.2f" % (acc2)+'%)'             
                all_tp+=pos_tp
                all_true_ante_present+=pos_true_ante_present
                all_cases+=pos_cases
                all_true_mentions+=pos_true_mentions
                
        accuracies['ALL']=100*float(all_tp)/all_true_ante_present                
        print >>sys.stderr,'OVERALL:\t',"%.2f" % (100*float(all_tp)/all_true_ante_present),'% ('+str(all_tp)+')\t\t',
        print >>sys.stderr,'true ante present in '+str(all_true_ante_present)+' of '+str(all_cases)+' cases ('+"%.2f" % (100*float(all_true_ante_present)/all_cases)+'%),',
        print >>sys.stderr,all_true_mentions,'true mentions ('+"%.2f" % (100*float(all_true_ante_present)/all_true_mentions)+'%)'

# ============================================= #    

if __name__ == '__main__':
    if mode=='train': main(sys.argv[1])
    else: main(sys.argv[1],sys.argv[2],sys.argv[3])
