package com.spm;

public class SPMException extends Exception {
    public SPMException(String message) {
        super(message);
    }
    
    public SPMException(String message, Throwable cause) {
        super(message, cause);
    }
}