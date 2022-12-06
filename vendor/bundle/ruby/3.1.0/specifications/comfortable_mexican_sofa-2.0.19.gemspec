# -*- encoding: utf-8 -*-
# stub: comfortable_mexican_sofa 2.0.19 ruby lib

Gem::Specification.new do |s|
  s.name = "comfortable_mexican_sofa".freeze
  s.version = "2.0.19"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Oleg Khabarov".freeze]
  s.date = "2019-12-31"
  s.description = "ComfortableMexicanSofa is a powerful Rails 5.2+ CMS Engine".freeze
  s.email = ["oleg@khabarov.ca".freeze]
  s.homepage = "http://github.com/comfy/comfortable-mexican-sofa".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.3.0".freeze)
  s.rubygems_version = "3.3.7".freeze
  s.summary = "Rails 5.2+ CMS Engine".freeze

  s.installed_by_version = "3.3.7" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_runtime_dependency(%q<active_link_to>.freeze, [">= 1.0.0"])
    s.add_runtime_dependency(%q<comfy_bootstrap_form>.freeze, [">= 4.0.0"])
    s.add_runtime_dependency(%q<haml-rails>.freeze, [">= 1.0.0"])
    s.add_runtime_dependency(%q<jquery-rails>.freeze, [">= 4.3.1"])
    s.add_runtime_dependency(%q<kramdown>.freeze, [">= 1.0.0"])
    s.add_runtime_dependency(%q<mimemagic>.freeze, [">= 0.3.2"])
    s.add_runtime_dependency(%q<mini_magick>.freeze, [">= 4.8.0"])
    s.add_runtime_dependency(%q<rails>.freeze, [">= 5.2.0"])
    s.add_runtime_dependency(%q<rails-i18n>.freeze, [">= 5.0.0"])
    s.add_runtime_dependency(%q<sassc-rails>.freeze, [">= 2.0.0"])
  else
    s.add_dependency(%q<active_link_to>.freeze, [">= 1.0.0"])
    s.add_dependency(%q<comfy_bootstrap_form>.freeze, [">= 4.0.0"])
    s.add_dependency(%q<haml-rails>.freeze, [">= 1.0.0"])
    s.add_dependency(%q<jquery-rails>.freeze, [">= 4.3.1"])
    s.add_dependency(%q<kramdown>.freeze, [">= 1.0.0"])
    s.add_dependency(%q<mimemagic>.freeze, [">= 0.3.2"])
    s.add_dependency(%q<mini_magick>.freeze, [">= 4.8.0"])
    s.add_dependency(%q<rails>.freeze, [">= 5.2.0"])
    s.add_dependency(%q<rails-i18n>.freeze, [">= 5.0.0"])
    s.add_dependency(%q<sassc-rails>.freeze, [">= 2.0.0"])
  end
end
