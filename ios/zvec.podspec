#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint zvec.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'zvec'
  s.version          = '0.1.4'
  s.summary          = 'Dart SDK for Zvec — a lightweight, lightning-fast, in-process vector database.'
  s.description      = <<-DESC
Dart/Flutter SDK for Zvec, an embedded vector database by Alibaba.
Provides dart:ffi bindings for high-performance vector similarity search
on iOS and Android.
                       DESC
  s.homepage         = 'https://github.com/alibaba/zvec'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Zvec Team' => 'zvec@alibaba-inc.com' }

  s.source           = { :path => '.' }
  s.dependency 'Flutter'
  s.platform = :ios, '14.0'

  # The native zvec library is provided as a prebuilt dynamic framework.
  # No source compilation needed — all symbols are in the vendored binary.
  s.ios.vendored_framework = 'zvec.framework'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
  }

  # ---------------------------------------------------------------------------
  # Download prebuilt zvec.framework from GitHub Releases if not present.
  # This runs during `pod install` so users don't need to build from source.
  # ---------------------------------------------------------------------------
  zvec_version = s.version.to_s
  s.prepare_command = <<-CMD
    mkdir -p zvec.framework
    if [ ! -f "zvec.framework/zvec" ]; then
      echo "Downloading zvec.framework v#{zvec_version} ..."
      curl -L -o zvec-framework-ios.zip \
        "https://github.com/zvec-ai/zvec-dart/releases/download/v#{zvec_version}/zvec-framework-ios.zip"
      unzip -o zvec-framework-ios.zip -d .
      rm zvec-framework-ios.zip
      echo "Done: zvec.framework downloaded."
    else
      echo "zvec.framework already exists, skipping download."
    fi
  CMD
end
