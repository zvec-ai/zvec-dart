#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint zvec.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'zvec'
  s.version          = '0.5.1'
  s.summary          = 'Dart SDK for Zvec - a lightweight, lightning-fast, in-process vector database.'
  s.description      = <<-DESC
Dart/Flutter SDK for Zvec, an embedded vector database by Alibaba.
Provides dart:ffi bindings for high-performance vector similarity search
on macOS.
                       DESC
  s.homepage         = 'https://github.com/alibaba/zvec'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Zvec Team' => 'zvec@alibaba-inc.com' }

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.15'

  s.osx.vendored_frameworks = 'zvec_native.framework'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
  }

  zvec_version = s.version.to_s
  s.prepare_command = <<-CMD
    set -e

    arch="$(uname -m)"

    validate_framework_arch() {
      binary="$1"
      if ! lipo -info "$binary" | grep -q "$arch"; then
        echo "zvec.framework does not contain required architecture: $arch"
        lipo -info "$binary"
        exit 1
      fi
    }

    sign_framework() {
      if command -v codesign >/dev/null 2>&1; then
        codesign --force --sign - --timestamp=none zvec_native.framework
      fi
    }

    if [ ! -f "zvec_native.framework/zvec_native" ]; then
      case "$arch" in
        arm64)
          artifact="zvec-framework-macos-arm64.zip"
          ;;
        x86_64)
          if [ -f "../build/macos/zvec_native.framework/zvec_native" ]; then
            echo "Using locally built zvec_native.framework from ../build/macos"
            validate_framework_arch "../build/macos/zvec_native.framework/zvec_native"
            rm -rf zvec_native.framework
            cp -R ../build/macos/zvec_native.framework .
            validate_framework_arch "zvec_native.framework/zvec_native"
            sign_framework
            exit 0
          fi
          echo "Prebuilt zvec_native.framework for Intel macOS is not published."
          echo "Use a source checkout and build it locally with: bash scripts/build_macos.sh"
          exit 1
          ;;
        *)
          echo "Unsupported macOS architecture for zvec: $arch"
          exit 1
          ;;
      esac

      if [ -f "../build/macos/zvec_native.framework/zvec_native" ]; then
        echo "Using locally built zvec_native.framework from ../build/macos"
        validate_framework_arch "../build/macos/zvec_native.framework/zvec_native"
        rm -rf zvec_native.framework
        cp -R ../build/macos/zvec_native.framework .
        validate_framework_arch "zvec_native.framework/zvec_native"
        sign_framework
      else
        echo "Downloading zvec_native.framework v#{zvec_version} ($arch) ..."
        curl -L -o "$artifact" \
          "https://github.com/zvec-ai/zvec-dart/releases/download/v#{zvec_version}/$artifact"
        unzip -o "$artifact" -d .
        rm "$artifact"
        validate_framework_arch "zvec_native.framework/zvec_native"
        sign_framework
        echo "Done: zvec_native.framework downloaded."
      fi
    else
      validate_framework_arch "zvec_native.framework/zvec_native"
      sign_framework
      echo "zvec_native.framework already exists, skipping download."
    fi
  CMD
end
