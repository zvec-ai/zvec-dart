require_relative '../tool/prepare_apple_sdk'

Pod::Spec.new do |s|
  s.name = 'zvec'
  s.version = '0.8.0'
  s.summary = 'Embedded vector database for Dart and Flutter.'
  s.homepage = 'https://github.com/alibaba/zvec'
  s.license = { :file => '../LICENSE' }
  s.author = { 'Zvec Team' => 'zvec@alibaba-inc.com' }
  s.source = { :path => '.' }
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '11.0'
  s.source_files = 'Classes/zvec.c'
  s.vendored_frameworks = ZvecAppleSdk.prepare(:macos, __dir__)
end
