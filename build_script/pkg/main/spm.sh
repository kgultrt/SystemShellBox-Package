build_spm() {
    cd ${BUILD_PROG_WORKING_DIR}/spm
    
    rm -rfv build
    mkdir -p build
    cd build
    javac ../*.java
    mv ../*.class .

    $ANDROID_HOME/build-tools/35.0.0/d8 *.class
    
    mkdir $OUTPUT_LIB_DIR/spm
    
    mv classes.dex $OUTPUT_LIB_DIR/spm
    
    cp ../spm $OUTPUT_LIB_DIR/../bin/spm
    
    echo "Suc!"
    SPM_HAS_BUILDED=true
}