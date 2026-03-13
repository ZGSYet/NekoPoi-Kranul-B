#!/bin/bash
#
# Compile script for kernel
#

set -e
SECONDS=0

# --- TELEGRAM CONFIG ---
TG_TOKEN="8647652050:AAG0ZKtMuE4NhlOKx8EHz4VHfgPLlguMTqw"
TG_CHAT_ID="7540957411"

send_tg() {
  curl -s -X POST https://api.telegram.org/bot$TG_TOKEN/sendMessage \
  -d chat_id=$TG_CHAT_ID \
  -d "text=$1" >/dev/null
}

# --- Helper Functions ---

check_variables() {
if [ "$KSU_BASE" ]; then
  echo "KSU_BASE is set to: $KSU_BASE"
  send_tg "ℹ️ KSU_BASE set: $KSU_BASE"
else
  echo "KSU_BASE is not set."
fi
}

setup_environment() {
  echo "Setting up build environment..."
  send_tg "⚙️ Setting up build environment..."

  export ARCH=arm64
  export KBUILD_BUILD_USER=vbajs
  export KBUILD_BUILD_HOST=tbyool

  export GCC64_DIR=$PWD/gcc64
  export GCC32_DIR=$PWD/gcc32
}

setup_toolchain() {
  echo "Setting up toolchains..."
  send_tg "⬇️ Preparing toolchains..."

  # Setup Clang
  if [ ! -d "$PWD/clang" ]; then
    echo "Cloning Clang..."
    send_tg "📥 Cloning Clang toolchain..."
    git clone https://gitlab.com/crdroidandroid/android_prebuilts_clang_host_linux-x86_clang-r547379.git --depth=1 -b 15.0 clang
  else
    echo "Local clang dir found, using it."
  fi

  # Setup GCC
  if [ ! -d "$PWD/gcc32" ] && [ ! -d "$PWD/gcc64" ]; then
    echo "Downloading GCC..."
    send_tg "📥 Downloading Eva GCC..."

    ASSET_URLS=$(curl -s "https://api.github.com/repos/mvaisakh/gcc-build/releases/latest" | grep "browser_download_url" | cut -d '"' -f 4 | grep -E "eva-gcc-arm.*\.xz")
    for url in $ASSET_URLS; do
      wget --content-disposition -L "$url"
    done
    
    for file in eva-gcc-arm*.xz; do
      if [[ "$file" == *arm64* ]]; then
        tar -xf "$file" && mv gcc-arm64 gcc64
      else
        tar -xf "$file" && mv gcc-arm gcc32
      fi
      rm -rf "$file"
    done
  else
    echo "Local gcc dirs found, using them."
  fi
}

update_path() {
  echo "Updating PATH..."
  export PATH="$PWD/clang/bin/:$GCC64_DIR/bin/:$GCC32_DIR/bin/:/usr/bin:$PATH"
}

compile_kernel() {
  echo -e "\nStarting compilation..."
  send_tg "🔨 Kernel compilation started..."

  make O=out ARCH=arm64 courbet_defconfig

  if [ "$KSU_BASE" ]; then
    make O=out ARCH=arm64 vendor/$KSU_BASE.config
  fi

  make -j$(nproc --all) \
    O=out \
    ARCH=arm64 \
    LLVM=1 \
    LLVM_IAS=1 \
    CROSS_COMPILE=$GCC64_DIR/bin/aarch64-elf- \
    CROSS_COMPILE_COMPAT=$GCC32_DIR/bin/arm-eabi-
}

package_output() {
  echo -e "\nPackaging outputs..."
  
  local kernel="out/arch/arm64/boot/Image"
  local dtbo="out/arch/arm64/boot/dtbo.img"
  local dtb="out/arch/arm64/boot/dtb.img"

  if [ ! -f "$kernel" ] || [ ! -f "$dtbo" ] || [ ! -f "$dtb" ]; then
    echo -e "\nCompilation failed! Output files not found."
    send_tg "❌ Kernel build failed!"
    exit 1
  fi

  if [ "$KSU_BASE" ]; then
  cp "$kernel" "./$KSU_BASE-Image"
  else
  cp "$kernel" "./Image"
  fi

  cp "$dtbo" "./dtbo.img"
  cp "$dtb" "./dtb.img"

  echo "Outputs copied to root directory with prefix '$KSU_BASE'"
  send_tg "📦 Kernel outputs generated successfully."
}

print_summary() {
  BUILD_TIME="$((SECONDS / 60))m $((SECONDS % 60))s"

  echo -e "\nCompleted in $BUILD_TIME !"

  send_tg "✅ Kernel build finished
⏱ Time: $BUILD_TIME
📱 Device: courbet
👤 Builder: $KBUILD_BUILD_USER"
}

# --- Main Execution ---

main() {

  send_tg "🚀 Kernel build started
Device: courbet
Host: $KBUILD_BUILD_HOST"

  check_variables
  setup_environment
  setup_toolchain
  update_path
  compile_kernel
  package_output
  print_summary
}

main
