Gem::Specification.new do |s|
  s.name = "currency-in-words"
  s.version = "0.1.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Bruno Carrere"]
  s.date = "2011-10-18"
  s.description = "Rails 3 helper number_to_currency_in_words that displays a currency amount in words (eg. 'one hundred dollars')"
  s.email = "bruno@carrere.cc"
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.rdoc"
  ]
  s.files = [
    "LICENSE.txt",
    "README.rdoc",
    "VERSION",
    "lib/currency-in-words.rb"
  ]
  s.homepage = "http://github.com/bcarrere/currency-in-words"
  s.licenses = ["MIT"]
  s.require_paths = ["lib"]
  s.rubygems_version = "1.8.10"
  s.summary = "View helper for Rails 3 that displays a currency amount in words (eg. 'one hundred dollars')"

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<activesupport>, [">= 3.1"])
      s.add_runtime_dependency(%q<actionpack>, [">= 3.1"])
    else
      s.add_dependency(%q<activesupport>, [">= 3.1"])
      s.add_dependency(%q<actionpack>, [">= 3.1"])
    end
  else
    s.add_dependency(%q<activesupport>, [">= 3.1"])
    s.add_dependency(%q<actionpack>, [">= 3.1"])
  end
end

