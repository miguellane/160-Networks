#define TIMERSIZE 7
configuration TransportC{
    provides interface Transport;
}

implementation{
//External
    components TransportP;
    Transport = TransportP.Transport;
//Internal
    components new TimerMilliC() as sendTimer;
    TransportP.sendTimer -> sendTimer;

    
    components new TimerMilliC() as timeout0;
    TransportP.timeout[0] -> timeout0;
    components new TimerMilliC() as timeout1;
    TransportP.timeout[1] -> timeout1;    
    components new TimerMilliC() as timeout2;
    TransportP.timeout[2] -> timeout2;
    components new TimerMilliC() as timeout3;
    TransportP.timeout[3] -> timeout3;
    components new TimerMilliC() as timeout4;
    TransportP.timeout[4] -> timeout4;
    components new TimerMilliC() as timeout5;
    TransportP.timeout[5] -> timeout5;
    components new TimerMilliC() as timeout6;
    TransportP.timeout[6] -> timeout6;
    components new TimerMilliC() as timeout7;
    TransportP.timeout[7] -> timeout7;
    components new TimerMilliC() as timeout8;
    TransportP.timeout[8] -> timeout8;
    components new TimerMilliC() as timeout9;
    TransportP.timeout[9] -> timeout9;
    components new TimerMilliC() as timeout10;
    TransportP.timeout[10] -> timeout10;
    components new TimerMilliC() as timeout11;
    TransportP.timeout[11] -> timeout11;
    components new TimerMilliC() as timeout12;
    TransportP.timeout[12] -> timeout12;
    components new TimerMilliC() as timeout13;
    TransportP.timeout[13] -> timeout13;
    components new TimerMilliC() as timeout14;
    TransportP.timeout[14] -> timeout14;
    components new TimerMilliC() as timeout15;
    TransportP.timeout[15] -> timeout15;
    components new TimerMilliC() as timeout16;
    TransportP.timeout[16] -> timeout16;
    components new TimerMilliC() as timeout17;
    TransportP.timeout[17] -> timeout17;
    components new TimerMilliC() as timeout18;
    TransportP.timeout[18] -> timeout18; 
    components new TimerMilliC() as timeout19;
    TransportP.timeout[19] -> timeout19;
    
    
    
    
    
    //Data
    components new HashmapC(socket_store_t, MAX_NUM_OF_SOCKETS) as socketHashC;
    TransportP.socketStates -> socketHashC;

    components new ListC(resendTCP_t, TIMERSIZE) as timeoutQueue;
    TransportP.timeoutQueue -> timeoutQueue;
}
