#!/usr/bin/env bash
#
# Skrip setup signing rilis Android untuk proyek Sing Stream Karaoke.
#
# Yang dilakukan skrip ini:
#   1. Membuat keystore upload baru (android/upload-keystore.jks).
#   2. Menulis file android/key.properties untuk dibaca build.gradle.kts.
#   3. Mengekspor sertifikat publik baru (.der dan .pem) ke folder certificates.
#
# Password diminta secara interaktif dan tidak pernah ditulis ke dalam skrip,
# sehingga tetap rahasia. Jalankan dari mana saja:
#
#   bash android/setup_signing.sh
#
set -euo pipefail

# --- Lokasi proyek (root = folder induk dari direktori android) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

KEYSTORE="$PROJECT_DIR/android/upload-keystore.jks"
KEY_PROPERTIES="$PROJECT_DIR/android/key.properties"
CERT_DIR="${CERT_DIR:-/home/padikering/Downloads/certificates}"

ALIAS="upload"
STORE_TYPE="JKS"
KEY_ALG="RSA"
KEY_SIZE="2048"
VALIDITY="10000"

# Identitas mengikuti sertifikat lama (upload_cert.der) agar konsisten.
DNAME="CN=padi kering, OU=tomsi music, O=tomsi music, L=gowa, ST=sulawesi selatan, C=62"

echo "== Setup Signing Android =="
echo "Keystore   : $KEYSTORE"
echo "Properties : $KEY_PROPERTIES"
echo "Cert out   : $CERT_DIR"
echo

if [[ -f "$KEYSTORE" ]]; then
  read -rp "Keystore sudah ada. Timpa? [y/N] " ans
  [[ "${ans,,}" == "y" ]] || { echo "Dibatalkan."; exit 1; }
fi

# --- Minta password (tidak ditampilkan) ---
while true; do
  read -rsp "Masukkan password keystore/key: " PW1; echo
  read -rsp "Ulangi password            : " PW2; echo
  if [[ -z "$PW1" ]]; then
    echo "Password tidak boleh kosong."
  elif [[ "$PW1" != "$PW2" ]]; then
    echo "Password tidak sama, coba lagi."
  else
    break
  fi
done

if ! command -v keytool >/dev/null 2>&1; then
  echo "ERROR: 'keytool' tidak ditemukan. Pastikan JDK terpasang." >&2
  exit 1
fi

mkdir -p "$(dirname "$KEYSTORE")"
mkdir -p "$CERT_DIR"

echo
echo ">> Membuat keystore..."
keytool -genkeypair -v \
  -keystore "$KEYSTORE" \
  -storetype "$STORE_TYPE" \
  -alias "$ALIAS" \
  -keyalg "$KEY_ALG" \
  -keysize "$KEY_SIZE" \
  -validity "$VALIDITY" \
  -dname "$DNAME" \
  -storepass "$PW1" -keypass "$PW1" \
  -noprompt

echo
echo ">> Menulis key.properties..."
cat > "$KEY_PROPERTIES" <<EOF
keyAlias=$ALIAS
keyPassword=$PW1
storePassword=$PW1
storeFile=../upload-keystore.jks
EOF
chmod 600 "$KEY_PROPERTIES" "$KEYSTORE" || true

echo
echo ">> Mengekspor sertifikat publik..."
keytool -exportcert -rfc -keystore "$KEYSTORE" -alias "$ALIAS" \
  -storepass "$PW1" -file "$CERT_DIR/upload_cert_new.pem"
keytool -exportcert -keystore "$KEYSTORE" -alias "$ALIAS" \
  -storepass "$PW1" -file "$CERT_DIR/upload_cert_new.der"

unset PW1 PW2

echo
echo ">> Verifikasi fingerprint:"
keytool -list -v -keystore "$KEYSTORE" -alias "$ALIAS" -storepass "$(grep '^storePassword=' "$KEY_PROPERTIES" | cut -d= -f2-)" 2>/dev/null | grep -E "SHA1|SHA256|Alias|Valid"

echo
echo "SELESAI."
echo "- Keystore    : $KEYSTORE"
echo "- Properties  : $KEY_PROPERTIES"
echo "- Sertifikat  : $CERT_DIR/upload_cert_new.pem & .der"
echo
echo "PENTING: simpan keystore + password di tempat aman. Untuk reset upload key"
echo "di Google Play Console, unggah file upload_cert_new.pem."
