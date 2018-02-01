// Module
#include "../../includes/am_types.h"
#include "../../includes/channels.h"
#include "../../includes/packet.h"
//#define BEACON_PERIOD 1000
#define BEACON_PERIOD 5001 + 73 * TOS_NODE_ID
#define RESTART_PERIOD 16

module NeighborDiscoveryP{
   provides interface NeighborDiscovery;

   uses interface SimpleSend as Sender;
   uses interface Receive as Receiver;
   uses interface Timer<TMilli> as beaconTimer;
 
   uses interface Hashmap<uint16_t> as neighborHash;
}
implementation{
   pack sendPackage;
   bool changed = FALSE;
   uint32_t age = 0;
   void sendPack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);
  
   command void NeighborDiscovery.start(){
      call beaconTimer.startPeriodic(BEACON_PERIOD);
   }

   command void NeighborDiscovery.print(){
      int i;
      uint32_t* neighbor = call neighborHash.getKeys();
      dbg(NEIGHBOR_CHANNEL, "NODE %u's NEIGHBORS:\n", TOS_NODE_ID);
      for(i = 0; i < call neighborHash.size(); i++){
         dbg(NEIGHBOR_CHANNEL, "\t NODE %u\n", neighbor[i]);
      }
   }

   command bool NeighborDiscovery.changed(){
      bool val = changed;
      changed = FALSE;
      return val;
   }
   
   command void NeighborDiscovery.get(uint8_t arr[]){
      int i;
      //uint8_t* arr[PACKET_MAX_PAYLOAD_SIZE];
      uint32_t* neighbor = call neighborHash.getKeys();

      for(i = 0; i < PACKET_MAX_PAYLOAD_SIZE; i++)
         arr[i] = 0;
      for(i = 0; i < call neighborHash.size(); i++)
         arr[neighbor[i] - 1] = call neighborHash.get(neighbor[i]);
         //dbg(GENERAL_CHANNEL, "NODE: %u : WITH NEIGHBORS\n",TOS_NODE_ID);
         //dbg(GENERAL_CHANNEL, "   1   2   3   4   5   6   7   8   9  10  11  12  13  14  15  16  17  18  19\n");
         //dbg(GENERAL_CHANNEL, "  %02u  %02u  %02u  %02u  %02u  %02u  %02u  %02u  %02u  %02u  %02u  %02u  %02u  %02u  %02u  %02u  %02u  %02u  %02u\n",arr[0],arr[1],arr[2],arr[3],arr[4],arr[5],arr[6],arr[7],arr[8],arr[9],arr[10],arr[11],arr[12],arr[13],arr[14],arr[15],arr[16],arr[17],arr[18],arr[19]);
      return;
   }   

   event void beaconTimer.fired(){
      uint32_t i;
      uint32_t* neighbor = call neighborHash.getKeys();
      age++;
      if(age >= RESTART_PERIOD)
         for(i = 0; i < call neighborHash.size(); i++){
            call neighborHash.remove(neighbor[i]);
            //changed = TRUE;
         }
      sendPack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, 1, 0, 0, "", PACKET_MAX_PAYLOAD_SIZE);
   }

   event message_t* Receiver.receive(message_t* msg, void* payload, uint8_t len){
      pack* myMsg = (pack*) payload;
      //If sent Disc, reply. If received Disc, save.
      if(myMsg->protocol == 0){
         sendPack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, 1, 1, 0, "", PACKET_MAX_PAYLOAD_SIZE);
      }else if(myMsg->protocol == 1){
         if(!call neighborHash.contains(myMsg->src)){
            call neighborHash.insert((uint32_t)(myMsg->src), (uint8_t)(1));
            changed = TRUE;
         }
      }
      return msg;
   }
   void sendPack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);

      call Sender.send(sendPackage, Package->dest);
   }

}