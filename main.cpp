#include <iostream>
#include <fstream>
#include <string>
#include <chrono>
#include <thread>
#include <curl/curl.h>
#include <syslog.h>
#include <netdb.h>
#include <arpa/inet.h>

struct HttpResponse {
    long status_code;
    std::string body;
};

HttpResponse http_get(const std::string &url) {
    CURL *curl = curl_easy_init();
    if (!curl) return {0, ""};

    std::string response;
    curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION,
        +[](char *ptr, size_t size, size_t nmemb, void *userdata) {
            std::string *resp = static_cast<std::string*>(userdata);
            resp->append(ptr, size * nmemb);
            return size * nmemb;
        });
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &response);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 10L);

    curl_easy_perform(curl);
    
    long status_code = 0;
    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &status_code);
    
    curl_easy_cleanup(curl);
    return {status_code, response};
}

std::string resolve_record(const std::string &hostname, int family) {
    addrinfo hints{}, *res = nullptr;
    hints.ai_family = family;
    hints.ai_socktype = SOCK_STREAM;

    int err = getaddrinfo(hostname.c_str(), nullptr, &hints, &res);
    if (err != 0 || !res) return "";

    char addrbuf[INET6_ADDRSTRLEN];
    void *addr_ptr = nullptr;

    if (family == AF_INET6) {
        addr_ptr = &((sockaddr_in6*)res->ai_addr)->sin6_addr;
    } else if (family == AF_INET) {
        addr_ptr = &((sockaddr_in*)res->ai_addr)->sin_addr;
    }

    inet_ntop(family, addr_ptr, addrbuf, sizeof(addrbuf));
    freeaddrinfo(res);
    return std::string(addrbuf);
}

int main() {
    openlog("duckdns-updater", LOG_PID | LOG_CONS, LOG_DAEMON);

    std::ifstream cfg("/etc/duckdns.conf");
    if (!cfg) {
        syslog(LOG_ERR, "Could not open /etc/duckdns.conf");
        printf("Could not open /etc/duckdns.conf\n");
        return 1;
    }

    std::string domain, token, ipv6_endpoint, ipv4_endpoint;
    int interval = 600;
    std::string line;

    while (std::getline(cfg, line)) {
        if (line.rfind("domain=", 0) == 0) domain = line.substr(7);
        else if (line.rfind("token=", 0) == 0) token = line.substr(6);
        else if (line.rfind("interval=", 0) == 0) interval = std::stoi(line.substr(9));
        else if (line.rfind("ipv6_endpoint=", 0) == 0) ipv6_endpoint = line.substr(14);
        else if (line.rfind("ipv4_endpoint=", 0) == 0) ipv4_endpoint = line.substr(14);
    }

    if (interval<60) {
        syslog(LOG_ERR, "Interval is less then 60; setting to 60");
        printf("Interval is less then 60; setting to 60\n");
        interval=60;
    }    

    if (domain.empty() || token.empty() || ipv6_endpoint.empty()) {
        syslog(LOG_ERR, "Missing required config values");
        return 1;
    }

    std::string fqdn = domain + ".duckdns.org";

    while (true) {
        // --- IPv6 detection ---
        auto ipv6_resp = http_get(ipv6_endpoint);
        std::string local_ipv6 = ipv6_resp.body;
        std::cout << "IPv6 - Status: " << ipv6_resp.status_code << ", Body: " << local_ipv6 << std::endl;
        
        if (local_ipv6.empty()) {
            syslog(LOG_ERR, "Failed to fetch IPv6 from endpoint");
            printf("Failed to fetch IPv6 from endpoint\n");
            std::this_thread::sleep_for(std::chrono::seconds(interval));
            continue;
        }

        std::string dns_ipv6 = resolve_record(fqdn, AF_INET6);

        bool ipv6_changed = (dns_ipv6 != local_ipv6);

        // --- IPv4 detection (optional) ---
        std::string local_ipv4, dns_ipv4;
        bool ipv4_enabled = !ipv4_endpoint.empty();
        bool ipv4_changed = false;

        if (ipv4_enabled) {
            auto ipv4_resp = http_get(ipv4_endpoint);
            local_ipv4 = ipv4_resp.body;
            std::cout << "IPv4 - Status: " << ipv4_resp.status_code << ", Body: " << local_ipv4 << std::endl;
            
            dns_ipv4 = resolve_record(fqdn, AF_INET);

            if (!local_ipv4.empty() && dns_ipv4 != local_ipv4) {
                ipv4_changed = true;
            }
        }

        // --- Only update if something changed ---
        if (ipv6_changed || ipv4_changed) {
            std::string url =
                "https://www.duckdns.org/update?domains=" + domain +
                "&token=" + token;
            if (ipv6_changed) {
                url += "&ipv6=" + local_ipv6;
            }

            if (ipv4_enabled && !local_ipv4.empty())
                url += "&ip=" + local_ipv4;
            std::cout << "URL is: " << url << std::endl;
            auto update_resp = http_get(url);
            std::cout << "Update - Status: " << update_resp.status_code << ", Body: " << update_resp.body << std::endl;
            if (update_resp.body == "OK") { std::cout << "Update was successful\n"; }
            syslog(LOG_INFO,
                   "DuckDNS update: ipv6_changed=%d ipv4_changed=%d result=%s",
                   ipv6_changed, ipv4_changed, update_resp.body.c_str());
            printf("DuckDNS update: ipv6_changed=%d ipv4_changed=%d result=%s\n",
                   ipv6_changed, ipv4_changed, update_resp.body.c_str());

        } else {
            syslog(LOG_INFO, "No update needed (IPv6=%s IPv4=%s)",
                   local_ipv6.c_str(),
                   ipv4_enabled ? local_ipv4.c_str() : "disabled");
            printf("No update needed (IPv6=%s IPv4=%s)\n",
                   local_ipv6.c_str(),
                   ipv4_enabled ? local_ipv4.c_str() : "disabled");
        }
        printf("Sleeping for %i\n", interval);   

        std::this_thread::sleep_for(std::chrono::seconds(interval));
    }

    closelog();
    return 0;
}
