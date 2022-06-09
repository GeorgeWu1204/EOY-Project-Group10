#include <Wifi.h>
#include<string>
class Communication{


    public:
        void init_WiFi();
        void reconnect_WiFi(unsigned long reconnectWifiPeriod, unsigned long& previousTime, bool& disconnectionHappened);
        void rubbish_function_for_wifi_offline_mode();
        void rubbish_function_after_wifi_reconnected(bool& disconnectionHappened);

        void server_connection(WiFiClient& client, bool &serverConnected);
        void is_server_connected(bool& serverConnected, bool disconnectionHappened);

        void listen_for_instr(WiFiClient& client, int* receivedInfo, String& received);
        void send_alien_msg(WiFiClient& client, int alienIndex, float x, float y, String color, int count);
        void send_coord_msg(WiFiClient& client, float x, float y);
        void rubbish_function_for_wifi_online_mode(WiFiClient& client, float& x, float& y, int& i);

};