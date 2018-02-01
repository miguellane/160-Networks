#define AM_NEIGHBOR 62
configuration NeighborDiscoveryC{
    provides interface NeighborDiscovery;
}

implementation{
//External
    components NeighborDiscoveryP;
    NeighborDiscovery = NeighborDiscoveryP.NeighborDiscovery;

//Internal
    //components new SimpleSendC(AM_NEIGHBOR);
    //NeighborDiscoveryP.Sender -> SimpleSendC;

    //components new AMReceiverC(AM_NEIGHBOR);
    //NeighborDiscoveryP.Receiver -> AMReceiverC;

    components new TimerMilliC() as beaconTimer;
    NeighborDiscoveryP.beaconTimer -> beaconTimer;
    
    //Custom
    components new FloodingC(AM_NEIGHBOR);
    NeighborDiscoveryP.Sender -> FloodingC.FloodSend;
    NeighborDiscoveryP.Receiver -> FloodingC.FloodReceive;

    //Data
    components new HashmapC(uint16_t, 20) as myNeighborHashC;
    NeighborDiscoveryP.neighborHash -> myNeighborHashC;
}
