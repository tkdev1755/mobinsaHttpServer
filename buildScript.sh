

VERSION=$1
PLATFORM=$2
ARCH=$3
libkeychainname="libkeychain.dylib"
packageName="mobinsaHttpServer"
executableName="${packageName}"
RELEASE_FOLDER="releases/$VERSION/${PLATFORM}_${ARCH}"
mkdir -p ${RELEASE_FOLDER}

dart compile exe ${packageName}.dart
cd mobinsa_web
flutter build web
cd ..

if [ "$PLATFORM" = "macos" ]; then
	mv ${packageName}.exe ${RELEASE_FOLDER}/${executableName}
	cd KeychainAPI/macos
fi
if [ "$PLATFORM" = "windows" ]; then
	$packageName="${packageName}.exe"
	mv ${packageName}.exe ${RELEASE_FOLDER}/
	cd KeychainAPI/windows
	$libkeychainname="libkeychain.dll"
fi
if [ "$PLATFORM" = "linux" ]; then
	mv ${packageName}.exe ${RELEASE_FOLDER}/${executableName}
	cd KeychainAPI/linux
	$libkeychainname="libkeychain.so"
fi
make

mv ${libkeychainname} ../../${RELEASE_FOLDER}/${libkeychainname}

cd ../../
mv mobinsa_web/build/web $RELEASE_FOLDER/ 

#Packing everything in an zip.
mkdir -p ${RELEASE_FOLDER}/unzipped

zip -r ${RELEASE_FOLDER}/mobinsaHTTPServer_v${VERSION}_${PLATFORM}.zip ${RELEASE_FOLDER}

# Cleaning up
mv -f ${RELEASE_FOLDER}/web ${RELEASE_FOLDER}/unzipped/
mv -f ${RELEASE_FOLDER}/${executableName} ${RELEASE_FOLDER}/unzipped/
mv -f ${RELEASE_FOLDER}/${libkeychainname} ${RELEASE_FOLDER}/unzipped/