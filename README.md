# Présentation

## Que cherche t-on a obtenir ?
![image](https://user-images.githubusercontent.com/101867500/236282961-03069477-f3fb-4fa3-b5c9-997182ba1ad1.png)

Le client et le serveur s’authentifie mutuellement via un certificat d’Autorité auto-signé.

## Liste des commandes utilisée

 - ls : Affiche le contenu d’un répertoire. Utilisez les options « -l » pour afficher tout les propriétés des fichiers et -a pour afficher l’ensemble des fichiers (fichiers cachés inclus)

 - cd : Change de répertoire (Change Directory)

 - mkdir : Crée un répertoire.

 - chmod : Modifie les droits d’accès du propriétaire, groupe et autres pour un fichier dossier un dossier. Notez que les droit peuvent se propager aux sous dossier avec l’option -R. https://fr.manpages.org/chmod

 - chown : Modifie le propriétaire et le groupe d'un fichier. https://fr.manpages.org/chown

 - nano: Mini éditeur texte

 - openssl: Ensemble d’outils cryptographique qui implémente les protocoles réseau Secure Sockets Layer (SSL v2/v3, couche de sockets sécurisées) et Transport Layer Security (TLS v1, sécurité pour la couche de transport). https://fr.manpages.org/openssl

 - systemctl: Ensemble d’outils permettant de gérer les démons de systemd

- netstat : Commande utilisée pour afficher les connexions réseau et les ports en cours d'utilisation sur un ordinateur.

# Pré-requis sur le serveur
## Installez SSH-server
Un peu plus loin, nous aurons besoin de transférer la clé client, le certificat client et le certificat d'autorité du serveur vers le client. Pour cela on utilisera la commande scp (Secure CoPy) qui fait partie des outils livrés avec open-ssh

 - Site : https://www.openssh.com
 - Documentation : https://www.openssh.com/manual.html

Installez le serveur Open-SSH
``` bash
sudo apt-get update
sudo apt-get install openssh-server
```
Créez un compte système pour le transfert de fichier

sudo adduser nom_utilisateur

### Configurez le serveur SSH
``` bash
sudo nano /etc/ssh/sshd_config
```
Modifiez le fichier comme suit
``` bash
…
PermitRootLogin no
…
PasswordAuthentication yes
…
AllowUsers nom_utilisateur
```
Nous avons :
 - Interdit les connexions SSH avec le compte root
 - Activé l’authentification des utilisateurs système
 - Autorisé un nouvel utilisateur à se connecter via SSH sur cette machine

Redémarrez SSH
``` bash
sudo systemctl restart sshd
```

## Vérification
Vérifiez que le service mariadb.service soit actif
``` bash
sudo systemctl status mariadb.service
```
![image](https://user-images.githubusercontent.com/101867500/236283558-b8c0a5fe-745b-4bf9-94b0-b208bb0b6dc0.png)

Vérifiez que le port réseau 3306 soit à l’écoute
``` bash
sudo netstat -tulnp | grep 3306
```
![image](https://user-images.githubusercontent.com/101867500/236283689-f3a6c212-36e5-4f9f-afce-55681277ec62.png)


> **Note**
> Options netstat utilisées \
>  - -t toutes les connexions TCP en cours.\
>  - -u toutes les connexions UDP en cours.\
>  - -l affiche les ports à l’"écoute" pour les connexions entrantes.
>  - -n affiche les numéros de port.
>  - -p affiche le nom du processus qui utilise le port.


> **Warning**
> Mariadb est à l'écoute sur l'interface (loopback) 127.0.0.1. Les connexions distantes ne sont donc pas autorisées.

Si vous tentez de vous connecter depuis le client 
``` bash
mariadb -u root -p - h <VOTRE IP>
ERROR 2002 (HY000): Can't connect to server on '<VOTRE IP>' (115)
```
Sans surprise, Mariadb ne répond pas.

## Autorisez les connexions distantes vers Mariadb

Rendez-vous sur le serveur et éditez le fichier 50-server.cnf
``` bash
sudo nano /etc/mysql/mariadb.conf.d/50-server.cnf
```
https://mariadb.com/kb/en/configuring-mariadb-for-remote-client-access/

``` bash
[mysqld]
...
Bind-address = 0.0.0.0
...
``` 
Redémarrez le serveur Mariadb
``` bash
sudo systemctl restart mariadb.service
```
Vérifiez à nouveau le port 3306
``` bash
sudo netstat -tulnp | grep 3306
```
> **Note** Lorsque Mariadb est configuré pour écouter sur l'adresse IP 0.0.0.0, cela signifie qu'il écoute sur toutes les interfaces réseau disponibles sur l'ordinateur et sur les interfaces réseau publiques.

Le service Mariadb est maintenant accessible depuis n’importe quelle adresse IP.

![image](https://user-images.githubusercontent.com/101867500/236311373-ffc386f5-5f56-4de7-99c5-b8c92f98d054.png)

# Création du certificat CA (TLS/SSL)

Note: Nous allons 3 certificats. A chaque création de certificat, nous devons impérativement renseigner un CN (Common Name) différent, comme par exemple :
 - CA common Name : MariaDB_CA
 - Serveur common Name : [IP DU SERVEUR]
 - Client common Name : MariaDB_client

 a) Depuis le serveur, créez le répertoire /etc/mysql/ssl
``` bash
cd /etc/mysql
sudo mkdir ssl
cd ssl
```
 b) Créez la clé CA
``` bash
openssl genrsa 2048 > ca-key.pem
```
 c) Utilisez la clé CA pour générer le certificat CA pour Mariadb
``` bash
sudo openssl req -new -x509 -nodes -days 365000 -key ca-key.pem -out ca-cert.pem
```
Vous venez de créer dans /etc/mysql/ssl/ les fichiers: 
 - ca-cert.pem: Fichier de certificat pour l'autorité de certification (CA).
 - ca-key: Fichier de clé pour l'autorité de certification (CA).

d) Vérifiez la validité du certificat CA
``` bash
openssl x509 -noout -dates -in /etc/mysql/ssl/ca-cert.pem
```
e) Vérifiez les droits du répertoire /etc/mysql/ssl
``` bash
cd /etc/mysql
ls -la
```

