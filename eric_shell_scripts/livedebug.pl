#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use IO::File;
use File::Temp qw/tempfile/;
use POSIX ":sys_wait_h";

my $CSX_OBJ_TREE_TOP="/EMC/csx";
my $MY_IC_NAME;
my $CONT64 = 0;
my $DUMP_KTRACE = 0;
my $LIVE_KTRACE = 0;
my $BACKEND_MODE = 0;
my $AFTER_STARTUP_EVENT = 0;
my $LOG = 0;
my $DAEMON = 0;

GetOptions
(
    'c=s' => \$MY_IC_NAME,
    '64' => \$CONT64,
    'dump_ktrace:s' => \$DUMP_KTRACE,
    'live_ktrace:s' => \$LIVE_KTRACE,
    'backend' => \$BACKEND_MODE,
    'log=s' => \$LOG,
    'daemon=s' => \$DAEMON
) or usage();

if(!$MY_IC_NAME)
{
    print "Error: container name not specified\n";
    usage();
}

my $CSX_IC_CLI;
my $CSX_IC_EXE;

$ENV{LD_LIBRARY_PATH} = "" if(!$ENV{LD_LIBRARY_PATH});

$CONT64 = 1 if($MY_IC_NAME eq "safe" or $MY_IC_NAME eq "ccsx" or $MY_IC_NAME eq "admin"); #people tend to forget it

#
# Point to right CSX obj tree
#
if($CONT64)
{
    $CSX_IC_CLI=$CSX_OBJ_TREE_TOP."/ubin/csx_cli.x";
    $CSX_IC_EXE=$CSX_OBJ_TREE_TOP."/ubin/csx_ic_std.x";
    $ENV{LD_LIBRARY_PATH}=$CSX_OBJ_TREE_TOP."/ulib64:".$ENV{LD_LIBRARY_PATH};
}
else
{
    $CSX_IC_CLI = $CSX_OBJ_TREE_TOP."/ubin32/csx_cli.x";
    $CSX_IC_EXE = $CSX_OBJ_TREE_TOP."/ubin32/csx_ic_std.x";
    $ENV{LD_LIBRARY_PATH}=$CSX_OBJ_TREE_TOP."/ulib32:".$ENV{LD_LIBRARY_PATH};
}

my $gdbstartup_fn;
my $gdbstartup_fh;
my $gdb_arguments = "";

if($DAEMON)
{
    print "Spawning livedebug daemon for $MY_IC_NAME... ";
    my ($dummy, $mutex_fn) = tempfile();
    $AFTER_STARTUP_EVENT = "shell rm $mutex_fn";#child will execute this command in case it starts ok
    
    my $pid = fork;
    die "Cannot create child process: $!" unless defined $pid;
    
    if($pid)
    {
        #
        #Parent waits for child to initialize
        #And terminates
        #
        
        do { sleep 1}
        while(-e $mutex_fn and waitpid($pid, WNOHANG) ne $pid);
        
        if(-e $mutex_fn) #if child left that file, then it failed to start and initialize. who know why
        {
            print "failed\n";
            unlink $mutex_fn;
            exit 1;
        }
        else
        {
            print "done\n";
            exit 0;
        }
    }
    else
    {
        #
        #Child redirects output
        #And carries on rest of the script
        #

        open STDOUT, "| log_output $LOG > $DAEMON" or die "output redirection failed"; #will output log_output pid to $DAEMON file, 
        #gdb output will be redirected thru rotated log pipe
        
        $LOG = 0; #dont use (gdb) logging redirection when daemon
        $gdb_arguments = "-batch "; #prevent gdb from going "interactive"
    }
}

#
# Create custom .gdbinit file with all needed info
#
my $csx_attach_info = `$CSX_IC_CLI -o execute -n $MY_IC_NAME -- -o gdbinfo | grep target`;
die("Error: container not found or not attachable") if($?);

($gdbstartup_fh, $gdbstartup_fn) = tempfile();

my $ppdbgmacros_path = "/opt/safe/safe_binaries/user/exec";

print $gdbstartup_fh <<END;
shell rm $gdbstartup_fn
file $CSX_IC_EXE
set confirm no
$csx_attach_info
set prompt (livegdb\@$MY_IC_NAME)
END


if($MY_IC_NAME eq "safe" or $MY_IC_NAME eq "ccsx" or $MY_IC_NAME eq "admin")
{
    print $gdbstartup_fh <<END;
set height 100000
echo Loading PPDBG macros... 
loadext  $ppdbgmacros_path/ppdbg.dll
echo Loading iscsiqldbg macros...
loadext  $ppdbgmacros_path/iscsiqldbg.dll
echo Set to port 0...
cpd_setport 0
echo Display htd...
cpd_ctlr htd
echo Display atd...
cpd_ctlr atd
echo Force the dump...
cpd_force_coredump
echo done\\n
END
}

if($AFTER_STARTUP_EVENT)
{
    print $gdbstartup_fh $AFTER_STARTUP_EVENT."\n";
}

if($LOG)
{
    print $gdbstartup_fh <<END;
set logging file $LOG
set logging on
END
}

if($MY_IC_NAME eq "safe" or $MY_IC_NAME eq "ccsx" or $MY_IC_NAME eq "admin")
{
    if($DUMP_KTRACE ne 0 and $LIVE_KTRACE ne 0)
    {
        print "use -dump_ktrace OR -live_ktrace";
        usage();
    }
    elsif($DUMP_KTRACE ne 0 or $LIVE_KTRACE ne 0)
    {
        $gdb_arguments = "-q -batch -nx " . $gdb_arguments; #quiet, terminate after -x, suppress .gdbinit
    }

    if($DUMP_KTRACE ne 0)
    {
        $DUMP_KTRACE = "-a -r all -T -l" if($DUMP_KTRACE eq "");
        print $gdbstartup_fh  <<END;
ktrace $DUMP_KTRACE
quit
END
    }
    elsif($LIVE_KTRACE ne 0)
    {
        $LIVE_KTRACE = "-a -r all -T" if($LIVE_KTRACE eq "");
        print $gdbstartup_fh <<END;
set pagination off
ktail $LIVE_KTRACE
quit
END
    }
}
else
{
    if($DUMP_KTRACE or $LIVE_KTRACE)
    {
        print "ktrace is only supported with ccsx container\n";
        usage();
    }
}

#
# If the caller requested a different interpreter, add that to the arguments now
#
$gdb_arguments = $gdb_arguments . " --interpreter=mi" if($BACKEND_MODE);

#
#Launch gdb
#
sys("/usr/bin/gdb $gdb_arguments -x $gdbstartup_fn");

sub usage
{
    print <<END;
Usage: livedebug.pl -c <container> [options]
Options:
    -c <container>              - container to attach
    -64                         - specifies 64 bit container
    -log="<filename>"           - duplicate output to a file
    -daemon="<pidfile>"         - spawn a daemon, place "log_output" pid to file
    
    with -c ccsx or -c safe:
    -dump_ktrace[="<ktrace options>"] - dump containts of ktrace buffer and quits
            see ktrace options in macros manual or specify "help"
        - or -
    -live_ktrace[="<ktail options>"] - show ktrace buffer real time (SIGINT to stop) 
            see ktail options in macros manual or specify "help"
END
    exit 1;
}

sub sys
{
    my $r = system(@_);
    die("SYSTEM FAILED: @_ WITH $r\n") unless ($r == 0);
}
