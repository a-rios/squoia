package qhichwa.client;

/*   2:    */ 
/*   3:    */ import com.sun.star.lang.Locale;
/*   4:    */ import com.sun.star.linguistic2.ProofreadingResult;
/*   5:    */ import com.sun.star.linguistic2.SingleProofreadingError;
import java.io.BufferedReader;
/*   6:    */ import java.io.File;
/*   7:    */ import java.io.InputStream;
import java.io.InputStreamReader;
/*   8:    */ import java.io.OutputStream;
/*   9:    */ import java.io.PrintStream;
/*  10:    */ import java.net.URL;
/*  11:    */ import java.nio.charset.Charset;
/*  12:    */ import java.security.MessageDigest;
/*  13:    */ import java.util.ArrayList;
/*  14:    */ import java.util.Formatter;
/*  15:    */ import java.util.Map;
/*  16:    */ import java.util.regex.Matcher;
/*  17:    */ import java.util.regex.Pattern;
/*  18:    */ import qhichwa.openoffice.Main;
/*  19:    */ 
/*  20:    */ public class Client
/*  21:    */ {
/*  22: 15 */   protected Process flookup = null;
/*  23: 16 */   protected OutputStream fl_wr = null;
/*  24: 17 */   protected InputStream fl_rd = null;

                /* TO OBTAIN THE SUGGESTIONS */
                /*
                protected OutputStream fm_wr = null;
                protected InputStream fm_rd = null;
                protected Process fmed = null;
                */
                protected File flookup_bin = null;
                protected File fmed_bin = null;                
                protected String[] command = null; 
                protected File foma_file = null;
                
/*  25: 18 */   protected Pattern rx = Pattern.compile("(\\S+)");
/*  26: 19 */   protected Matcher rx_m = this.rx.matcher("");
/*  27: 20 */   protected Pattern rx_pb = Pattern.compile("^\\p{Punct}+(\\S+?)$");
/*  28: 21 */   protected Matcher rx_pb_m = this.rx_pb.matcher("");
/*  29: 22 */   protected Pattern rx_pe = Pattern.compile("^(\\S+?)\\p{Punct}+$");
/*  30: 23 */   protected Matcher rx_pe_m = this.rx_pe.matcher("");
/*  31: 24 */   protected Pattern rx_pbe = Pattern.compile("^\\p{Punct}+(\\S+?)\\p{Punct}+$");
/*  32: 25 */   protected Matcher rx_pbe_m = this.rx_pbe.matcher("");
/*  33: 26 */   protected int position = 0;
/*  34: 27 */   protected boolean debug = false;
/*  35:    */   
/*  36:    */   public static void main(String[] args)
/*  37:    */     throws Exception
/*  38:    */   {
/*  39: 30 */     System.out.println("Initializing client");
/*  40:    */     
/*  41: 32 */     Client temp = new Client();
/*  42: 33 */     temp.debug = true;
/*  43: 34 */     Locale lt = new Locale();
/*  44: 35 */     //lt.Language = "qu";
/*  45: 36 */     //lt.Country = "PE";
/*  44: 35 */     lt.Language = "quh";
/*  45: 36 */     lt.Country = "BO";
/*  46: 37 */     lt.Variant = "UTF-8";
/*  47:    */     
/*  48: 39 */     System.out.println("Checking validity of WAIO: " + temp.isValidWord("WAIO"));
                  String[] alt = temp.getAlternatives("yaachay");
                    for (int i = 0; i < alt.length; i++) {
                        System.out.println("Checking alternatives of WAIO: " + alt[i]);        
                    }
/*  50: 41 */     ProofreadingResult error = temp.proofreadText("PACHANTIN LLAQTAKUNAPA RUNAP ALLIN KANANPAQ HATUN KAMACHIY.", lt, new ProofreadingResult());
/*  51: 42 */     for (int x = 0; x < error.aErrors.length; x++)
/*  52:    */     {
/*  53: 43 */       System.out.println(error.aErrors[x].nErrorStart + ", " + error.aErrors[x].nErrorLength + ", " + error.aErrors[x].nErrorType + ", " + error.aErrors[x].aRuleIdentifier + ", " + error.aErrors[x].aShortComment + ", " + error.aErrors[x].aFullComment);
/*  54: 44 */       for (int j = 0; j < error.aErrors[x].aSuggestions.length; j++) {
/*  55: 45 */         System.out.println("\t" + error.aErrors[x].aSuggestions[j]);
/*  56:    */       }
/*  57:    */     }
/*  58:    */   }
/*  59:    */   
/*  60:    */   public Client()
/*  61:    */   {
/*  62: 51 */     System.err.println("os.name\t" + System.getProperty("os.name"));
/*  63: 52 */     System.err.println("os.arch\t" + System.getProperty("os.arch"));
/*  64:    */     try
/*  65:    */     {
/*  66: 55 */       URL url = null;
/*  66: 55 */       URL fm_url = null;
                    this.command = new String[] { "/bin/bash", "-c", ""};
/*  67: 56 */       if (System.getProperty("os.name").startsWith("Windows")) {
/*  68: 57 */         url = getClass().getResource("../../lib/foma/win32/flookup.exe");
                      fm_url = getClass().getResource("../../lib/foma/win32/fmed.exe");
                      this.command = new String[] { "CMD", "/C", ""};
/*  69: 59 */       } else if (System.getProperty("os.name").startsWith("Mac")) {
/*  70: 60 */         url = getClass().getResource("../../lib/foma/mac/flookup");
                      fm_url = getClass().getResource("../../lib/foma/mac/fmed");
/*  71: 62 */       } else if (System.getProperty("os.name").startsWith("Linux")) {
/*  72: 63 */         if ((System.getProperty("os.arch").startsWith("x86_64")) || (System.getProperty("os.arch").startsWith("amd64"))) {
/*  73: 64 */           url = getClass().getResource("../../lib/foma/linux64/flookup");
                        fm_url = getClass().getResource("../../lib/foma/linux64/fmed");
/*  74:    */         } else {
/*  75: 67 */           url = getClass().getResource("../../lib/foma/linux32/flookup");
                        fm_url = getClass().getResource("../../lib/foma/linux32/fmed");
/*  76:    */         }
/*  77:    */       }
/*  78: 72 */       this.flookup_bin = new File(url.toURI());
                    this.fmed_bin = new File(fm_url.toURI());
                    
/*  79: 73 */       if ((!this.flookup_bin.canExecute()) && (!this.flookup_bin.setExecutable(true))) {
/*  80: 74 */         throw new Exception("Foma's flookup is not executable and could not be made executable!\nTried to execute " + this.flookup_bin.getCanonicalPath());
/*  81:    */       }

                    if ((!this.fmed_bin.canExecute()) && (!this.fmed_bin.setExecutable(true))) {
                      throw new Exception("Foma's fmed is not executable and could not be made executable!\nTried to execute " + this.fmed_bin.getCanonicalPath());
                    }

/*  82: 77 */       this.foma_file = new File(getClass().getResource("../../lib/foma/qhichwa.fst").toURI());
/*  83: 78 */       if (!this.foma_file.canRead()) {
/*  84: 79 */         throw new Exception("qhichwa.fst is not readable!");
/*  85:    */       }
/*  86: 83 */       ProcessBuilder pb = new ProcessBuilder(new String[] { flookup_bin.getAbsolutePath(), "-b", "-x", foma_file.getAbsolutePath() });
/*  87: 84 */       Map<String, String> env = pb.environment();
/*  88: 85 */       env.put("CYGWIN", "nodosfilewarning");
/*  89:    */       
/*  90:    */ 
/*  91: 88 */       this.flookup = pb.start();
/*  92:    */       
/*  93: 90 */       this.fl_wr = this.flookup.getOutputStream();
/*  94: 91 */       this.fl_rd = this.flookup.getInputStream();
/*  95:    */     }
/*  96:    */     catch (Exception ex)
/*  97:    */     {
/*  98: 94 */       showError(ex);
/*  99:    */     }
/* 100:    */   }
/* 101:    */   
/* 102:    */   public synchronized ProofreadingResult proofreadText(String paraText, Locale locale, ProofreadingResult paRes)
/* 103:    */   {
/* 104:    */     try
/* 105:    */     {
/* 106:100 */       paRes.nStartOfSentencePosition = this.position;
/* 107:101 */       paRes.nStartOfNextSentencePosition = (this.position + paraText.length());
/* 108:102 */       paRes.nBehindEndOfSentencePosition = paRes.nStartOfNextSentencePosition;
/* 109:    */       
/* 110:104 */       ArrayList<SingleProofreadingError> errors = new ArrayList();
/* 111:    */       
/* 112:106 */       this.rx_m.reset(paraText);
/* 113:107 */       while (this.rx_m.find())
/* 114:    */       {
/* 115:108 */         SingleProofreadingError err = processWord(this.rx_m.group(), this.rx_m.start());
/* 116:109 */         if (err != null) {
/* 117:110 */           errors.add(err);
/* 118:    */         }
/* 119:    */       }
/* 120:114 */       paRes.aErrors = ((SingleProofreadingError[])errors.toArray(paRes.aErrors));
/* 121:    */     }
/* 122:    */     catch (Throwable t)
/* 123:    */     {
/* 124:117 */       showError(t);
/* 125:118 */       paRes.nBehindEndOfSentencePosition = paraText.length();
/* 126:    */     }
/* 127:120 */     return paRes;
/* 128:    */   }
/* 129:    */   
/* 130:    */   public synchronized boolean isValid(String word)
/* 131:    */   {
/* 132:124 */     if ((this.flookup == null) || (this.fl_wr == null) || (this.fl_rd == null)) {
/* 133:125 */       return false;
/* 134:    */     }
/* 135:128 */     if (isValidWord(word)) {
/* 136:130 */       return true;
/* 137:    */     }
/* 138:133 */     String lword = word.toLowerCase();
/* 139:134 */     if ((!word.equals(lword)) && (isValidWord(lword))) {
/* 140:136 */       return true;
/* 141:    */     }
/* 142:139 */     this.rx_pe_m.reset(word);
/* 143:140 */     if (this.rx_pe_m.matches())
/* 144:    */     {
/* 145:141 */       if (isValidWord(this.rx_pe_m.group(1))) {
/* 146:143 */         return true;
/* 147:    */       }
/* 148:145 */       if (isValidWord(this.rx_pe_m.group(1).toLowerCase())) {
/* 149:147 */         return true;
/* 150:    */       }
/* 151:    */     }
/* 152:151 */     this.rx_pb_m.reset(word);
/* 153:152 */     if (this.rx_pb_m.matches())
/* 154:    */     {
/* 155:153 */       if (isValidWord(this.rx_pb_m.group(1))) {
/* 156:155 */         return true;
/* 157:    */       }
/* 158:157 */       if (isValidWord(this.rx_pb_m.group(1).toLowerCase())) {
/* 159:159 */         return true;
/* 160:    */       }
/* 161:    */     }
/* 162:163 */     this.rx_pbe_m.reset(word);
/* 163:164 */     if (this.rx_pbe_m.matches())
/* 164:    */     {
/* 165:165 */       if (isValidWord(this.rx_pbe_m.group(1))) {
/* 166:167 */         return true;
/* 167:    */       }
/* 168:169 */       if (isValidWord(this.rx_pbe_m.group(1).toLowerCase())) {
/* 169:171 */         return true;
/* 170:    */       }
/* 171:    */     }
/* 172:174 */     return false;
/* 173:    */   }

                public synchronized String[] getAlternatives(String word)
                {
                  String[] rv = new String[0];
                  try
                  {
                    if ((this.fmed_bin == null) || (this.flookup_bin == null) || (this.foma_file == null)) {
                      return rv;
                    }
                    rv = alternatives(word);
                  }
                  catch (Exception ex)
                  {
                    showError(ex);
                    return rv;
                  }
                  return rv;
                }

                public String[] alternatives(String word)
                {
                  String[] rv = new String[0];
                  word = word.trim().toLowerCase();                  
                  try
                  {
                    String ret = "";      
                    
                    String c = "echo "+ word +"| " + this.fmed_bin.getAbsolutePath() + " -l10 " + this.foma_file.getAbsolutePath();
                    this.command[2] = c;
                    System.out.println(word);
                    Process p = Runtime.getRuntime().exec(this.command);
                    InputStreamReader isr = new InputStreamReader(p.getInputStream(),"UTF8");
                    BufferedReader input = new BufferedReader(isr);
                    String str;
                    while ((str = input.readLine()) != null) {
                        ret = str.trim();
                    }
                    input.close();
                    isr.close();
                    //System.out.println("S: " + ret);                    
                    String delimiter = ",";
                    if (ret.contains(delimiter)) {
                      rv = ret.split(delimiter);
                    }
                    else {
                        rv = new String[1];
                        rv[0] = ret;
                    }                    
                  }
                  catch (Exception ex)
                  {
                    showError(ex);
                    return rv;
                  }
                  return rv;
                }                
                
/* 174:    */   
/* 175:    */   protected SingleProofreadingError processWord(String word, int start)
/* 176:    */   {
/* 177:178 */     if (this.debug) {
/* 178:179 */       System.err.println(word + "\t" + start);
/* 179:    */     }
/* 180:182 */     if (isValid(word)) {
/* 181:183 */       return null;
/* 182:    */     }
/* 183:186 */     SingleProofreadingError err = new SingleProofreadingError();
/* 184:187 */     err.nErrorStart = start;
/* 185:188 */     err.nErrorLength = word.length();
/* 186:189 */     err.nErrorType = 1;
/* 187:190 */     return err;
/* 188:    */   }
/* 189:    */   
/* 190:    */   public boolean isValidWord(String word)
/* 191:    */   {
/* 192:194 */     word = word + "\n";
/* 193:195 */     byte[] res = new byte[4];
/* 194:    */     try
/* 195:    */     {
/* 196:198 */       this.fl_wr.write(word.getBytes(Charset.forName("UTF-8")));
/* 197:199 */       this.fl_wr.flush();
/* 198:201 */       if (this.fl_rd.read(res, 0, 4) != 4) {
/* 199:202 */         throw new Exception("Failed to read first 4 bytes from flookup!");
/* 200:    */       }
/* 201:205 */       int avail = this.fl_rd.available();
/* 202:206 */       byte[] res2 = new byte[4 + avail];
/* 203:207 */       System.arraycopy(res, 0, res2, 0, 4);
/* 204:208 */       res = res2;
/* 205:209 */       if (this.fl_rd.read(res2, 4, avail) != avail) {
/* 206:210 */           throw new Exception("Failed to read first 4 bytes from flookup!");
/* 207:    */       }
                    else {
                        //String s = new String(res);
                        //System.out.println("RES: " + s + "\n");
                    }
/* 208:    */     }
/* 209:    */     catch (Exception ex)
/* 210:    */     {
/* 211:215 */       showError(ex);
/* 212:216 */       return false;
/* 213:    */     }
/* 214:219 */     return (res[0] != 43) || (res[1] != 63) || (res[2] != 10);
/* 215:    */   }
/* 216:    */   
/* 217:    */   static void showError(Throwable e)
/* 218:    */   {
/* 219:223 */     Main.showError(e);
/* 220:    */   }
/* 221:    */   
/* 222:    */   public static String makeHash(byte[] convertme)
/* 223:    */   {
/* 224:227 */     MessageDigest md = null;
/* 225:    */     try
/* 226:    */     {
/* 227:229 */       md = MessageDigest.getInstance("SHA-1");
/* 228:    */     }
/* 229:    */     catch (Throwable t) {}
/* 230:    */     try
/* 231:    */     {
/* 232:234 */       md = MessageDigest.getInstance("MD5");
/* 233:    */     }
/* 234:    */     catch (Throwable t) {}
/* 235:238 */     return byteArray2Hex(md.digest(convertme));
/* 236:    */   }
/* 237:    */   
/* 238:    */   private static String byteArray2Hex(byte[] hash)
/* 239:    */   {
/* 240:242 */     Formatter formatter = new Formatter();
/* 241:243 */     for (byte b : hash) {
/* 242:244 */       formatter.format("%02x", new Object[] { Byte.valueOf(b) });
/* 243:    */     }
/* 244:246 */     return formatter.toString();
/* 245:    */   }
/* 246:    */ }
