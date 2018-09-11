FROM docker.elastic.co/elasticsearch/elasticsearch:6.4.0

ARG ES_NAME=es1

RUN yum install -y keepalived iproute

COPY --chown=elasticsearch:elasticsearch ${ES_NAME}/elasticsearch.yml /usr/share/elasticsearch/config/

COPY ${ES_NAME}/keepalived.conf /etc/keepalived/

COPY start.sh /usr/local/bin/start.sh
RUN chgrp 0 /usr/local/bin/start.sh && \
    chmod g=u /etc/passwd && \
    chmod 0775 /usr/local/bin/start.sh

ENTRYPOINT ["/usr/local/bin/start.sh"]
