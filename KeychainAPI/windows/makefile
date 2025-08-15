# Nom des fichiers
SRC = windowsKeychain.c
TARGET = libkeychain.dll

# Options de compilation
CC = gcc
CFLAGS = -Wall -Wextra -O2
LDFLAGS = -shared -lAdvapi32
IMPLIB = -Wl,--out-implib,libkeychain.a

# Règle principale
all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) $(SRC) -o $(TARGET) $(LDFLAGS) $(IMPLIB)

# Nettoyage
clean:
	del /f /q $(TARGET) libkeychain.a