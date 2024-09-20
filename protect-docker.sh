#!/bin/bash
#------------------------------------------------------------------------
# Script to Install Protect the Docker daemon socket on Linux Ubuntu 
#
# Developed by Ivan Filatoff 20.09.2024
#------------------------------------------------------------------------

# check file
if [ -s "var.conf" ]; then
  # load param
  source var.conf
else
  echo "Error: var.conf empty!"
  exit 1
fi

mkdir -p /etc/docker/tls && cd /etc/docker/tls
echo -e "\n===============\nGenerate CA private and public keys\n==============="
echo
openssl genrsa -aes256 -out ca-key.pem 4096
openssl req -new -x509 -days 365 -key ca-key.pem -sha256 -out ca.pem
echo
echo -e "\n====================\nGenerate server key\n===================="
echo
openssl genrsa -out server-key.pem 4096
openssl req -subj "/CN=$HOST_SERV" -sha256 -new -key server-key.pem -out server.csr
echo subjectAltName = DNS:$HOST_SERV,IP:$IP_HOST,IP:127.0.0.1 >> extfile.cnf
echo extendedKeyUsage = serverAuth >> extfile.cnf
echo -e "\n====================\nSign server key\n===================="
echo
openssl x509 -req -days 365 -sha256 -in server.csr -CA ca.pem -CAkey ca-key.pem \
  -CAcreateserial -out server-cert.pem -extfile extfile.cnf
echo
echo -e "\n====================\nGenerate client key\n===================="
echo
openssl genrsa -out key.pem 4096
openssl req -subj '/CN=client' -new -key key.pem -out client.csr
echo extendedKeyUsage = clientAuth > extfile-client.cnf
echo -e "\n====================\nSign client key\n===================="
echo
openssl x509 -req -days 365 -sha256 -in client.csr -CA ca.pem -CAkey ca-key.pem \
  -CAcreateserial -out cert.pem -extfile extfile-client.cnf
echo
rm -v client.csr server.csr extfile.cnf extfile-client.cnf
chmod -v 0400 ca-key.pem key.pem server-key.pem
chmod -v 0444 ca.pem server-cert.pem cert.pem
echo -e "\n==============\nCreate unit-file for docker service\n================"
echo
cat <<EOF> /etc/systemd/system/docker.service
[Unit]
Description=Docker Application Container Engine

[Service]

ExecStart=
ExecStart=/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock \
    --tlsverify \
    --tlscacert=/etc/docker/tls/ca.pem \
    --tlscert=/etc/docker/tls/server-cert.pem \
    --tlskey=/etc/docker/tls/server-key.pem \
    -H=0.0.0.0:2376
ExecReload=/bin/kill -s HUP $MAINPID
TimeoutStartSec=0
RestartSec=2
Restart=always

[Install]
WantedBy=multi-user.target
EOF
echo -e "\n==================\nRestart docker service\n===================="
echo
systemctl daemon-reload
systemctl restart docker.service
systemctl enable docker.service
echo -e "\n=============\nDocker service mTLS listen port: 2376\n=============\n"
echo -e "\nOK\n"