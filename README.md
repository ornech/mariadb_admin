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
> "-t" toutes les connexions TCP en cours.\
> "-u" toutes les connexions UDP en cours.\
> "-l" affiche les ports à l’"écoute" pour les connexions entrantes.
> "-n" affiche les numéros de port.
> "-p" affiche le nom du processus qui utilise le port.


> **Warning**
> Mariadb est à l'écoute sur l'interface (loopback) 127.0.0.1. Les connexions distantes ne sont donc pas autorisées.
