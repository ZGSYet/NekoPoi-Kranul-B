#!/bin/bash

# --- KONFIGURASI TELEGRAM ---
TG_TOKEN="8647652050:AAG0ZKtMuE4NhlOKx8EHz4VHfgPLlguMTqw"
TG_CHAT_ID="7540957411"
# ----------------------------

SECONDS=0 
DEVICE="courbet"
export ARCH=arm64
export KBUILD_BUILD_USER=esteh
export KBUILD_BUILD_HOST=TUF-FA5093

# Direktori Toolchain
export GCC64_DIR="$PWD/gcc64"
export GCC32_DIR="$PWD/gcc32"

# --- FUNGSI TOOLCHAIN ---
setup_toolchain() {
  echo "Setting up toolchains..."

  # Setup Clang (crdroid 15.0)
  if [ ! -d "$PWD/clang" ]; then
    echo "Cloning Clang..."
    git clone https://gitlab.com/crdroidandroid/android_prebuilts_clang_host_linux-x86_clang-r547379.git --depth=1 -b 15.0 clang
  else
    echo "Local clang dir found, using it."
  fi

  # Setup GCC (Eva GCC)
  if [ ! -d "$GCC32_DIR" ] || [ ! -d "$GCC64_DIR" ]; then
    echo "Downloading GCC..."
    ASSET_URLS=$(curl -s "https://api.github.com/repos/mvaisakh/gcc-build/releases/latest" | grep "browser_download_url" | cut -d '"' -f 4 | grep -E "eva-gcc-arm.*\.xz")
    for url in $ASSET_URLS; do
      wget -q --content-disposition -L "$url"
    done
    
    for file in eva-gcc-arm*.xz; do
      if [[ "$file" == *arm64* ]]; then
        mkdir -p "$GCC64_DIR"
        tar -xf "$file" -C "$GCC64_DIR" --strip-components=1
      else
        mkdir -p "$GCC32_DIR"
        tar -xf "$file" -C "$GCC32_DIR" --strip-components=1
      fi
      rm -f "$file"
    done
  else
    echo "Local gcc dirs found, using them."
  fi
}

update_path() {
  echo "Updating PATH..."
  # Menempatkan Clang dan GCC di urutan terdepan PATH
  export PATH="$PWD/clang/bin/:$GCC64_DIR/bin/:$GCC32_DIR/bin/:$PATH"
}

# --- FUNGSI TELEGRAM ---
tg_send_sticky() {
    res=$(curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
        -d chat_id="$TG_CHAT_ID" \
        -d text="$1" \
        -d parse_mode="Markdown")
    MESSAGE_ID=$(echo $res | grep -oP '(?<="message_id":)\d+')
}

tg_update() {
    curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/editMessageText" \
        -d chat_id="$TG_CHAT_ID" \
        -d message_id="$MESSAGE_ID" \
        -d text="$1" \
        -d parse_mode="Markdown" > /dev/null
}

tg_send_log() {
    curl -F document=@"error.log" \
         -F chat_id="$TG_CHAT_ID" \
         -F caption="$1" \
         -F parse_mode="Markdown" \
         "https://api.telegram.org/bot$TG_TOKEN/sendDocument"
}

# --- MULAI PROSES ---
echo "KUDA ASELI NAIL KUDA BESI"

# Jalankan persiapan toolchain
setup_toolchain
update_path

tg_send_sticky "🛠 **Kernel Build Update**
📱 **Device**: \`$DEVICE\`
👤 **User**: \`$KBUILD_BUILD_USER\`
⏳ **Status**: nyapu lingkungan..."

# 1. Step: Cleaning
if [[ $1 = "-c" || $1 = "--clean" ]]; then
    tg_update "🛠 **Kernel Build Update**
⏳ **Status**: resik-resik folder out..."
    rm -rf out
    rm -f error.log
fi

# 2. Step: Config
tg_update "🛠 **Kernel Build Update**
⏳ **Status**: delok \`${DEVICE}_defconfig\`..."
make O=out ARCH=arm64 ${DEVICE}_defconfig

# 3. Step: Compiling
tg_update "🛠 **Kernel Build Update**
⏳ **Status**: Sedang Kompilasi (Mengebut dengan Ninja 2T Olsam Motul... ⚡"

# Menjalankan kompilasi dengan instruksi baru Anda
make -j$(nproc --all) \
    O=out \
    ARCH=arm64 \
    LLVM=1 \
    LLVM_IAS=1 \
    CROSS_COMPILE=$GCC64_DIR/bin/aarch64-elf- \
    CROSS_COMPILE_COMPAT=$GCC32_DIR/bin/arm-eabi- 2> error.log

kernel="out/arch/arm64/boot/Image.gz"
dtbo="out/arch/arm64/boot/dtbo.img"
dtb="out/arch/arm64/boot/dtb.img"

# Cek Gagal
if [ ! -f "$kernel" ]; then
    tg_update "❌ **Anjir Gagal cok**
Cek log sing dikirim ngisor iki gus."
    tg_send_log "❌ **Build Error Log**
📱 Device: \`$DEVICE\`
🛠 Kompilasi mandeg nek kene."
    exit 1
fi

# 4. Step: Zipping
ZIPNAME="${DEVICE}-$(date '+%Y%m%d-%H%M').zip"
tg_update "🛠 **Kernel Build Update**
⏳ **Status**: Sek ngebungkus (Zipping)..."
[ -d "AnyKernel3" ] && rm -rf AnyKernel3
git clone -q https://github.com/basamaryan/AnyKernel3 -b master AnyKernel3
sed -i "s/device\.name1=.*/device.name1=${DEVICE}/" AnyKernel3/anykernel.sh
sed -i "s/device\.name2=.*/device.name2=${DEVICE}in/" AnyKernel3/anykernel.sh
cp $kernel AnyKernel3/
[ -f "$dtbo" ] && cp $dtbo AnyKernel3/
[ -f "$dtb" ] && cp $dtb AnyKernel3/

cd AnyKernel3
zip -r9 "../$ZIPNAME" * -x .git
cd ..
rm -rf AnyKernel3

# 5. Step: Final (Kirim File)
DURATION="$((SECONDS / 60)) menit $((SECONDS % 60)) detik"
tg_update "🛠 **Kernel Build Update**
✅ **Status**: Sampe gus $DURATION! Sek upload gus.."

curl -F document=@"$ZIPNAME" \
     -F chat_id="$TG_CHAT_ID" \
     -F caption="✅ **Allhamdullilah!**
📦 **File**: \`$ZIPNAME\`
⏱ **Durasi**: $DURATION
👤 **User**: $KBUILD_BUILD_USER" \
     -F parse_mode="Markdown" \
     "https://api.telegram.org/bot$TG_TOKEN/sendDocument"

echo -e "\nSelesai!"
