import 'dart:io';

import 'package:basic_utils/basic_utils.dart';

import 'mobinsaHttpServer.dart';



String certPath = Platform.isMacOS ? "${getExecutableAbsolutePath()}/cert.pem": "cert.pem";
String keyPath = Platform.isMacOS ? "${getExecutableAbsolutePath()}/key.pem": "key.pem";

Future<bool> checkForCertificate() async{
  if (!File(certPath).existsSync() || !File(keyPath).existsSync()){
    return false;
  }
  try{
    SecurityContext? context = SecurityContext()
      ..useCertificateChain(keyPath) // certificat (ou chaîne complète)
      ..usePrivateKey(certPath);
    context = null;
    return true;
  }
  catch (e,s){
    return false;
  }
  return true;

}
Future<void> generateCertificateWithBasicUtils() async {
  if (await checkForCertificate()){
    print("Certificate already exists");
    return;
  }
  // Générer une paire de clés RSA
  final keyPair = CryptoUtils.generateRSAKeyPair(keySize: 2048);
  final secondKeyPair = CryptoUtils.generateEcKeyPair();
  // Créer les informations du certificat
  final dn = {
    'CN': 'localhost',
    'O': "Mob'INSA Software",
    'C': 'FR',
  };
  var privKey = secondKeyPair.privateKey as ECPrivateKey;
  var pubKey = secondKeyPair.publicKey as ECPublicKey;
  // Créer le certificat auto-signé

  final csr = X509Utils.generateEccCsrPem(dn, privKey, pubKey);
  // Convertir en format PEM
  var x509PEM = X509Utils.generateSelfSignedCertificate(secondKeyPair.privateKey, csr, 365);
  final keyPem = CryptoUtils.encodeEcPrivateKeyToPem(secondKeyPair.privateKey as ECPrivateKey);
  // Sauvegarder les fichiers
  // Saving the cert.pem file
  File(certPath).writeAsStringSync(x509PEM);
  // Saving the key.pem file
  File(keyPath).writeAsStringSync(keyPem);

  print('Certificat généré avec basic_utils :');
  print('- cert.pem');
  print('- key.pem');
}