require_relative '../tool/prepare_apple_sdk'

Pod::Spec.new do |s|
  s.name = 'zvec'
  s.version = '0.8.0'
  s.summary = 'Embedded vector database for Dart and Flutter.'
  s.homepage = 'https://github.com/alibaba/zvec'
  s.license = { :file => '../LICENSE' }
  s.author = { 'Zvec Team' => 'zvec@alibaba-inc.com' }
  s.source = { :path => '.' }
  s.dependency 'Flutter'
  s.platform = :ios, '14.0'
  s.source_files = 'Classes/zvec.c'
  s.vendored_frameworks = ZvecAppleSdk.prepare(:ios, __dir__)

  # Generic simulator builds must select the available arm64 XCFramework slice.
  simulator_arch = { 'ARCHS[sdk=iphonesimulator*]' => 'arm64' }
  s.pod_target_xcconfig = simulator_arch
  s.user_target_xcconfig = simulator_arch
end
