FROM python:3

COPY kubespray-runner.sh /usr/local/bin/

RUN pip install ansible==2.7.* \
&& wget https://github.com/mikefarah/yq/releases/download/2.3.0/yq_linux_amd64 -O /usr/local/bin/yq \
&& chmod +x /usr/local/bin/yq
