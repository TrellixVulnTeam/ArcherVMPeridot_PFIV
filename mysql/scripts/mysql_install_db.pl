#!/usr/bin/perl
# -*- cperl -*-
#
# Copyright (c) 2007, 2013, Oracle and/or its affiliates. All rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

##############################################################################
#
#  This scripts creates the MySQL Server system tables.
#
#  This script try to match the shell script version as close as possible,
#  but in addition being compatible with ActiveState Perl on Windows.
#
#  All unrecognized arguments to this script are passed to mysqld.
#
#  NOTE: This script in 5.0 doesn't really match the shell script
#        version 100%, it is more close to the 5.1 version.
#
#  NOTE: This script was deliberately written to be as close to the shell
#        script as possible, to make the maintenance of both in parallel
#        easier.
#
##############################################################################

use File::Basename;
use Getopt::Long;
use Sys::Hostname;
use Data::Dumper;
use strict;

Getopt::Long::Configure("pass_through");

my @args;                       # Argument list filled in

##############################################################################
#
#  Usage information
#
##############################################################################

sub usage
{
  print <<EOF;
Usage: $0 [OPTIONS]
  --basedir=path       The path to the MySQL installation directory.
  --builddir=path      If using --srcdir with out-of-directory builds, you
                       will need to set this to the location of the build
                       directory where built files reside.
  --cross-bootstrap    For internal use.  Used when building the MySQL system
                       tables on a different host than the target.
  --datadir=path       The path to the MySQL data directory.
  --defaults-extra-file=name
                       Read this file after the global files are read.
  --defaults-file=name Only read default options from the given file name.
  --force              Causes mysql_install_db to run even if DNS does not
                       work.  In that case, grant table entries that normally
                       use hostnames will use IP addresses.
  --help               Display this help and exit.                     
  --ldata=path         The path to the MySQL data directory. Same as --datadir.
  --no-defaults        Don't read default options from any option file.
  --rpm                For internal use.  This option is used by RPM files
                       during the MySQL installation process.
  --skip-name-resolve  Use IP addresses rather than hostnames when creating
                       grant table entries.  This option can be useful if
                       your DNS does not work.
  --srcdir=path        The path to the MySQL source directory.  This option
                       uses the compiled binaries and support files within the
                       source tree, useful for if you don't want to install
                       MySQL yet and just want to create the system tables.
  --user=user_name     The login username to use for running mysqld.  Files
                       and directories created by mysqld will be owned by this
                       user.  You must be root to use this option.  By default
                       mysqld runs using your current login name and files and
                       directories that it creates will be owned by you.

All other options are passed to the mysqld program

EOF
  exit 1;
}

##############################################################################
#
#  Parse an argument list
#
#  We only need to pass arguments through to the server if we don't
#  handle them here.  So, we collect unrecognized options (passed on
#  the command line) into the args variable.
#
##############################################################################

sub parse_arguments
{
  my $opt = shift;

  my @saved_ARGV = @ARGV;
  @ARGV = @_;                           # Set ARGV so GetOptions works

  my $pick_args;
  if (@ARGV and $ARGV[0] eq 'PICK-ARGS-FROM-ARGV')
  {
    $pick_args = 1;
    shift @ARGV;
  }

  GetOptions(
             $opt,
             "force",
             "basedir=s",
             "builddir=s",      # FIXME not documented
             "srcdir=s",
             "ldata|datadir=s",

             # Note that the user will be passed to mysqld so that it runs
             # as 'user' (crucial e.g. if log-bin=/some_other_path/
             # where a chown of datadir won't help)
             "user=s",

             "skip-name-resolve",
             "verbose",
             "rpm",
             "help",
             "defaults-file|defaults-extra-file|no-defaults:s",

             # Used when building the MySQL system tables on a different host than
             # the target. The platform-independent files that are created in
             # --datadir on the host can be copied to the target system.
             #
             # The most common use for this feature is in the Windows installer
             # which will take the files from datadir and include them as part of
             # the install package.  See top-level 'dist-hook' make target.
             #
             # --windows is a deprecated alias
             "cross-bootstrap|windows", # FIXME undocumented, even needed?
  ) or usage();

  usage() if $opt->{help};

  @args =  @ARGV if $pick_args;

  @ARGV = @saved_ARGV;                  # Set back ARGV
}

##############################################################################
#
#  Try to find a specific file within --basedir which can either be a binary
#  release or installed source directory and return the path.
#
##############################################################################

sub find_in_basedir
{
  my $opt   = shift;
  my $mode  = shift;            # "dir" or "file"
  my $files = shift;

  foreach my $file ( @{ref($files) ? $files : [$files]} )
  {
    foreach my $dir ( @_ )
    {
      foreach my $part ( "$file","$file.exe","release/$file.exe",
                         "debug/$file.exe","relwithdebinfo/$file.exe" )
      {
        my $path = "$opt->{basedir}/$dir/$part";
        if ( -f $path )
        {
          return $mode eq "dir" ? dirname($path) : $path;
        }
      }
    }
  }
}

