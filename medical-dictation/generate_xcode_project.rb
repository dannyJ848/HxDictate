#!/usr/bin/env ruby
# generate_xcode_project.rb
# Generates HxDictate.xcodeproj with proper configuration for C++ libraries

require 'xcodeproj'
require 'fileutils'

PROJECT_NAME = "HxDictate"
PROJECT_PATH = "#{PROJECT_NAME}.xcodeproj"
IOS_DEPLOYMENT_TARGET = "17.0"

# Remove existing project if any
FileUtils.rm_rf(PROJECT_PATH)

# Create new project
project = Xcodeproj::Project.new(PROJECT_PATH)
frameworks_group = project.main_group.new_group('Frameworks')

# Create main target
app_target = project.new_target(:application, PROJECT_NAME, :ios, IOS_DEPLOYMENT_TARGET)

app_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.danny.hxdictate'
  config.build_settings['DEVELOPMENT_TEAM'] = 'G99N9A97Z4'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['SWIFT_VERSION'] = '5.9'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = IOS_DEPLOYMENT_TARGET
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1' # iPhone only
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks']
  config.build_settings['ENABLE_BITCODE'] = 'NO'
  config.build_settings['SWIFT_OBJC_BRIDGING_HEADER'] = '$(SRCROOT)/ios-app/Scribe-Bridging-Header.h'
  config.build_settings['CLANG_ENABLE_MODULES'] = 'YES'
  config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone' # Debug builds faster
  config.build_settings['INFOPLIST_FILE'] = '$(SRCROOT)/ios-app/Resources/Info.plist'
  config.build_settings['ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS'] = 'YES'
  
  # Library search paths - include all subdirectories where .a files live
  config.build_settings['LIBRARY_SEARCH_PATHS'] = [
    '$(inherited)',
    '$(SRCROOT)/scripts/build/whisper.cpp/build-ios/src',
    '$(SRCROOT)/scripts/build/whisper.cpp/build-ios/ggml/src',
    '$(SRCROOT)/scripts/build/llama.cpp/build-ios/src',
    '$(SRCROOT)/scripts/build/llama.cpp/build-ios/ggml/src',
    '$(SRCROOT)/scripts/build/llama.cpp/build-ios/ggml/src/ggml-blas',
    '$(SRCROOT)/scripts/build/llama.cpp/build-ios/ggml/src/ggml-metal'
  ]
  
  # Header search paths
  config.build_settings['HEADER_SEARCH_PATHS'] = [
    '$(inherited)',
    '$(SRCROOT)/scripts/build/whisper.cpp/include',
    '$(SRCROOT)/scripts/build/llama.cpp/include',
    '$(SRCROOT)/scripts/build/whisper.cpp/ggml/include',
    '$(SRCROOT)/scripts/build/llama.cpp/ggml/include',
    '$(SRCROOT)/ios-app'
  ]
  
  # Link libraries - use full paths to avoid ambiguity
  config.build_settings['OTHER_LDFLAGS'] = [
    '$(inherited)',
    '-lwhisper',
    '-lllama',
    '-lggml',
    '-lggml-base',
    '-lggml-cpu',
    '-lggml-metal',
    '-lggml-blas',
    '-lc++',
    '-lc++abi',
    '-framework', 'Accelerate',
    '-framework', 'Metal',
    '-framework', 'MetalKit',
    '-framework', 'Foundation',
    '-framework', 'AVFoundation',
    '-framework', 'SwiftData',
    '-framework', 'UIKit'
  ]
  
  # C++ standard library
  config.build_settings['CLANG_CXX_LIBRARY'] = 'libc++'
  config.build_settings['CLANG_CXX_LANGUAGE_STANDARD'] = 'c++17'
end

# Add Swift source files
sources_group = project.main_group.new_group('Sources')
swift_files = Dir.glob('ios-app/Sources/**/*.swift')
swift_files.each do |file|
  file_ref = sources_group.new_file(file)
  app_target.add_file_references([file_ref])
end

# Add C wrapper files
c_sources = Dir.glob('ios-app/*.c')
c_sources.each do |file|
  file_ref = sources_group.new_file(file)
  app_target.add_file_references([file_ref])
end

# Add Resources group
resources_group = project.main_group.new_group('Resources')

# Add Assets.xcassets
assets_path = 'ios-app/Resources/Assets.xcassets'
if File.exist?(assets_path)
  assets_ref = resources_group.new_file(assets_path)
  app_target.add_resources([assets_ref])
end

# Add Info.plist
info_plist_path = 'ios-app/Resources/Info.plist'
if File.exist?(info_plist_path)
  info_plist_ref = resources_group.new_file(info_plist_path)
  # Don't add to resources - it's referenced in build settings
end

# Add models as resources - they'll be copied to app bundle
models_group = project.main_group.new_group('Models')
model_files = [
  'scripts/build/models/ggml-small.bin',
  'scripts/build/models/ggml-medium.bin',
  'scripts/build/models/ggml-large-v3-turbo.bin',
  'scripts/build/models/ggml-large-v3.bin', 
  'scripts/build/models/deepseek-r1-distill-qwen-7b-q4_k_m.gguf',
  'scripts/build/models/deepseek-r1-distill-qwen-14b-q3_k_m.gguf'
]

models_added = 0
model_files.each do |model|
  if File.exist?(model)
    file_ref = models_group.new_file(model)
    app_target.add_resources([file_ref])
    models_added += 1
    puts "📦 Added model: #{File.basename(model)}"
  else
    puts "⚠️  Model not found: #{model}"
  end
end

# Add frameworks
frameworks = ['Accelerate.framework', 'Metal.framework', 'MetalKit.framework', 'AVFoundation.framework', 'UIKit.framework']
frameworks.each do |framework|
  file_ref = frameworks_group.new_reference("System/Library/Frameworks/#{framework}", :sdk_root)
  app_target.frameworks_build_phase.add_file_reference(file_ref)
end

# Save project
project.save

puts ""
puts "✅ Xcode project created: #{PROJECT_PATH}"
puts ""
puts "📊 Configuration:"
puts "   - Models added: #{models_added}/#{model_files.length}"
puts "   - Libraries: whisper, llama, ggml (Metal + CPU)"
puts "   - Target: iOS #{IOS_DEPLOYMENT_TARGET}+, iPhone only"
puts ""
puts "🚀 Next steps:"
puts "   1. Open #{PROJECT_PATH} in Xcode"
puts "   2. Select your iPhone 17 Pro as target device"
puts "   3. Set your development team (Signing & Capabilities)"
puts "   4. Build and run (⌘R)"
puts ""
puts "⚠️  Important:"
puts "   - First build will copy ~10GB of models (takes several minutes)"
puts "   - Must use physical iPhone 17 Pro (simulator won't work with Metal)"
puts "   - App bundle will be ~10GB due to models"
