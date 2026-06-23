Pod::Spec.new do |s|
  s.name             = 'usesense_flutter'
  s.version          = '2.0.1'
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
  # Native UseSense iOS SDK. Minimum version 4.4.0 — vendors patched MediaPipe
  # (UseSenseMediaPipe) so on-device face mesh works with no per-app pod,
  # pre_install patch, or linkage change. Face capture needs face mesh, so on
  # < 4.4 the liveness step fails with "No frames captured". 4.4 also carries the
  # V4 capture API (startV4Session / LiveSenseV4Config) and the Flows runner
  # (UseSenseFlows.run) this plugin's bridge calls into. UseSenseSDK 4.4 is a
  # static_framework, so it works under the default `use_frameworks!`.
  s.dependency 'UseSenseSDK', '~> 4.4'

  s.platform         = :ios, '16.0'
  s.swift_version    = '5.9'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end