##############################################################################
#
#  Just a function to write out an error report
#
##############################################################################

sub cannot_find_file
{
  my $file = shift;

  print "FATAL ERROR: Could not find $file\n";
  print "\n";
  print "If you compiled from source, you need to run 'make install' to\n";
  print "copy the software into the correct location ready for operation.\n";
  print "\n";
  print "If you are using a binary release, you must either be at the top\n";
  print "level of the extracted archive, or pass the --basedir option\n";
  print "pointing to that location.\n";
  print "\n";

  exit 1;
}

##############################################################################
#
#  Form a command line that can handle spaces in paths and arguments
#
##############################################################################

# FIXME this backslash escaping needed if using '"..."' ?
# This regexp makes sure that any special chars are quoted,
# so the arg gets passed exactly to the server.
# XXX: This is broken; true fix requires using eval and proper
# quoting of every single arg ($opt->{basedir}, $opt->{ldata}, etc.)
#  join(" ", map {s/([^\w\_\.\-])/\\$1/g}

sub quote_options {
  my @cmd;
  foreach my $opt ( @_ )
  {
    next unless $opt;           # If undefined or empty, just skip
    push(@cmd, "\"$opt\"");     # Quote argument
  }
  return join(" ", @cmd);
}

##############################################################################
#
#  Ok, let's go.  We first need to parse arguments which are required by
#  my_print_defaults so that we can execute it first, then later re-parse
#  the command line to add any extra bits that we need.
#
##############################################################################

my $opt = {};
parse_arguments($opt, 'PICK-ARGS-FROM-ARGV', @ARGV);

# ----------------------------------------------------------------------
# We can now find my_print_defaults.  This script supports:
#
#   --srcdir=path pointing to compiled source tree
#   --basedir=path pointing to installed binary location
#
# or default to compiled-in locations.
# ----------------------------------------------------------------------

my $print_defaults;

if ( $opt->{srcdir} and $opt->{basedir} )
{
  error("Specify either --basedir or --srcdir, not both");
}
if ( $opt->{srcdir} )
{
  $opt->{builddir} = $opt->{srcdir} unless $opt->{builddir};
  $print_defaults = "$opt->{builddir}/extra/my_print_defaults";
}
elsif ( $opt->{basedir} )
{
  $print_defaults = find_in_basedir($opt,"file","my_print_defaults","bin","extra");
}
else
{
  $print_defaults='./bin/my_print_defaults';
}

-x $print_defaults or -f "$print_defaults.exe"
  or cannot_find_file($print_defaults);

# ----------------------------------------------------------------------
# Now we can get arguments from the groups [mysqld] and [mysql_install_db]
# in the my.cfg file, then re-run to merge with command line arguments.
# ----------------------------------------------------------------------

my @default_options;
my $cmd = quote_options($print_defaults,$opt->{'defaults-file'},
                        "mysqld","mysql_install_db");
open(PIPE, "$cmd |") or error($opt,"can't run $cmd: $!");
while ( <PIPE> )
{
  chomp;
  next unless /\S/;
  push(@default_options, $_);
}
close PIPE;
$opt = {};                              # Reset the arguments FIXME ?
parse_arguments($opt, @default_options);
parse_arguments($opt, 'PICK-ARGS-FROM-ARGV', @ARGV);

# ----------------------------------------------------------------------
# Configure paths to support files
# ----------------------------------------------------------------------

# FIXME $extra_bindir is not used
my ($bindir,$extra_bindir,$mysqld,$pkgdatadir,$mysqld_opt,$scriptdir);

if ( $opt->{srcdir} )
{
  $opt->{basedir} = $opt->{builddir};
  $bindir         = "$opt->{basedir}/client";
  $extra_bindir   = "$opt->{basedir}/extra";
  $mysqld         = "$opt->{basedir}/sql/mysqld";
  $mysqld_opt     = "--language=$opt->{srcdir}/sql/share/english";
  $pkgdatadir     = "$opt->{srcdir}/scripts";
  $scriptdir      = "$opt->{srcdir}/scripts";
}
elsif ( $opt->{basedir} )
{
  $bindir         = "$opt->{basedir}/bin";
  $extra_bindir   = $bindir;
  $mysqld         = find_in_basedir($opt,"file",["mysqld-nt","mysqld"],
                                    "libexec","sbin","bin") ||  # ,"sql"
                    find_in_basedir($opt,"file","mysqld-nt",
                                  "bin");  # ,"sql"
  $pkgdatadir     = find_in_basedir($opt,"dir","fill_help_tables.sql",
                                    "share","share/mysql");  # ,"scripts"
  $scriptdir      = "$opt->{basedir}/scripts";
}
else
{
  $opt->{basedir} = '.';
  $bindir         = './bin';
  $extra_bindir   = $bindir;
  $mysqld         = './bin/mysqld';
  $pkgdatadir     = './share';
  $scriptdir      = './bin';
}

