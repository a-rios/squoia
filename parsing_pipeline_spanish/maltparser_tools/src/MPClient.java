import java.io.*;
import java.net.*;

public class MPClient {
  public static void main(String[] args) throws Exception {
	if (args.length != 2) {
		System.err.println("Usage: java MPClient <hostName> <portNumber>");
		System.exit(1);
	}
	// declaration and initialization
    String hostName = args[0];
    int portNumber = Integer.parseInt(args[1]);
	//System.err.println("Reading data from file");
	//File unparsedFile = new File(args[2]);
	//byte[] unparsedbytearray = new byte[(int) unparsedFile.length()];
	
	//BufferedInputStream out = new BufferedInputStream(System.in);
	//System.err.println(unparsedFile.length() + " bytes of data read");
	//BufferedInputStream unparsedbis = new BufferedInputStream(new FileInputStream(unparsedFile));
	//unparsedbis.read(unparsedbytearray, 0, unparsedbytearray.length);
	System.err.println("Connecting to server...");
	Socket sock = new Socket(hostName, portNumber);
	System.err.println("Connection established");
	
    BufferedInputStream unparsedbis = new BufferedInputStream(System.in);
    BufferedReader reader = new BufferedReader(new InputStreamReader(unparsedbis, "UTF-8"));
    BufferedOutputStream bos = new BufferedOutputStream(sock.getOutputStream());
    BufferedWriter writer = new BufferedWriter(new OutputStreamWriter(bos, "UTF-8"));

    try{
    	String inline;
    	while( (inline = reader.readLine()) != null){
    	   // System.err.println("read line: " +inline);
    		writer.write(inline+"\n");
    	}
    }
    catch(Exception e){
    	e.printStackTrace();
    }
    finally{
    	writer.write("\n#EOF\n");
    	writer.flush();
    }
    
//	System.err.println("Sending data to server...");
//	OutputStream os = sock.getOutputStream();
//	os.write(unparsedbytearray, 0, unparsedbytearray.length);
//	os.write("\n#EOF\n".getBytes());
//	os.flush();
	
 
    
//	bos.writeLine(line);
	

//	System.err.println("Data sent ");

    byte[] mybytearray = new byte[1024];
    InputStream is = sock.getInputStream();
    BufferedInputStream bis = new BufferedInputStream(is);
    //wait for server to send the parsed file
  //  System.err.println("Waiting for server to send data...");
    int attempts = 0;
    while(bis.available() == 0 && attempts < 1000)
    {
            attempts++;
            Thread.sleep(10);
    }
  //  FileOutputStream fos = new FileOutputStream(parsedFile);
    BufferedOutputStream out = new BufferedOutputStream(System.out);
   // BufferedWriter out = new BufferedWriter(new OutputStreamWriter(System.out));
//    System.err.println("Reading data from server...");
	int totalBytes = 0;
	while(true){
		int bytesRead = bis.read(mybytearray, 0, mybytearray.length);
		if(bytesRead == -1){
			out.flush();
			break;
		}
		//System.err.println(bytesRead + " bytes of data read");
	//	System.err.println("and writing it to stdout");
		out.write(mybytearray, 0, bytesRead);
		totalBytes += bytesRead;
	}
	//System.err.println("Total bytes " + totalBytes);
	sock.close();
//	try{
//		while(true){
//			int bytesRead = bis.read(mybytearray, 0, mybytearray.length);
//			System.out.println(bytesRead + " bytes of data read");
//			System.out.println("and writing it to file");
//			bos.write(mybytearray, 0, bytesRead);
//			totalBytes += bytesRead;
//		}
//	}
//	catch(Exception e){
//		//System.out.println("Total bytes " + totalBytes);
//		//e.printStackTrace();
//		//System.exit(1);
//	}
//	finally{
//		System.out.println("Total bytes " + totalBytes);
//		is.close();
//		bis.close();
//	    bos.close();
//		os.close();
//	    sock.close();
//	}
  }
}
