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
  s.license = 'MIT'

  s.add_development_dependency("rspec", "~> 2.14.1")
  s.add_development_dependency("rake", "~> 0.9", ">= 0.9.2")
  s.add_dependency('streamio-ffmpeg', '~> 0.9', '>= 0.9.0')
  s.add_dependency('language_list', '~> 0.0', '>= 0.0.3')
  s.add_dependency('imdb', '~> 0.6', '>= 0.6.8')
  s.add_dependency('httparty', '~> 0')
  s.add_dependency('rubyzip', '~> 0.9', '>= 0.9.9')
  s.add_dependency('libxml-ruby', '~> 2.7', '>= 2.7.0')
  s.add_dependency('rest-client', '~> 1.7.2', '>= 1.7.2')

  s.files       = Dir.glob("lib/**/*") + Dir.glob("gems/**/*") + Dir.glob("bin/**/*") + %w(README.md LICENSE CHANGELOG Gemfile Gemfile.lock VERSION)
  s.executables = %w(apple-tv-converter)
end
