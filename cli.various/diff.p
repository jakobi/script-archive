#!/usr/bin/perl

# zdiff wrapper
# a rather brute force diff command (diffarg FILES findargs targetdir)
# e.g.  diff.p -v * -follow old
# all pathes are relative to both cwd and targetdir!

$brief="--brief";

args: while (1) {
   if ($ARGV[0] eq '-') { shift @ARGV; last args; }
   elsif ($ARGV[0] eq '-f'){ shift @ARGV; $find = $ARGV[0]; shift @ARGV; }
   elsif ($ARGV[0] eq '-o'){ shift @ARGV; $opts = $ARGV[0]; shift @ARGV; }
   elsif ($ARGV[0] eq '-v'){ shift @ARGV; $brief=""; }
   else{ last args; }
}

$dir=pop @ARGV;
$dir=~s/\/$//;
$cwd=`pwd`; chop $cwd;

$"=" ";
foreach $arg ( @ARGV ) {
   $arg=~s/\/$//;
   $arg=~/([^\/]+)$/;
   $basename=$1;
   $dirname=$`; if (!($dirname)) { $dirname="." }
   $files=`(cd $dirname; find $basename $find -follow -maxdepth 0 -print)`;
   if ($?) { print "\x7 *** Cannot find $basename!\n"; $err=$?; }
   @files=split(/\n/, $files); # don't fail repeatedly ...
   file: foreach (@files) {
      $dfile=$ddir="$dir/$_"; $ddir=~s/[^\/]+$//;
      $_="$dirname/$_";
      if (!(-e "$dfile")) {
         print "\n######################## " if (!($brief));
         $err=1; print    "\x7 *** $dfile does not exist: $dfile\n";
         print "\n" if (!($brief));
      } elsif ( ( (-r $dfile) && (-f _) && (-r $_) && (-f _) ) || ( (-r $dfile) && (-d _) && (-r $_) && (-d _) ) ) {
         $diffs=`zdiff $brief -r $opts $_ $dfile`;
         if ($diffs) {
            print "\n######################## " if (!($brief));
	    $err=$?; print     "\x7 *** File $_ and $dfile differ\n";
	    print "\n" if (!($brief));
	    print $diffs;
         }
      } else {
         print "\n######################## "  if (!($brief));
         $err=1; print     "\x7 *** type mismatch / unreadable: $_ or $dfile\n";
         system("ls -l $_ $dir/$_");
         print "\n" if (!($brief));
      }
   }
}
exit($err);
