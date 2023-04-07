FROM bcgovimages/aries-cloudagent:py36-1.16-1_0.8.0

USER root
WORKDIR /root


RUN apt-get -qq -y update
RUN apt-get -qq -y upgrade unattended-upgrades
RUN apt-get -qq -y install --no-install-recommends \
                    sudo pstack strace sysstat lsof linux-tools-generic \
                    net-tools netcat tcpdump libcap2-bin \
                    postgresql-client redis-tools \
                    patch

RUN pip3 install git+https://github.com/Indicio-tech/aries-acapy-cache-redis.git

COPY ./patch.diff /root/patch.diff
WORKDIR /home/indy/.pyenv/versions/3.6.13/lib/python3.6/site-packages
RUN patch -p1 < /root/patch.diff

RUN echo 'indy ALL=NOPASSWD: ALL' >> /etc/sudoers
USER indy
WORKDIR /home/indy
