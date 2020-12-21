MRuby::Build.new('host') do |conf|
  toolchain :gcc

  conf.gembox 'full-core'

  conf.gem :github => 'iij/mruby-env'
  conf.gem :github => 'iij/mruby-dir'
  conf.gem :github => 'iij/mruby-digest'
  conf.gem :github => 'iij/mruby-process'
  conf.gem :github => 'mattn/mruby-json'
  conf.gem :github => 'mattn/mruby-onig-regexp'
  conf.gem :github => 'matsumotory/mruby-redis'
  conf.gem :github => 'matsumotory/mruby-vedis'
  conf.gem :github => 'matsumotory/mruby-userdata'
  conf.gem :github => 'matsumotory/mruby-uname'
  conf.gem :github => 'matsumotory/mruby-mutex'
  conf.gem :github => 'matsumotory/mruby-localmemcache'
  conf.gem :mgem => 'mruby-secure-random'
  conf.gem :mgem => 'mruby-time-strftime'
  conf.gem :mgem => 'mruby-http'

  conf.cc do |cc|
    cc.flags << '-fPIC'
  end
end
