require 'digest'
require 'fileutils'
require 'json'
require 'tmpdir'
require 'xcodeproj'

module ZvecAppleSdk
  extend self

  # Flutter installs local :path pods, for which CocoaPods skips prepare_command.
  # Materialize the vendored framework before CocoaPods enumerates the files.
  def prepare(platform, pod_dir)
    manifest_path = File.join(__dir__, 'zvec_sdk.json')
    manifest = JSON.parse(File.read(manifest_path))
    fingerprint = Digest::SHA256.hexdigest(File.binread(manifest_path) + File.binread(__FILE__))[0, 16]
    relative = File.join('.zvec-sdk', "#{manifest.fetch('version')}-#{fingerprint}")
    destination = File.expand_path(relative, pod_dir)
    name = platform == :ios ? 'zvec_native.xcframework' : 'zvec_native.framework'
    FileUtils.mkdir_p(File.dirname(destination))
    File.open("#{destination}.lock", 'a') do |lock|
      lock.flock(File::LOCK_EX)
      unless File.directory?(File.join(destination, name))
        Dir.mktmpdir('package-', File.dirname(destination)) do |work|
          output = File.join(work, 'out', name)
          FileUtils.mkdir_p(File.dirname(output))
          if platform == :ios
            package_ios(manifest, work, output)
          else
            package_macos(manifest, work, output)
          end
          File.rename(File.dirname(output), destination)
        end
      end
    end
    File.join(relative, name)
  end

  private

  def run(*args)
    raise "zvec: #{args.first} failed" unless system(*args, :out => $stderr)
  end

  def archive(manifest, target)
    asset = manifest.fetch('assets').fetch(target)
    name = asset.fetch('file')
    digest = asset.fetch('sha256')
    cache = ENV.fetch('ZVEC_SDK_CACHE') { File.join(Dir.home, '.cache', 'zvec-dart') }
    directory = File.expand_path(File.join(cache, digest))
    path = File.join(directory, name)
    return path if File.file?(path) && Digest::SHA256.file(path).hexdigest == digest

    FileUtils.mkdir_p(directory)
    Dir.mktmpdir('download-', directory) do |tmp|
      download = File.join(tmp, name)
      url = "#{manifest.fetch('baseUrl')}/v#{manifest.fetch('version')}/#{name}"
      $stderr.puts "Downloading #{url}"
      run('curl', '--fail', '--location', '--silent', '--show-error', '--retry', '3',
          '--output', download, url)
      raise "zvec: invalid SHA-256 for #{name}" unless Digest::SHA256.file(download).hexdigest == digest

      File.rename(download, path)
    end
    path
  end

  def package_ios(manifest, work, output)
    run('unzip', '-q', archive(manifest, 'ios'), 'libzvec_c_api.xcframework/*', '-d', work)
    source = File.join(work, 'libzvec_c_api.xcframework')
    info = Xcodeproj::Plist.read_from_path(File.join(source, 'Info.plist'))
    info.fetch('AvailableLibraries').each do |library|
      slice = library.fetch('LibraryIdentifier')
      dylib = File.join(source, slice, library.fetch('LibraryPath'))
      framework = File.join(output, slice, 'zvec_native.framework')
      platform = library['SupportedPlatformVariant'] == 'simulator' ? 'iPhoneSimulator' : 'iPhoneOS'
      wrap_framework(framework, [dylib], platform, manifest.fetch('version'))
      library['LibraryPath'] = 'zvec_native.framework'
      library['BinaryPath'] = 'zvec_native.framework/zvec_native'
    end
    Xcodeproj::Plist.write_to_path(info, File.join(output, 'Info.plist'))
  end

  def package_macos(manifest, work, output)
    dylibs = %w[osx-arm64 osx-amd64].map do |target|
      directory = File.join(work, target)
      FileUtils.mkdir_p(directory)
      run('tar', '-xzf', archive(manifest, target), '-C', directory, './lib/libzvec_c_api.dylib')
      File.join(directory, 'lib', 'libzvec_c_api.dylib')
    end
    wrap_framework(output, dylibs, 'MacOSX', manifest.fetch('version'))
  end

  def wrap_framework(framework, dylibs, platform, version)
    macos = platform == 'MacOSX'
    contents = macos ? File.join(framework, 'Versions', 'A') : framework
    resources = macos ? File.join(contents, 'Resources') : contents
    FileUtils.mkdir_p(resources)
    binary = File.join(contents, 'zvec_native')
    if macos
      run('lipo', '-create', *dylibs, '-output', binary)
      File.symlink('A', File.join(framework, 'Versions', 'Current'))
      File.symlink('Versions/Current/Resources', File.join(framework, 'Resources'))
      File.symlink('Versions/Current/zvec_native', File.join(framework, 'zvec_native'))
    else
      FileUtils.copy_file(dylibs.first, binary)
    end
    File.chmod(0755, binary)
    executable = macos ? 'Versions/A/zvec_native' : 'zvec_native'
    run('install_name_tool', '-id', "@rpath/zvec_native.framework/#{executable}", binary)
    info = {
      'CFBundleIdentifier' => 'org.zvec.native',
      'CFBundleName' => 'zvec_native',
      'CFBundleExecutable' => 'zvec_native',
      'CFBundlePackageType' => 'FMWK',
      'CFBundleDevelopmentRegion' => 'en',
      'CFBundleInfoDictionaryVersion' => '6.0',
      'CFBundleVersion' => version,
      'CFBundleShortVersionString' => version,
      'CFBundleSupportedPlatforms' => [platform],
    }
    if macos
      info['LSMinimumSystemVersion'] = '11.0'
    else
      info['MinimumOSVersion'] = '14.0'
    end
    Xcodeproj::Plist.write_to_path(info, File.join(resources, 'Info.plist'))
    run('codesign', '--force', '--sign', '-', '--timestamp=none', framework)
  end
end
