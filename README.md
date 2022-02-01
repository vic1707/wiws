<div align="center">

![WIWS logo](./WIWS.svg) 
<h1>WIWS <img alt="Version" src="https://img.shields.io/badge/version-1.0-blue?style=flat-square" /></h1>

[![Generic badge](https://img.shields.io/badge/Based%20of-linuxserver%2Fdocker--wireguard-success?style=flat-square&logo=GitHub)](https://github.com/linuxserver/docker-wireguard)
[![Generic badge](https://img.shields.io/badge/Incorporates-erebe%2Fwstunnel-success?style=flat-square&logo=GitHub)](https://github.com/linuxserver/docker-wireguard)

[![GitHub Forks](https://img.shields.io/github/forks/vic1707/wiws.svg?color=6e5494&labelColor=555555&logoColor=ffffff&style=flat-square&logo=github)](https://github.com/vic1707/WIWS)
[![GitHub Stars](https://img.shields.io/github/stars/vic1707/wiws.svg?color=6e5494&labelColor=555555&logoColor=ffffff&style=flat-square&logo=github)](https://github.com/vic1707/WIWS)
[![Docker Pulls](https://img.shields.io/docker/pulls/vic1707/wiws.svg?color=0DB7ED&labelColor=555555&logoColor=ffffff&style=flat-square&label=pulls&logo=docker)](https://hub.docker.com/r/vic1707/wiws)
[![Docker Stars](https://img.shields.io/docker/stars/vic1707/wiws.svg?color=0DB7ED&labelColor=555555&logoColor=ffffff&style=flat-square&label=stars&logo=docker)](https://hub.docker.com/r/vic1707/wiws)

WIWS stand for **W**ireguard **I**n a **W**eb**S**ocket, more accurately it's a [Linuxserver](https://github.com/linuxserver/docker-wireguard) docker (W/ server mode forced) container that encapsulate a Wireguard server to go through a [WebSocketTunnel](https://github.com/erebe/wstunnel).

Long story short, like all the student's in there twenties I was looking for a way to bypass firewall rules at my school which blocks UDP, VPN connexions even via TCP etc (a true nightmare belive me). In my researches I came across [Kirill888's notes](https://kirill888.github.io/notes/wireguard-via-websocket/) on the subject (kudos to him) witch inspired me to create this container.

TL DR If the firewall your trying to bypass doesn't block the 443 TCP port, this container should do the trick (you must additionally set `WSSERVERPORT` to 443).

[<img height="100em" src="https://www.wireguard.com/img/wireguard.svg">](https://github.com/erebe/wstunnel) &emsp; &emsp; &emsp; &emsp;
[<img width="200em" src="https://github.com/erebe/wstunnel/raw/master/logo_wstunnel.png">](https://www.wireguard.com)&emsp; &emsp; &emsp; &emsp;

</div>

# Before starting

* First of all, note that this container requires the Linux's headers to be passed `-v /lib/modules:/lib/modules`, so if you want to run the container on a Windows or MacOS machine you'll need to pass them by another way.

* Secondly, **this project is only available for `x86_64 | amd64` on Linux, MacOS and Windows (No phones)**. Because [WSTunnel](https://github.com/erebe/wstunnel) isn't consistently releasing the binary for `arm64` nor `armhf` and [WSTunnel](https://github.com/erebe/wstunnel) on a phone might be too complicated to pull of.

* Thirdly you need root access on the client for Linux or MacOS or Windows for windows due to some PowerShell line execution.

Note that even if [WSTunnel](https://github.com/erebe/wstunnel) is installed, this is just an addon and the classic Wireguard tunnel will still run normally (maybe for your phone and arm).

# Getting started

## Server side configuration

### Deploy the docker

In order to deploy a wiws docker container you can use the docker CLI or the Docker-Compose. The wiws docker container is based on the Linux server Wireguard Docker container but in order to use [WSTunnel](https://github.com/erebe/wstunnel), some required environment variables were added to the container, a new port was also added to the container to allow the [WSTunnel](https://github.com/erebe/wstunnel)to listen and forward the traffic. I listed below all the [parameters](#parameters-list) that you need to set in order to use the wiws docker container followed by [usage exemples](#usage-examples).

### Parameters list

<details>
<summary>Let me see the list !</summary>

| Parameter | Function | Optional | Default value |
| --------- | -------- | -------- | ------------- |
| `--name=wiws` | Set the container name on the network (usefull when using the provided nginx configs). | ✔️ | |
| `-e PUID=1000` | Used to avoid eventual permission issues. [see why](https://github.com/linuxserver/docker-wireguard#user--group-identifiers). | ✔️ | |
| `-e PGID=1000` | Used to avoid eventual permission issues. [see why](https://github.com/linuxserver/docker-wireguard#user--group-identifiers). | ✔️ | |
| `-e TZ=Europe/Paris` | The timezone used by the container. | ✔️ | `Europe/London` |
| `-e PEERS=1` | Number of peers to create confs for. Can also be a list of names: `myPC,myPhone,myTablet` (alphanumeric only, please do not excede 6 char long). | ❌ | |
| `-e PEERDNS=auto` | DNS server set in peer/client configs (can be set as 8.8.8.8). Used in server mode. Defaults to `auto`, which uses wireguard docker host's DNS via included CoreDNS forward. | ✔️ | `auto` |
| `-e INTERNAL_SUBNET=10.13.13.0` | Internal subnet for the wireguard and server and peers (only change if it clashes). | ✔️ | `10.13.13.0` |
| `-e SERVERURL=wiws.domain.com` | External IP or domain name for docker host. Used in server mode. If set to `auto`, the container will try to determine and set the external IP automatically. | ✔️ | `auto` which will be your external IP |
| `-e SERVERPORT=51820` | External port for classic Wireguard use. | ✔️ | `51820` |
| `-e USINGDNSMASQ=false` | if `dnsmasq` used by Linux and MacOS clients. It can be changed independently afterwards by editing the `wstunnel.sh` script. | ✔️ | `false` |
| `-e VERBOSE=false` | Causes the container to output full logs of WSTunnel. | ✔️ | `false` |
| `-e WSPREFIX=""` | The prefix used by an optionnal reverse proxy (see the NGINX-SWAG confs). | ✔️ | `""` |
| `-e WSSERVERPORT=27832` | External port for WSTunnel. | ✔️ | `27832` |
| `-p 27832:27832/tcp` | WSTunnel port. | ❌ | |
| `-p 51820:51820/udp` | Wireguard port, used if you want to keep a normal Wireguard | ✔️ | |
| `-v /path/to/data/config:/config` | Contains all relevant configuration files (needed for persistent data). | ❌ | |
| `-v /lib/modules:/lib/modules` | Maps host's modules folder. | ❌ | |
</details>

### Usage exemples

<details>
<summary>docker-compose (recommended)</summary>

### Need some help with docker compose? Docker Documentation is [here](https://docs.linuxserver.io/general/docker-compose)

```yaml
  version: '3.3'
  services:
      wiws:
          container_name: wiws
          cap_add:
            - NET_ADMIN
            - SYS_MODULE
          environment:
              - PUID=1000
              - PGID=1000
              - TZ=Europe/Paris
              - PEERS=1
              - PEERDNS=auto #optional defaults to 'auto'
              - INTERNAL_SUBNET=10.13.13.0 #optional defaults to 10.13.13.0
              - SERVERURL=wiws.domain.com #optional defaults to 'auto' which will be your external IP
              - SERVERPORT=51820 #optional defaults to 51820
              - USINGDNSMASQ=false #optional defaults to false
              - WSPREFIX="" #optional defaults to ""
              - WSSERVERPORT=27832 #optional defaults to 27832
          ports:
              - 27832:27832/tcp
              - 51820:51820/udp #optional used if you want to keep a normal Wireguard server
          volumes:
              - '/path/to/data/config:/config'
              - '/lib/modules:/lib/modules'
          sysctls:
            - net.ipv4.conf.all.src_valid_mark=1
          restart: unless-stopped
          image: vic1707/wiws
```

</details>

<details>
<summary>docker cli</summary>

### Need some help with docker CLI? Docker Documentation is [here](https://docs.docker.com/engine/reference/commandline/cli/)

```bash
docker run -d \
  --name=wiws \
  --cap-add=NET_ADMIN \
  --cap-add=SYS_MODULE \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Europe/Paris \
  -e PEERS=1 \
  -e PEERDNS=auto `#optional defaults to 'auto'` \
  -e INTERNAL_SUBNET=10.13.13.0 `#optional defaults to 10.13.13.0` \
  -e SERVERURL=wiws.domain.com `#optional defaults to 'auto' which will be your external IP` \
  -e SERVERPORT=51820 `#optional defaults to 51820` \
  -e USINGDNSMASQ=false `#optional defaults to false` \
  -e WSPREFIX="" `#optional defaults to ""` \
  -e WSSERVERPORT=27832 `#optional defaults to 27832` \
  -p 27832:27832/tcp \
  -p 51820:51820/udp `#optional used if you want to keep a normal Wireguard server` \
  -v /path/to/data/config:/config \
  -v /lib/modules:/lib/modules \
  --sysctl="net.ipv4.conf.all.src_valid_mark=1" \
  --restart unless-stopped \
  vic1707/wiws
```

</details>

### Get needed client files

Once the server is started it will generate a usefull a batch of files. You will need to save them in order [to put them on the client](#needed-files-set-up).

| File | Function |
| ----------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `peer.conf` & `peer.png` | For simple Wireguard server (requires port 51820 to be binded to `SERVERPORT`) |
| `peer.unix.conf` & `peer.win.conf` | For Wireguard by [WSTunnel](https://github.com/erebe/wstunnel) (requires port 27832 to be binded to `WSSERVERPORT`) |
| `peer.wstunnel.sh` & `peer.wstunnel.ps1` | (`.sh` for Linux and MacOS, `.ps1` for Windows) to use the [WSTunnel](https://github.com/erebe/wstunnel). |

## Client side configuration

### Needed binary installation

On all clients using the [WSTunnel](https://github.com/erebe/wstunnel) you will need to install the latest [WSTunnel binary](https://github.com/erebe/wstunnel/releases) and add it to `PATH`.

<details>
<summary>Windows process</summary>

* run `reg add HKLM\Software\WireGuard /v DangerousScriptExecution /t REG_DWORD /d 1 /f` in an administrator Window's PowerShell, this allows Wireguard to execute external scripts.
* Create `C:\wstunnel\bin` and add it to `PATH` [HOW TO](https://www.architectryan.com/2018/03/17/add-to-the-path-on-windows-10/)
* Copy the downloaded binary to `C:\wstunnel\bin`

</details>

<details>
<summary>MacOS and Linux process</summary>

* Copy the downloaded binary to `/usr/local/bin/wstunnel` **(Don't forget to `chmod +x` it!!)**

</details>

### Needed files set up

Get your file batch from [earlier](#get-needed-client-files).

On Windows you'll copy `wstunnel.ps1` in `C:\wstunnel\`.

On Linux and MacOS you'll copy `wstunnel.sh` in `/etc/wireguard/` **(don't forget to `chmod +x` it!!)**.

Those paths and script names can be customized by editing the `.unix.conf` or `.win.conf`.

### Connection to the server

Unfortunately, the MacOS GUI of Wireguard isn't compatible with [WSTunnel](https://github.com/erebe/wstunnel), but the GUI works fine on Windows.

If the GUI isn't accepting the `wspeer.XXXX.conf` you'll have to use the CLI:

* `wg-quick up wspeer.XXXX.conf` to connect to the server
* `wg-quick down wspeer.XXXX.conf` to disconnect.

# Support Info

* Shell access whilst the container is running: `docker exec -it wiws /bin/bash`
* To monitor the logs of the container in realtime: `docker logs -f wiws`

# Troubleshooting

If you're facing problem with the container, you should try running the container with the `VERBOSE` flag set to `true`.
This option should allow you to see the logs of wstunnel.
To efficiently debug the problem you should try different things step by step.

1. Check if a normal Wireguard connection works.

2. Check if you can connect to WSTunnel from your local network (by running the `wstunnel` client command directly on your machine) and request a packet (I personnaly use `netcat` to do this).
  a. If you can, you should see a new connection in logs of the container and so the problem is elsewere.
  b. If you can't, open an issue with all your configuration and the logs of the container.

3. Check if you can connect to WSTunnel from the internet (first without any reverse proxy then with it).
