#!/usr/bin/perl

# description: threading example: tail with blocking threads
# last change 20090602 jakobi@acm.org

# allowing to use tail with non-select-able "files" like the
# shell process substitution <(cmd) or to "tail" over
# output from multiple ssh sessions. Note that for plain
# files, we degenerate to sleep-3-sec-busy waiting, so 
# stat-ing and falling back to select() for this case 
# would be an optimization.
#
# see man perlthrtut
#
# example:
#
# instead of the usual workaround to have remote-host-local
# tails to remote-host-local summary files with ssh remote
# "tail -f summary" > summary.remote and locally tailing 
# these, we can just say $0 <(ssh remote tail) <(tail).

use threads;
use threads::shared;
$|=1;
$verbose=0;
$bufsize=4095; # just larger than most lines...
$sleep=3;                  # becomes thread-local...
my $output    :shared =""; # globaly synchronized with (only with my)
my $outputlen :shared =0;  # some restrictions on content

foreach (@ARGV) {
   $thr=threads->new(\&reader, $_); 
   push @reader,$thr;
   push @thr,$thr;
}

$thr=threads->new(\&writer); 
push @thr,$thr;
$thr->join; # main thread: just hang and wait for ^C
exit;

sub writer {
   vprint("starting: writer\n",1);
   while(1) {
      vprint("writer - $outputlen\n",2);
      { 
         lock($output);
         if ($outputlen) {
            print $output;
            $output="";
            $outputlen=0;
         }
      }
      sleep $sleep;
   }
   vprint("exiting:  writer\n",1);
}

sub reader {
   my($file)=@_;
   my($buf,$len);
   vprint("starting: reader $file\n",1);

# BUG POSSIBILITY 
# IN MIXING OPEN-FORK/IPC WITHIN THREADING
# want to guess what happens for e.g. $file="tail -f X0|" ?
# then again, given bash command substitution <(), opening
# pipes is no longer a gain in expressitivity in such basic cases. 
# --> seems to work (reliable?)
# --> though it hangs even after the input commands died, so
#     we skip ensuring that FH is still valid, which indeed
#     we do not check (undef bytecount + nonempty $! should detect 
#     this situation for "tail -f X0|"-style stuff. AND WITH 5.8
#     IT DEFINITELY DOES _NOT_ for both perl open "...|" and bash 
#     <() cases. Sigh.)

   open(FH, "$file") or warn "cannot open $file";
   # sysopen(FH, $file, 2) or warn "cannot open $file";

# a small problem, sysread returns at eof and does not want
# to block even w/o O_NONBLOCK, so we degenerate to 
# busy waiting for plain files.
   $buf=""; $len=0; while(defined $buf and defined $len) {
      $len=sysread(FH, $buf, $bufsize);
      vprint("reader $file: $len chars sysread (global $outputlen - $!)\n",2);
      if ($len) {
         lock($output);    
         $output.=$buf;
         $outputlen+=$len;
      }
      # print $buf;
      sleep $main::sleep;
   }
   vprint("exiting:  reader $file\n",1);
}

sub vprint {
   print main::STDERR $_[0] if not $_[1] or $verbose>=$_[1];
}
