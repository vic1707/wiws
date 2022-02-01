#Requires -RunAsAdministrator
## took from: https://github.com/gaspard-v/wireguard-over-wss-PS/blob/master/wstunnel.ps1

Param(
 [Parameter(Mandatory)]
 [string]
 $FUNC
)

## ENVS ##
## ENVS ##

$WG = $env:WIREGUARD_TUNNEL_NAME
$HOSTS_BACKUP = "${UPDATE_HOSTS}-${WG}.wstunnel"

function update_host_entry([string] $current_host, [string] $current_ip) {
    $file_content = Get-Content "$UPDATE_HOSTS"
    [string] $content = ""
    foreach($line in $file_content) {
        if($line -match $current_host)
        {
            Write-Output "[#] Updating ${current_host} -> ${current_ip}"
            $content += "${current_ip}`t${current_host}`n"
        } else {
            $content += "${line}`n"
        }
    }
    $content.Substring(0, $content.Length-1) | Out-File -NoNewline -Encoding utf8 "$UPDATE_HOSTS"
}

function delete_host_entry([string] $current_host, [string] $current_ip) {
    $file_content = Get-Content "$UPDATE_HOSTS"
    [string] $content = ""
    Write-Output "[#] delete entry ${current_host} -> ${current_ip}"
    foreach($line in $file_content) {
        if($line -notmatch $current_host) { $content += "${line}`n" }
    }
    $content.Substring(0, $content.Length-1) | Out-File -NoNewline -Encoding utf8 "$UPDATE_HOSTS"
}

function maybe_update_host([string] $current_host, [string] $current_ip) {
    if([ipaddress]::TryParse("$current_host",[ref][ipaddress]::Loopback)) {
        # the $current_host is a loopback ip address
        Write-Output "[#] ${current_host} is an IP address"
        return
    }
    $file_content = Get-Content "$UPDATE_HOSTS"
    if($file_content -match $current_host) {
        update_host_entry $current_host $current_ip
    } else {
        Write-Output "[#] Add new entry ${current_host} => <${current_ip}>"
        "`n${current_ip}`t${current_host}" | Out-File -Append -Encoding utf8 -NoNewline -FilePath $UPDATE_HOSTS
    }
}

function launch_wstunnel() {
    if ($WSS_PORT) { $wssport=$WSS_PORT }
    else { $wssport=27832 }

    $param = @("--quiet", 
              "--udpTimeoutSec -1",
              "--udp"
              "-L 127.0.0.1:51820:127.0.0.1:51820",
              "wss://${REMOTE_HOST}:$wssport")

    if($WS_PREFIX) { $param += "--upgradePathPrefix ${WS_PREFIX}" }

    return (Start-Process -NoNewWindow -FilePath "wstunnel" -ArgumentList $param -PassThru).id
}

function pre_up() {
    try {
        $remote_ip = [System.Net.Dns]::GetHostAddresses($REMOTE_HOST)
        $remote_ip = $remote_ip.IPAddressToString
    } catch {
        $remote_ip = [IPAddress] $REMOTE_HOST
    }

    maybe_update_host -current_host $REMOTE_HOST -current_ip $remote_ip
    # Find out the current route to $remote_ip and make it explicit
    [string] $gw = (Find-NetRoute -RemoteIPAddress $remote_ip).NextHop
    $gw = $gw.Trim()
    route add ${remote_ip}/32 ${gw} | Out-Null
    $wspid = launch_wstunnel
    "${wspid} ${remote_ip} ${gw} ${REMOTE_HOST}" | Out-File -NoNewline -FilePath "${HOSTS_BACKUP}"
}

function post_up() {
    $interface = (Get-NetAdapter -Name "${WG}*").ifIndex
    try { 
        $ipv4 = (Get-NetIPAddress -ErrorAction SilentlyContinue -InterfaceIndex $interface -AddressFamily IPv4).IPAddress
        route add 0.0.0.0/0 ${ipv4} METRIC 1 IF ${interface} 2>&1 | Out-Null
    } catch {}

    try {
        $ipv6 = (Get-NetIPAddress -ErrorAction SilentlyContinue -InterfaceIndex $interface -AddressFamily IPv6).IPAddress
        route add ::0/0 ${ipv6} METRIC 1 IF ${interface} 2>&1 | Out-Null
    } catch {}
}


function post_down() {
    if (Test-Path -PathType Leaf -Path "$HOSTS_BACKUP") {
        $file_content = Get-Content -Path "${HOSTS_BACKUP}"
        $file_content = $file_content.Split(" """)
        $wspid = $file_content[0]
        $remote_ip = $file_content[1]
        $gw = $file_content[2]
        $wshost = $file_content[3]
        delete_host_entry $wshost $remote_ip

        try { Stop-Process -Force -id $wspid | Out-Null } 
        catch {}

        route delete ${remote_ip}/32 ${gw} | Out-Null
        Remove-Item "$HOSTS_BACKUP"
    } 
    else { Write-Output "[#] Missing BAK file: ${HOSTS_BACKUP}" }
}

Invoke-Expression $FUNC
