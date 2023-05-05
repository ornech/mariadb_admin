# Sécurisation des connexions Client SQL/Mariadb

## De quoi parle t-on ?
 * Nous allons utiliser des certificats SSL pour authentifier un client SQL distant qui souhaite se connecter à un serveur SQL (Mariadb v10.11.3), afin de s'assurer qu'il soit bien autorisé à se connecter. 
 * Nous allons également utiliser des certificats SSL pour authentifier le serveur SQL (Mariadb v10.11.3) auprès des clients distants, afin de garantir que les clients se connectent bien au serveur souhaité.

## Que cherche t-on a obtenir ?
![image](https://user-images.githubusercontent.com/101867500/236282961-03069477-f3fb-4fa3-b5c9-997182ba1ad1.png)

> **INFO** Un certificat numérique est un document électronique qui sert à prouver l'identité d'un ordinateur ou d'un site web sur internet. Ce document permet également de sécuriser les communications entre ces différents éléments. Par exemple, lorsque vous vous connectez à un site web en utilisant un navigateur, un certificat est utilisé pour chiffrer les données que vous échangez avec le site, afin que personne ne puisse les intercepter ou les lire. Ici nous nous servirons des certificats pour vérifier que le client et le serveur sont bien les machines qui prétendent être avant d'établir la connexion avec Mariadb.

Pour générer ces certificats numériques, nous allons effectuer une **requêtes de certificat** à une autorité de certification (CA), qui vérifie aura la charge de fournit et  le certificat numérique correspondant.

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
``` bash
sudo adduser nom_utilisateur
```
Ajouter cet utilisateur au groupe sudo
``` bash
usermod -aG sudo nom_utilisateur
```

### Configurez le serveur SSH
``` bash
sudo nano /etc/ssh/sshd_config
```
Modifiez le fichier comme suit. Supprimez les commentaires des options indiquées et modifiez le paramètre.
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
> Options netstat utilisées 
>  - -t toutes les connexions TCP en cours.
>  - -u toutes les connexions UDP en cours.
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

# Création des clés et certificats SSL

Nous allons créer 3 certificats. A chaque création de certificat, nous devons impérativement renseigner un CN (Common Name) différent, comme par exemple :
 - CA common Name : MariaDB_CA
 - Serveur common Name : [IP DU SERVEUR]
 - Client common Name : MariaDB_client

## Générez la clé et le certicat d'autorité CA
Depuis le serveur, loggez vous avec l'utilisateur précédement créé
``` bash
su <VOTRE UTILISATEUR>
```
Créez un répertoire ssl à la racine de votre utilisateur
``` bash
mkdir ~/ssl
cd ~/ssl
```
 Créez la clé privé CA
``` bash
openssl genrsa 2048 > ca-key.pem
```
Utilisez la clé CA pour générer le certificat CA
``` bash
openssl req -new -x509 -nodes -days 365000 -key ca-key.pem -out ca-cert.pem
```
> **NOTE** Vous venez de créer dans /home/<VOTRE UTILISATEUR>/ssl/ les fichiers:
> - ca-cert.pem: Fichier de certificat pour l'autorité de certification (CA).
> - ca-key: Fichier de clé pour l'autorité de certification (CA).

Vérifiez la validité du certificat CA
``` bash
openssl x509 -noout -dates -in /etc/mysql/ssl/ca-cert.pem
```

## Générer la clé et certificat serveur

Créez la clé serveur
``` bash
openssl req -newkey rsa:2048 -days 365000 -subj "/CN=192.168.1.82" -nodes -keyout server-key.pem -out server-req.pem
```
> **Note**
> Remarquez que nous avons défini le CN serveur avec l'option -subj "/CN=192.168.1.82" 

Supprimez toute phrase secrète associée à la clé privée server-key.pem
``` bash
openssl rsa -in server-key.pem -out server-key.pem
```
Signez le certificat serveur avec le certificat d’autorité et la clé CA
``` bash
openssl x509 -req -in server-req.pem -days 365000  -CA ca-cert.pem -CAkey ca-key.pem -set_serial 01 -out server-cert.pem
```

> **Note** Vous venez de créer dans /home/<VOTRE UTILISATEUR>/ssl/ les fichiers:
> - server-cert.pem: Fichier du certificat serveur .
> - server-key: Fichier de la clé privé serveur.

## Générez la clé et le certificat client
Créez le clé client
``` bash
openssl req -newkey rsa:2048 -days 365000 -subj "/CN=Mariadb_Client" -nodes -keyout client-key.pem -out client-req.pem
```
> **Note**
> Remarquez que nous avons défini le CN client avec l'option -subj "/CN=Mariadb_Client" 

Supprimez toute phrase secrète associée à la clé privée client-key.pem
``` bash
openssl rsa -in client-key.pem -out client-key.pem
```
Signez le certificat client avec le certificat d’autorité et la clé CA
``` bash
openssl x509 -req -in client-req.pem -days 365000 -CA ca-cert.pem -CAkey ca-key.pem -set_serial 01 -out client-cert.pem
```

> **Note** Vous venez de créer dans /home/<VOTRE UTILISATEUR>/ssl/ les fichiers:
> - client-cert.pem: Fichier du certificat client .
> - client-key: Fichier de la clé privé client.
 
## Verification des certificats
``` bash
openssl verify -CAfile ca-cert.pem server-cert.pem client-cert.pem
```
## Copie des certicats et clé coté serveur
Créez un répertoire 'ssl' dans /etc/mysql
``` bash
sudo mkdir /etc/mysql/ssl/
``` 
Copiez les certicats server et CA, ainsi que la clé serveur
``` bash
sudo cp -v ./server-cert.pem /etc/mysql/ssl/server-cert.pem
sudo cp -v ./server-key.pem /etc/mysql/ssl/server-key.pem
sudo cp -v ./ca-cert.pem /etc/mysql/ssl/ca-cert.pem
```
Modifiez le propriétaire de tous les fichiers précédement copiés dans /etc/mysql/ssl pour les rendre accessible à l'utilisateur "mysql". 
``` bash
sudo chown -Rv mysql:root /etc/mysql/ssl/*
 ```
 > **WARNING** Si ces fichiers n'ont pas comme propriétaire "mysql", mariadb sera incapble de les voir et un message d'erreur vous indiquera que les certificats ne sont pas trouvés.

# Configuration de Mariadb
Logguez vous sur l'hôte serveur

 ``` bash
Mariadb -u root -p
 ```

Créez une base de données et un compte SQL
 ``` sql
CREATE DATABASE db_test ;
CREATE USER 'admin'@'%' IDENTIFIED BY 'password' REQUIRE SSL;
GRANT ALL PRIVILEGES ON db_test.* TO admin'@'%';
FLUSH PRIVILEGES ;
```
 - 'admin'@'%' signifie que l'utilisateur "admin" est autorisé à se connecter à la base de données à partir de n'importe quelle adresse IP ou nom d'hôte
  - La clause REQUIRE SSL spécifie que les connexions à ce compte doivent être établies en utilisant le protocole SSL. Si un client tente de se connecter à ce compte sans utiliser SSL ou TLS, la connexion sera refusée.  

Modifiez le fichier de configuration du serveur Mariadb
``` bash
sudo nano /etc/mysql/mariadb.conf.d/50-server.cnf
 ```
Ajoutez ces lignes dans le groupe [mysqld]
``` bash
[mysqld]
…
log_warnings=9
log_error = /var/log/mysql/error.log
...
ssl-ca = /etc/mysql/ssl/ca-cert.pem
ssl-cert = /etc/mysql/ssl/server-cert.pem
ssl-key = /etc/mysql/ssl/server-key.pem
```

Redémarrez le serveur Mariadb:
``` bash
 sudo systemctl restart mariadb.service
```

Si le serveur ne redémarre pas, lisez le message d’erreur de la commande
``` bash
sudo systemctl status mariadb.service
```
Affichez les journaux d’erreur
``` bash
cat /var/log/mysql/error.log
```
1. Vérifiez que les certificats possède bien les droits accès en 644
2. Vérifiez que les certificats aient bien comme propriétaire mysql:root
3. Vérifiez les droits d'accès du répertoire /etc/mysql/ssl

# Configuration du client
 Connectez-vous à l'hôte client
 
## Copie des certicats et clé sur le client
Nous devons récupérer 3 fichiers:
 - client-cert.pem: certificat SSL du client
 - client-key.pem: clé privée du client
 - ca-cert.pem: certificat d'autorité (CA) qui a signé le certificat du client et du serveur
 
Depuis le client, utilisez la commande scp :
``` bash
scp <UTILISATEUR>@<IP SERVEUR>:/chemin/fichier /chemin/client
```
où :
 - <UTILISATEUR> est le nom de l'utilisateur précédement créé sur le serveur
 - <IP SERVEUR> est l'adresse IP du serveur
 - /chemin/fichier est le chemin absolu du fichier sur le serveur
 - /chemin/client est le chemin local où vous souhaitez copier le fichier

Exemple :
``` bash
scp nom_utilisateur@192.168.1.100:/home/nom_utilisateur/ssl/client-cert.pem /home/utilisateur/.mysql/
scp nom_utilisateur@192.168.1.100:/home/nom_utilisateur/ssl/client-key.pem /home/utilisateur/.mysql/
scp nom_utilisateur@192.168.1.100:/home/nom_utilisateur/ssl/ca-cert.pem /home/utilisateur/.mysql/
```

Editez le fichier ~/.mysql/my.cnf
``` bash
nano ~/.mysql/my.cnf
```
Ajoutez ces lignes au groupe [client]
``` bash
#ssl
ssl-ca=/home/<VOTRE UTILISATEUR>/.mysql/ca-cert.pem
ssl-cert=/home/<VOTRE UTILISATEUR>/.mysql/client-cert.pem
ssl-key=/home/<VOTRE UTILISATEUR>/.mysql/client-key.pem
```
Testez votre configuration client
``` bash
mariadb -u admin -p -h <IP DU SERVEUR>
```

Les paramètres ssl-ca, ssl-cert et ssl-key sont maintenant renseignés par le fichier my.cnf
