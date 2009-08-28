#!/usr/bin/perl

# protect by locks (atomic mkdir or shared/exclusive perl flock)
# lock.pl [options] lockpath ... -- command ... # lock/command/unlock
# lock.pl [options] lockpath ...                # lock; unlock with rmdir/rm -rf

# 2002XXXX PJ   0.1  jakobi@acm.org initial version
# 20090729 PJ   0.2  added flock and command
#
# copyright: (c) 2002-2009 PJ, GPL v3 or later
# archive:   http://jakobi.github.com/script-archive-doc/
my $version="0.2";

use strict;
use warnings;
use vars;
my $Me="lock.pl";


# Compact_pm::Flock.pm is required for use of -f and --flock
#do "Flock.pm";
BEGIN{
   do{my $p=$0; $0=~s@[^/]*$@@; unshift @INC, $p};
   unshift @INC,  "$ENV{HOME}/bin", "$ENV{HOME}/bin/perl",  "$ENV{HOME}/bin/perl/Compact_pm"; 
}
use Flock; # Compact_pm::Flock


my($break,$timeout,$rc,$flock,$verbose,$terse,$lock,$err)=(0,0,0,0,0,"");
my $delaymessage=1; # regardless of terse/verbose, one pointer to point out delays please.
my $timestep=5;    # period for decrementing timeout
my $greedy=0;      # keep obtained incomplete locks?
my $flockstrict=0; # require plainfile + existance of lockfile
my $mode="ex";     # flock mode (always non-blocking)
my(@cmd,@lock,%mode,@locked,@tolock,@lockfh);

args: while(@ARGV){
   $_=shift;

   if    (/^-b$/o)               { $break=shift; }
   elsif (/^-r$/o)               { $timestep=shift; }
   elsif (/^-t$/o)               { $timeout=shift; }
   elsif (/^-q$/o)               { $terse=1 }
   elsif (/^-1$/o)               { $delaymessage=1 }
   elsif (/^-?-greedy$/o)        { $greedy=shift; }
   elsif (/^-?-flock$/o)         { $flock=1; }
   elsif (/^-?-f(lockstrict)?$/o){ $flock=$flockstrict=1; }
   elsif (/^-v$/o)               { $verbose++; }
   elsif (/^-?-$/o)              { last }  
   elsif (/^-h$|^-?-help$/o)     { &help(); exit 1; }
   else                          { unshift @ARGV, $_; last}
}
die "# no locks specified" if not @ARGV or $ARGV[0] eq '--';


$err=0;
while($lock=shift, defined $lock){
   if ($lock eq '--') {
      @cmd=@ARGV; @ARGV=(); last;
   }
   if ($flock and $lock=~/^[+\-]x$/) {
      $mode="sh" if $lock eq '+x';
      $mode="ex" if $lock eq '-x';
      next;
   }
   if ($flock) {
      warn "# $Me: lock $lock is no file\n" and ++$err if -e $lock and not -f $lock and $flockstrict;
      warn "# $Me: lock $lock does not exist\n" and ++$err if not -e $lock and $flockstrict;
   } else {
      warn "# $Me: lockpath $lock exists but is no directory??" and ++$err if -e $lock and not -d $lock;
      my $parent=$lock; $parent=~s@/[^/]*$@@;
      warn "# $Me: lockpath parent $parent does not exist??" and ++$err if not -d $parent and not $parent eq $lock;
   }
   push @lock,$lock if not $mode{$lock}; # dupes: just update mode
   $mode{$lock}=$mode;
}
die "# no locks specified\n" if not @lock;
die "# erroneous locks\n" if $err;


