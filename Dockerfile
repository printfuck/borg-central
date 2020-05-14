FROM alpine:latest

RUN apk update && apk add --no-cache \
	borgbackup \
	wget \
	openssh-server \
	openssh-client 

ADD entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

