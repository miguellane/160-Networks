#define AM_FLOODING 10
configuration LinkStateC{
    provides interface LinkState;
}

implementation{
//External
    components LinkStateP;
    LinkState = LinkStateP.LinkState;

//Internal
    //Custom
    components new FloodingC(AM_FLOODING);
    LinkStateP.Sender -> FloodingC.FloodSend;
    LinkStateP.Receiver -> FloodingC.FloodReceive;
}
