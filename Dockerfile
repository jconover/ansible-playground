FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    openssh-server \
    python3 \
    python3-pip \
    python3-mysqldb \
    build-essential \
    sudo \
    vim \
    curl \
    iproute2 \
    iputils-ping \
    net-tools \
    mysql-client \
    && rm -rf /var/lib/apt/lists/*

# Configure SSH
RUN mkdir /var/run/sshd \
    && echo 'root:ansible' | chpasswd \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

EXPOSE 22
RUN ssh-keygen -A
CMD ["/usr/sbin/sshd", "-D"]