unless ( $opt->{ldata} )
{
  $opt->{ldata} = './data';
}

if ( $opt->{srcdir} )
{
  $pkgdatadir = "$opt->{srcdir}/scripts";
}

# ----------------------------------------------------------------------
# Set up paths to SQL scripts required for bootstrap
# ----------------------------------------------------------------------

my $fill_help_tables     = "$pkgdatadir/fill_help_tables.sql";
my $create_system_tables = "$pkgdatadir/mysql_system_tables.sql";
my $fill_system_tables   = "$pkgdatadir/mysql_system_tables_data.sql";

foreach my $f ( $fill_help_tables,$create_system_tables,$fill_system_tables )
{
  -f $f or cannot_find_file($f);
}

-x $mysqld or -f "$mysqld.exe" or cannot_find_file($mysqld);
# Try to determine the hostname
my $hostname = hostname();

# ----------------------------------------------------------------------
# Check if hostname is valid
# ----------------------------------------------------------------------

my $resolved;
if ( !$opt->{'cross-bootstrap'} and !$opt->{rpm} and !$opt->{force} )
{
  my $resolveip;

  $resolved = `$resolveip $hostname 2>&1`;
  if ( $? != 0 )
  {
    $resolved=`$resolveip localhost 2>&1`;
    if ( $? != 0 )
    {
      error($opt,
            "Neither host '$hostname' nor 'localhost' could be looked up with",
            "$bindir/resolveip",
            "Please configure the 'hostname' command to return a correct",
            "hostname.",
            "If you want to solve this at a later stage, restart this script",
            "with the --force option");
    }
    warning($opt,
            "The host '$hostname' could not be looked up with resolveip.",
            "This probably means that your libc libraries are not 100 % compatible",
            "with this binary MySQL version. The MySQL daemon, mysqld, should work",
            "normally with the exception that host name resolving will not work.",
            "This means that you should use IP addresses instead of hostnames",
            "when specifying MySQL privileges !");
  }
}

# FIXME what does this really mean....
if ( $opt->{'skip-name-resolve'} and $resolved and $resolved =~ /\s/ )
{
  $hostname = (split(' ', $resolved))[5];
}

# ----------------------------------------------------------------------
# Create database directories mysql & test
# ----------------------------------------------------------------------

foreach my $dir ( $opt->{ldata}, "$opt->{ldata}/mysql", "$opt->{ldata}/test" )
{
  # FIXME not really the same as original "mkdir -p", but ok?
  mkdir($dir, 0700) unless -d $dir;
  chown($opt->{user}, $dir) if -w "/" and !$opt->{user};
}

push(@args, "--user=$opt->{user}") if $opt->{user};

# ----------------------------------------------------------------------
# Configure mysqld command line
# ----------------------------------------------------------------------

# FIXME use --init-file instead of --bootstrap ?!

my $mysqld_bootstrap = $ENV{MYSQLD_BOOTSTRAP} || $mysqld;
my $mysqld_install_cmd_line = quote_options($mysqld_bootstrap,
                                            $opt->{'defaults-file'},
                                            $mysqld_opt,
                                            "--bootstrap",
                                            "--basedir=$opt->{basedir}",
                                            "--datadir=$opt->{ldata}",
                                            "--log-warnings=0",
                                            "--loose-skip-innodb",
                                            "--loose-skip-ndbcluster",
                                            "--max_allowed_packet=8M",
                                            "--default-storage-engine=MyISAM",
                                            "--net_buffer_length=16K",
                                            @args,
                                          );

# ----------------------------------------------------------------------
# Create the system and help tables by passing them to "mysqld --bootstrap"
# ----------------------------------------------------------------------

report_verbose_wait($opt,"Installing MySQL system tables...");

open(SQL, $create_system_tables)
  or error($opt,"can't open $create_system_tables for reading: $!");
open(SQL2, $fill_system_tables)
  or error($opt,"can't open $fill_system_tables for reading: $!");
