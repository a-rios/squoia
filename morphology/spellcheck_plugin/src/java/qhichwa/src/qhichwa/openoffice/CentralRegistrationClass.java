/*  1:   */ package qhichwa.openoffice;
/*  2:   */ 
/*  3:   */ import com.sun.star.lang.XSingleComponentFactory;
/*  4:   */ import com.sun.star.registry.XRegistryKey;
/*  5:   */ import java.lang.reflect.InvocationTargetException;
/*  6:   */ import java.lang.reflect.Method;
/*  7:   */ import java.util.StringTokenizer;
/*  8:   */ 
/*  9:   */ public class CentralRegistrationClass
/* 10:   */ {
/* 11:   */   public static XSingleComponentFactory __getComponentFactory(String sImplementationName)
/* 12:   */   {
/* 13:12 */     String regClassesList = getRegistrationClasses();
/* 14:13 */     StringTokenizer t = new StringTokenizer(regClassesList, " ");
/* 15:14 */     while (t.hasMoreTokens())
/* 16:   */     {
/* 17:15 */       String className = t.nextToken();
/* 18:16 */       if ((className != null) && (className.length() != 0)) {
/* 19:   */         try
/* 20:   */         {
/* 21:18 */           Class regClass = Class.forName(className);
/* 22:19 */           Method writeRegInfo = regClass.getDeclaredMethod("__getComponentFactory", new Class[] { String.class });
/* 23:20 */           Object result = writeRegInfo.invoke(regClass, new Object[] { sImplementationName });
/* 24:21 */           if (result != null) {
/* 25:22 */             return (XSingleComponentFactory)result;
/* 26:   */           }
/* 27:   */         }
/* 28:   */         catch (ClassNotFoundException ex)
/* 29:   */         {
/* 30:26 */           ex.printStackTrace();
/* 31:   */         }
/* 32:   */         catch (ClassCastException ex)
/* 33:   */         {
/* 34:28 */           ex.printStackTrace();
/* 35:   */         }
/* 36:   */         catch (SecurityException ex)
/* 37:   */         {
/* 38:30 */           ex.printStackTrace();
/* 39:   */         }
/* 40:   */         catch (NoSuchMethodException ex)
/* 41:   */         {
/* 42:32 */           ex.printStackTrace();
/* 43:   */         }
/* 44:   */         catch (IllegalArgumentException ex)
/* 45:   */         {
/* 46:34 */           ex.printStackTrace();
/* 47:   */         }
/* 48:   */         catch (InvocationTargetException ex)
/* 49:   */         {
/* 50:36 */           ex.printStackTrace();
/* 51:   */         }
/* 52:   */         catch (IllegalAccessException ex)
/* 53:   */         {
/* 54:38 */           ex.printStackTrace();
/* 55:   */         }
/* 56:   */       }
/* 57:   */     }
/* 58:42 */     return null;
/* 59:   */   }
/* 60:   */   
/* 61:   */   public static boolean __writeRegistryServiceInfo(XRegistryKey xRegistryKey)
/* 62:   */   {
/* 63:46 */     boolean bResult = true;
/* 64:47 */     String regClassesList = getRegistrationClasses();
/* 65:48 */     StringTokenizer t = new StringTokenizer(regClassesList, " ");
/* 66:49 */     while (t.hasMoreTokens())
/* 67:   */     {
/* 68:50 */       String className = t.nextToken();
/* 69:51 */       if ((className != null) && (className.length() != 0)) {
/* 70:   */         try
/* 71:   */         {
/* 72:53 */           Class regClass = Class.forName(className);
/* 73:54 */           Method writeRegInfo = regClass.getDeclaredMethod("__writeRegistryServiceInfo", new Class[] { XRegistryKey.class });
/* 74:55 */           Object result = writeRegInfo.invoke(regClass, new Object[] { xRegistryKey });
/* 75:56 */           bResult &= ((Boolean)result).booleanValue();
/* 76:   */         }
/* 77:   */         catch (ClassNotFoundException ex)
/* 78:   */         {
/* 79:59 */           ex.printStackTrace();
/* 80:   */         }
/* 81:   */         catch (ClassCastException ex)
/* 82:   */         {
/* 83:61 */           ex.printStackTrace();
/* 84:   */         }
/* 85:   */         catch (SecurityException ex)
/* 86:   */         {
/* 87:63 */           ex.printStackTrace();
/* 88:   */         }
/* 89:   */         catch (NoSuchMethodException ex)
/* 90:   */         {
/* 91:65 */           ex.printStackTrace();
/* 92:   */         }
/* 93:   */         catch (IllegalArgumentException ex)
/* 94:   */         {
/* 95:67 */           ex.printStackTrace();
/* 96:   */         }
/* 97:   */         catch (InvocationTargetException ex)
/* 98:   */         {
/* 99:69 */           ex.printStackTrace();
/* :0:   */         }
/* :1:   */         catch (IllegalAccessException ex)
/* :2:   */         {
/* :3:71 */           ex.printStackTrace();
/* :4:   */         }
/* :5:   */       }
/* :6:   */     }
/* :7:75 */     return bResult;
/* :8:   */   }
/* :9:   */   
/* ;0:   */   private static String getRegistrationClasses()
/* ;1:   */   {
/* ;2:79 */     return "qhichwa.openoffice.Main";
/* ;3:   */   }
/* ;4:   */ }
