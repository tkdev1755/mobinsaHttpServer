import 'dart:ffi';
import 'dart:io';
import '../keyring.dart';
import '../../extensions.dart';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

typedef CUpdatePassword = Int32 Function(
    Pointer<Utf8> account,
    Pointer<Utf8> service,
    Pointer<Utf8> newPassword
    );

typedef DartUpdatePassword = int Function(
    Pointer<Utf8> account,
    Pointer<Utf8> service,
    Pointer<Utf8> newPassword
    );

typedef CDeletePassword = Int32 Function(
    Pointer<Utf8> account,
    Pointer<Utf8> service
    );

typedef DartDeletePassword = int Function(
    Pointer<Utf8> account,
    Pointer<Utf8> service
    );

typedef CAddPassword = Int32 Function(
    Pointer<Utf8> account,
    Pointer<Utf8> service,
    Pointer<Utf8> password,
    );

typedef DartAddPassword = int Function(
    Pointer<Utf8> account,
    Pointer<Utf8> service,
    Pointer<Utf8> password,
    );
typedef CReadPassword = Pointer<Utf8> Function(
    Pointer<Utf8> account,
    Pointer<Utf8> service,
    );

typedef DartReadPassword = Pointer<Utf8> Function(
    Pointer<Utf8> account,
    Pointer<Utf8> service,
    );

typedef CFreePassword = Void Function(Pointer<Utf8>);
typedef DartFreePassword = void Function(Pointer<Utf8>);
/// {@category SAFETY}
/// Interface FFI (Foreign Function Interface) permettant d'intéragir avec une librairie dynamique C (Ici le Trousseau de clé)
class MacOSKeychainBindings extends KeyringBase{

  late final DynamicLibrary _lib;
  late final DartAddPassword _addPassword;
  late final DartReadPassword _readPassword;
  late final DartFreePassword _freePassword;
  late final DartUpdatePassword _updatePassword;
  late final DartDeletePassword _deletePassword;
  MacOSKeychainBindings() {
    final libPath = Platform.isMacOS ? path.join(path.current,'libkeychain.dylib')
    : throw UnsupportedError("macOS only");
    _lib = DynamicLibrary.open(libPath);

    _addPassword = _lib
        .lookup<NativeFunction<CAddPassword>>('add_password')
        .asFunction();

    _readPassword = _lib
        .lookup<NativeFunction<CReadPassword>>('read_password')
        .asFunction();
    _updatePassword = _lib
        .lookup<NativeFunction<CUpdatePassword>>('update_password')
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
    final accountPtr = account.toNativeUtf8();
    final servicePtr = service.toNativeUtf8();
    final passwordPtr = password.toNativeUtf8();

    final result = _addPassword(accountPtr, servicePtr, passwordPtr);
    logger("Added password with result : $result");
    malloc.free(accountPtr);
    malloc.free(servicePtr);
    malloc.free(passwordPtr);

    return result;
  }

  @override
  String? readPassword(String account, String service) {
    final acc = account.toNativeUtf8();
    final srv = service.toNativeUtf8();

    final ptr = _readPassword(acc, srv);
    malloc.free(acc);
    malloc.free(srv);
    logger("ptr is ${ptr}");
    if (ptr.address == 0) return null;
    final result = ptr.toDartString();
    _freePassword(ptr);

    return result;
  }

  @override
  int deletePassword(String account, String service) {

    final acc = account.toNativeUtf8();
    final srv = service.toNativeUtf8();

    final result = _deletePassword(acc, srv);
    malloc.free(acc);
    malloc.free(srv);

    return result;
  }

  @override
  int updatePassword(String account, String service, String password) {
    final accountPtr = account.toNativeUtf8();
    final servicePtr = service.toNativeUtf8();
    final passwordPtr = password.toNativeUtf8();
    final res1 = _deletePassword(accountPtr,servicePtr);

    final result = _addPassword(accountPtr, servicePtr, passwordPtr);
    logger("Added password with result : $result");
    malloc.free(accountPtr);
    malloc.free(servicePtr);
    malloc.free(passwordPtr);

    return result;

  }
}