# FIXME  > /dev/null ?
if ( open(PIPE, "| $mysqld_install_cmd_line") )
{
  print PIPE "use mysql;\n";
  while ( <SQL> )
  {
    # When doing a "cross bootstrap" install, no reference to the current
    # host should be added to the system tables.  So we filter out any
    # lines which contain the current host name.
    next if $opt->{'cross-bootstrap'} and /\@current_hostname/;

    print PIPE $_;
  }
  while ( <SQL2> )
  {
    # TODO: make it similar to the above condition when we're sure 
    #   @@hostname returns a fqdn
    # When doing a "cross bootstrap" install, no reference to the current
    # host should be added to the system tables.  So we filter out any
    # lines which contain the current host name.
    next if /\@current_hostname/;

    print PIPE $_;
  }
  close PIPE;
  close SQL;
  close SQL2;

  report_verbose($opt,"OK");

  # ----------------------------------------------------------------------
  # Pipe fill_help_tables.sql to "mysqld --bootstrap"
  # ----------------------------------------------------------------------

  report_verbose_wait($opt,"Filling help tables...");
  open(SQL, $fill_help_tables)
    or error($opt,"can't open $fill_help_tables for reading: $!");
  # FIXME  > /dev/null ?
  if ( open(PIPE, "| $mysqld_install_cmd_line") )
  {
    print PIPE "use mysql;\n";
    while ( <SQL> )
    {
      print PIPE $_;
    }
    close PIPE;
    close SQL;

    report_verbose($opt,"OK");
  }
  else
  {
    warning($opt,"HELP FILES ARE NOT COMPLETELY INSTALLED!",
                 "The \"HELP\" command might not work properly");
  }

  report_verbose($opt,"To start mysqld at boot time you have to copy",
                      "support-files/mysql.server to the right place " .
                      "for your system");

  if ( !$opt->{'cross-bootstrap'} )
  {
    # This is not a true installation on a running system.  The end user must
    # set a password after installing the data files on the real host system.
    # At this point, there is no end user, so it does not make sense to print
    # this reminder.
    report($opt,
           "PLEASE REMEMBER TO SET A PASSWORD FOR THE MySQL root USER !",
           "To do so, start the server, then issue the following commands:",
           "",
           "  $bindir/mysqladmin -u root password 'new-password'",
           "  $bindir/mysqladmin -u root -h $hostname password 'new-password'",
           "",
           "Alternatively you can run:",
           "",
           "  $bindir/mysql_secure_installation",
           "",
           "which will also give you the option of removing the test",
           "databases and anonymous user created by default.  This is",
           "strongly recommended for production servers.",
           "",
           "See the manual for more instructions.");

    if ( !$opt->{rpm} )
    {
      report($opt,
             "You can start the MySQL daemon with:",
             "",
             "  cd " . '.' . " ; $bindir/mysqld_safe &",
             "",
             "You can test the MySQL daemon with mysql-test-run.pl",
             "",
             "  cd mysql-test ; perl mysql-test-run.pl");
    }
    report($opt,
           "Please report any problems at http://bugs.mysql.com/",
           "",
           "The latest information about MySQL is available on the web at",
           "",
           "  http://www.mysql.com",
           "",
           "Support MySQL by buying support/licenses at http://shop.mysql.com");
  }
  exit 0
}
else
{
  error($opt,
        "Installation of system tables failed!",
         "",
        "Examine the logs in $opt->{ldata} for more information.",
        "You can try to start the mysqld daemon with:",
        "$mysqld --skip-grant &",
        "and use the command line tool",
        "$bindir/mysql to connect to the mysql",
        "database and look at the grant tables:",
        "",
        "shell> $bindir/mysql -u root mysql",
        "mysql> show tables",
        "",
        "Try 'mysqld --help' if you have problems with paths. Using --log",
        "gives you a log in $opt->{ldata} that may be helpful.",
        "",
        "The latest information about MySQL is available on the web at",
        "http://www.mysql.com",
        "Please consult the MySQL manual section: 'Problems running mysql_install_db',",
        "and the manual section that describes problems on your OS.",
        "Another information source is the MySQL email archive.",
        "",
        "Please check all of the above before submitting a bug report",
        "at http://bugs.mysql.com/")
}

##############################################################################
#
#  Misc
#
##############################################################################

sub report_verbose
{
  my $opt  = shift;
  my $text = shift;

  report_verbose_wait($opt, $text, @_);
  print "\n\n";
}

sub report_verbose_wait
{
  my $opt  = shift;
  my $text = shift;

  if ( $opt->{verbose} or (!$opt->{rpm} and !$opt->{'cross-bootstrap'}) )
  {
    print "$text";
    map {print "\n$_"} @_;
  }
}

sub report
{
  my $opt  = shift;
  my $text = shift;

  print "$text\n";
  map {print "$_\n"} @_;
  print "\n";
}

sub error
{
  my $opt  = shift;
  my $text = shift;

  print "FATAL ERROR: $text\n";
  map {print "$_\n"} @_;
  exit 1;
}

sub warning
{
  my $opt  = shift;
  my $text = shift;

  print "WARNING: $text\n";
  map {print "$_\n"} @_;
  print "\n";
}
