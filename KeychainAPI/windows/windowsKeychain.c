#include <windows.h>
#include <wincred.h>
#include <wchar.h>
#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>
// Export de fonctions en C standard
#ifdef _WIN32
#define EXPORT __declspec(dllexport)
#else
#define EXPORT
#endif

// Fonction FFI : Enregistrer un mot de passe
EXPORT bool set_password(const wchar_t* targetName, const wchar_t* username, const wchar_t* password) {
    DWORD passwordSize = (DWORD)(wcslen(password) * sizeof(wchar_t));

    CREDENTIALW credential = {0};
    credential.Type = CRED_TYPE_GENERIC;
    credential.TargetName = (LPWSTR)targetName;
    credential.CredentialBlobSize = passwordSize;
    credential.CredentialBlob = (LPBYTE)password;
    credential.Persist = CRED_PERSIST_LOCAL_MACHINE;
    credential.UserName = (LPWSTR)username;

    return CredWriteW(&credential, 0);
}

// Fonction FFI : Lire un mot de passe (résultat écrit dans le buffer passé en argument)
EXPORT bool read_password(const wchar_t* targetName, wchar_t* outPassword, int maxLen) {
    PCREDENTIALW pCredential = NULL;
    //printf("Credential are %c", targetName);
    if (CredReadW(targetName, CRED_TYPE_GENERIC, 0, &pCredential)) {
        int len = pCredential->CredentialBlobSize / sizeof(wchar_t);

        if (len >= maxLen) {
            //printf("Password is longer than the original");
            CredFree(pCredential);
            return false;
        }
        wcsncpy(outPassword, (const wchar_t*)pCredential->CredentialBlob, len);
        outPassword[len] = L'\0';
        CredFree(pCredential);
        //printf("Password found !");
        return true;
    }
    //printf("Password not found");
    return false;
}

EXPORT bool delete_password(const wchar_t* targetName) {
    return CredDeleteW(targetName, CRED_TYPE_GENERIC, 0);
}

/*int main(int argc, char *argv[]) {
    //bool result = set_password(L"appDartCli", L"userName", L"PASWOOOOOOOOOOORD");
    /*if (result){
        printf("Password set succesfully");
    }
    wchar_t password[2048];
    // bzero(password);
    bool result2 = read_password(L"celene202", password, 2048);
    //printf("Password is %s", password);
    return EXIT_SUCCESS;
}*/