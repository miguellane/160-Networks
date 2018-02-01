#define AM_FLOODING 10

generic configuration FloodingC(int channel){
    provides interface SimpleSend as FloodSend;
    provides interface Receive as FloodReceive;
}

implementation{
//External
    components FloodingP;
    FloodSend = FloodingP.externalSender;
    FloodReceive = FloodingP.externalReceiver;
//Internal
    components new SimpleSendC(channel);
    FloodingP.internalSender -> SimpleSendC;

    components new AMReceiverC(channel);
	FloodingP.internalReceiver -> AMReceiverC;

    //Data
    components new HashmapC(uint16_t, 32) as sentHashC;
    FloodingP.sentHash -> sentHashC;
}
