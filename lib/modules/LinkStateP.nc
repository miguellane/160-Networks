// Module
#include "../../includes/am_types.h"
#include "../../includes/channels.h"
#include "../../includes/packet.h"

module LinkStateP{
   provides interface LinkState;

   uses interface SimpleSend as Sender;
   uses interface Receive as Receiver;
}

implementation{
   pack sendPackage;
   uint32_t sequence = 1;
   uint8_t neighbor2D[PACKET_MAX_PAYLOAD_SIZE][PACKET_MAX_PAYLOAD_SIZE];
   uint8_t routeTable[PACKET_MAX_PAYLOAD_SIZE];
   //Prototype
   void sendPack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);
   void dijkstras();

   command void LinkState.start(){
      int i, j;
      for(i = 0; i < PACKET_MAX_PAYLOAD_SIZE; i++)
         for(j = 0; j < PACKET_MAX_PAYLOAD_SIZE; j++)
            neighbor2D[i][j] = 0;
      for(i = 0; i < PACKET_MAX_PAYLOAD_SIZE; i++)
         routeTable[i] = 0;
   }

   command void LinkState.print(){
      int i, j;
      //Neighbors Listing
      for(i = 0; i < PACKET_MAX_PAYLOAD_SIZE; i++){
         dbg(ROUTING_CHANNEL, "V NODE %d NEIGHBORS V\n", i + 1);
      for(j = 0; j < PACKET_MAX_PAYLOAD_SIZE; j++){
         if(neighbor2D[i][j] != 0)
            dbg(ROUTING_CHANNEL, "%d\n", j + 1);
      }  }
      //Routing Table
      for(i = 0; i < PACKET_MAX_PAYLOAD_SIZE; i++){
         if(routeTable[i] != 0)
         dbg(ROUTING_CHANNEL, "TO NODE %i: USE NODE %u\n",i + 1, routeTable[i]);
      }
   }

   command void LinkState.update(uint8_t neighbor[]){
      int i;
      routeTable[TOS_NODE_ID - 1] = TOS_NODE_ID;
      for(i = 0; i < PACKET_MAX_PAYLOAD_SIZE; i++){
         neighbor2D[TOS_NODE_ID - 1][i] = neighbor[i];
         if(neighbor[i] != 0)
            routeTable[i] = i + 1;
      }
      sendPack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, MAX_TTL, 2, sequence++, neighbor, PACKET_MAX_PAYLOAD_SIZE);
      dijkstras();
   }

   command uint16_t LinkState.route(uint16_t dest){
      return (uint16_t)routeTable[dest - 1];
   }   

   event message_t* Receiver.receive(message_t* msg, void* payload, uint8_t len){
      pack* myMsg = (pack*) payload;
      if(myMsg->dest == AM_BROADCAST_ADDR){
         if(myMsg->protocol == 2){
            int i;
            for(i = 0; i < PACKET_MAX_PAYLOAD_SIZE; i++)
               neighbor2D[myMsg->src - 1][i] = myMsg->payload[i];
               dijkstras();
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

   void dijkstras(){
         int i, j;
         uint8_t minV, minI;
         uint8_t distance[PACKET_MAX_PAYLOAD_SIZE];
         bool explored[PACKET_MAX_PAYLOAD_SIZE];
         for (i = 0; i < PACKET_MAX_PAYLOAD_SIZE; i++){
             distance[i] = 255;
             explored[i] = FALSE;
         }
         distance[TOS_NODE_ID - 1] = 0;
         for (i = 0; i < PACKET_MAX_PAYLOAD_SIZE - 1; i++){
            minV = 255;
            for(j = 0; j < PACKET_MAX_PAYLOAD_SIZE; j++)
               if (distance[j] <= minV && !explored[j]){
                  minV = distance[j];
                  minI = j;
               }
            explored[minI] = TRUE;
            for (j = 0; j < PACKET_MAX_PAYLOAD_SIZE; j++)
               if (distance[minI] + neighbor2D[minI][j] < distance[j] && !explored[j] && neighbor2D[minI][j] != 0 && distance[minI] != 255){
                  distance[j] = distance[minI] + neighbor2D[minI][j];
                  if(routeTable[minI] != TOS_NODE_ID)
                     routeTable[j] = routeTable[minI];
               }
         }


   }
}