node 'coroutine.local' {

  class { 'apt': }

  apt::sources_list {"mirror-1":
    ensure  => present,
    content => 'deb mirror://mirrors.ubuntu.com/mirrors.txt precise main restricted universe multiverse'
  }

  apt::sources_list { 'mirror-2':
    ensure => present,
    content => 'deb mirror://mirrors.ubuntu.com/mirrors.txt precise-updates main restricted universe multiverse',
  }
  
  apt::sources_list { 'mirror-3':
    ensure => present,
    content => 'deb mirror://mirrors.ubuntu.com/mirrors.txt precise-backports main restricted universe multiverse'
  }

  apt::sources_list { 'mirror-4':
    ensure => present,
    content => 'deb mirror://mirrors.ubuntu.com/mirrors.txt precise-security main restricted universe multiverse',
  }

  Apt::Sources_list['mirror-1'] -> Package <| |>
  Apt::Sources_list['mirror-2'] -> Package <| |>
  Apt::Sources_list['mirror-3'] -> Package <| |>
  Apt::Sources_list['mirror-4'] -> Package <| |>

  Exec {
    path => '/usr/bin:/usr/sbin:/bin'
  }

  File {
    owner  => 'root',
    group  => 'root',
    mode   => '0644'
  }

  file { '/etc/dak':
    ensure => directory,
    mode   => '0755'
  }

  file { '/etc/dak/dak.conf':
    ensure  => link,
    target  => '/srv/dak/dak.conf',
    require => File['/srv/dak/dak.conf']
  }

  file { '/srv/dak':
    ensure => directory,
    mode   => '2755',
    owner  => 'dak',
    group  => 'ftpmaster'
  }

  file { '/srv/dak/dak.conf':
    ensure  => link,
    target  => '/vagrant/files/dak.conf',
    owner   => 'dak',
    require => File['/srv/dak']
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

  file { '/home/dak/.bash_profile':
    content => "PATH=\$PATH:/home/dak/bin\nexport PATH",
    require => [
      User['dak'],
      File['/home/dak/bin']
    ]
  }

  file { '/home/dak/bin':
    ensure => directory,
    owner  => 'dak',
    mode   => '0755',
    require=> User['dak']
  }

  file { '/home/dak/bin/dak':
    ensure   => link,
    owner    => 'dak',
    target   => '/vagrant/dak/dak.py',
    require  => File['/home/dak/bin']
  }

  user { 'dak':
    ensure     => present,
    system     => true,
    home       => "/home/dak",
    gid        => ['ftpmaster', 'postgresql-admin'],
    shell      => '/bin/bash',
    managehome => true,
    require    => [
      Group['ftpmaster'],
      User['dak']
    ]
  }

  group {'ftpteam':
    ensure => present
  }

  group { 'ftptrainee':
    ensure => present
  }

  include postgresql

  # CREATE USER dak CREATEROLE;
  postgresql::user { 'dak':
    createrole => true,
    require    => User['dak']
  }

  # CREATE DATABASE projectb WITH OWNER dak TEMPLATE template0 ENCODING 'SQL_ASCII';
  postgresql::database { 'projectb':
    source => '/vagrant/setup/current_schema.sql', 
    owner  => 'dak',
    template => 'template0',
    encoding => 'SQL_ASCII',
    require  => Postgresql::User['dak']
  }


  # Run this manually! # sudo -u postgres psql
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
  
  # load from /vagrant/files instead (higher up)
  #exec { 'init_minimal_conf > /srv/dak/dak.conf':
  #  unless  => 'ls /srv/dak/dak.conf',
  #  require => File['/srv/dak/dak.conf'] 
  #}
  
  /*At this point, you should be able to test that the database schema is
up-to-date
# dak update-db

Run dak init-dirs to set up the initial /srv/dak tree
# dak init-dirs

Copy the email templates into the /srv/dak tree.
WARNING: Please check these templates over and customise as necessary
# cp templates/* /srv/dak/templates/

Set up a private signing key: don't set a passphrase as dak will not
pass one through to gpg.  Guard this key carefully!
The key only needs to be able to sign, it doesn't need to be able
to encrypt.
# gpg --no-default-keyring --secret-keyring /srv/dak/keyrings/s3kr1t/dot-gnupg/secring.gpg --keyring /srv/dak/keyrings/s3kr1t/dot-gnupg/pubring.gpg --gen-key
Remember the signing key id for when creating the suite below.
Here we'll pretend it is DDDDDDDD for convenience

Import some developer keys.
Either import from keyservers (here AAAAAAAA):
# gpg --no-default-keyring --keyring /srv/dak/keyrings/upload-keyring.gpg --recv-key AAAAAAAA
or import from files:
# gpg --no-default-keyring --keyring /srv/dak/keyrings/upload-keyring.gpg --import /path/to/keyfile

Import the developer keys into the database
The -U '%s' tells dak to add UIDs automatically
# dak import-keyring -U '%s' /srv/dak/keyrings/upload-keyring.gpg

Add some architectures you care about:
# dak admin architecture add i386 "Intel x86 port"
# dak admin architecture add amd64 "AMD64 port"

Add a suite (origin=, label= and codename= are optional)
signingkey= will ensure that Release files are signed
# dak admin suite add-all-arches unstable x.y.z origin=MyDistro label=Master codename=sid signingkey=DDDDDDDD

Re-run dak init-dirs to add new suite directories to /srv/dak
# dak init-dirs

#######################################################################
# Example package flow
#######################################################################

For this example, we've grabbed and built the hello source package
for AMD64 and copied it into /srv/dak/queue/unchecked.

We start by performing initial package checks which will
result in the package being moved to NEW
# cd /srv/dak/queue/unchecked
# dak process-upload *.changes

-----------------------------------------------------------------------
hello_2.6-1_amd64.changes
NEW for unstable


(new) hello_2.6-1.debian.tar.gz optional devel
(new) hello_2.6-1.dsc optional devel
(new) hello_2.6-1_amd64.deb optional devel
The classic greeting, and a good example
 The GNU hello program produces a familiar, friendly greeting.  It
 allows non-programmers to use a classic computer science tool which
 would otherwise be unavailable to them.
 .
 Seriously, though: this is an example of how to do a Debian package.
 It is the Debian version of the GNU Project's `hello world' program
 (which is itself an example for the GNU Project).
(new) hello_2.6.orig.tar.gz optional devel
Changes: hello (2.6-1) unstable; urgency=low
 .
  * New upstream release.
  * Drop unused INSTALL_PROGRAM stuff.
  * Switch to 3.0 (quilt) source format.
  * Standards-Version: 3.9.1 (no special changes for this).


Override entries for your package:

Announcing to debian-devel-changes@lists.debian.org

[N]ew, Skip, Quit ?N
Moving to NEW queue.
Sending new ack.
-----------------------------------------------------------------------

We can now look at the NEW queue-report
# dak queue-report
-----------------------------------------------------------------------
NEW
---

hello | 2.6-1 | source amd64 | 5 seconds old

1 new source package / 1 new package in total.
-----------------------------------------------------------------------

And we can then process the NEW queue:
# cd /srv/dak/queue/new
# dak process-new *.changes

-----------------------------------------------------------------------
hello_2.6-1_amd64.changes
NEW

hello                optional             devel
Add overrides, Edit overrides, Check, Manual reject, Note edit, Prod, [S]kip, Quit ?A
ACCEPT
-----------------------------------------------------------------------

At this stage, the package has been ACCEPTed from NEW into NEWSTAGE.
We now need to finally ACCEPT it into the pool:

# cd /srv/dak/queue/newstage
# dak process-upload *.changes

-----------------------------------------------------------------------
hello_2.6-1_amd64.changes
ACCEPT


hello_2.6-1.debian.tar.gz
  to main/h/hello/hello_2.6-1.debian.tar.gz
hello_2.6-1.dsc
  to main/h/hello/hello_2.6-1.dsc
hello_2.6-1_amd64.deb
  to main/h/hello/hello_2.6-1_amd64.deb
hello_2.6.orig.tar.gz
  to main/h/hello/hello_2.6.orig.tar.gz


Override entries for your package:
hello_2.6-1.dsc - optional devel
hello_2.6-1_amd64.deb - optional devel

Announcing to debian-devel-changes@lists.debian.org
[A]ccept, Skip, Quit ?A
Installing.
Installed 1 package set, 646 KB.
-----------------------------------------------------------------------

We can now see that dak knows about the package:
# dak ls -S hello

-----------------------------------------------------------------------
     hello |      2.6-1 |      unstable | source, amd64
-----------------------------------------------------------------------

# dak control-suite -l unstable

-----------------------------------------------------------------------
hello 2.6-1 amd64
hello 2.6-1 source
-----------------------------------------------------------------------

Next, we can generate the packages and sources files:
# dak generate-packages-sources2
(zcat /srv/dak/ftp/dists/unstable/main/binary-amd64/Packages.gz for instance)

And finally, we can generate the signed Release files:
# dak generate-release

-----------------------------------------------------------------------
Processing unstable
-----------------------------------------------------------------------
(Look at /srv/dak/ftp/dists/unstable/Release, Release.gpg and InRelease)


#######################################################################
# Next steps
#######################################################################

The debian archive automates most of these steps in jobs called
cron.unchecked, cron.hourly and cron.dinstall.
   */
}
