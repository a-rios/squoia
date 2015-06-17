import java.net.*;
import java.io.*;

import org.maltparser.concurrent.ConcurrentMaltParserModel;
import org.maltparser.concurrent.ConcurrentMaltParserService;
import org.maltparser.concurrent.ConcurrentUtils;
import org.maltparser.concurrent.graph.ConcurrentDependencyGraph;

// compile: javac -cp ../parser/maltparser-1.8/maltparser-1.8.jar MaltParserServer.java 
// auf kitt (default z.z. javac 1-9, nicht kompatibel): /usr/lib/jvm/java-7-openjdk-amd64/bin/javac -cp ../../parser/maltparser-1.8/maltparser-1.8.jar MaltParserServer.java
// aufruf: java -cp ../parser/maltparser-1.8/maltparser-1.8.jar:. MaltParserServer 9123  /mnt/storage/hex/projects/clsquoia/arios_squoia/MT_systems/model_large_training.mco
public class MaltParserServer {
  private static ConcurrentMaltParserModel model;
  private static URL modelFile;

  private static void loadModel(URL modelFile) {
	// load parser model
	try {
		model = ConcurrentMaltParserService.initializeParserModel(modelFile);
	} catch (Exception e) {
		System.err.println("Cannot load the parser model "+ modelFile.toString());
		e.printStackTrace();
		System.exit(1);
	}
  }

  private static void parseSentences(InputStream is, OutputStream os) {

    BufferedReader reader = null;
	BufferedWriter writer = null;
    try {
		int sentenceCount = 0;
		reader = new BufferedReader(new InputStreamReader(is, "UTF-8"));
		writer = new BufferedWriter(new OutputStreamWriter(os,"UTF-8"));
		while (true) {
			// Reads a sentence from the input file
			String[] inputTokens = ConcurrentUtils.readSentence(reader);
			System.out.println(inputTokens.length + " tokens to parse");
			// If there are no tokens then we have reach the end of file
			if (inputTokens.length == 0) {
				System.out.println("EOF reached");
				break;
			}
			// Parse the sentence
			String[] parsedTokens = model.parseTokens(inputTokens);
			System.out.println(parsedTokens.length + " tokens parsed");
			ConcurrentUtils.printTokens(parsedTokens);
			ConcurrentUtils.writeSentence(parsedTokens, writer);
//	    	for (int i = 0; i < parsedTokens.length; i++) {
//	    		writer.write(parsedTokens[i]);
//	    		writer.newLine();
//	    	}
//	    	writer.newLine();
//	    	writer.flush();
			sentenceCount++;
		}
		System.out.println("Parsed " + sentenceCount +" sentences");
    } catch (Exception e) {
	e.printStackTrace();
	//System.exit(1);
    } finally {
	if (reader != null) {
		try {
			reader.close();
		} catch (IOException e) {
			e.printStackTrace();
		}
	}
	if (writer != null) {
		try {
			writer.close();
		} catch (IOException e) {
			e.printStackTrace();
		}
	}
    }
  } // end of parseSentences(is,os)

    public static void main(String[] args) throws IOException {
        
	if (args.length != 2) {
		System.err.println("Usage: java MaltParserServer <portNumber> <modelFile>");
		System.exit(1);
	}
	// declaration and initialization
	int portNumber = Integer.parseInt(args[0]);
	URL modelFile = new File(args[1]).toURI().toURL();
	ServerSocket serverSocket = null;

	// load parser model
	loadModel(modelFile);

	// Start the server
	System.out.println("Starting MaltParser server...");
	// try to open a server socket
	try { 
		serverSocket = new ServerSocket(portNumber);
		while (true) {
			System.out.println("Waiting for a client...");
			Socket sock = serverSocket.accept();
			System.out.println("Connection accepted");
			System.out.println("Reading data from client...");
			InputStream is = sock.getInputStream();
			OutputStream os = sock.getOutputStream();
			System.out.println("Parsing and sending it back to client...");
			parseSentences(is, os);
			System.out.println("Data sent");
			sock.close();
		}
	}
	catch (IOException e) {
		System.out.println(e);
	}
  }
}
