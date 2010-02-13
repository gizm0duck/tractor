# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run the gemspec command
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{tractor}
  s.version = "0.2.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Shane Wolf"]
  s.date = %q{2010-02-12}
  s.description = %q{Very simple object mappings for ruby objects}
  s.email = %q{shanewolf@gmail.com}
  s.extra_rdoc_files = [
    "LICENSE",
     "README.rdoc"
  ]
  s.files = [
    ".document",
     ".gitignore",
     "LICENSE",
     "README.rdoc",
     "Rakefile",
     "VERSION",
     "lib/tractor.rb",
     "lib/tractor/model/base.rb",
     "lib/tractor/model/mapper.rb",
     "spec/model/base_spec.rb",
     "spec/model/mapper_spec.rb",
     "spec/spec.opts",
     "spec/spec_helper.rb",
     "spec/tractor_spec.rb",
     "tractor.gemspec"
  ]
  s.homepage = %q{http://github.com/gizm0duck/tractor}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{Very simple object mapping for ruby objects}
  s.test_files = [
    "spec/model/base_spec.rb",
     "spec/model/mapper_spec.rb",
     "spec/spec_helper.rb",
     "spec/tractor_spec.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end

