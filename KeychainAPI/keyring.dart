import 'dart:io';
import '../mobinsaHttpServer.dart';
import 'linux/linuxKeychainAPI.dart';
import 'windows/windowsKeychainAPI.dart';

import 'macos/macOSKeychainAPI.dart';
String DEV_BASEDIR = !Platform.isWindows ? "${Platform.environment['HOME']}/devSTI/projApp/dart_httpServer" : "${Platform.environment['USERPROFILE']}/dart_httpServer/";

String libBaseDir = getExecutableAbsolutePath();

bool DEBUG = bool.fromEnvironment('DEBUG', defaultValue: false);
/// {@category SAFETY}
/// Classe abstraite pour intéragir avec les API trousseau de clés des OS (linux,windows,macos)
abstract class KeyringBase{

  int addPassword(String account, String service, String password);

  int updatePassword(String account, String service, String password);

  int deletePassword(String account, String service);

  String? readPassword(String account, String service);
}

/// {@category SAFETY}
/// Interface unifiée pour accéder au trousseau de clés du système d'exploitation
class Keyring {
  /// Objet permettant d'intéragir avec les API trousseau de clé, change en fonction de la plateforme
  KeyringBase? base;

  Keyring(){
    if (Platform.isMacOS){
      base = MacOSKeychainBindings();
    }
    else if (Platform.isLinux){
      base = LinuxKeychainBindings();
    }
    else if (Platform.isWindows){
      base = WindowsKeychainBindings();
    }
  }

  /// Fonction récupèrant un mot de passe donné depuis le trousseau de clé.
  ///
  /// Prends un nom de service et un nom d'utilisateur.
  ///
  /// Retourne une String si le mot de passe est trouvé, null autrement.
  String? getPassword(String service, String username){
    if (base == null){
      print("Base isn't initialized");
      return null;
    }
    String? password  = base?.readPassword(username, service);
    return password;
  }


  /// Fonction fixant un mot de passe dans le trousseau de clé.
  /// Prends un nom de service, username et mot de passe.
  /// retourne 0 si le mot de passe a été ajouté correctement
  int setPassword(String serviceName, String username, String password){
    if (base == null){
      print("KeyringBase isn't initialized properly");
      return -1;
    }
    int? result = base?.addPassword(username, serviceName, password);
    return result ?? -1;
  }

  int updatePassword(String serviceName, String username, String password){
    if (base == null){
      print("KeyringBase isn't initialized properly");
      return -1;
    }
    int? result = base?.updatePassword(username, serviceName, password);
    return result ?? -1;
  }
  
  int deletePassword(String service, String username){
    if (base == null){
      return -1;
    }
    int? result =  base?.deletePassword(username,service);
    return result ?? -1;
  }
  
}