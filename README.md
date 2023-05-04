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
## Installez et configurez ssh sur le serveur

Un peu plus loin, nous aurons besoin de transférer la clé client et des certificats du serveur vers le client. Pour cela on utilisera la commande scp (Secure CoPy) qui fait partie des outils livrés avec open-ssh

 - Site : https://www.openssh.com
 - Documentation : https://www.openssh.com/manual.html

Installez le serveur Open-SSH
``` bash
sudo apt-get update
sudo apt-get install openssh-server
```
Créez un compte système pour le transfert de fichier

sudo adduser nom_utilisateur

### Configurez SSH
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

Si vous tentez un connexino depuis le client au serveur Mariadb
``` bash
ERROR 2002 (HY000): Can't connect to server on '172.16.254.151' (115)
```
https://mariadb.com/kb/en/mariadb-error-codes/
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

