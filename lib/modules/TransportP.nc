
#include "../../includes/tcp.h"
module TransportP{
   provides interface Transport;

   uses interface Timer<TMilli> as sendTimer;
   uses interface Timer<TMilli> as timeout[uint8_t id];


   uses interface Hashmap<socket_store_t> as socketStates;
   uses interface List<resendTCP_t> as timeoutQueue;
}
implementation{
   socket_t wrSocket;
   packTCP_t packTCP;
   socket_addr_t receivedAddr;
   
   void sendTCPPack(socket_t fd, uint16_t flag){
      socket_store_t socketState = call socketStates.get(fd);
      if(socketState.effectiveWindow == 0)
         return;
      packTCP.srcPort = socketState.src.port;
      packTCP.destPort = socketState.dest.port;
      packTCP.flag = flag;
      packTCP.window = (socketState.lastRead > socketState.lastRcvd)
                        ?socketState.lastRead - socketState.lastRcvd
                        :SOCKET_BUFFER_SIZE - socketState.lastRead - socketState.lastRcvd;
      if(flag == 0){
         //Data
         int i = 0;
         int seq = socketState.lastSent + 1;
         while(i < TCP_PACKET_PAYLOAD_SIZE && seq != socketState.lastAck){
            packTCP.payload[i] = socketState.sendBuff[seq];
            i++;
            seq = (seq + 1) % SOCKET_BUFFER_SIZE;
            socketState.lastSent = (socketState.lastSent + 1) % SOCKET_BUFFER_SIZE;
         }
         if(i == 0)
            return;
         packTCP.seq = socketState.lastSent;
         packTCP.ack = 0;
      }else if(flag == 1){
         //ACK
         packTCP.seq = 0;
         packTCP.ack = socketState.lastRcvd;
      }else{
         // SYN / SYN + ACK / FIN / FIN + ACK
         socketState.lastSent += 1;
         packTCP.seq = socketState.lastSent;
         packTCP.ack = socketState.lastRcvd;
      }
      if(packTCP.flag != 1){ //If !ACK start timer
         resendTCP_t resend;
         int i;
         for(i = 0; i < TIMERSIZE; i++)
            if(!call timeout.isRunning[i]()){
               resend.timer = i;
               resend.dest = socketState.dest.addr;
               resend.msg = packTCP;
               call timeoutQueue.pushback(resend);
               call timeout.startPeriodic[resend.timer](2 * socketState.RTT);
               break;
            }
         if(i == TIMERSIZE)
            return;
      }
      signal Transport.sendTCP(socketState.dest.addr, (uint8_t *)&packTCP);
      call socketStates.insert(fd, socketState);
      return;
   }

   command socket_t Transport.socket(){
      int i;
      socket_t fd = INVALID_SOCKET;
      for(i = 1; i < MAX_NUM_OF_SOCKETS; i++)
         if(!call socketStates.contains(i)){
            fd = i;
            break;
         }
      if(fd != INVALID_SOCKET){
         socket_store_t socketState = {
            .flag = 0,
            .state = CLOSED,
            .lastWritten = 1,
            .lastAck = 0,
            .lastSent = 0,
            .lastRead = 1,
            .lastRcvd = 0,
            .nextExpected = 2,
            .RTT = 10000,
            .effectiveWindow = 1,
         };
         call socketStates.insert(fd, socketState);
      }
      wrSocket = fd;
      receivedAddr.addr = 0;
      call sendTimer.startPeriodic(20000);
      return fd;
   }

   command error_t Transport.bind(socket_t fd, socket_addr_t *addr){
      socket_store_t socketState;
      if(!call socketStates.contains(fd))
         return FAIL;
      socketState = call socketStates.get(fd);
      if(socketState.state != CLOSED)
         return FAIL;
      socketState.src = *addr;
      call socketStates.insert(fd, socketState);
      return SUCCESS;
   }

   command socket_t Transport.accept(socket_t fd){
      socket_t newfd = INVALID_SOCKET;
      int i;
      socket_store_t socketState;
      if(!call socketStates.contains(fd) || call socketStates.size() == MAX_NUM_OF_SOCKETS || receivedAddr.addr == 0)
         return newfd;
      socketState = call socketStates.get(fd);
      if(socketState.state != SYN_RCVD)
         return newfd;
      for(i = 0; i < MAX_NUM_OF_SOCKETS; i++)
         if(!call socketStates.contains(i))
            newfd = i;
      socketState.state = SYN_RCVD;
      socketState.dest = receivedAddr;
      call socketStates.insert(newfd, socketState);
      sendTCPPack(newfd, 3);
      receivedAddr.addr = 0;
      return newfd;
   }

   command uint16_t Transport.write(socket_t fd, uint8_t *buff, uint16_t bufflen){
      socket_store_t socketState;
      if(!call socketStates.contains(fd))
         return 0;
      socketState = call socketStates.get(fd);
      if(socketState.state == ESTABLISHED){
         int i = 0;
         int seq = socketState.lastWritten + 1;
         //dbg(TRANSPORT_CHANNEL, "Client write to socket: size%hu\n", bufflen);
         while(i < bufflen && seq != socketState.lastAck){
            socketState.sendBuff[seq] = buff[i];
            socketState.lastWritten = seq;
            i++;
            seq = (seq + 1) % SOCKET_BUFFER_SIZE;
         }
         call socketStates.insert(fd, socketState);
         return (socketState.lastAck > socketState.lastWritten)?socketState.lastAck - socketState.lastWritten:SOCKET_BUFFER_SIZE + socketState.lastAck - socketState.lastWritten;
      }
      return 0;
   }

   command error_t Transport.receive(socket_t fd, uint8_t* payload){
      socket_store_t socketState;
      uint8_t trigger = 255;
      packTCP = *(packTCP_t *)payload;
      if(!call socketStates.contains(fd))
         return FAIL;
      socketState = call socketStates.get(fd);
      logTCPPack(&packTCP);

      socketState.effectiveWindow = packTCP.window;
      //If ACK
      if(packTCP.flag == 1 || packTCP.flag == 3){
         int i = 0;
         int queueSize = call timeoutQueue.size();
         resendTCP_t resend;
         resendTCP_t timers[TIMERSIZE];

         while(i < queueSize){
            resend = call timeoutQueue.popfront();
            if(resend.msg.seq == packTCP.ack)
               break;
            timers[i] = resend;
            i++;
         }
         while(i > 0){
            call timeoutQueue.pushfront(timers[i - 1]);
            i--;
         }


         //RTT Adjustment 0.75
         if(queueSize != 0){
            socketState.RTT = socketState.RTT * (1 - 0.75) + (call timeout.getNow[resend.timer]() - call timeout.gett0[resend.timer]()) * (0.75);
            call timeout.stop[resend.timer]();
         }

      }


      if(packTCP.flag == 0){        //Data
         if(socketState.state == ESTABLISHED){

            //Received  [DDD|ex|____DDDD|rc|------------|rd|D]
            int i = 0;
            int seq;
            if(packTCP.seq+1 < TCP_PACKET_PAYLOAD_SIZE) //Wrapped
               seq = SOCKET_BUFFER_SIZE - (TCP_PACKET_PAYLOAD_SIZE - packTCP.seq - 1);
            else
               seq = packTCP.seq+1 - TCP_PACKET_PAYLOAD_SIZE;
            while(i < TCP_PACKET_PAYLOAD_SIZE && seq != socketState.lastRead){
               socketState.rcvdBuff[seq] = packTCP.payload[i];
               socketState.lastRcvd = seq;
               if(socketState.nextExpected == seq)
                  socketState.nextExpected = (socketState.nextExpected + 1) % SOCKET_BUFFER_SIZE;
               i++;
               seq = (seq + 1) % SOCKET_BUFFER_SIZE;
            }
            trigger = 1;
         }
      }else if(packTCP.flag == 1){  //Ack
         socketState.lastAck = packTCP.ack;
         if(socketState.state == ESTABLISHED){
            trigger = 0;
         }else if(socketState.state == SYN_RCVD){
            socketState.state = ESTABLISHED;
            trigger = 0;
         }else if(socketState.state == FIN_WAIT_1){
            socketState.state = FIN_WAIT_2;
            trigger = 0;
         }else if(socketState.state == LAST_ACK){
            socketState.state = CLOSED;
            trigger = 0;
         }
      }else if(packTCP.flag == 2){  //Syn
         socketState.lastRcvd = packTCP.seq;
         if(socketState.state == LISTEN){
            receivedAddr.addr = 4;
            receivedAddr.port = packTCP.srcPort;
            socketState.state = SYN_RCVD;
            trigger = 0;
         }else if(socketState.state == SYN_RCVD){
            receivedAddr.addr = 4;
            receivedAddr.port = packTCP.srcPort;
            socketState.state = SYN_RCVD;
            trigger = 0;
         }
      }else if(packTCP.flag == 3){  //Syn + Ack
         socketState.lastRcvd = packTCP.seq;
         socketState.lastAck = packTCP.ack;
         if(socketState.state == ESTABLISHED){
            socketState.state = ESTABLISHED;
            trigger = 1;            
         }else if(socketState.state == SYN_SENT){
            socketState.state = ESTABLISHED;
            trigger = 1;
         }
      }else if(packTCP.flag == 4){  //Fin
         socketState.lastRcvd = packTCP.seq;
         if(socketState.state == ESTABLISHED){
            socketState.state = CLOSE_WAIT;
            trigger = 1;
         }else if(socketState.state == FIN_WAIT_2){
            socketState.state = TIME_WAIT;
            call sendTimer.startOneShot(100000);
            trigger = 0;
         }
      }
      if(packTCP.seq != 0)
         logSocket(&socketState, 2);
      if(packTCP.ack != 0)
         logSocket(&socketState, 1);
      if(trigger == 0){
         call socketStates.insert(fd, socketState);
         return SUCCESS;
      }else if(trigger != 255){
         call socketStates.insert(fd, socketState);
         sendTCPPack(fd, trigger);
         return SUCCESS;
      }else{
         return FAIL;
      }

   }

   command uint16_t Transport.read(socket_t fd, uint8_t *buff, uint16_t bufflen){
      int i;
      int seq;
      socket_store_t socketState;
      if(!call socketStates.contains(fd))
         return 0;
      socketState = call socketStates.get(fd);
      if(socketState.state != ESTABLISHED)
         return 0;
      i = 0;

      seq = (socketState.lastRead + 1) % SOCKET_BUFFER_SIZE;
      while(i < bufflen && seq != (socketState.lastRcvd + 1) % SOCKET_BUFFER_SIZE){
         buff[i] = socketState.rcvdBuff[seq];
         socketState.lastRead = seq;
         i++;
         seq = (seq + 1) % SOCKET_BUFFER_SIZE;
      }
      call socketStates.insert(fd, socketState);
      return (socketState.lastRcvd > socketState.lastRead)?socketState.lastRcvd - socketState.lastRead:SOCKET_BUFFER_SIZE + socketState.lastRcvd - socketState.lastRead;
   }

   command error_t Transport.connect(socket_t fd, socket_addr_t * addr){
      socket_store_t socketState;
      if(!call socketStates.contains(fd))
         return FAIL;
      socketState = call socketStates.get(fd);
      if(socketState.state == CLOSED){
         socketState.dest = *addr;
         socketState.state = SYN_SENT;
         call socketStates.insert(fd, socketState);
         sendTCPPack(fd, 2);
         return SUCCESS;
      }
      return FAIL;
   }

   command error_t Transport.close(socket_t fd, socket_addr_t * srcAddr, socket_addr_t * destAddr){
      socket_store_t socketState;
      if(!call socketStates.contains(fd))
         return FAIL;
      socketState = call socketStates.get(fd);
      if(socketState.src.addr != srcAddr->addr || socketState.src.port != srcAddr->port || socketState.dest.addr != destAddr->addr || socketState.dest.port != destAddr->port)
         return FAIL;
      if(socketState.state == ESTABLISHED){
         socketState.state = FIN_WAIT_1;
         sendTCPPack(fd, 4);
      }else if(socketState.state == CLOSE_WAIT){
         socketState.state = LAST_ACK;
         sendTCPPack(fd,1);
      }
      call socketStates.insert(fd, socketState);
      return SUCCESS;
   }

   command error_t Transport.release(socket_t fd){
      //No Hard Release
      //
   }

   command error_t Transport.listen(socket_t fd){
      socket_store_t socketState;
      if(!call socketStates.contains(fd))
         return FAIL;
      socketState = call socketStates.get(fd);
      if(socketState.state == CLOSED){
         socketState.state = LISTEN;
         call socketStates.insert(fd, socketState);
         return SUCCESS;
      }
      return FAIL;
   }

   event void sendTimer.fired(){
      socket_store_t socketState;
      if(!call socketStates.contains(wrSocket))
         return;
      socketState = call socketStates.get(wrSocket);
      if(socketState.state == ESTABLISHED)
         sendTCPPack(wrSocket, 0);
      else if(socketState.state == TIME_WAIT){
         socketState.state = CLOSED;
         call socketStates.insert(wrSocket, socketState);
      }
      return;
   }
   default command void timeout.startPeriodic[uint8_t id](uint32_t interval){
      dbg(TRANSPORT_CHANNEL, "Start buffer is larger than timer buffer: %hhu\n", id);
      //
   }
   default command bool timeout.isRunning[uint8_t id](){
      dbg(TRANSPORT_CHANNEL, "Running buffer is larger than timer buffer: %hhu\n", id);
      //
   }
   default command uint32_t timeout.gett0[uint8_t id](){
      dbg(TRANSPORT_CHANNEL, "GetT0 buffer is larger than timer buffer: %hhu\n", id);
      //
   } 
   default command uint32_t timeout.getNow[uint8_t id](){
      dbg(TRANSPORT_CHANNEL, "GetNow buffer is larger than timer buffer: %hhu\n", id);
      //
   } 
   default command void timeout.stop[uint8_t id](){
      dbg(TRANSPORT_CHANNEL, "Stop buffer is larger than timer buffer: %hhu\n", id);
      // 
   }
   event void timeout.fired[uint8_t id](){
      int i = 0;
      int queueSize = call timeoutQueue.size();
      resendTCP_t resend;
      resendTCP_t timers[TIMERSIZE];

      while(i < queueSize){
         resend = call timeoutQueue.popfront();
         if(resend.timer == id)
            break;
         timers[i] = resend;
         i++;
      }
      dbg(TRANSPORT_CHANNEL, "Message Timed Out: Seq %hhu\n", resend.msg.seq);
      signal Transport.sendTCP(resend.dest, (uint8_t *)&resend.msg);
      call timeoutQueue.pushfront(resend);
      while(i > 0){
         call timeoutQueue.pushfront(timers[i - 1]);
         i--;
      }
   }
}
