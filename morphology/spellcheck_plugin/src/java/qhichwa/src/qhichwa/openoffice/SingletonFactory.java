/*  1:   */ package qhichwa.openoffice;
/*  2:   */ 
/*  3:   */ import com.sun.star.lang.XSingleComponentFactory;
/*  4:   */ import com.sun.star.uno.Exception;
/*  5:   */ import com.sun.star.uno.XComponentContext;
/*  6:   */ 
/*  7:   */ public class SingletonFactory
/*  8:   */   implements XSingleComponentFactory
/*  9:   */ {
/* 10:   */   private transient Main instance;
/* 11:   */   
/* 12:   */   public final Object createInstanceWithArgumentsAndContext(Object[] arguments, XComponentContext xContext)
/* 13:   */     throws Exception
/* 14:   */   {
/* 15:19 */     return createInstanceWithContext(xContext);
/* 16:   */   }
/* 17:   */   
/* 18:   */   public final Object createInstanceWithContext(XComponentContext xContext)
/* 19:   */     throws Exception
/* 20:   */   {
/* 21:23 */     if (this.instance == null) {
/* 22:24 */       this.instance = new Main(xContext);
/* 23:   */     } else {
/* 24:26 */       this.instance.changeContext(xContext);
/* 25:   */     }
/* 26:28 */     return this.instance;
/* 27:   */   }
/* 28:   */ }
