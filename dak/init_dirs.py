#!/usr/bin/env python

"""Initial setup of an archive."""
# Copyright (C) 2002, 2004, 2006  James Troup <james@nocrew.org>

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

################################################################################

import os, sys
import apt_pkg
from daklib import utils

################################################################################

Cnf = None
AptCnf = None

################################################################################

def usage(exit_code=0):
    """Print a usage message and exit with 'exit_code'."""

    print """Usage: dak init-dirs
Creates directories for an archive based on dak.conf configuration file.

  -h, --help                show this help and exit."""
    sys.exit(exit_code)

################################################################################

def do_dir(target, config_name):
    """If 'target' exists, make sure it is a directory.  If it doesn't, create
it."""

    if os.path.exists(target):
        if not os.path.isdir(target):
            utils.fubar("%s (%s) is not a directory."
                               % (target, config_name))
    else:
        print "Creating %s ..." % (target)
        os.makedirs(target)

def process_file(config, config_name):
    """Create directories for a config entry that's a filename."""

    if config.has_key(config_name):
        target = os.path.dirname(config[config_name])
        do_dir(target, config_name)

def process_tree(config, tree):
    """Create directories for a config tree."""

    for entry in config.SubTree(tree).List():
        entry = entry.lower()
        if tree == "Dir":
            if entry in [ "poolroot", "queue" , "morguereject" ]:
                continue
        config_name = "%s::%s" % (tree, entry)
        target = config[config_name]
        do_dir(target, config_name)

def process_morguesubdir(subdir):
    """Create directories for morgue sub directories."""

    config_name = "%s::MorgueSubDir" % (subdir)
    if Cnf.has_key(config_name):
        target = os.path.join(Cnf["Dir::Morgue"], Cnf[config_name])
        do_dir(target, config_name)

######################################################################

def create_directories():
    """Create directories referenced in dak.conf and apt.conf."""

    # Process directories from dak.conf
    process_tree(Cnf, "Dir")
    process_tree(Cnf, "Dir::Queue")
    for config_name in [ "Dinstall::LockFile", "Rm::LogFile",
                         "Import-Archive::ExportDir" ]:
        process_file(Cnf, config_name)
    for subdir in [ "Clean-Queues", "Clean-Suites" ]:
        process_morguesubdir(subdir)

    # Process directories from apt.conf
    process_tree(AptCnf, "Dir")
    for tree in AptCnf.SubTree("Tree").List():
        config_name = "Tree::%s" % (tree)
        tree_dir = os.path.join(Cnf["Dir::Root"], tree)
        do_dir(tree_dir, tree)
        for filename in [ "FileList", "SourceFileList" ]:
            process_file(AptCnf, "%s::%s" % (config_name, filename))
        for component in AptCnf["%s::Sections" % (config_name)].split():
            for architecture in AptCnf["%s::Architectures" \
                                       % (config_name)].split():
                if architecture != "source":
                    architecture = "binary-"+architecture
                target = os.path.join(tree_dir, component, architecture)
                do_dir(target, "%s, %s, %s" % (tree, component, architecture))


################################################################################

def main ():
    """Initial setup of an archive."""

    global AptCnf, Cnf

    Cnf = utils.get_conf()
    arguments = [('h', "help", "Init-Dirs::Options::Help")]
    for i in [ "help" ]:
        if not Cnf.has_key("Init-Dirs::Options::%s" % (i)):
            Cnf["Init-Dirs::Options::%s" % (i)] = ""

    arguments = apt_pkg.ParseCommandLine(Cnf, arguments, sys.argv)

    options = Cnf.SubTree("Init-Dirs::Options")
    if options["Help"]:
        usage()
    elif arguments:
        utils.warn("dak init-dirs takes no arguments.")
        usage(exit_code=1)

    AptCnf = apt_pkg.newConfiguration()
    apt_pkg.ReadConfigFileISC(AptCnf, utils.which_apt_conf_file())

    create_directories()

################################################################################

if __name__ == '__main__':
    main()
