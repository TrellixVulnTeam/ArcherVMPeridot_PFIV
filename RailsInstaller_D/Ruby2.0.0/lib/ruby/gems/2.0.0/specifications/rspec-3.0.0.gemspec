# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "rspec"
  s.version = "3.0.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Steven Baker", "David Chelimsky", "Myron Marston"]
  s.cert_chain = ["-----BEGIN CERTIFICATE-----\nMIIDjjCCAnagAwIBAgIBATANBgkqhkiG9w0BAQUFADBGMRIwEAYDVQQDDAlyc3Bl\nYy1kZXYxGzAZBgoJkiaJk/IsZAEZFgtnb29nbGVnb3VwczETMBEGCgmSJomT8ixk\nARkWA2NvbTAeFw0xMzExMDcxOTQyNTlaFw0xNDExMDcxOTQyNTlaMEYxEjAQBgNV\nBAMMCXJzcGVjLWRldjEbMBkGCgmSJomT8ixkARkWC2dvb2dsZWdvdXBzMRMwEQYK\nCZImiZPyLGQBGRYDY29tMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA\nnhCeZouDLXWO55no+EdZNCtjXjfJQ1X9TbPcvBDD29OypIUce2h/VdKXB2gI7ZHs\nF5NkPggslTErGFmWAtIiur7u943RVqHOsyoIsy065F9fCtrykkA+22elvTDha4Iz\nRUCvuhQ3klatYk4jF+cGt1jNONNVdLOiy0bMynvcM7hoVQ2AomwGs+cEOWQ/4dkD\nJcNV3qfzF5QBcTD2372XNM53b25nYVQSX2KH5FF7BhlKyov33bOm2gA9M+mWIujW\nqgkyxVlfrlE+ZBgV3wXn1Cojg1LpTq35yOArgwioyrwwlZZJR9joN9s/nDklfr5A\n+dyETjFc6cmEPWZrt2cJBQIDAQABo4GGMIGDMAkGA1UdEwQCMAAwCwYDVR0PBAQD\nAgSwMB0GA1UdDgQWBBSW+WD7hn1swJ1A7i8tbuFeuNCJCjAkBgNVHREEHTAbgRly\nc3BlYy1kZXZAZ29vZ2xlZ291cHMuY29tMCQGA1UdEgQdMBuBGXJzcGVjLWRldkBn\nb29nbGVnb3Vwcy5jb20wDQYJKoZIhvcNAQEFBQADggEBAH27jAZ8sD7vnXupj6Y+\nBaBdfHtCkFaslLJ0aKuMDIVXwYuKfqoW15cZPDLmSIEBuQFM3lw6d/hEEL4Uo2jZ\nFvtmH5OxifPDzFyUtCL4yp6qgNe/Xf6sDsRg6FmKcpgqCwNOmsViaf0LPSUH/GYQ\n3Teoz8QCaDbD7AKsffT7eDrnbHnKweO1XdemRJC98u/yYxnGzMSWKEsn09etBlZ9\n7H67k5Z3uf6cfLZgToWL6zShzZY3Nun5r73YsNf2/QZOe4UZe4vfGvn6baw53ys9\n1yHC1AcSYpvi2dAbOiHT5iQF+krm4wse8KctXgTNnjMsHEoGKulJS2/sZl90jcCz\nmuA=\n-----END CERTIFICATE-----\n"]
  s.date = "2014-06-02"
  s.description = "BDD for Ruby"
  s.email = "rspec@googlegroups.com"
  s.extra_rdoc_files = ["README.md"]
  s.files = ["README.md"]
  s.homepage = "http://github.com/rspec"
  s.licenses = ["MIT"]
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubyforge_project = "rspec"
  s.rubygems_version = "2.0.2"
  s.summary = "rspec-3.0.0"

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<rspec-core>, ["~> 3.0.0"])
      s.add_runtime_dependency(%q<rspec-expectations>, ["~> 3.0.0"])
      s.add_runtime_dependency(%q<rspec-mocks>, ["~> 3.0.0"])
    else
      s.add_dependency(%q<rspec-core>, ["~> 3.0.0"])
      s.add_dependency(%q<rspec-expectations>, ["~> 3.0.0"])
      s.add_dependency(%q<rspec-mocks>, ["~> 3.0.0"])
    end
  else
    s.add_dependency(%q<rspec-core>, ["~> 3.0.0"])
    s.add_dependency(%q<rspec-expectations>, ["~> 3.0.0"])
    s.add_dependency(%q<rspec-mocks>, ["~> 3.0.0"])
  end
end
