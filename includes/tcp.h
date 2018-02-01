#ifndef PACKET_TCP_H
#define PACKET_TCP_H

enum{
	INVALID_SOCKET = 0,

    MAX_NUM_OF_SOCKETS = 10,
    ROOT_SOCKET_ADDR = 255,
    ROOT_SOCKET_PORT = 255,
    SOCKET_BUFFER_SIZE = 128,

    TCP_PACKET_HEADER_LENGTH = 16,
    TCP_PACKET_PAYLOAD_SIZE = 20 - TCP_PACKET_HEADER_LENGTH,
};
//********************
// Socket Interface
//********************
typedef uint8_t socket_t;

enum socket_state{
    CLOSED,
    LISTEN,
    ESTABLISHED,
    SYN_SENT,
    SYN_RCVD,
    FIN_WAIT_1,
    FIN_WAIT_2,
    CLOSING,
    TIME_WAIT,
    CLOSE_WAIT,
    LAST_ACK,
};
typedef nx_struct socket_addr_t{
    nx_uint16_t port;
    nx_uint16_t addr;
}socket_addr_t;

typedef struct socket_store_t{
    uint8_t flag;
    enum socket_state state;
    socket_addr_t src;
    socket_addr_t dest;

    uint8_t sendBuff[SOCKET_BUFFER_SIZE];
    uint8_t lastAck;
    uint8_t lastSent;
    uint8_t lastWritten;

    uint8_t rcvdBuff[SOCKET_BUFFER_SIZE];
    uint8_t lastRead;
    uint8_t nextExpected;
    uint8_t lastRcvd;

    uint16_t RTT;
    uint8_t effectiveWindow;
}socket_store_t;

void logSocket(socket_store_t *input, uint8_t type){
	if(type == 0)
        dbg(TRANSPORT_CHANNEL, "Flag: %hhu State: %hhu Src: %hhu - %hhu Dest: %hhu - %hu RTT: %hhu Window: %hhu \n",
	       input->flag, input->state, input->src.port, input->src.addr, input->dest.port, input->dest.addr, input->RTT, input->effectiveWindow);
	if(type == 1)
		dbg(TRANSPORT_CHANNEL, "Last Written: %hhu Last Acknowledged: %hhu Last Sent: %hhu \n\n",
		input->lastWritten, input->lastAck, input->lastSent);
	if(type == 2)
		dbg(TRANSPORT_CHANNEL, "Last Read: %hhu Last Received: %hhu Next Expected: %hhu \n\n",
		input->lastRead, input->lastRcvd, input->nextExpected);
}
//********************
// TCP Packet
//********************
typedef nx_struct packTCP_t{
	nx_uint16_t srcPort;
	nx_uint16_t destPort;
	
	nx_uint32_t seq;
	nx_uint32_t ack;
	//nx_uint4_t headerLen;
	//nx_uint6_t zero;
	//nx_uint6_t flag;
	nx_uint16_t flag;
	nx_uint16_t window;
	//nx_uint16_t checksum;
	//nx_uint16_t urgentPointer;

	//nx_uint8_t options[(headerLen - 5) * 4];

	nx_uint8_t payload[TCP_PACKET_PAYLOAD_SIZE];
}packTCP_t;

void logTCPPack(packTCP_t *input){
	dbg(TRANSPORT_CHANNEL, "Src: %hu Dest: %hu Seq: %u Ack: %u Flag: %hu Window: %hu Payload: [%c][%c][%c][%c]\n",
	input->srcPort, input->destPort, input->seq, input->ack, input->flag, input->window, input->payload[0], input->payload[1], input->payload[2], input->payload[3]);
}
//********************
// TCP Resend Data
//********************
typedef nx_struct resendTCP_t{
    nx_uint8_t timer;
    nx_uint16_t dest;
    packTCP_t msg;
}resendTCP_t;
#endif