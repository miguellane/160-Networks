// Custom Interface
interface LinkState{
    command void start();
    command void print();
    command void update(uint8_t arr[]);
    command uint16_t route(uint16_t dest);
}
