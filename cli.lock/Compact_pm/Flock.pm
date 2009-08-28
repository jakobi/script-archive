
# created     PJ 200907XX jakobi@acm.org
# copyright:  (c) 2009 jakobi@acm.org, GPL v3 or later
# archive:    http://jakobi.github.com/script-archive-doc/
my $version="0.1";

use strict;
use vars;
use warnings;


package Flock; 
our @ISA=qw(Compact_pm::Flock);
sub import {
   shift;
   local($Exporter::ExportLevel)=1;
   Exporter::import("Compact_pm::Flock",@_);
}


package Compact_pm::Flock;
require Exporter;
our @EXPORT = qw(openFH closeFH flockFH);
our @ISA    = qw(Exporter);


# (bool,@FH) = openFH("<", "/foo/bar", "|", "ls", "cat /etc/passwd")
# bool       = flockFH("-ex", @FH)
# bool       = closeFH(@FH)

###########################################################
# on perl's flock builtin:
#
# flock is a whole file lock, trying flock, fallback fcntl and lockf 
# (vendor-defined-snafu warning apply for all 3, esp. flock(2)
#  and nfs, as flock(2) might actually be less capable than fcntl;
#  only real flock(2) do survive fork, fcntl doesn't). Note that
#  flock(2) on linux shouldn't support NFS, while perl's builtin flock()
#  does do the trick on linux.
#
# note that exec'ed apps may choose to rename a file
# thus what we've still opened isn't the file we
# have locked, and that there's a race where others
# even honoring locks can still 'rename the original'
# and place a modified copy at the same location
# before we have looked at the new file and operated on it
# (copy/rcs/...); however at least the writes
# themselves were properly protected or even sequenced.
#
# we'd need to remember the inode and recheck the inode
# to notice this. Not much to do against this, depends
# on the app we wrap - if it keeps the inode, nice, else race;
# unless we'd change the filenames before exec, which is
# not that good an idea unless with heavy lifting like
# FUSE and giving up any chance of portability
#
# note another race: upgrading a lock from shared to exclusive transiently
# releases the lock.
#
#
# fcntl example, ancient:
#  open(LOCKFILE, ">>/usr/sysop/etc/menulock") || die "cant open lockfile";
#  require('sys/fcntl.ph');
#  $lock = pack('s s l l s', &F_WRLCK, 0, 0, 0, 0);
#  fcntl(LOCKFILE, &F_SETLK, $lock) || die "another process has the lock";
#
# the skulker might also have had some locking?
#
# 
# a mkdir-based example is in lock.p



sub openFH {
   my($m,$err,$tmp,@FH)=("<","");
   for(@_){
      do{$m=$_; next} if /  ^(    \+?[<>]>?  |  -\|  |  \|-)$  /xo; # new default open mode
      my $FH;
      if (/  ^\s*\+[<>]>?  |  ^\s*-?\|  |  \|\s*$  /xo) {
         open($FH, $_)     or ++$err and next;
      } else {
         open($FH, $m, $_) or ++$err and next;
      }
      # in case of no strict refs, these may help in debugging:
      #$tmp=$_; $tmp =~ s/  ^\s*\+?[<>]>?  //xo;
      #$FH.=$tmp;
      # alternatively, try a global hash associating names to FHs
      push @FH,$FH;
   }
   return($err,@FH);
}

sub closeFH {
   my($err);
   my(@FH)=@_;
   for(@FH){ close $_ or $err+=$?; } 
   return $err ? 0 : 1;
}

sub flockFH {  # 1 flockFH('ex',  fh, ...)   to lock nonblocking or fail
               # 2 flockFH('-ex', fh, ...)   to lock nonblocking and immediately unlock
               # 3 flockFH('-=',  fh, ...)   to unlock (#2 will fail, but still unlock)
   my ($err,$m,$op);
   $op=$err=0;

   # mode: ex(clusive), sh(ared;default), un(lock-before-return)
   # bl(locking), nb(locking;default)
   $m=shift; $m="" if not defined $m; 
   $op|=4 if $m=~/\bnb/;
   $op|=2 if $m=~/\bex/;
   $op|=1 if $m=~/\bsh/; # can be upgrade for the process itself to ex
   # add defaults to op?
   $op|=4 if $m!~/\bbl/ and $m!~/=/o;
   $op|=1 if $m!~/\bex/ and $m!~/=/o; 


   $op and do{for(@_) {
      flock $_,$op or $err++;
   }};
   $op=8; if ($err or $m=~/-/) {
      for(@_) { flock $_,$op };
   }
   return $err ? 0 : 1;
}

1;
