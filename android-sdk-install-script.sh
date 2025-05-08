#!/bin/bash

set -e

# Default directory for SDK installation
DEFAULT_SDK_DIR="$HOME/.android"
read -p "Enter the directory to install the Android SDK [$DEFAULT_SDK_DIR]: " SDK_DIR
SDK_DIR=${SDK_DIR:-$DEFAULT_SDK_DIR}
export ANDROID_HOME="$SDK_DIR"
mkdir -p "$ANDROID_HOME"

echo "ANDROID_HOME set to $ANDROID_HOME"

# Detect user's shell
USER_SHELL=$(basename "$SHELL")
echo "Detected shell: $USER_SHELL"

# Check and install OpenJDK if not present
if ! command -v javac >/dev/null 2>&1; then
    echo "OpenJDK not found. Installing OpenJDK..."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo apt update && sudo apt install -y openjdk-11-jdk
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew install openjdk@11
    else
        echo "Unsupported OS. Please install OpenJDK manually."
        exit 1
    fi
else
    echo "OpenJDK already installed."
fi

# Set JAVA_HOME
JAVA_HOME_PATH=$(dirname $(dirname $(readlink -f $(which javac))))
export JAVA_HOME="$JAVA_HOME_PATH"
echo "JAVA_HOME set to $JAVA_HOME"

# Download Android SDK Command Line Tools
SDK_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
SDK_TOOLS_DIR="$ANDROID_HOME/cmdline-tools"

if [[ "$OSTYPE" == "darwin"* ]]; then
    SDK_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-mac-11076708_latest.zip"
fi

echo "Downloading Android SDK command line tools..."
mkdir -p "$SDK_TOOLS_DIR"
curl -o /tmp/commandlinetools.zip "$SDK_TOOLS_URL"
unzip -q /tmp/commandlinetools.zip -d /tmp/cmdline-tools-temp

# Move to correct structure expected by SDK
mkdir -p "$SDK_TOOLS_DIR/latest"
mv /tmp/cmdline-tools-temp/cmdline-tools/* "$SDK_TOOLS_DIR/latest"
rm -rf /tmp/commandlinetools.zip /tmp/cmdline-tools-temp

# Set PATHs for current session
echo "Setting PATH to add the cmdline-tools directory..."
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

# Accept licenses and install base packages
yes | sdkmanager --licenses
sdkmanager "platform-tools" "platforms;android-33" "build-tools;33.0.2"

# Ask to install emulator & system image
read -p "Do you want to set up an Android Virtual Device (AVD)? (y/n): " SETUP_AVD
if [[ "$SETUP_AVD" =~ ^[Yy]$ ]]; then
    sdkmanager "emulator" "system-images;android-33;google_apis;x86_64"
    echo "Creating AVD named Pixel_3a_API_33..."
    echo "no" | avdmanager create avd -n Pixel_3a_API_33 -k "system-images;android-33;google_apis;x86_64" --device "pixel_3a"
    echo "AVD setup complete."
fi

# Update user shell config
case "$USER_SHELL" in
    bash)
        SHELL_CONFIG="$HOME/.bashrc"
        ;;
    zsh)
        SHELL_CONFIG="$HOME/.zshrc"
        ;;
    fish)
        SHELL_CONFIG="$HOME/.config/fish/config.fish"
        ;;
    *)
        echo "Unknown shell. Please manually add environment variables to your shell config."
        exit 0
        ;;
esac

echo "Updating $SHELL_CONFIG..."

if [[ "$USER_SHELL" == "fish" ]]; then
    echo "set -x ANDROID_HOME \"$ANDROID_HOME\"" >> "$SHELL_CONFIG"
    echo "set -x JAVA_HOME \"$JAVA_HOME\"" >> "$SHELL_CONFIG"
    echo "set -x PATH \$ANDROID_HOME/cmdline-tools/latest/bin \$ANDROID_HOME/platform-tools \$ANDROID_HOME/emulator \$PATH" >> "$SHELL_CONFIG"
else
    echo "export ANDROID_HOME=\"$ANDROID_HOME\"" >> "$SHELL_CONFIG"
    echo "export JAVA_HOME=\"$JAVA_HOME\"" >> "$SHELL_CONFIG"
    echo "export PATH=\"\$ANDROID_HOME/cmdline-tools/latest/bin:\$ANDROID_HOME/platform-tools:\$ANDROID_HOME/emulator:\$PATH\"" >> "$SHELL_CONFIG"
fi

echo ""
echo "Installation complete."
echo "Your environment has been updated in $SHELL_CONFIG."
echo "Restart your terminal or run 'source $SHELL_CONFIG' to apply changes."
if [[ "$SETUP_AVD" =~ ^[Yy]$ ]]; then
    echo "You can launch the emulator with: emulator -avd Pixel_3a_API_33"
fi
