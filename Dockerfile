FROM ghcr.io/linuxserver/wireguard:latest

# set maintainer label
LABEL maintainer "vic1707 <28602203+vic1707@users.noreply.github.com>"

# set non-interactive frontend
ENV DEBIAN_FRONTEND="noninteractive"

RUN apt-get update
RUN apt-get install -y --no-install-recommends gettext-base

## WSTunnel ##
RUN echo "**** install WSTunnel ****" && \
  WSTUNNEL_RELEASE=$(curl -sX GET "https://api.github.com/repos/erebe/wstunnel/releases/latest" | awk '/tag_name/{print $4;exit}' FS='[""]' | awk '{print substr($1,2); }') && \
  curl -s \
    -o /app/wstunnel \
    -L "https://github.com/erebe/wstunnel/releases/download/v${WSTUNNEL_RELEASE}/wstunnel-x64-linux"
RUN chmod +x /app/wstunnel

# import configs folder
COPY /root /

# expose WSTunnel port (Wireguard port is already exposed from parent image)
EXPOSE 27832/tcp