Pod::Spec.new do |s|
  s.name             = 'age_verification'
  s.version          = '0.2.1'
  s.summary          = 'Flutter plugin for querying platform age signals on Android and iOS.'
  s.description      = <<-DESC
A Flutter plugin for querying platform age signals via Google Play Age Signals on Android
and Apple DeclaredAgeRange on iOS, for regional age verification compliance.
                       DESC
  s.homepage         = 'https://github.com/gktirkha/age_verification'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'gktirkha' => 'gktirkha@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'age_verification/Sources/age_verification/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  s.resource_bundles = {'age_verification_privacy' => ['age_verification/Sources/age_verification/PrivacyInfo.xcprivacy']}
end
