/*   1:    */ package qhichwa.client;
/*   2:    */ 
/*   3:    */ import java.io.File;
/*   4:    */ import java.io.FileInputStream;
/*   5:    */ import java.io.FileOutputStream;
/*   6:    */ import java.lang.ref.WeakReference;
/*   7:    */ import java.util.HashSet;
/*   8:    */ import java.util.Iterator;
/*   9:    */ import java.util.LinkedList;
/*  10:    */ import java.util.List;
/*  11:    */ import java.util.Properties;
/*  12:    */ import java.util.Set;
/*  13:    */ 
/*  14:    */ public class Configuration
/*  15:    */ {
/*  16:    */   protected Properties config;
/*  17:    */   protected File file;
/*  18:    */   protected Set<String> categories;
/*  19:    */   protected Set<String> phrases;
/*  20: 13 */   protected List<WeakReference<ChangeListener>> listeners = new LinkedList();
/*  21: 15 */   protected static Configuration singleton = null;
/*  22:    */   
/*  23:    */   public void fireChange()
/*  24:    */   {
/*  25: 18 */     Iterator i = this.listeners.iterator();
/*  26: 19 */     while (i.hasNext())
/*  27:    */     {
/*  28: 20 */       WeakReference ref = (WeakReference)i.next();
/*  29: 21 */       Object o = ref.get();
/*  30: 22 */       if (o == null) {
/*  31: 23 */         i.remove();
/*  32:    */       } else {
/*  33: 25 */         ((ChangeListener)o).settingsChanged();
/*  34:    */       }
/*  35:    */     }
/*  36:    */   }
/*  37:    */   
/*  38:    */   public void addChangeListener(ChangeListener l)
/*  39:    */   {
/*  40: 30 */     this.listeners.add(new WeakReference(l));
/*  41:    */   }
/*  42:    */   
/*  43:    */   public static synchronized Configuration getConfiguration()
/*  44:    */   {
/*  45: 34 */     if (singleton == null)
/*  46:    */     {
/*  47: 35 */       singleton = new Configuration(new File(System.getProperty("user.home"), ".Kukkuniiaat-OpenOffice.org"));
/*  48: 36 */       singleton.load();
/*  49:    */     }
/*  50: 38 */     return singleton;
/*  51:    */   }
/*  52:    */   
/*  53:    */   public Configuration(File _file)
/*  54:    */   {
/*  55: 42 */     this.config = new Properties();
/*  56: 43 */     this.file = _file;
/*  57:    */   }
/*  58:    */   
/*  59:    */   public void load()
/*  60:    */   {
/*  61:    */     try
/*  62:    */     {
/*  63: 48 */       this.config.load(new FileInputStream(this.file));
/*  64: 49 */       this.phrases = getIgnoredPhrases();
/*  65: 50 */       this.categories = getCategories();
/*  66:    */     }
/*  67:    */     catch (Exception ex)
/*  68:    */     {
/*  69: 53 */       this.phrases = new HashSet();
/*  70: 54 */       this.categories = new HashSet();
/*  71:    */     }
/*  72:    */   }
/*  73:    */   
/*  74:    */   private Set<String> createSet(String[] strings)
/*  75:    */   {
/*  76: 59 */     Set<String> temp = new HashSet();
/*  77: 60 */     for (int x = 0; x < strings.length; x++) {
/*  78: 61 */       temp.add(strings[x]);
/*  79:    */     }
/*  80: 63 */     return temp;
/*  81:    */   }
/*  82:    */   
/*  83:    */   public synchronized boolean isIgnored(String phrase)
/*  84:    */   {
/*  85: 67 */     return this.phrases.contains(phrase);
/*  86:    */   }
/*  87:    */   
/*  88:    */   public synchronized boolean isEnabled(String category)
/*  89:    */   {
/*  90: 71 */     return this.categories.contains(category);
/*  91:    */   }
/*  92:    */   
/*  93:    */   public synchronized void ignorePhrase(String phrase)
/*  94:    */   {
/*  95: 75 */     this.phrases.add(phrase);
/*  96: 76 */     this.config.setProperty("ignoredPhrases", createString(this.phrases));
/*  97:    */   }
/*  98:    */   
/*  99:    */   public synchronized void removePhrase(String phrase)
/* 100:    */   {
/* 101: 80 */     this.phrases.remove(phrase);
/* 102: 81 */     this.config.setProperty("ignoredPhrases", createString(this.phrases));
/* 103:    */   }
/* 104:    */   
/* 105:    */   public synchronized void showCategory(String category)
/* 106:    */   {
/* 107: 85 */     this.categories.add(category);
/* 108: 86 */     this.config.setProperty("categories", createString(this.categories));
/* 109:    */   }
/* 110:    */   
/* 111:    */   public synchronized void hideCategory(String category)
/* 112:    */   {
/* 113: 90 */     this.categories.remove(category);
/* 114: 91 */     this.config.setProperty("categories", createString(this.categories));
/* 115:    */   }
/* 116:    */   
/* 117:    */   private String createString(Set<String> strings)
/* 118:    */   {
/* 119: 95 */     StringBuffer temp = new StringBuffer();
/* 120: 96 */     Iterator<String> i = strings.iterator();
/* 121: 97 */     while (i.hasNext())
/* 122:    */     {
/* 123: 98 */       String value = (String)i.next();
/* 124: 99 */       temp.append(value);
/* 125:101 */       if (i.hasNext()) {
/* 126:102 */         temp.append(", ");
/* 127:    */       }
/* 128:    */     }
/* 129:105 */     return temp.toString();
/* 130:    */   }
/* 131:    */   
/* 132:    */   public synchronized Set<String> getIgnoredPhrases()
/* 133:    */   {
/* 134:109 */     return createSet(this.config.getProperty("ignoredPhrases", "").split(",\\s+"));
/* 135:    */   }
/* 136:    */   
/* 137:    */   public synchronized Set<String> getCategories()
/* 138:    */   {
/* 139:113 */     return createSet(this.config.getProperty("categories", "").split(",\\s+"));
/* 140:    */   }
/* 141:    */   
/* 142:    */   public synchronized String getServiceHost()
/* 143:    */   {
/* 144:117 */     return "http://alpha.visl.sdu.dk:80/tools/office/";
/* 145:    */   }
/* 146:    */   
/* 147:    */   public synchronized void setServiceHost(String name)
/* 148:    */   {
/* 149:121 */     this.config.setProperty("host", name);
/* 150:    */   }
/* 151:    */   
/* 152:    */   public synchronized String getLogin()
/* 153:    */   {
/* 154:125 */     return this.config.getProperty("login", "").trim();
/* 155:    */   }
/* 156:    */   
/* 157:    */   public synchronized void setLogin(String name)
/* 158:    */   {
/* 159:129 */     this.config.setProperty("login", name);
/* 160:    */   }
/* 161:    */   
/* 162:    */   public synchronized String getPassword()
/* 163:    */   {
/* 164:133 */     return this.config.getProperty("password", "").trim();
/* 165:    */   }
/* 166:    */   
/* 167:    */   public synchronized void setPassword(String name)
/* 168:    */   {
/* 169:137 */     this.config.setProperty("password", name);
/* 170:    */   }
/* 171:    */   
/* 172:    */   public void save()
/* 173:    */   {
/* 174:    */     try
/* 175:    */     {
/* 176:142 */       this.config.store(new FileOutputStream(this.file), "Kukkuniiaat-OpenOffice Properties");
/* 177:143 */       fireChange();
/* 178:    */     }
/* 179:    */     catch (Exception ex)
/* 180:    */     {
/* 181:146 */       throw new RuntimeException("Could not save properties\nLocation:" + this.file + "\n" + ex.getMessage());
/* 182:    */     }
/* 183:    */   }
/* 184:    */ }

