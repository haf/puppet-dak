# Debian Archive Kit

dak is the collection of programs used to maintain the Debian
project's archives.  It's not yet in a state where it can be easily
used by others; if you want something to maintain a small archive and
apt-ftparchive (from the apt-utils package) is insufficient, I strongly
recommend you investigate mini-dinstall, debarchiver or similar.
However, if you insist on trying to try using dak, please read the
documentation in 'doc/README.first'.

There are some manual pages and READMEs in the doc sub-directory.  The
TODO file is an incomplete list of things needing to be done.

There's a mailing list for discussion, development of and help with
dak.  See:

  http://lists.debian.org/debian-dak/

for archives and details on how to subscribe.

# Vagrant + Puppet modification

The aim is to be able to clone this repo and run:

```bash
cd puppet-dak
bundle
vagrant up
```

and have a finished debian repository running locally. While this is the aim,
most likely are you going to have to configure your GPG keys before running
`vagrant up`, because the repository requires signatures to work.

## Future of this repo

I'm aiming to make it a pure puppet repository, without all the source-code of
dak, but while that is the aim, the first milestone is getting it up and
running for people to use for testing their debs in a realistic setting.

When I finish the pieces required to get it up and running, I'm going to
transform the repository: deleting all history, by overwriting with the commits
required for the module -- only. The module will then pull in the source code
of dak to a known location, and use that git clone as its foundation for
bringing up the system.

Henrik 2012.
