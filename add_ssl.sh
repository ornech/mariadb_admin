#!/bin/bash
sudo rm /home/jf/ssl/*.pem
sudo rm /home/jf/ssl/*.req
sudo rm /etc/mysql/ssl/*.pem

sudo openssl genrsa 2048 > ca-key.pem
sudo openssl req -new -x509 -nodes -days 365000 -subj "/CN=Mariadb_CA" -key ca-key.pem -out ca-cert.pem

# certificat et clé serveur
sudo openssl req -newkey rsa:2048 -days 365000 -subj "/CN=Mariadb_Server" -nodes -keyout server-key.pem -out server-req.pem
# Supprime toute phrase secrète associée à la clé privée server-key.pem
sudo openssl rsa -in server-key.pem -out server-key.pem
# Signe le certificat serveur avec le certificat d’autorité et la clé CA
sudo openssl x509 -req -in server-req.pem -days 365000  -CA ca-cert.pem -CAkey ca-key.pem -set_serial 01 -out server-cert.pem


# certificat et clé client
sudo openssl req -newkey rsa:2048 -days 365000 -subj "/CN=Mariadb_Client" -nodes -keyout client-key.pem -out client-req.pem
# Supprime toute phrase secrète associée à la clé privée server-key.pem
sudo openssl rsa -in client-key.pem -out client-key.pem
# Signe le certificat client avec le certificat d’autorité et la clé CA
sudo openssl x509 -req -in client-req.pem -days 365000 -CA ca-cert.pem -CAkey ca-key.pem -set_serial 01 -out client-cert.pem


# Verification des certificats
openssl verify -CAfile ca-cert.pem server-cert.pem client-cert.pem


# sudo rm /etc/mysql/ssl/*.req

# sudo cp -v ./server-cert.pem /etc/mysql/ssl/server-cert.pem
# sudo cp -v ./server-key.pem /etc/mysql/ssl/server-key.pem
#
# sudo cp -v ./ca-cert.pem /etc/mysql/ssl/ca-cert.pem
# sudo cp -v ./ca-key.pem /etc/mysql/ssl/ca-key.pem
#
# sudo cp -v ./client-cert.pem /etc/mysql/ssl/client-cert.pem
# sudo cp -v ./client-key.pem /etc/mysql/ssl/client-key.pem
sudo cp -v /home/jf/ssl/script/*.pem /etc/mysql/ssl

sudo chown -Rv mysql:root /etc/mysql/ssl
#sudo chmod -R 644 /etc/mysql/ssl

sudo systemctl restart mariadb.service
# sudo systemctl status mariadb.service
mariadb --ssl-verify-server-cert
