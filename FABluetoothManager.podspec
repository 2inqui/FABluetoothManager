#
#  Be sure to run `pod spec lint FABluetoothManager.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see http://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|
  s.name         = "FABluetoothManager"
  s.version      = "0.0.1"
  s.summary      = "A simple bluetooth manager block based to interact with peripherals for iOS"

  s.homepage     = "https://github.com/2inqui/FABluetoothManager"

  s.license      = "MIT"

  s.author             = { "Fernando Arellano" => "fernando.faa@gmail.com" }

  s.platform     = :ios
  
  s.source       = { :git => "http://EXAMPLE/FABluetoothManager.git", :tag => "0.0.1" }

  s.source_files  = "FABluetoothManager/FABluetoothManager/**/*.{h,m}"

  s.framework  = "CoreBluetooth"

  s.requires_arc = true
end
