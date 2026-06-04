platform :ios, '13.0'

require File.expand_path(File.join(ENV['FLUTTER_ROOT'], 'packages', 'flutter_tools', 'bin', 'podhelper.rb'))

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      config.build_settings['GCC_TREAT_WARNINGS_AS_ERRORS'] = 'NO'
      
      # Resolve o erro de SWIFT_OPTIMIZATION_LEVEL e Preview desativado
      # Define -Onone apenas para Debug e -O para os outros (Release/Profile)
      if config.name == 'Debug'
        config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone'
      else
        config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-O'
      end

      config.build_settings['SWIFT_VERSION'] = '5.0'
    end
  end
end
