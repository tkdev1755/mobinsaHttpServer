import 'dart:io';

import 'package:basic_utils/basic_utils.dart';


Future<bool> checkForCertificate() async{
  if (!File("cert.pem").existsSync() || !File("key.pem").existsSync()){
    return false;
  }
  try{
    SecurityContext? context = SecurityContext()
      ..useCertificateChain('cert.pem') // certificat (ou chaîne complète)
      ..usePrivateKey('key.pem');
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
  File('cert.pem').writeAsStringSync(x509PEM);
  File('key.pem').writeAsStringSync(keyPem);

  print('Certificat généré avec basic_utils :');
  print('- cert.pem');
  print('- key.pem');
}