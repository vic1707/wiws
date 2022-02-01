#!/bin/bash
## modified from https://github.com/jnsgruk/wireguard-over-wss/blob/master/wstunnel.sh

## ENVS ##
## ENVS ##

read_host_entry () {
    local host=$1
    local hfile=$2
    awk -v host="$host" '{
     if( !($0~"^[ ]*#") && $2==host )
       print $1, ($0~"## wstunnel end-point")?"auto":"manual"
     }' "${hfile}"
}

maybe_update_host () {
    local host="$1"
    local current_ip="$2"
    local hfile=$3
    local recorded_ip h_mode

    read -r recorded_ip h_mode < <(read_host_entry "${host}" "${hfile}") || true

    if [[ -z "${recorded_ip}" ]]; then
        echo "[#] Add new entry ${host} => <${current_ip}>"
        echo -e "${current_ip}\t${host}\t## wstunnel end-point" >> "${hfile}"
    else
        if [[ "${recorded_ip}" == "${current_ip}" ]]; then
            echo "[#] Recorded address is already correct"
        else
            if [[ "${h_mode}" == "auto" ]]; then
                echo "[#] Updating ${recorded_ip} -> ${current_ip}"
                local edited
                edited=$(awk -v host="$host" -v ip="$current_ip" '{
                    if( !($0~"^[ ]*#") && $2==host && ($0~"## wstunnel end-point") )
                        print ip "\t" host "\t" "## wstunnel end-point"
                    else
                        print $0
                    }' "${hfile}")

                echo "${edited}" > "${hfile}"
            else
                echo "[#] Manual entry doesn't match current ip: ${recorded_ip} -> ${current_ip}"
                exit 2
            fi
        fi
    fi
}

launch_wstunnel () {
    local host=${REMOTE_HOST}
    local wssport=${WSS_PORT:-27832}
    local prefix="$WS_PREFIX"
    local user=${1:-"nobody"}
    local timeout=${TIMEOUT:-"-1"}
    local cmd

    cmd=$(command -v wstunnel)
    cmd="sudo -n -u ${user} -- $cmd"

    $cmd &>/dev/null </dev/null \
      --quiet \
      --udp \
      --udpTimeoutSec "${timeout}" \
      --upgradePathPrefix "${prefix}" \
      -L "127.0.0.1:51820:127.0.0.1:51820" \
      "wss://${host}:${wssport}" & disown
    echo "$!"
}

pre_up () {
    local wg=$1
    local remote remote_ip gw wstunnel_pid hosts_file _dnsmasq

    remote=${REMOTE_HOST}
    hosts_file=${UPDATE_HOSTS}
    _dnsmasq=${USING_DNSMASQ:-0}
    remote_ip=$(dig +short "${remote}")

    if [[ -z "${remote_ip}" ]]; then
        echo "[#] Can't resolve ${remote}"
        exit 1
    fi

    if [[ -f "${hosts_file}" ]]; then
        # Cache DNS in
        maybe_update_host "${remote}" "${remote_ip}" "${hosts_file}"

        [[ $_dnsmasq -eq 0 ]] || killall -HUP dnsmasq || true
    fi

    # Find out current route to ${remote_ip} and make it explicit
    gw=$(ip route get "${remote_ip}" | cut -d" " -f3)
    ip route add "${remote_ip}" via "${gw}" > /dev/null 2>&1 || true
    # Start wstunnel in the background
    wstunnel_pid=$(launch_wstunnel nobody)

    # save state
    mkdir -p /var/run/wireguard
    echo "${wstunnel_pid} ${remote} ${remote_ip} \"${hosts_file}\" ${_dnsmasq}" > "/var/run/wireguard/${wg}.wstunnel"
}

post_up () {
    local tun=$1
    ip route add 0.0.0.0/1 dev "${tun}" > /dev/null 2>&1
    ip route add ::0/1 dev "${tun}" > /dev/null 2>&1
    ip route add 128.0.0.0/1 dev "${tun}" > /dev/null 2>&1
    ip route add 8000::/1 dev "${tun}" > /dev/null 2>&1
}

post_down () {
    local wg=$1
    local state_file="/var/run/wireguard/${wg}.wstunnel"
    local wstunnel_pid remote remote_ip hosts_file _dnsmasq

    if [[ -f "${state_file}" ]]; then
        read -r wstunnel_pid remote remote_ip hosts_file _dnsmasq < "${state_file}"
        # unquote
        hosts_file=${hosts_file%\"}
        hosts_file=${hosts_file#\"}

        rm "${state_file}"
    else
        echo "[#] Missing state file: ${state_file}"
        exit 1
    fi

    kill -TERM "${wstunnel_pid}" > /dev/null 2>&1 || true

    if [[ -n "${remote_ip}" ]]; then
	    ip route delete "${remote_ip}" > /dev/null 2>&1 || true
    fi

    if [[ -f "${hosts_file}" ]]; then

        local edited
        edited=$(awk -v host="$remote" '{
        if( !($0~"^[ ]*#") && $2==host && ($0~"## wstunnel end-point") )
            ;
        else
            print $0
        }' "${hosts_file}")

        echo "${edited}" > "${hosts_file}"
        [[ $_dnsmasq -eq 0 ]] || killall -HUP dnsmasq || true
    fi
}
