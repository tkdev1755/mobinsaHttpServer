# MobINSA HTTP Server

# Quel est le but de ce programme ?

- Donner accès au site collaboratif de mob'INSA et transmettre les informations nécessaires au programme Maitre mobinsa
- Gérer l'authentification des utilisateurs sur la plateforme

# Quelles fonctionnalités ?

✅ -  Site Mobinsa collaboratif servi en HTTPS

✅ -  Mises à jour en temps réel des statistiques de la séances



# Fonctionnement du programme

- Une fois le programme ouvert, celui-ci ouvre 2 sockets 
- Une sert à communiquer avec le programme maitre (Mobinsa.exe/Mobinsa.app/Mobinsa) sur le port 7070 et l'adresse IP 127.0.0.1 
- L'autre sert à servir le site web mobinsa_web (code source dans le dossier mobinsa_web du repo) en HTTPS sur le port 8080 et l'adresse de la première interface réseau ayant une adresse
- La communication avec le programme maitre sont faites à l'aide de messages envoyés à l'aide du protocole TCP
- La communication avec le client web elle est faite à travers de messages à l'aide de WebSockets
- Les clés importantes (clé JWT, clé certificat X509 auto-signé) sont stockées dans le trousseau de clés de votre système, à l'aide de la librairie libkeychain.dll/.so/.dylib (Code source au dans le dossier KeychainAPI à la racine du repo)

# Arborescence du repo
- mobinsaHttpServer.dart : Code source du serveur http, avec les fonctions pour communiquer avec le programme maitre et le client web

# Questions fréquentes

- > Pourquoi il y’a des fichiers `.dll`, `.dylib`, `.so` avec le binaire ?
    - Le langage de programmation utilisé (Dart) ne possède pas de librairie donnant accès au trousseau de clé du système d’exploitation, par conséquent j’ai du développer une "librairie" en C pour interagir avec le trousseau de clés, plus de détail sont donnés dans le wiki. Tout le code source de la « librairie » C est disponible sur le github dans le dossier lib/model/KeychainAPI/${votre_système_d’exploitation}/${votre_système_d’exploitation}keychainAPI.c




