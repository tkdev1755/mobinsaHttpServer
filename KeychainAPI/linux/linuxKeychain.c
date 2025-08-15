#include "linuxKeychain.h"
#include <libsecret/secret.h>
#include <string.h>
#include <stdio.h>
#define SCHEMA_NAME "com.celeneManager.userInfo"
#define ATTRIBUTE_KEY "celeneManager UserInfo"

static const SecretSchema *get_schema() {
    static const SecretSchema schema = {
            SCHEMA_NAME,
            SECRET_SCHEMA_NONE,
            {
                    { ATTRIBUTE_KEY, SECRET_SCHEMA_ATTRIBUTE_STRING },
                    { NULL, 0 }
            }
    };
    return &schema;
}

int store_password(const char *key, const char *password) {
    int result = secret_password_store_sync(
            get_schema(),
            SECRET_COLLECTION_DEFAULT,
            "CeleneManager Credentials",
            password,
            NULL,  // GCancellable
            NULL,  // GError**
            ATTRIBUTE_KEY, key,
            NULL);
    return result == 1 ? 0 : -1;
}

char *get_password(const char *key) {
    gchar *retrieved = secret_password_lookup_sync(
            get_schema(),
            NULL,
            NULL,
            ATTRIBUTE_KEY, key,
            NULL);

    if (retrieved == NULL) {
        return NULL;
    }

    // On copie le mot de passe pour pouvoir le libérer depuis Dart
    char *result = strdup(retrieved);
    secret_password_free(retrieved);
    return result;
}

int delete_password(const char *key) {
    GError *error = NULL;
    gboolean res = secret_password_clear_sync(
            get_schema(),
            NULL,  // GCancellable
            &error,  // GError**
            ATTRIBUTE_KEY, key,
            NULL
    );
    if (error != NULL){
        printf("Unable to delete password: %s\n", error->message);
        g_error_free(error);
    }
    if (res) {return 0;}
    else{ return -1;}

}

void free_password(char *password) {
    free(password);
}

/*int main(int argc, char *argv[]) {
    char* pwd = get_password("taka");
    printf("PWD is %s",pwd);
    return EXIT_SUCCESS;
}*/