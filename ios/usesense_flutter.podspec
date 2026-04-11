Pod::Spec.new do |s|
  s.name             = 'usesense_flutter'
  s.version          = '2.0.0'
  s.summary          = 'Flutter plugin for UseSense human presence verification.'
  s.description      = <<-DESC
  Flutter plugin wrapping the UseSense iOS SDK for human presence verification
  with DeepSense (device integrity), LiveSense (proof-of-life), and MatchSense
  (identity collision detection).
                       DESC
  s.homepage         = 'https://usesense.ai'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'UseSense' => 'support@usesense.ai' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'

  s.dependency 'Flutter'
  # Native UseSense iOS SDK. Minimum version 4.2.2 — earlier 4.x versions
  # had `Color.UseSense` theming issues and a terminal-screen centering
  # bug that's fixed in 4.2.2.
  s.dependency 'UseSenseSDK', '~> 4.2'

  s.platform         = :ios, '16.0'
  s.swift_version    = '5.9'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end
