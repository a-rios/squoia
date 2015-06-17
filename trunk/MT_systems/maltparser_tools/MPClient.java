import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.Socket;

public class MPClient {
  public static void main(String[] args) throws Exception {
	if (args.length != 4) {
		System.err.println("Usage: java MPClient <hostName> <portNumber> <unparsedConllFile> <parsedConllFile>");
		System.exit(1);
	}
	// declaration and initialization
    String hostName = args[0];
    int portNumber = Integer.parseInt(args[1]);
	System.out.println("Reading data from file");
	File unparsedFile = new File(args[2]);
	File parsedFile = new File(args[3]);
	byte[] unparsedbytearray = new byte[(int) unparsedFile.length()];
	System.out.println(unparsedFile.length() + " bytes of data read");
	BufferedInputStream unparsedbis = new BufferedInputStream(new FileInputStream(unparsedFile));
	unparsedbis.read(unparsedbytearray, 0, unparsedbytearray.length);
	System.out.println("Connecting to server...");
	Socket sock = new Socket(hostName, portNumber);
	System.out.println("Sending data to server...");
	OutputStream os = sock.getOutputStream();
	os.write(unparsedbytearray, 0, unparsedbytearray.length);
	//os.flush();
	System.out.println("Data sent ");

    byte[] mybytearray = new byte[1024];
    InputStream is = sock.getInputStream();
    BufferedInputStream bis = new BufferedInputStream(is);
    //wait for server to send the parsed file
    System.out.println("Waiting for server to send data...");
    int attempts = 0;
    while(bis.available() == 0 && attempts < 1000)
    {
            attempts++;
            Thread.sleep(10);
    }
    FileOutputStream fos = new FileOutputStream(parsedFile);
    BufferedOutputStream bos = new BufferedOutputStream(fos);
    System.out.println("Reading data from server...");
	int totalBytes = 0;
	while(true){
		int bytesRead = bis.read(mybytearray, 0, mybytearray.length);
		if(bytesRead == -1){
			bos.flush();
			break;
		}
		System.out.println(bytesRead + " bytes of data read");
		System.out.println("and writing it to file");
		bos.write(mybytearray, 0, bytesRead);
		totalBytes += bytesRead;
	}
	System.out.println("Total bytes " + totalBytes);
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
