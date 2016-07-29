for i in `cat SHA512SUM.txt | cut -f1 -d\ `; 
  do 
    python util/testurl.py http://download.shacache.org/$i && echo OK $i || echo FAIL $i 
    sleep 10
done
