/*  1:   */ package qhichwa.client;
/*  2:   */ 
/*  3:   */ import com.sun.star.lang.Locale;
/*  4:   */ import com.sun.star.linguistic2.XHyphenatedWord;
/*  5:   */ 
/*  6:   */ public class HyphenatedWord
/*  7:   */   implements XHyphenatedWord
/*  8:   */ {
/*  9:   */   private String word;
/* 10:   */   private Locale locale;
/* 11:   */   private short pos;
/* 12:   */   
/* 13:   */   public HyphenatedWord(String word, Locale locale, short pos)
/* 14:   */   {
/* 15:12 */     this.word = word;
/* 16:13 */     this.locale = locale;
/* 17:14 */     this.pos = pos;
/* 18:   */   }
/* 19:   */   
/* 20:   */   public short getHyphenPos()
/* 21:   */   {
/* 22:18 */     return this.pos;
/* 23:   */   }
/* 24:   */   
/* 25:   */   public String getHyphenatedWord()
/* 26:   */   {
/* 27:22 */     return getWord();
/* 28:   */   }
/* 29:   */   
/* 30:   */   public short getHyphenationPos()
/* 31:   */   {
/* 32:26 */     return getHyphenPos();
/* 33:   */   }
/* 34:   */   
/* 35:   */   public Locale getLocale()
/* 36:   */   {
/* 37:30 */     return this.locale;
/* 38:   */   }
/* 39:   */   
/* 40:   */   public String getWord()
/* 41:   */   {
/* 42:34 */     return this.word;
/* 43:   */   }
/* 44:   */   
/* 45:   */   public boolean isAlternativeSpelling()
/* 46:   */   {
/* 47:38 */     return false;
/* 48:   */   }
/* 49:   */ }
