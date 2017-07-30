/*   1:    */ package qhichwa.openoffice;
/*   2:    */ 
/*   3:    */ import com.sun.star.beans.PropertyValue;
/*   4:    */ import com.sun.star.frame.XDesktop;
/*   5:    */ import com.sun.star.lang.IllegalArgumentException;
/*   6:    */ import com.sun.star.lang.Locale;
/*   7:    */ import com.sun.star.lang.XComponent;
/*   8:    */ import com.sun.star.lang.XMultiComponentFactory;
/*   9:    */ import com.sun.star.lang.XServiceDisplayName;
/*  10:    */ import com.sun.star.lang.XServiceInfo;
/*  11:    */ import com.sun.star.lang.XSingleComponentFactory;
/*  12:    */ import com.sun.star.lib.uno.helper.Factory;
/*  13:    */ import com.sun.star.lib.uno.helper.WeakBase;
/*  14:    */ import com.sun.star.linguistic2.LinguServiceEvent;
/*  15:    */ import com.sun.star.linguistic2.XHyphenatedWord;
/*  16:    */ import com.sun.star.linguistic2.XHyphenator;
/*  17:    */ import com.sun.star.linguistic2.XLinguServiceEventBroadcaster;
/*  18:    */ import com.sun.star.linguistic2.XLinguServiceEventListener;
/*  19:    */ import com.sun.star.linguistic2.XPossibleHyphens;
/*  20:    */ import com.sun.star.linguistic2.XSpellAlternatives;
/*  21:    */ import com.sun.star.linguistic2.XSpellChecker;
/*  22:    */ import com.sun.star.registry.XRegistryKey;
/*  23:    */ import com.sun.star.task.XJobExecutor;
/*  24:    */ import com.sun.star.uno.UnoRuntime;
/*  25:    */ import com.sun.star.uno.XComponentContext;
/*  26:    */ import java.io.PrintStream;
/*  27:    */ import java.util.ArrayList;
/*  28:    */ import java.util.HashSet;
/*  29:    */ import java.util.List;
/*  30:    */ import java.util.Set;
/*  31:    */ import qhichwa.client.ChangeListener;
/*  32:    */ import qhichwa.client.Client;
/*  33:    */ import qhichwa.client.Configuration;
/*  34:    */ import qhichwa.client.Hyphenator;
/*  35:    */ import qhichwa.client.PossibleHyphens;
/*  36:    */ import qhichwa.client.SpellAlternatives;
/*  37:    */ 
/*  38:    */ public class Main
/*  39:    */   extends WeakBase
/*  40:    */   implements XJobExecutor, XServiceDisplayName, XServiceInfo, XSpellChecker, XHyphenator, XLinguServiceEventBroadcaster, ChangeListener
/*  41:    */ {
/*  42: 33 */   private Set<String> disabledRules = new HashSet();
/*  43:    */   private List<XLinguServiceEventListener> xEventListeners;
/*  44: 39 */   private static final String[] SERVICE_NAMES = { "com.sun.star.linguistic2.SpellChecker", "com.sun.star.linguistic2.Hyphenator", "qhichwa.openoffice.Main" };
/*  45:    */   private XComponentContext xContext;
/*  46: 42 */   private Client qhichwaClient = null;
/*  47:    */   
/*  48:    */   public Main(XComponentContext xCompContext)
/*  49:    */   {
/*  50:    */     try
/*  51:    */     {
/*  52: 46 */       changeContext(xCompContext);
/*  53: 47 */       this.disabledRules = new HashSet();
/*  54: 48 */       this.xEventListeners = new ArrayList();
/*  55: 49 */       this.qhichwaClient = new Client();
/*  56: 50 */       Configuration.getConfiguration().addChangeListener(this);
/*  57:    */     }
/*  58:    */     catch (Throwable t)
/*  59:    */     {
/*  60: 53 */       showError(t);
/*  61:    */     }
/*  62:    */   }
/*  63:    */   
/*  64:    */   public final void changeContext(XComponentContext xCompContext)
/*  65:    */   {
/*  66: 58 */     this.xContext = xCompContext;
/*  67:    */   }
/*  68:    */   
/*  69:    */   private XComponent getxComponent()
/*  70:    */   {
/*  71:    */     try
/*  72:    */     {
/*  73: 63 */       XMultiComponentFactory xMCF = this.xContext.getServiceManager();
/*  74: 64 */       Object desktop = xMCF.createInstanceWithContext("com.sun.star.frame.Desktop", this.xContext);
/*  75: 65 */       XDesktop xDesktop = (XDesktop)UnoRuntime.queryInterface(XDesktop.class, desktop);
/*  76: 66 */       return xDesktop.getCurrentComponent();
/*  77:    */     }
/*  78:    */     catch (Throwable t)
/*  79:    */     {
/*  80: 70 */       showError(t);
/*  81:    */     }
/*  82: 71 */     return null;
/*  83:    */   }
/*  84:    */   
/*  85:    */   public boolean isValid(String aWord, Locale aLocale, PropertyValue[] aProperties)
/*  86:    */   {
/*  87: 76 */     return this.qhichwaClient.isValid(aWord);
/*  88:    */   }
/*  89:    */   
/*  90:    */   public XSpellAlternatives spell(String aWord, Locale aLocale, PropertyValue[] aProperties)
/*  91:    */   {
/*  92: 80 */     XSpellAlternatives rv = null;
/*  93:    */     try
/*  94:    */     {
/*  95: 82 */       rv = new SpellAlternatives(aWord, aLocale, this.qhichwaClient);
/*  96:    */     }
/*  97:    */     catch (Throwable t)
/*  98:    */     {
/*  99: 85 */       showError(t);
/* 100:    */     }
/* 101: 87 */     return rv;
/* 102:    */   }
/* 103:    */   
/* 104:    */   public XHyphenatedWord hyphenate(String aWord, Locale aLocale, short nMaxLeading, PropertyValue[] aProperties)
/* 105:    */   {
/* 106: 91 */     XHyphenatedWord rv = null;
/* 107:    */     try
/* 108:    */     {
/* 109: 93 */       rv = Hyphenator.hyphenate(aWord, aLocale, nMaxLeading);
/* 110:    */     }
/* 111:    */     catch (Throwable t)
/* 112:    */     {
/* 113: 96 */       showError(t);
/* 114:    */     }
/* 115: 98 */     return rv;
/* 116:    */   }
/* 117:    */   
/* 118:    */   public XHyphenatedWord queryAlternativeSpelling(String aWord, Locale aLocale, short nIndex, PropertyValue[] aProperties)
/* 119:    */   {
/* 120:102 */     XHyphenatedWord rv = null;
/* 121:    */     
/* 122:104 */     return rv;
/* 123:    */   }
/* 124:    */   
/* 125:    */   public XPossibleHyphens createPossibleHyphens(String aWord, Locale aLocale, PropertyValue[] aProperties)
/* 126:    */   {
/* 127:109 */     return new PossibleHyphens(aWord, aLocale);
/* 128:    */   }
/* 129:    */   
/* 130:    */   public boolean hasLocale(Locale locale)
/* 131:    */   {
/* 132:113 */     return "quh".equals(locale.Language);
/* 133:    */   }
/* 134:    */   
/* 135:    */   public final Locale[] getLocales()
/* 136:    */   {
/* 137:117 */     return new Locale[] { new Locale("quh", "BO", "quh_BO") };
/* 138:    */   }
/* 139:    */   
/* 140:    */   public final boolean isSpellChecker()
/* 141:    */   {
/* 142:123 */     return true;
/* 143:    */   }
/* 144:    */   
/* 145:    */   public final boolean hasOptionsDialog()
/* 146:    */   {
/* 147:127 */     return false;
/* 148:    */   }
/* 149:    */   
/* 150:    */   public final boolean addLinguServiceEventListener(XLinguServiceEventListener xLinEvLis)
/* 151:    */   {
/* 152:131 */     if (xLinEvLis == null) {
/* 153:132 */       return false;
/* 154:    */     }
/* 155:134 */     this.xEventListeners.add(xLinEvLis);
/* 156:135 */     return true;
/* 157:    */   }
/* 158:    */   
/* 159:    */   public final boolean removeLinguServiceEventListener(XLinguServiceEventListener xLinEvLis)
/* 160:    */   {
/* 161:139 */     if (xLinEvLis == null) {
/* 162:140 */       return false;
/* 163:    */     }
/* 164:143 */     if (this.xEventListeners.contains(xLinEvLis))
/* 165:    */     {
/* 166:144 */       this.xEventListeners.remove(xLinEvLis);
/* 167:145 */       return true;
/* 168:    */     }
/* 169:147 */     return false;
/* 170:    */   }
/* 171:    */   
/* 172:    */   public final void recheckDocument()
/* 173:    */   {
/* 174:151 */     if (!this.xEventListeners.isEmpty()) {
/* 175:152 */       for (XLinguServiceEventListener xEvLis : this.xEventListeners) {
/* 176:153 */         if (xEvLis != null)
/* 177:    */         {
/* 178:154 */           LinguServiceEvent xEvent = new LinguServiceEvent();
/* 179:155 */           xEvent.nEvent = 8;
/* 180:156 */           xEvLis.processLinguServiceEvent(xEvent);
/* 181:    */         }
/* 182:    */       }
/* 183:    */     }
/* 184:    */   }
/* 185:    */   
/* 186:    */   public final void resetDocument()
/* 187:    */   {
/* 188:163 */     this.disabledRules = new HashSet();
/* 189:164 */     recheckDocument();
/* 190:    */   }
/* 191:    */   
/* 192:    */   public String[] getSupportedServiceNames()
/* 193:    */   {
/* 194:168 */     return getServiceNames();
/* 195:    */   }
/* 196:    */   
/* 197:    */   public static String[] getServiceNames()
/* 198:    */   {
/* 199:172 */     return SERVICE_NAMES;
/* 200:    */   }
/* 201:    */   
/* 202:    */   public boolean supportsService(String sServiceName)
/* 203:    */   {
/* 204:176 */     for (String sName : SERVICE_NAMES) {
/* 205:177 */       if (sServiceName.equals(sName)) {
/* 206:178 */         return true;
/* 207:    */       }
/* 208:    */     }
/* 209:181 */     return false;
/* 210:    */   }
/* 211:    */   
/* 212:    */   public String getImplementationName()
/* 213:    */   {
/* 214:185 */     return Main.class.getName();
/* 215:    */   }
/* 216:    */   
/* 217:    */   public static XSingleComponentFactory __getComponentFactory(String sImplName)
/* 218:    */   {
/* 219:189 */     SingletonFactory xFactory = null;
/* 220:190 */     if (sImplName.equals(Main.class.getName())) {
/* 221:191 */       xFactory = new SingletonFactory();
/* 222:    */     }
/* 223:193 */     return xFactory;
/* 224:    */   }
/* 225:    */   
/* 226:    */   public static boolean __writeRegistryServiceInfo(XRegistryKey regKey)
/* 227:    */   {
/* 228:197 */     return Factory.writeRegistryServiceInfo(Main.class.getName(), getServiceNames(), regKey);
/* 229:    */   }
/* 230:    */   
/* 231:    */   public void trigger(String sEvent)
/* 232:    */   {
/* 233:201 */     if (!javaVersionOkay()) {
/* 234:202 */       return;
/* 235:    */     }
/* 236:    */     try
/* 237:    */     {
/* 238:206 */       if (sEvent.equals("reset")) {
/* 239:207 */         resetDocument();
/* 240:    */       } else {
/* 241:210 */         System.err.println("Sorry, don't know what to do, sEvent = " + sEvent);
/* 242:    */       }
/* 243:    */     }
/* 244:    */     catch (Throwable e)
/* 245:    */     {
/* 246:214 */       showError(e);
/* 247:    */     }
/* 248:    */   }
/* 249:    */   
/* 250:    */   public void settingsChanged()
/* 251:    */   {
/* 252:219 */     resetDocument();
/* 253:    */   }
/* 254:    */   
/* 255:    */   private boolean javaVersionOkay()
/* 256:    */   {
/* 257:223 */     String version = System.getProperty("java.version");
/* 258:225 */     if ((version != null) && ((version.startsWith("1.0")) || (version.startsWith("1.1")) || (version.startsWith("1.2")) || (version.startsWith("1.3")) || (version.startsWith("1.4")) || (version.startsWith("1.5"))))
/* 259:    */     {
/* 260:226 */       DialogThread dt = new DialogThread("Error: Qhichwa Spell Checker requires Java 1.6 or later. Current version: " + version);
/* 261:227 */       dt.start();
/* 262:228 */       return false;
/* 263:    */     }
/* 264:231 */     return true;
/* 265:    */   }
/* 266:    */   
/* 267:    */   public static void showError(Throwable e)
/* 268:    */   {
/* 269:235 */     e.printStackTrace();
/* 270:    */     try
/* 271:    */     {
/* 272:238 */       String metaInfo = "OS: " + System.getProperty("os.name") + " on " + System.getProperty("os.arch") + ", Java version " + System.getProperty("java.vm.version") + " from " + System.getProperty("java.vm.vendor");
/* 273:239 */       String msg = "An error has occurred in Qhichwa Spell Checker:\n" + e.toString() + "\nStacktrace:\n";
/* 274:    */       
/* 275:241 */       StackTraceElement[] elem = e.getStackTrace();
/* 276:242 */       for (StackTraceElement element : elem) {
/* 277:243 */         msg = msg + element.toString() + "\n";
/* 278:    */       }
/* 279:245 */       msg = msg + metaInfo;
/* 280:246 */       DialogThread dt = new DialogThread(msg);
/* 281:247 */       dt.start();
/* 282:    */     }
/* 283:    */     catch (Throwable t)
/* 284:    */     {
/* 285:250 */       t.printStackTrace();
/* 286:    */     }
/* 287:    */   }
/* 288:    */   
/* 289:    */   public static void showMessage(String msg)
/* 290:    */   {
/* 291:255 */     DialogThread dt = new DialogThread(msg);
/* 292:256 */     dt.start();
/* 293:    */   }
/* 294:    */   
/* 295:    */   public void ignoreRule(String ruleId, Locale locale)
/* 296:    */     throws IllegalArgumentException
/* 297:    */   {
/* 298:    */     try
/* 299:    */     {
/* 300:261 */       this.disabledRules.add(ruleId);
/* 301:262 */       recheckDocument();
/* 302:    */     }
/* 303:    */     catch (Throwable t)
/* 304:    */     {
/* 305:265 */       showError(t);
/* 306:    */     }
/* 307:    */   }
/* 308:    */   
/* 309:    */   public void resetIgnoreRules()
/* 310:    */   {
/* 311:    */     try
/* 312:    */     {
/* 313:271 */       this.disabledRules = new HashSet();
/* 314:    */     }
/* 315:    */     catch (Throwable t)
/* 316:    */     {
/* 317:274 */       showError(t);
/* 318:    */     }
/* 319:    */   }
/* 320:    */   
/* 321:    */   public String getServiceDisplayName(Locale locale)
/* 322:    */   {
/* 323:279 */     return "Qhichwa Spell Checker";
/* 324:    */   }
/* 325:    */ }
