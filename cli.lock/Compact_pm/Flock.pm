
my $version="0.1";
# created     PJ 200907XX jakobi@acm.org
# copyright:  (c) 2009 jakobi@acm.org, GPL v3 or later
# archive:    http://jakobi.github.com/script-archive-doc/

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
# for module-users appending data to a locked file, 
# it _might_ be useful to explicitely seek to EOF
# with seek(FH,0,2) or sysseek(...) in order to avoid lost
# updates from outside (possible? race condition between start 
# of open and success of locking).
#
# note another race: upgrading a lock from shared to exclusive transiently
# releases the lock.
#
# note: don't flock inherited or duplicated FDs - it probably won't work,
# as it's the same open-file-table-entry in the kernel in the end, and
# flock between parent and child becomes idempotent.
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


# open a bunch of files. Requires explicit assigment/test for (0,@FH)
# args    mode (! to allow per name overrides), name, ...
# returns (number-of-errors, FH-array)
sub openFH {
   my($m,$err,$m_override,$tmp,@FH)=("<",0,0,"");
   for(@_){
      do{$m=$_; $m_override++ if $m=~s/^!//; next} if m/  ^\!?(    \+?[<>]>?  |  -\|  |  \|-)$  /xo; # new default open mode
      my $FH;
      if ( $m_override and m/  ^\s*\+[<>]>?  |  ^\s*-?\|  |  \|\s*$  /xo) {
         # IFF mode starts with '!', then use insecure magic open2 if file has mode prefix override
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
               # 3 flockFH('-=',  fh, ...)   to unlock owned locks (ignore errors if any)
               #                             (NOTE: use closeFH instead!)
               # 4 flockFH('',    fh, ...)   to shared-non-blocking lock or fail
               # mode: ex(clusive), sh(ared;default), un(lock-before-return)
               #       bl(locking), nb(locking;default)
               #       - unlock before returning (NOTE: use close or closeFH() instead)
               #       = don't add defaults of sh,nb
   my ($err,$m,$op);
   $op=$err=0;

   $m=shift; $m="" if not defined $m; 
   $err=1 if not @_;

   #    8        /-/     # unlock, see below
   $op|=4 if $m=~/\bnb/; # nonblock
   $op|=2 if $m=~/\bex/; # exclusive
   $op|=1 if $m=~/\bsh/; # shared     -- can be upgraded for the calling process to ex

   # add defaults to op: shared nonblocking UNLESS exact mode requested '=' 
   $op|=4 if $m!~/\bbl/ and $m!~/=/o;
   $op|=1 if $m!~/\bex/ and $m!~/=/o; 

   $op and do{                   # non-zero op
      for(@_) { flock $_,$op or $err++ }
   };

   $op=8; if ($err or $m=~/-/) { # unlock if requested or error
      for(@_) { flock $_,$op };
   };

   return $err ? 0 : 1;
}

1;
