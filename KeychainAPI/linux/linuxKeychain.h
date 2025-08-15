#ifndef LIBSECRET_BRIDGE_H
#define LIBSECRET_BRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

int store_password(const char *key, const char *password);
char *get_password(const char *key);
int delete_password(const char *key);
void free_password(char *password);

#ifdef __cplusplus
}
#endif

#endif // LIBSECRET_BRIDGE_H