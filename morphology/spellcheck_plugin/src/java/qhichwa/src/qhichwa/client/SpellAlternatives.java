/*  1:   */ package qhichwa.client;
/*  2:   */ 
/*  3:   */ import com.sun.star.lang.Locale;
/*  4:   */ import com.sun.star.linguistic2.XSpellAlternatives;
/*  5:   */ 
/*  6:   */ public class SpellAlternatives
/*  7:   */   implements XSpellAlternatives
/*  8:   */ {
/*  9:   */   private String word;
/* 10:   */   private Locale locale;
              private Client qhichwaClient = null;
              private String[] rv = new String[0];
/* 11:   */   
/* 12:   */   public SpellAlternatives(String word, Locale locale, Client client)
/* 13:   */   {
/* 14:11 */     this.word = word;
/* 15:12 */     this.locale = locale;
                this.qhichwaClient = client;
                this.rv = this.qhichwaClient.getAlternatives(this.word);                
/* 16:   */   }
/* 17:   */   
/* 18:   */   public String getWord()
/* 19:   */   {
/* 20:16 */     return this.word;
/* 21:   */   }
/* 22:   */   
/* 23:   */   public Locale getLocale()
/* 24:   */   {
/* 25:20 */     return this.locale;
/* 26:   */   }
/* 27:   */   
/* 28:   */   public String[] getAlternatives()
/* 29:   */   {
/* 30:24 */     //String[] rv = new String[0];
/* 31:25 */     return this.rv;
/* 32:   */   }
/* 33:   */   
/* 34:   */   public short getAlternativesCount()
/* 35:   */   {
/* 36:29 */     return (short)this.rv.length;
/* 37:   */   }
/* 38:   */   
/* 39:   */   public short getFailureType()
/* 40:   */   {
/* 41:33 */     return 1;
/* 42:   */   }
/* 43:   */ }
