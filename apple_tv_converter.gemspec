# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require "apple_tv_converter/version"

Gem::Specification.new do |s|
  s.name        = "apple-tv-converter"
  s.version     = AppleTvConverter::VERSION
  s.authors     = ["Pedro Rodrigues"]
  s.email       = ["pedro@bbde.org"]
  s.homepage    = "http://github.com/gokuu/apple-tv-converter"
  s.summary     = "Converts movies to a format playable on Apple TV."
  s.description = "Converts movies to a format playable on Apple TV. Supporting multiple subtitles."

  s.add_development_dependency("rspec", "~> 2.7")
  s.add_development_dependency("rake", "~> 0.9.2")
  s.add_dependency('streamio-ffmpeg', '~> 0.9.0')
  s.add_dependency('language_list', '~> 0.0.3')

  s.files       = Dir.glob("lib/**/*") + %w(README.md LICENSE CHANGELOG)
  s.executables = %w(apple-tv-converter)
end
