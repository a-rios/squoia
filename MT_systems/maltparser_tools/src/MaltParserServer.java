import java.net.*;
import java.io.*;
import java.util.ArrayList;

import org.maltparser.concurrent.ConcurrentMaltParserModel;
import org.maltparser.concurrent.ConcurrentMaltParserService;
import org.maltparser.concurrent.ConcurrentUtils;
import org.maltparser.concurrent.graph.ConcurrentDependencyGraph;
import org.maltparser.core.options.OptionManager;


// compile: javac -cp /mnt/storage/hex/projects/clsquoia/parser/maltparser-1.8/maltparser-1.8.jar MaltParserServer.java 
// auf kitt (default z.z. javac 1-9, nicht kompatibel): /usr/lib/jvm/java-7-openjdk-amd64/bin/javac -cp /mnt/storage/hex/projects/clsquoia/parser/maltparser-1.8/maltparser-1.8.jar ../src/MaltParserServer.java
// aufruf: java -cp /mnt/storage/hex/projects/clsquoia/parser/maltparser-1.8/maltparser-1.8.jar:. MaltParserServer 9123  /mnt/storage/hex/projects/clsquoia/arios_squoia/MT_systems/models/splitDatesModel.mco


public class MaltParserServer {
  private static ConcurrentMaltParserModel model;
  private static URL modelFile;
  private static boolean EOFreached = false;

  private static void loadModel(URL modelFile) {
	// load parser model
	try {
		OptionManager.instance().loadOptionDescriptionFile();
		OptionManager.instance().generateMaps();
		OptionManager.instance().parseCommandLine("-nt true", 0); //enforce output to be a tree, otherwise we can't convert this to xml
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
    
    int sentenceCount = 0;
    try {
		//int sentenceCount = 0;
		reader = new BufferedReader(new InputStreamReader(is, "UTF-8"));
		writer = new BufferedWriter(new OutputStreamWriter(os,"UTF-8"));
		while (true) {
			// Reads a sentence from the input file
			//System.err.println("TEST");
			//String[] inputTokens = ConcurrentUtils.readSentence(reader);
			String[] inputTokens = readSentence(reader);
			//System.err.println("input tokens: "+ inputTokens);
			//System.err.println(inputTokens.length + " tokens to parse");
			// If there are no tokens then we have reach the end of file
			if (inputTokens.length == 0 ) {
				//System.err.println("EOF 0 tokens reached");
				break;
			}
			else if( EOFreached ) {
				//System.err.println("EOF boolean reached");
				EOFreached = false;
				String[] parsedTokens = model.parseTokens(inputTokens);
				ConcurrentUtils.writeSentence(parsedTokens, writer);
				sentenceCount++;
				break;
			}
			// Parse the sentence
			String[] parsedTokens = model.parseTokens(inputTokens);
			//System.err.println(parsedTokens.length + " tokens parsed");
			//ConcurrentUtils.printTokens(parsedTokens);
			ConcurrentUtils.writeSentence(parsedTokens, writer);
//	    	for (int i = 0; i < parsedTokens.length; i++) {
//	    		writer.write(parsedTokens[i]);
//	    		writer.newLine();
//	    	}
//	    	writer.newLine();
//	    	writer.flush();
			sentenceCount++;
		}
		System.err.println("Parsed " + sentenceCount +" sentences");
    } catch (Exception e) {
        System.err.println("in sentence nr " + sentenceCount);
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
  
  
public static String[] readSentence(BufferedReader reader) throws IOException {
  	ArrayList<String> tokens = new ArrayList<String>();
  	String line;
  	//System.err.println("reached sub");

  	//  	line = reader.readLine();
//	System.err.println("read before while" +line + " ,length is " +line.trim().length());
//  	while(line != null && !line.equals("#EOF") ){
//  		System.err.println("read " +line + " ,length is " +line.trim().length());
//  		if (line.trim().length() == 0) {
//			System.err.println("kkk" +line);
//			break;
//		} else {
//			tokens.add(line.trim());
//			System.err.println("lll" +line);
//		}
//  		line = reader.readLine();
//  		System.err.println("next line read " +line + "length " +line.trim().length());
//  	}
  	
  	
  	
		while ((line = reader.readLine()) != null) {
		//	System.err.println("read line" +line + "length " +line.trim().length());
			if (line.trim().length() == 0  ) {
				break;
			} 
			else if(line.equals("#EOF")){
				EOFreached = true;
				break;
			}
			else {
				tokens.add(line.trim());
			}

		}
		
//		while ((line = reader.readLine()) != null ) {
//			System.err.println("read line" +line + "length " +line.trim().length());
//			if(line.equals("#EOF")){
//				EOFreached = true;
//				break;
//			}
//
//		}
		


	String [] test = tokens.toArray(new String[tokens.size()]);
//	System.err.println("length of String []: " + test.length);
  	return tokens.toArray(new String[tokens.size()]);
  }


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
	System.err.println("Starting MaltParser server...");
	// try to open a server socket
	try { 
		serverSocket = new ServerSocket(portNumber);
		while (true) {
			System.err.println("Waiting for a client...");
			Socket sock = serverSocket.accept();
			System.err.println("Connection accepted");
			System.err.println("Reading data from client...");
			InputStream is = sock.getInputStream();
			OutputStream os = sock.getOutputStream();
			System.err.println("Parsing and sending it back to client...");
			parseSentences(is, os);
			System.err.println("Data sent");
			sock.close();
		}
	}
	catch (IOException e) {
		System.err.println(e);
	}
  }
}
