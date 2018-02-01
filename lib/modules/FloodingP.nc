// Module
#include "../../includes/am_types.h"
#include "../../includes/channels.h"

module FloodingP{
   //provides interface Flooding;
   provides interface SimpleSend as externalSender;
   provides interface Receive as externalReceiver;

   uses interface SimpleSend as internalSender;
   uses interface Receive as internalReceiver;

   uses interface Hashmap<uint16_t> as sentHash;
}
implementation{

   command error_t externalSender.send(pack msg, uint16_t dest){
      call internalSender.send(msg, AM_BROADCAST_ADDR);
      dbg(FLOODING_CHANNEL, "PACKAGE FLOODED\n");
   }

   event message_t* internalReceiver.receive(message_t* msg, void* payload, uint8_t len){
      pack* myMsg = (pack*) payload;
      //If Invalid Packet
      if(len!=sizeof(pack)){
         dbg(FLOODING_CHANNEL, "UNNKNOWN PACKET TYPE %d\n", len);
         return msg;
      }
      //If Timeout
      if(myMsg->TTL == 0){
         return msg;
      }
      myMsg->TTL--;
      //If Seen
      if(call sentHash.contains(myMsg->seq)){
         uint16_t src = call sentHash.get(myMsg->seq);
         if(src == myMsg->src){
            dbg(FLOODING_CHANNEL, "REPEAT\n");
            return msg;
         }
      }
      call sentHash.insert(myMsg->seq, myMsg->src);
      dbg(FLOODING_CHANNEL, "PACKET RECIEVED %u\n",myMsg->src);

      //Receive or Flood (If TTL isn't 0)
      if(myMsg->dest == TOS_NODE_ID || myMsg->dest == AM_BROADCAST_ADDR)
         signal externalReceiver.receive(msg, payload, len);
      if(myMsg->dest != TOS_NODE_ID && myMsg->TTL != 0)
         call externalSender.send(*myMsg, AM_BROADCAST_ADDR);

      return msg;
   }
}
