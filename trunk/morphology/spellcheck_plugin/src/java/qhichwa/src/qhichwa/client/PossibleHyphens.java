/*  1:   */ package qhichwa.client;
/*  2:   */ 
/*  3:   */ import com.sun.star.lang.Locale;
/*  4:   */ import com.sun.star.linguistic2.XPossibleHyphens;
/*  5:   */ 
/*  6:   */ public class PossibleHyphens
/*  7:   */   implements XPossibleHyphens
/*  8:   */ {
/*  9:   */   private String word;
/* 10:   */   private String lcword;
/* 11:   */   private Locale locale;
/* 12:   */   
/* 13:   */   public PossibleHyphens(String word, Locale locale)
/* 14:   */   {
/* 15:12 */     this.word = word;
/* 16:13 */     this.lcword = word.toLowerCase();
/* 17:14 */     this.locale = locale;
/* 18:   */   }
/* 19:   */   
/* 20:   */   public short[] getHyphenationPositions()
/* 21:   */   {
/* 22:24 */     int num = 0;
/* 23:25 */     for (short i = 0; i < this.lcword.length() - 2; i = (short)(i + 1)) {
/* 24:26 */       if ((this.lcword.charAt(i) == this.lcword.charAt(i + 1)) && (Hyphenator.is_consonant(this.lcword.charAt(i)))) {
/* 25:27 */         num++;
/* 26:29 */       } else if ((this.lcword.charAt(i) != this.lcword.charAt(i + 1)) && (Hyphenator.is_vowel(this.lcword.charAt(i))) && (Hyphenator.is_vowel(this.lcword.charAt(i + 1)))) {
/* 27:30 */         num++;
/* 28:32 */       } else if ((Hyphenator.is_vowel(this.lcword.charAt(i))) && (Hyphenator.is_consonant(this.lcword.charAt(i + 1))) && (Hyphenator.is_vowel(this.lcword.charAt(i + 2)))) {
/* 29:33 */         num++;
/* 30:35 */       } else if ((i < this.lcword.length() - 3) && (Hyphenator.is_vowel(this.lcword.charAt(i))) && (this.lcword.charAt(i + 1) == 'n') && (this.lcword.charAt(i + 2) == 'g') && (Hyphenator.is_vowel(this.lcword.charAt(i + 3)))) {
/* 31:36 */         num++;
/* 32:38 */       } else if ((this.lcword.charAt(i) == 'r') && (Hyphenator.is_consonant(this.lcword.charAt(i + 1)))) {
/* 33:39 */         num++;
/* 34:41 */       } else if ((this.lcword.charAt(i) == 't') && (this.lcword.charAt(i + 1) == 's')) {
/* 35:42 */         num++;
/* 36:   */       }
/* 37:   */     }
/* 38:46 */     short[] ps = new short[num];
/* 39:47 */     num = 0;
/* 40:48 */     for (short i = 0; i < this.lcword.length() - 2; i = (short)(i + 1)) {
/* 41:49 */       if ((this.lcword.charAt(i) == this.lcword.charAt(i + 1)) && (Hyphenator.is_consonant(this.lcword.charAt(i)))) {
/* 42:50 */         ps[(num++)] = i;
/* 43:52 */       } else if ((this.lcword.charAt(i) != this.lcword.charAt(i + 1)) && (Hyphenator.is_vowel(this.lcword.charAt(i))) && (Hyphenator.is_vowel(this.lcword.charAt(i + 1)))) {
/* 44:53 */         ps[(num++)] = i;
/* 45:55 */       } else if ((Hyphenator.is_vowel(this.lcword.charAt(i))) && (Hyphenator.is_consonant(this.lcword.charAt(i + 1))) && (Hyphenator.is_vowel(this.lcword.charAt(i + 2)))) {
/* 46:56 */         ps[(num++)] = i;
/* 47:58 */       } else if ((i < this.lcword.length() - 3) && (Hyphenator.is_vowel(this.lcword.charAt(i))) && (this.lcword.charAt(i + 1) == 'n') && (this.lcword.charAt(i + 2) == 'g') && (Hyphenator.is_vowel(this.lcword.charAt(i + 3)))) {
/* 48:59 */         ps[(num++)] = i;
/* 49:61 */       } else if ((this.lcword.charAt(i) == 'r') && (Hyphenator.is_consonant(this.lcword.charAt(i + 1)))) {
/* 50:62 */         ps[(num++)] = i;
/* 51:64 */       } else if ((this.lcword.charAt(i) == 't') && (this.lcword.charAt(i + 1) == 's')) {
/* 52:65 */         ps[(num++)] = i;
/* 53:   */       }
/* 54:   */     }
/* 55:68 */     return ps;
/* 56:   */   }
/* 57:   */   
/* 58:   */   public Locale getLocale()
/* 59:   */   {
/* 60:72 */     return this.locale;
/* 61:   */   }
/* 62:   */   
/* 63:   */   public String getPossibleHyphens()
/* 64:   */   {
/* 65:76 */     short[] ps = getHyphenationPositions();
/* 66:77 */     StringBuilder sb = new StringBuilder(this.word);
/* 67:78 */     for (int i = ps.length; i > 0; i--) {
/* 68:79 */       sb.insert(ps[(i - 1)] + 1, '=');
/* 69:   */     }
/* 70:81 */     return sb.toString();
/* 71:   */   }
/* 72:   */   
/* 73:   */   public String getWord()
/* 74:   */   {
/* 75:85 */     return this.word;
/* 76:   */   }
/* 77:   */ }

