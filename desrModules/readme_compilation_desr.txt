# readme compilation
export $FREELING= path-to-your-freeling-installation
export $FREELING_SRC= path-to-your-freeling-sources ( trunk from svn)
export DESRHOME=/home/clsquoia/parser/desr-1.3.2/

# compile parser client: desr_client
g++ -c -o desr_client.o desr_client.cc -I$FREELING/include/

# link parser client:
#/bin/bash $FREELING_SRC/libtool --tag=CXX --mode=link g++ -O3 -Wall -o desr_client desr_client.o
g++ -O3 -Wall -o desr_client desr_client.o

# compile parser server:
#g++ -c -o desr_server.o desr_server.cc -I/opt/matxin/local/include/ -I/home/clsquoia/parser/desr-1.3.2/src/ -I/usr/include/python2.7/ -I/home/clsquoia/parser/desr-1.3.2/ -I/home/clsquoia/parser/desr-1.3.2/ixe/ -I/home/clsquoia/parser/desr-1.3.2/classifier/
g++ -c -o desr_server.o desr_server.cc -std=gnu++0x -I$FREELING/include/ -I$DESRHOME/src/ -I/usr/include/python2.7/ -I$DESRHOME -I$DESRHOME/ixe/ -I$DESRHOME/classifier/

# link parser server:
#/bin/bash /opt/matxin/freeling-3.0-trunk/libtool --tag=CXX --mode=link g++ -O3 -Wall -o desr_server desr_server.o /home/clsquoia/parser/desr-1.3.2/src/libdesr.so /home/clsquoia/parser/desr-1.3.2/ixe/libixe.a 
#/bin/bash $FREELING_SRC/libtool --tag=CXX --mode=link g++ -O3 -Wall -o desr_server desr_server.o $DESRHOME/src/libdesr.so $DESRHOME/ixe/libixe.a 
g++ -O3 -Wall -o desr_server desr_server.o $DESRHOME/src/libdesr.so  $DESRHOME/ixe/libixe.a


# start the server:
./desr_server -m $DESRHOME/spanish_es4.MLP --port 5678 2> logdesr_es4 &

# test the client:
echo "la madre se va. El padre se queda. El hijo duerme." | analyzer_client 8866 | ./desr_client 5678

