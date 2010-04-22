Gem::Specification.new do |s|
  s.name = %q{background_process}
  s.version = "1.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Tim Harper"]
  s.date = Date.today.to_s
  s.description = %q{A library for spawning and interacting with UNIX processes}
  s.email = ["timcharper+bp@gmail.com"]
  s.extra_rdoc_files = [
    "MIT-LICENSE",
     "README.textile"
  ]
  s.files = ["README.textile", "MIT-LICENSE"] + Dir["lib/**/*"] + Dir["spec/**/*"]
  s.homepage = %q{http://github.com/timcharper/background_process}
  s.rdoc_options = ["--main", "README.textile"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{background_process}
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{background_process}
  s.test_files = Dir["spec/**/*"]

  s.specification_version = 3
end
