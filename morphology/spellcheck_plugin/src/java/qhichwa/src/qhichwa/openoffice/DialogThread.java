/*   1:    */ package qhichwa.openoffice;
/*   2:    */ 
/*   3:    */ import javax.swing.JOptionPane;
/*   4:    */ 
/*   5:    */ class DialogThread
/*   6:    */   extends Thread
/*   7:    */ {
/*   8:    */   private final String text;
/*   9:    */   
/*  10:    */   DialogThread(String text)
/*  11:    */   {
/*  12:287 */     this.text = text;
/*  13:    */   }
/*  14:    */   
/*  15:    */   public void run()
/*  16:    */   {
/*  17:292 */     JOptionPane.showMessageDialog(null, this.text);
/*  18:    */   }
/*  19:    */ }
