/*
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */
#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"
#include "includes/tcp.h"

module Node{
   uses interface Boot;

   uses interface SimpleSend as Sender;
   uses interface Receive;
   uses interface SplitControl as AMControl;
   uses interface CommandHandler;

   uses interface NeighborDiscovery as Discover;
   uses interface LinkState;
   uses interface Transport;

   uses interface Timer<TMilli> as beaconTimer;
   uses interface Timer<TMilli> as clientTimer;
   uses interface Timer<TMilli> as serverTimer;
   uses interface Hashmap<uint8_t*> as userClients;

}

implementation{
   pack sendPackage;
   uint32_t sequence = 1;

   socket_t socket[MAX_NUM_OF_SOCKETS];
   uint8_t socketIt = 0;
   uint16_t transferData;

   //uint8_t name[]
   uint8_t messageIt;
   uint8_t message[SOCKET_BUFFER_SIZE];
   // Prototypes
   void sendPack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);

   event void Boot.booted(){
      call AMControl.start();
      dbg(GENERAL_CHANNEL, "Booted\n");
   }

   event void AMControl.startDone(error_t err){
      if(err == SUCCESS){
         call Discover.start();
         call LinkState.start();
         call beaconTimer.startPeriodic(10000);
         dbg(GENERAL_CHANNEL, "Radio On\n");
      }else{
         //Retry until successful
         call AMControl.start();
      }
   }

   event void AMControl.stopDone(error_t err){}
 
   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
      pack* myMsg = (pack*) payload;
      //If Invalid Packet
      if(len!=sizeof(pack)){
         dbg(GENERAL_CHANNEL, "UNNKNOWN PACKET TYPE %d\n", len);
         return msg;
      }
      //If Timeout
      if(myMsg->TTL == 0){
         return msg;
      }
      myMsg->TTL--;

      if(myMsg->dest == TOS_NODE_ID){   

         if(myMsg->protocol == 0){
            //dbg(GENERAL_CHANNEL, "PACKAGE DELIVERED; PAYLOAD: %s\n", myMsg->payload);
            call Transport.receive(socket[socketIt], (packTCP_t *)myMsg->payload);
            //sendPack(&sendPackage, myMsg->dest, myMsg->src, MAX_TTL, 1, sequence++, myMsg->payload, len);
         }//else if(myMsg->protocol == 1){
          //  dbg(GENERAL_CHANNEL, "PACKAGE DELIVERY WAS CONFIRMED\n");

         //}
      }
      if(myMsg->dest != TOS_NODE_ID && myMsg->TTL != 0)
         sendPack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL, myMsg->protocol, myMsg->seq, (uint8_t *)myMsg->payload, len);
      return msg;
   }


   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
      dbg(GENERAL_CHANNEL, "PING EVENT \n");
      sendPack(&sendPackage, TOS_NODE_ID, destination, MAX_TTL, 0, sequence++, payload, PACKET_MAX_PAYLOAD_SIZE);
   }

   event void beaconTimer.fired(){
      if(call Discover.changed() == TRUE){
         uint8_t neighbor[PACKET_MAX_PAYLOAD_SIZE];
         call Discover.get(neighbor);
         call LinkState.update(neighbor);
      }
   }

   event void CommandHandler.printNeighbors(){
      call Discover.print();
   }

   event void CommandHandler.printRouteTable(){
      call LinkState.print();          
   }

   event void CommandHandler.printLinkState(){}

   event void CommandHandler.printDistanceVector(){}

   event void CommandHandler.setTestServer(uint16_t port){
      socket_addr_t socketAddr;
      socketAddr.addr = TOS_NODE_ID;
      socketAddr.port = port;
      socket[socketIt] = call Transport.socket();
      call Transport.bind(socket[socketIt], &socketAddr);

      call Transport.listen(socket[socketIt]);
      call serverTimer.startPeriodic(80000);
   }

   event void CommandHandler.setTestClient(uint16_t srcPort, uint16_t dest, uint16_t destPort, uint16_t transfer){
      socket_addr_t socketAddr;
      socketAddr.addr = TOS_NODE_ID;
      socketAddr.port = srcPort;
      transferData = transfer;
      socket[socketIt] = call Transport.socket();
      call Transport.bind(socket[socketIt], &socketAddr);

      socketAddr.addr = dest;
      socketAddr.port = destPort;
      call Transport.connect(socket[socketIt], &socketAddr);
      call clientTimer.startPeriodic(40000);
   }

   event void CommandHandler.closeClient(uint16_t srcPort, uint16_t dest, uint16_t destPort){
      int i;
      socket_addr_t srcAddr;
      socket_addr_t destAddr;
      srcAddr.addr = TOS_NODE_ID;
      srcAddr.port = srcPort;
      destAddr.addr = dest;
      destAddr.port = destPort;
      for(i = socketIt; i >= 0; i--){
         if(call Transport.close(socket[i], &srcAddr, &destAddr))
            break;
      }
   }

   event void Transport.sendTCP(uint16_t destination, uint8_t *payload){
      sendPack(&sendPackage, TOS_NODE_ID, destination, MAX_TTL, 0, sequence++, payload, PACKET_MAX_PAYLOAD_SIZE);  
   }

   event void CommandHandler.setAppServer(uint16_t srcPort){
      socket_addr_t socketAddr;
      socketAddr.addr = TOS_NODE_ID;
      socketAddr.port = srcPort;
      socket[socketIt] = call Transport.socket();
      call Transport.bind(socket[socketIt], &socketAddr);

      call Transport.listen(socket[socketIt]);
      call serverTimer.startPeriodic(20000);
   }

   event void serverTimer.fired(){
      /*
      socket_t newfd = call Transport.accept(socket[socketIt]);
      uint16_t bufferCap;
      uint8_t data[transferData];
      int i;
      if(newfd != INVALID_SOCKET){
         socketIt++;
         socket[socketIt] = newfd;
      }
      for(i = 1; i <= socketIt; i++){
         bufferCap = call Transport.read(socket[socketIt], data, 0);
         if(bufferCap != 0){
            call Transport.read(socket[socketIt], data, bufferCap);
            dbg(TRANSPORT_CHANNEL, "--------------------\n");
            for(i = 0; i < bufferCap; i+=4)
               dbg(TRANSPORT_CHANNEL, "Byte Received On Server: [%c][%c][%c][%c] \n", data[i],data[i+1],data[i+2],data[i+3]);
            dbg(TRANSPORT_CHANNEL, "--------------------\n\n");
         }
      }
      */
      socket_t newfd = call Transport.accept(socket[socketIt]);
      uint16_t bufferCap;
      uint8_t* username;

      int i, j, k;
      if(newfd != INVALID_SOCKET){
         socketIt++;
         socket[socketIt] = newfd;
      }
      for(i = 1; i <= socketIt; i++){
         bufferCap = call Transport.read(socket[socketIt], " ", 0);
         if(bufferCap != 0){
            uint8_t data[bufferCap];
            call Transport.read(socket[socketIt], data, bufferCap);
            for(j = 0; j < bufferCap; j++)
               message[messageIt + j] = data[j];
            messageIt += j;
            break;
         }
      }
      if(strstr(message, "\r\n") != NULL){
         dbg(APPLICATION_CHANNEL, "Message Received On Server: %s\n", message);
         if(strstr(message, "hello") != NULL){
            j = 0;
            for(i = 6; i < strlen(message - 1); i++){
               if(message[i] == ' ')
                  break;
               username[j++] = message[i];
            }
            call userClients.insert(socketIt, username);
         }else if(strstr(message, "msg") != NULL){
            for(i = 1; i <= socketIt; i++){
               dbg(APPLICATION_CHANNEL, "Send From Server %s",message);
               call Transport.write(socket[i], message, strlen(message));
            }
         }else if(strstr(message, "whisper") != NULL){
            j = 0;
            for(i = 8; i < strlen(message - 1); i++){
               if(message[i] == ' ')
                  break;
               username[j++] = message[i];
            }
            for(i = 0; i < MAX_NUM_OF_SOCKETS; i++){
               if(strcmp(call userClients.get(i), username) != 0){
                  dbg(APPLICATION_CHANNEL, "Send From Server %s",message);
                  call Transport.write(socket[i], message, strlen(message));
                  break;
               }
            }
         }else if(strstr(message, "listusr") != NULL){
            uint8_t* usernames;
            uint32_t* keys = call userClients.getKeys();
            k = 0;
            for(i = 0; i < call userClients.size(); i++){
               uint8_t* username = call userClients.get(keys[i]);
               for(j = 0; j < strlen(username); j++)
                  usernames[k++] = username[j];
               usernames[k++] = ' ';
            }

         }
         messageIt = 0;
         message[0] = '\0';
      }
   }

   event void CommandHandler.setAppClient(uint16_t srcPort, uint16_t dest, uint16_t destPort){
      socket_addr_t socketAddr;
      socketAddr.addr = TOS_NODE_ID;
      socketAddr.port = srcPort;
      socket[socketIt] = call Transport.socket();
      call Transport.bind(socket[socketIt], &socketAddr);

      socketAddr.addr = dest;
      socketAddr.port = destPort;
      call Transport.connect(socket[socketIt], &socketAddr);
      call clientTimer.startPeriodic(20000);
   }
   event void clientTimer.fired(){
      /*
      uint16_t bufferCap;
      uint8_t data[transferData];
      int i;
      bufferCap = call Transport.write(socket[socketIt], data, 0);
      for(i = 0; i < transferData && i < bufferCap; i++)
         data[i] = i;
      call Transport.write(socket[socketIt], data, i);
      */
      uint16_t bufferCap;
      int i;
      bufferCap = call Transport.read(socket[socketIt], " ", 0);
      if(bufferCap != 0){
         uint8_t data[bufferCap - 1];
         call Transport.read(socket[socketIt], data, bufferCap);
         for(i = 0; i < bufferCap; i++)
            message[messageIt + i] = data[i];
         messageIt += i;
      }
      if(strstr(message, "\r\n") != NULL){
         dbg(APPLICATION_CHANNEL, "Message Received On Client: %s\n", message);
         messageIt = 0;
         message[0] = '\0';
      }
   }

   event void CommandHandler.sendMsgClient(uint8_t *payload){
      dbg(APPLICATION_CHANNEL, "Send From Client %s",payload);
      call Transport.write(socket[socketIt], payload, strlen(payload));
   }

   void sendPack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);

      call Sender.send(sendPackage, call LinkState.route(dest));
   }

}
