import 'dart:ffi';
import '../keyring.dart';
import '../../extensions.dart';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

typedef CStorePassword = Int32 Function(Pointer<Utf8>, Pointer<Utf8>);
typedef CGetPassword = Pointer<Utf8> Function(Pointer<Utf8>);
typedef CFreePassword = Void Function(Pointer<Utf8>);

typedef DartStorePassword = int Function(Pointer<Utf8>, Pointer<Utf8>);
typedef DartGetPassword = Pointer<Utf8> Function(Pointer<Utf8>);
typedef DartFreePassword = void Function(Pointer<Utf8>);

typedef CDeletePassword = Int32 Function(Pointer<Utf8>);
typedef DartDeletePassword = int Function(Pointer<Utf8>);
/// {@category SAFETY}
/// Interface FFI (Foreign Function Interface) permettant d'intéragir avec une librairie dynamique C (Ici le GNOME-SECRET de GNU/Linux)
class LinuxKeychainBindings extends KeyringBase {
  late final DartStorePassword _storePassword;
  late final DartGetPassword _getPassword;
  late final DartFreePassword _freePassword;
  late final DartDeletePassword _deletePassword;

  LinuxKeychainBindings() {
    final _lib = DynamicLibrary.open(path.join(path.current,'libkeychain.so'));

    _storePassword = _lib
        .lookup<NativeFunction<CStorePassword>>('store_password')
        .asFunction();

    _getPassword = _lib
        .lookup<NativeFunction<CGetPassword>>('get_password')
        .asFunction();

    _deletePassword = _lib
        .lookup<NativeFunction<CDeletePassword>>('delete_password')
        .asFunction();

    _freePassword = _lib
        .lookup<NativeFunction<CFreePassword>>('free_password')
        .asFunction();
  }



  @override
  int addPassword(String account, String service, String password) {
    final keyPtr = account.toNativeUtf8();
    final passwordPtr = password.toNativeUtf8();

    final result = _storePassword(keyPtr, passwordPtr);

    malloc.free(keyPtr);
    malloc.free(passwordPtr);

    return result;
  }

  @override
  String? readPassword(String account, String service) {
    final keyPtr = account.toNativeUtf8();
    final resultPtr = _getPassword(keyPtr);
    malloc.free(keyPtr);
    if (resultPtr == nullptr) return null;

    final result = resultPtr.toDartString();
    _freePassword(resultPtr);
    return result;
  }

  @override
  int deletePassword(String account, String service) {
    final keyPtr = account.toNativeUtf8();
    final result = _deletePassword(keyPtr);
    malloc.free(keyPtr);
    return result;
  }

  // Same as windows, Linux doesn't need to 'update' the password if it already exists in the keychain, so just calling the addpassword function
  @override
  int updatePassword(String account, String service, String password) {
    int res = addPassword(account, service, password);
    return res;
  }
}