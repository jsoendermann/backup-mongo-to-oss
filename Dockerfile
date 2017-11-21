FROM mongo:latest
LABEL maintainer="Jan Soendermann <jan.soendermann+git@gmail.com>"

RUN apt-get update && \
  apt-get install -y cron curl bzip2 file openssl coreutils && \
  apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /scripts


ADD ./scripts/* ./
RUN chmod +x ./*

VOLUME /tmp-dir

ENTRYPOINT [ "./entrypoint.sh" ]
