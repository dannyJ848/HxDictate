#!/usr/bin/env ruby
# generate_xcode_project.rb
# Generates HxDictate.xcodeproj with proper configuration

require 'xcodeproj'
require 'fileutils'

PROJECT_NAME = "HxDictate"
PROJECT_PATH = "#{PROJECT_NAME}.xcodeproj"
IOS_DEPLOYMENT_TARGET = "17.0"

# Remove existing project if any
FileUtils.rm_rf(PROJECT_PATH)

# Create new project
project = Xcodeproj::Project.new(PROJECT_PATH)

# Create main target
app_target = project.new_target(:application, PROJECT_NAME, :ios, IOS_DEPLOYMENT_TARGET)
app_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.danny.hxdictate'
  config.build_settings['SWIFT_VERSION'] = '5.9'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = IOS_DEPLOYMENT_TARGET
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1' # iPhone only
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks']
  config.build_settings['ENABLE_BITCODE'] = 'NO'
  config.build_settings['SWIFT_OBJC_BRIDGING_HEADER'] = '$(SRCROOT)/Scribe-Bridging-Header.h'
  
  # Add library search paths
  config.build_settings['LIBRARY_SEARCH_PATHS'] = [
    '$(inherited)',
    '$(SRCROOT)/scripts/build/whisper.cpp/build-ios',
    '$(SRCROOT)/scripts/build/llama.cpp/build-ios'
  ]
  
  # Add header search paths
  config.build_settings['HEADER_SEARCH_PATHS'] = [
    '$(inherited)',
    '$(SRCROOT)/scripts/build/whisper.cpp/include',
    '$(SRCROOT)/scripts/build/llama.cpp/include',
    '$(SRCROOT)/scripts/build/whisper.cpp/ggml/include',
    '$(SRCROOT)/scripts/build/llama.cpp/ggml/include'
  ]
  
  # Link libraries
  config.build_settings['OTHER_LDFLAGS'] = [
    '-lwhisper',
    '-lllama',
    '-lggml',
    '-framework', 'Accelerate',
    '-framework', 'Metal',
    '-framework', 'MetalKit'
  ]
end

# Add Swift files
swift_files = Dir.glob('ios-app/Sources/**/*.swift')
swift_files.each do |file|
  file_ref = project.main_group.new_file(file)
  app_target.add_file_references([file_ref])
end

# Add bridging header
bridging_header = project.main_group.new_file('ios-app/Scribe-Bridging-Header.h')

# Add models as resources (copy them to the project first)
models_group = project.main_group.new_group('Models')
model_files = ['scripts/build/models/ggml-large-v3.bin', 'scripts/build/models/deepseek-r1-distill-qwen-14b-q3_k_m.gguf']
model_files.each do |model|
  if File.exist?(model)
    file_ref = models_group.new_file(model)
    app_target.add_resources([file_ref])
  end
end

# Save project
project.save

puts "✅ Xcode project created: #{PROJECT_PATH}"
puts ""
puts "Next steps:"
puts "1. Open #{PROJECT_PATH} in Xcode"
puts "2. Select your development team"
puts "3. Build and run on iPhone 17 Pro"
