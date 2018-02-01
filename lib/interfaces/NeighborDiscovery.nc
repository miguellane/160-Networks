// Custom Interface
interface NeighborDiscovery{
    command void start();
    command void print();
    command bool changed();
    command void get(uint8_t arr[]);
}
