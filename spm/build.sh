rm -rfv build
mkdir -p build
cd build
javac ../*.java
mv ../*.class .

~/android-sdk/build*/35.0.0/d8 *.class