MRuby::Build.new('host') do |conf|
  toolchain :gcc
  conf.gembox 'full-core'
  conf.gem :github => 'iij/mruby-digest'
  conf.gem :github => 'iij/mruby-dir'
  conf.gem :github => 'iij/mruby-env'
  conf.gem :github => 'iij/mruby-process'
  conf.gem :github => 'mattn/mruby-json'
  conf.gem :github => 'mattn/mruby-onig-regexp'
  conf.gem :mgem => 'mruby-secure-random'
  conf.cc.flags << '-fPIC'
end
