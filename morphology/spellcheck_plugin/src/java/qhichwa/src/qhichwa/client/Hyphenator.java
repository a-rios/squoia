/*  1:   */ package qhichwa.client;
/*  2:   */ 
/*  3:   */ import com.sun.star.lang.Locale;
/*  4:   */ import com.sun.star.linguistic2.XHyphenatedWord;
/*  5:   */ 
/*  6:   */ public class Hyphenator
/*  7:   */ {
/*  8:   */   public static final String vowels = "aiueo√�?y√¶√•0AIUEY√Ö√ò√Ü";
/*  9:   */   public static final String consonants = "ntsrlmqkgpfvjdhbczwxNKSTXPMGDJLQCHBRFVWZ";
/* 10:   */   
/* 11:   */   public static boolean is_vowel(int c)
/* 12:   */   {
/* 13:11 */     return "aiueo√�?y√¶√•0AIUEY√Ö√ò√Ü".indexOf(c) != -1;
/* 14:   */   }
/* 15:   */   
/* 16:   */   public static boolean is_consonant(int c)
/* 17:   */   {
/* 18:15 */     return "ntsrlmqkgpfvjdhbczwxNKSTXPMGDJLQCHBRFVWZ".indexOf(c) != -1;
/* 19:   */   }
/* 20:   */   
/* 21:   */   public static XHyphenatedWord hyphenate(String word, Locale aLocale, short nMaxLeading)
/* 22:   */   {
/* 23:19 */     String lcword = word.toLowerCase();
/* 24:20 */     int pos = -1;
/* 25:21 */     for (short i = 0; (i < nMaxLeading) && (i < lcword.length() - 2); i = (short)(i + 1)) {
/* 26:22 */       if ((lcword.charAt(i) == lcword.charAt(i + 1)) && (is_consonant(lcword.charAt(i)))) {
/* 27:23 */         pos = i;
/* 28:25 */       } else if ((lcword.charAt(i) != lcword.charAt(i + 1)) && (is_vowel(lcword.charAt(i))) && (is_vowel(lcword.charAt(i + 1)))) {
/* 29:26 */         pos = i;
/* 30:28 */       } else if ((is_vowel(lcword.charAt(i))) && (is_consonant(lcword.charAt(i + 1))) && (is_vowel(lcword.charAt(i + 2)))) {
/* 31:29 */         pos = i;
/* 32:31 */       } else if ((i < lcword.length() - 3) && (is_vowel(lcword.charAt(i))) && (lcword.charAt(i + 1) == 'n') && (lcword.charAt(i + 2) == 'g') && (is_vowel(lcword.charAt(i + 3)))) {
/* 33:32 */         pos = i;
/* 34:34 */       } else if ((lcword.charAt(i) == 'r') && (is_consonant(lcword.charAt(i + 1)))) {
/* 35:35 */         pos = i;
/* 36:37 */       } else if ((lcword.charAt(i) == 't') && (lcword.charAt(i + 1) == 's')) {
/* 37:38 */         pos = i;
/* 38:   */       }
/* 39:   */     }
/* 40:42 */     if (pos != -1) {
/* 41:43 */       return new HyphenatedWord(word, aLocale, (short)pos);
/* 42:   */     }
/* 43:46 */     return null;
/* 44:   */   }
/* 45:   */ }

