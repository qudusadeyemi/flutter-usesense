Pod::Spec.new do |s|
  s.name             = 'usesense_flutter'
  s.version          = '2.2.0'
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
  # 4.6.1 raised the floor: earlier 4.6.x tore the runner down on a failed
  # document upload, ejecting the subject mid-flow, and cancelling the
  # scanner or photo picker cancelled the whole verification.
  # 4.6.2 is the floor: below it an upload that arrived incomplete was reported
  # as `provider`, so the runner told a subject holding a perfectly good
  # document that verification was "temporarily unavailable" and offered a
  # retry that re-sent identical bytes.
  # 4.6.3 is the floor: from it the runner reports whether the subject scanned
  # the document or chose a file, so failure guidance can name an action they
  # can actually take. Below it the server has to guess from the step config.
  # 4.7.0 is the floor: below it the signals upload could not complete on a
  # slow connection. Frames were encoded at the camera's full 1080x1920 with no
  # downscale, so a session put 12.9 MB on the wire, against a 30s request
  # timeout and a 120s URLSession resource timeout. Clearing those needed
  # ~430 KB/s and ~107 KB/s of uplink; a measured production session managed
  # 14.6 KB/s, so the upload was cancelled mid-transfer every time and the
  # subject just saw a spinner. 4.7.0 caps frames at 960, raises both timeouts
  # to 300s, gzips the metadata, and emits real upload progress.
  #
  # Note `~> 4.7.0` means >= 4.7.0, < 4.8.0. The previous `~> 4.6.3` excluded
  # 4.7.0 outright, so this pin has to be raised by hand for every native fix.
  s.dependency 'UseSenseSDK', '~> 4.7.0'

  s.platform         = :ios, '16.0'
  s.swift_version    = '5.9'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end
