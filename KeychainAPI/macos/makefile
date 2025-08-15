# Nom de la bibliothèque
LIB_NAME = libkeychain.dylib

# Fichiers source C
SRC = macOSKeychain.c

# Options de compilation
CFLAGS = -dynamiclib
LDFLAGS = -framework Security -framework CoreFoundation

# Commande de compilation
CC = clang

# Règle par défaut
all: $(LIB_NAME)

# Construction de la dylib
$(LIB_NAME): $(SRC)
	$(CC) $(CFLAGS) $(SRC) $(LDFLAGS) -o $(LIB_NAME)

# Nettoyage des fichiers générés
clean:
	rm -f $(LIB_NAME)