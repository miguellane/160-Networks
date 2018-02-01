/**
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */

#include <Timer.h>
#include "includes/CommandMsg.h"
#include "includes/packet.h"

configuration NodeC{
}
implementation {
//External
    components MainC;
    components Node;
    Node -> MainC.Boot;

//Internal
    components new SimpleSendC(AM_PACK);
    Node.Sender -> SimpleSendC; 

    components new AMReceiverC(AM_PACK);
    Node.Receive -> AMReceiverC;

    components ActiveMessageC;
    Node.AMControl -> ActiveMessageC;
    
    components CommandHandlerC;
    Node.CommandHandler -> CommandHandlerC;

    components new TimerMilliC() as beaconTimer;
    Node.beaconTimer -> beaconTimer;
    components new TimerMilliC() as clientTimer;
    Node.clientTimer -> clientTimer;
    components new TimerMilliC() as serverTimer;
    Node.serverTimer -> serverTimer;


    components new HashmapC(uint8_t*, MAX_NUM_OF_SOCKETS) as userHashC;
    Node.userClients -> userHashC;
    //Custom
    //components FloodingC;
    //Node.Sender -> FloodingC.FloodSend;
    //Node.Receive -> FloodingC.FloodReceive;

    components NeighborDiscoveryC;
    Node.Discover -> NeighborDiscoveryC;

    components LinkStateC;
    Node.LinkState -> LinkStateC;

    components TransportC;
    Node.Transport -> TransportC;
}