my $start=time;
my @lock0=@lock;
my $t;
while(1) {
   @tolock=();
   foreach $lock (@lock) {
      if ($flock) {
         my($lockfh,$openmode);
         if($flockstrict) {
            $openmode="<";
         } else {
            $openmode=">>"; 
            # QQQ silently try turning a dir into a filelock or just ignore it?
            # $lock.="/.lock" if -d $lock;
            # QQQ or hope it gets a clue and turns into a file?
            # QQQ just remove it from the list
            # next if -d $lock;
            # QQQ ABORT early on if it's a dir?
            # DEPRECIATE NONSTRICT -flock?
         }
         if (($err,$lockfh)=openFH($openmode,$lock) and not $err and flockFH($mode{$lock},$lockfh)) {
            warn ("# $Me: locked ($mode{$lock})       $lock\n") if $verbose;
            push @locked, $lock;
            push @lockfh, $lockfh;
            next;
         }
         if ($break and time-$start>$break) {
            warn ("# $Me: breaking/ignoring $lock\n"); # if $verbose;
            next;
         } else {
            warn ("# $Me: failed to obtain  $lock\n") if $verbose;
            push @tolock, $lock;
         }
      } else {
         # lock type mkdir
         $t=(stat $lock)[10];
         $t=0 if not defined $t;
         $t=$start if $t>$start;
         if ($break and -d $lock and time-$t>$break) {
            rmdir $lock; 
            unlink $lock if -z $lock; # procmail lockfile locks
#           rename $lock.$$ and warn "# ?? $Me: renamed strange lock $lock.$$\n"
            warn ("# $Me: trying to break   $lock\n") if $verbose;
         }
         if (mkdir $lock,0555) {
            warn ("# $Me: locked            $lock\n") if $verbose;
            push @locked, $lock if -d  $lock;
            next;
         } else {
            warn ("# $Me: failed to obtain $lock\n") if $verbose;
            push @tolock, $lock;
         }
      }
   }
   
   # success
   last if not @tolock;

   warn "# $Me: could not obtain all locks, retrying.\n" if not $verbose and $delaymessage-->0;
   warn "# $Me: = still to lock   ", join " ",@tolock ,"\n" if $verbose;
   warn "# $Me: = obtained locks  ", join " ",@locked ,"\n" if $verbose;
   @lock=@tolock;
   
   # failure if timeout
   if($timeout<=0) {
      warn "# !!! $Me: ABORTING - could no obtain locks ".join " ",@tolock,"\n";
      if (not $flock) {
         foreach $lock (@locked) {
            rmdir $lock;
         }
      }
      $rc=1;
      last;
   }
   
   if (not $greedy) {
      warn "# $Me: release partial set of locks\n" if $verbose;
       if ($flock) {
         foreach(@lockfh) {
            close $_;
         }
      } else {
         foreach $lock (@locked) {
            rmdir $lock;
         }
      }
      @lock=@lock0; @locked=();
   }

   warn "# = delay           $timeout - $timestep ($break)\n" if $verbose;
   sleep $timestep;
   $timeout-=$timestep;
}


if (@cmd and not $rc) {
   warn "# $Me: running command   ", join " ", @cmd, "\n" if $verbose;
   system @cmd; $rc=$?>>8;
   warn "# $Me: command returned  $rc - ".join(" ",@cmd)."\n" if $rc and not $terse;
}


# exit, with unlock if we wrapped a single command
# (for flock, exit will to it for us)
if(@cmd and not $rc and not $flock) {
   foreach(@locked){rmdir $_}
}
exit $rc;

# ----------------------------------------------------------------
sub help {
   warn <<EOF;

lock.pl [-t timeout] [-b lockbreak] [-r retry] 
        [-v|-q|-1] [--greedy (-g)] [--flock[strict (-f)]]
        [--]  lockpath ... 
        [--   [COMMAND ...]]

Create  locks  with timeout and optionally run a command. 

By default, mkdir is used, which allows the lock to also double as the
application  instance's work directory. If you provide no command, use
rm -rf lockpath ... / rmdir lockpath ... as unlock after you're done.

With  -flock, existing files are used as non-blocking exclusive  locks
via  perl's (usually NFS-safe) flock implementation. For -flock, +x/-x
turns  off/on exclusive locks. Note that -flock creates missing  locks
and  that the locks are released on exit, so use COMMAND to execute  a
command  while the files are still locked. With -flockstrict, the lock
must be an existing plain file.

For mkdir-locking, breaking happens with rmdir according to the age of
the  directory  ctime and may fail. For flock, breaking happens  after
lockbreak seconds.

Returns  0  on  success. Does not block unless -t timeout is  used  to
allow  blocking upto timeout+retry seconds. All times are specified in
seconds.  Incomplete  sets of locks are immediately released to  avoid
deadlocks,  unless  --greedy.  With type mkdir, the break  timeout  is
meassured  against min(start,lock ctime), with flock against the start
time.  Verbosity is controlled by -v/-q, with -1 reporting that  locks
could not be obtained just ONCE.

See also: 
  - lockfile(procmail)
  - vipw =^= lock.pl -f /etc/passwd -- vi /etc/passwd
    (with the slight difference that vipw used a different locking 
     scheme of *.lock / .pwd.lock and thus lock.pl and vipw don't 
     see each other)

EOF
}