f) Vérifiez le propriétaire du répertoire /etc/mysql/ssl
``` bash
cd ..
ls -la
```

g) Vérifiez les droits d’accès et propriétaire du fichier /etc/mysql/ssl/ca-cert.pem
``` bash
cd /etc/mysql/ssl
ls -la
sudo chmod 644 ./ca-cert.pem
sudo chown mysql:root ./ca-cert.pem
```
# Générer la clé et certificat serveur
Créez la clé serveur
``` bash
sudo openssl req -newkey rsa:2048 -days 365000 -subj "/CN=192.168.1.82" -nodes -keyout server-key.pem -out server-req.pem
```
Supprimez toute phrase secrète associée à la clé privée server-key.pem
``` bash
sudo openssl rsa -in server-key.pem -out server-key.pem
```
Signez le certificat serveur avec le certificat d’autorité et la clé CA
``` bash
sudo openssl x509 -req -in server-req.pem -days 365000  -CA ca-cert.pem -CAkey ca-key.pem -set_serial 01 -out server-cert.pem
```

# Générez la clé et le certificat client
Créez le clé client
``` bash
openssl req -newkey rsa:2048 -days 365000 -subj "/CN=Mariadb_Client" -nodes -keyout client-key.pem -out client-req.pem
```
Supprimez toute phrase secrète associée à la clé privée client-key.pem
``` bash
openssl rsa -in client-key.pem -out client-key.pem
```
Signez le certificat client avec le certificat d’autorité et la clé CA
``` bash
openssl x509 -req -in client-req.pem -days 365000 -CA ca-cert.pem -CAkey ca-key.pem -set_serial 01 -out client-cert.pem
```

