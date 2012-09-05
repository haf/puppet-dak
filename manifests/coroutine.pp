node 'coroutine.local' {

  # you'll need to fix any broken apt-get sources first!
  # http://askubuntu.com/questions/37753/how-can-i-get-apt-to-use-a-mirror-close-to-me-or-choose-a-faster-mirror

  include postgresql
  
  $sentinel = "/var/lib/apt/first-puppet-run"
  exec { "apt-update":
    command => "/usr/bin/apt-get update && touch ${sentinel}",
    onlyif => "/usr/bin/env test \\! -f ${sentinel} || /usr/bin/env test \\! -z \"$(find /etc/apt -type f -c
newer ${sentinel})\"",
    timeout => 3600
  }

  Exec {
    path => '/usr/bin:/usr/sbin:/bin'
  }

  Exec["apt-update"] -> Package <| |>

  File {
    owner  => 'root',
    group  => 'root',
    mode   => '0644'
  }

  file { '/etc/dak':
    ensure => directory,
    mode   => '0755'
  }

  file { '/srv/dak':
    ensure => directory,
    mode   => '2755',
    owner  => 'dak',
    group  => 'ftpmaster'
  }

  file { '/etc/dak/dak.conf':
    ensure  => link,
    target  => '/srv/dak/dak.conf',
    require => File['/srv/dak/dak.conf']
  }

  file { '/srv/dak/dak.conf':
    ensure  => present,
    content => "Config\
{\
  coroutine.local\
  {\
    DatbaseHostname     \"coroutine.local\";\
    DakConfig   \"/org/ftp.debian.org/dak/config/debian/dak.conf\";\
    AptConfig   \"/org/ftp.debian.org/dak/config/debian/apt.conf\";\
  }\
}",
    require=> File['/srv/dak']
  }

  file { '/srv/dak/apt.conf':
    ensure  => present,
    content => '',
    require => File['/srv/dak']
  }

  $deps = ['python', 'libaugeas0', 'augeas-lenses', 'libaugeas-ruby', 'vim',
    'python-psycopg2', 'python-sqlalchemy', 'python-apt', 'gnupg', 'dpkg-dev', 'lintian',
   'binutils-multiarch', 'python-yaml', 'less', 'python-ldap', 'python-pyrss2gen', 'python-rrdtool',
   'symlinks', 'python-debian', 'postgresql-9.1-debversion'
  ]

  package { $deps:
    ensure => latest
  }

  group { 'ftpmaster':
    ensure => present,
    system => true
  }

  file { '/home/dak':
    ensure => directory,
    owner  => 'dak',
    mode   => '0755'
  }
  
  file { '/home/dak/bin':
    ensure => directory,
    owner  => 'dak',
    mode   => '0755',
    require=> File['/home/dak']
  }
  file { '/home/dak/bin/dak':
    ensure   => link,
    target   => '/vagrant/dak/dak.py'
  }

  user { 'dak':
    ensure => present,
    system => true,
    home   => "/home/dak",
    gid    => ['ftpmaster', 'postgresql-admin'],
    shell  => '/bin/bash',
    require => [
      Group['ftpmaster'],
      File['/home/dak']
    ]
  }
  group {'ftpteam':
    ensure => present
  }
  group { 'ftptrainee':
    ensure => present
  }

  # CREATE USER dak CREATEROLE;
  postgresql::user { 'dak':
    createrole => true
  }

  # CREATE DATABASE projectb WITH OWNER dak TEMPLATE template0 ENCODING 'SQL_ASCII';
  postgresql::database { 'projectb':
    source => '/vagrant/setup/current_schema.sql', 
    owner  => 'dak',
    template => 'template0',
    encoding => 'SQL_ASCII',
    require  => Postgresql::User['dak']
  }


  #CREATE ROLE ftpmaster;
  #CREATE ROLE ftpteam WITH ROLE ftpmaster;
  #CREATE ROLE ftptrainee WITH ROLE ftpmaster, ftpteam;
  #\c projectb
  #CREATE EXTENSION IF NOT EXISTS plpgsql;
  #CREATE EXTENSION IF NOT EXISTS debversion;

  #exec { 'init_core':
  #  cwd      => '/vagrant/setup',
  #  user     => 'dak',
  #  require  => [
  #    User['dak'],
  #    Postgresql::Database['projectb']
  #  ]
  #}
  
  #exec { 'init_minimal_conf > /srv/dak/dak.conf':
  #  unless  => 'ls /srv/dak/dak.conf',
  #  require => File['/srv/dak/dak.conf'] 
  #}
}
