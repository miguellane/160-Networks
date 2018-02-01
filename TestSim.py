#ANDES Lab - University of California, Merced
#Author: UCM ANDES Lab
#$Author: abeltran2 $
#$LastChangedDate: 2014-08-31 16:06:26 -0700 (Sun, 31 Aug 2014) $
#! /usr/bin/python
import sys
from TOSSIM import *
from CommandMsg import *

class TestSim:
    # COMMAND TYPES
    CMD_PING = 0
    CMD_NEIGHBOR_DUMP = 1
    CMD_ROUTE_DUMP=3
    CMD_TEST_CLIENT = 4
    CMD_TEST_SERVER = 5
    CMD_CLOSE_CLIENT = 6
    CMD_APP_CLIENT=10
    CMD_APP_SERVER=11
    CMD_MSG_CLIENT=12

    # CHANNELS - see includes/channels.h
    COMMAND_CHANNEL="command";
    GENERAL_CHANNEL="general";

    # Project 1
    NEIGHBOR_CHANNEL="neighbor";
    FLOODING_CHANNEL="flooding";

    # Project 2
    ROUTING_CHANNEL="routing";

    # Project 3
    TRANSPORT_CHANNEL="transport";

    # Project 4
    APPLICATION_CHANNEL="application";

    # Personal Debuggin Channels for some of the additional models implemented.
    HASHMAP_CHANNEL="hashmap";

    # Initialize Vars
    numMote=0

    def __init__(self):
        self.t = Tossim([])
        self.r = self.t.radio()

        #Create a Command Packet
        self.msg = CommandMsg()
        self.pkt = self.t.newPacket()
        self.pkt.setType(self.msg.get_amType())

    # Load a topo file and use it.
    def loadTopo(self, topoFile):
        print 'Creating Topo!'
        # Read topology file.
        topoFile = 'topo/'+topoFile
        f = open(topoFile, "r")
        self.numMote = int(f.readline());
        print 'Number of Motes', self.numMote
        for line in f:
            s = line.split()
            if s:
                print " ", s[0], " ", s[1], " ", s[2];
                self.r.add(int(s[0]), int(s[1]), float(s[2]))

    # Load a noise file and apply it.
    def loadNoise(self, noiseFile):
        if self.numMote == 0:
            print "Create a topo first"
            return;

        # Get and Create a Noise Model
        noiseFile = 'noise/'+noiseFile;
        noise = open(noiseFile, "r")
        for line in noise:
            str1 = line.strip()
            if str1:
                val = int(str1)
            for i in range(1, self.numMote+1):
                self.t.getNode(i).addNoiseTraceReading(val)

        for i in range(1, self.numMote+1):
            print "Creating noise model for ",i;
            self.t.getNode(i).createNoiseModel()

    def bootNode(self, nodeID):
        if self.numMote == 0:
            print "Create a topo first"
            return;
        self.t.getNode(nodeID).bootAtTime(1333*nodeID);

    def bootAll(self):
        i=0;
        for i in range(1, self.numMote+1):
            self.bootNode(i);

    def moteOff(self, nodeID):
        self.t.getNode(nodeID).turnOff();

    def moteOn(self, nodeID):
        self.t.getNode(nodeID).turnOn();

    def run(self, ticks):
        for i in range(ticks):
            self.t.runNextEvent()

    # Rough run time. tickPerSecond does not work.
    def runTime(self, amount):
        self.run(amount*1000)

    # Generic Command
    def sendCMD(self, ID, dest, payloadStr):
        self.msg.set_dest(dest);
        self.msg.set_id(ID);
        self.msg.setString_payload(payloadStr)

        self.pkt.setData(self.msg.data)
        self.pkt.setDestination(dest)
        self.pkt.deliver(dest, self.t.time()+5)

    def ping(self, source, dest, msg):
        self.sendCMD(self.CMD_PING, source, "{0}{1}".format(chr(dest),msg));

    def neighborDMP(self, destination):
        self.sendCMD(self.CMD_NEIGHBOR_DUMP, destination, "neighbor command");

    def routeDMP(self, destination):
        self.sendCMD(self.CMD_ROUTE_DUMP, destination, "routing command");

    def testClient(self, src, srcPort, dest, destPort, transfer):
        self.sendCMD(self.CMD_TEST_CLIENT, src, "{0}{1}{2}{3}".format(chr(srcPort),chr(dest),chr(destPort),chr(transfer)));

    def testServer(self, src, port):
        self.sendCMD(self.CMD_TEST_SERVER, src, "{0}{1}".format(chr(port),chr(port)));

    def closeClient(self, src, srcPort, dest, destPort):
        self.sendCMD(self.CMD_CLOSE_CLIENT, src, "{0}{1}{2}".format(chr(srcPort),chr(dest),chr(destPort)));

    def appClient(self, src, srcPort, dest, destPort):
        self.sendCMD(self.CMD_APP_CLIENT, src, "{0}{1}{2}".format(chr(srcPort),chr(dest),chr(destPort)));

    def appServer(self, src, port):
        self.sendCMD(self.CMD_APP_SERVER, src, "{0}{1}".format(chr(port),chr(port)));

    def sendMsgClient(self, src, srcPort,  msg):
        self.sendCMD(self.CMD_MSG_CLIENT, src, "{0}{1}".format(chr(srcPort),msg));

    def addChannel(self, channelName, out=sys.stdout):
        print 'Adding Channel', channelName;
        self.t.addChannel(channelName, out);

def main():
    s = TestSim();
    s.runTime(10);
    s.loadTopo("long_line.topo");
    s.loadNoise("no_noise.txt");
    s.bootAll();
    #s.runTime(5);
    
    s.addChannel(s.COMMAND_CHANNEL);
    s.addChannel(s.GENERAL_CHANNEL);
    #s.addChannel(s.FLOODING_CHANNEL);
    #s.addChannel(s.NEIGHBOR_CHANNEL);
    #s.addChannel(s.ROUTING_CHANNEL);
    #s.addChannel(s.TRANSPORT_CHANNEL);
    s.addChannel(s.APPLICATION_CHANNEL);

    s.runTime(150);    
    
    #s.routeDMP(19);
    #s.runTime(10);
    #s.testServer(1, 41);
    #s.runTime(10);
    #s.testClient(4, 40, 1, 41, 100);
    #s.runTime(2500);
    #s.closeClient(4, 40, 1, 41)

    s.appServer(1, 41);
    s.runTime(10);
    s.appClient(4, 40, 1, 41);
    s.runTime(10);
    s.appClient(7, 70, 1, 41);
    s.runTime(10);
    s.sendMsgClient(4, 40, "hello mlane6 40\r\n");
    #s.runTime(1000);
    #s.sendMsgClient(4, 40, "msg No.\r\n");
    #s.runTime(1000);
    #s.sendMsgClient(4, 40, "whisper jsingh Yes\r\n");
    #s.runTime(1000);
    #s.sendMsgClient(4, 40, "listusr\r\n");

    s.runTime(2500);

    s.runTime(150);

if __name__ == '__main__':
    main()
