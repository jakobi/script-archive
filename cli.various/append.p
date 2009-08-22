#!/usr/bin/perl -w
use strict "vars";

# a rather brute force append command
# 199XXXXX PJ        jakobi@acm.org --initial version
# 20071220 PJ   0.2  
# copyright:  (c) PJ 2007-2009, GPL v3 or later
my $version="0.2";

# compress stuff if compressed target exists with additional suffix gz?
my($gz,$compressionsfx,$find,$dir,$err,$success,$ignore,$verbose,$sep);
if ($0=~m@/z[^/]+$@) { $gz=1 }
$compressionsfx='(?:\.(?:Z|bz2?|gz|tgz)$)';
$err=$success=0;
$find="";
$sep="~"x72;

args: while (1) {
   if ($ARGV[0]=~/^-?-$/)            {shift; last}
   elsif ($ARGV[0] eq '-f')        {shift; $find = $ARGV[0]; shift}
   elsif ($ARGV[0] eq '-d')        {shift; $dir=shift}
   elsif ($ARGV[0] eq '-v')        {shift; $verbose++}
   elsif ($ARGV[0]=~/^-g?z$/)      {shift; $gz=1}
   elsif ($ARGV[0]=~/^-?-h(elp)?$/){&usage; die}
   else{last}
}
$dir=pop @ARGV if not $dir;
die "no destination and/or no files" if not $dir;
$dir=~s/\/$//;

$"=" ";
my $arg; foreach $arg ( @ARGV ) {
   my($basename, $dirname, $sqbasename, $sqdirname, @files);
   $arg=~s/\/$//;
   $arg=~/([^\/]+)$/;
   $basename=$1;
   $dirname=$`; if (!($dirname)) { $dirname="." }
   $sqdirname=sq($dirname); $sqbasename=sq($basename);
   verbose("Find: cd '$sqdirname'; find '$sqbasename' $find -follow -print");
   @files=split(/\n/,`(cd '$sqdirname'; find '$sqbasename' $find -follow -print)`);
   if ($?) { err("Find cannot find $basename!\n",1) }
   $ignore="NoNoNo"x20;

   file: foreach (@files) {
      my ($ddir,$dfile,$format,$sqddir,$sqdfile,$sqsrc,$tmp,@stat,@dstat,$dest,$sqdest);
      $dfile=$ddir="$dir/$_"; $ddir=~s/[^\/]+$//;
      $_="$dirname/$_";
      $sqsrc=sq($_); $sqddir=sq($ddir); $sqdfile=sq($dfile);
      verbose("File: $_ - $sqsrc");
      if (-r) {
         if ($ddir=~/^$ignore/) { 
            ;
         } else {
            if (-d and not -d $dfile) {
               system("mkdir -p '$sqdfile'");
               if ($?) {
		  err("Cannot create (empty) dir $dfile\n");
	       }
            } elsif (-f) {
               if (!(-d $ddir)) {
                  system("mkdir -p '$sqddir'");
	          if ($?) {
                     $ignore=quotemeta($ddir);
		     err("Cannot create dir $dfile - skipping $dfile and below\n",10);
		     next file;
		  }
	       }
               $format="";
               $tmp=""; open(FH,"<$_")        and sysread(FH,$tmp,100,0); close FH; $format.=" srccompressed "   if $tmp=~/\A\037\213/; $format.=" nosrc "   if 0==length($tmp);
               $tmp=""; open(FH,"<$dfile")    and sysread(FH,$tmp,100,0); close FH; $format.=" dstcompressed "   if $tmp=~/\A\037\213/; $format.=" nodst "   if 0==length($tmp);
               $tmp=""; open(FH,"<$dfile.gz") and sysread(FH,$tmp,100,0); close FH; $format.=" dstgzcompressed " if $tmp=~/\A\037\213/; $format.=" nodstgz " if 0==length($tmp);
               @stat=stat($_);
               verbose("Format: $format");
               if      (-f "$dfile" and -f "$dfile.gz") {
                  err("Will not clobber: both plain and .gz exist for $_\n",20);
                  next file;
               } elsif ($gz and not /$compressionsfx/ and ($format=~/nosrc/ or $format!~/srccompressed/) and ($format=~/dstgzcompressed|nodstgz/)) { 
                  # append even empty gzip record, for $?/file creation
                  if (not -f "$dfile") {
                     $dest="$dfile.gz"; @dstat=stat($dest);
                     system("( echo;echo '$sep'; echo ) | gzip >> '$sqdfile'.gz");
                     system("/bin/cat '$sqsrc' | gzip >> '$sqdfile'.gz");
                  } else {
                     err("Will not create .gz, while plain file already exists: $_\n",20);
                     next file;
                  }
	       } elsif (not $gz or /$compressionsfx/ ) {
                  # possibly allow tricks if the other file's empty [0 byte or only gziprecords]??
                  if (not -f "$dfile.gz") {
                     $dest="$dfile"; @dstat=stat($dest);
                     if      ($format=~/srccompressed/ and $format=~/dstcompressed/) {
                        system("( echo;echo '$sep'; echo ) | gzip >> '$sqdfile'");
                     } elsif ($format=~/nosrc|nodst/) {
                        ;
                     } else {
                        # actually this might mix files, so make ascii separator win, as it can be
                        # used to manually recover the file with a binary true editor or perl
                        # [mixing can only happen if actual content, magic number and suffix disagree]
                        system("( echo;echo '$sep'; echo ) >> '$sqdfile'");
                     }
	             system("/bin/cat '$sqsrc' >> '$sqdfile'");
                  } else {
                     err("Will not create .gz, while plain file already exists: $_\n",20);
                     next file;
                  }
               } else {
                  err("Will not clobber - confused about non/compression:\n     ($format)\n     $_\n     $dfile\n     $dfile.gz",20);
                  next file;
	       }
	       if ($?) {
	          err("Shell error - cannot append to $dfile\n",5);
	       } else {
                  chmod $stat[2] & 07777,   "$dest";
                  chown $stat[4], $stat[5], "$dest";
                  $sqdest=sq($dest); 
#                  # for now ONLY TOUCH if the file's new
#                  system("touch -r '$sqsrc' '$sqdest'") if not defined @dstat;
	          $success++;
	       }
            } else {
	       err("Skipping non-dir/non-plainfile $_:\n",5);
	    }
         }
      } else {
          err("File $_ unreadable!\n",25);
      }
   }
}

print "# $success file(s) appended" . ( $err ? " (with errors, most recent: $err)": "" ) . "\n";
sleep 2 if $err;
exit ($err);

#######################################################################

sub usage {
   print <<EOF;
$0 [OPTIONS] FILES DEST

version: $version

append/copy iso-8859-* or UTF8 text or mbox files to DEST. 

Appended text is prefixed by a plain or gzipped separator of 
\\n~{72}\\n\\n  if the target file is non-empty, which is harmless,
as long as additional text is considered part of the previous email, 
as most mbox-capable mailreaders do. This also allows for manual
recovery if a bad html file is encountered or e.g. a non-appendable
format file (e.g. a pdf) is placed into the source or target by accident.

Options:
  -             last argument
  -d DEST       destination 
  -f FINDOPTS   additional options for restricting/finding files via find
  -v            verbosity
  -z / -gz      gzip/copy files to DEST. Compressed files will retain
                their names, all other files will gain a .gz suffix; some
                sanity checking included to avoid mixing corruption.
                [also if the basename of this command starts with z]

Notes:
  - do NOT mix plain and gzip copies in a target dir [though 
    these cases should be skipped and flagged for user attention]
  - maybe we should create tarballs if the user throws some
    non-appendable files at us.
    Or insert a (gzipped?) ~~~~ before appending further files...
  - bzip2 is FAR more suitable, so maybe we should switch to that
    format at least for compression [maybe even de/recompress if
    in old format?]. It allows recovery and block extraction
    (i.e. of partial file stretches).

EOF
}

sub err {
   my($tmp,$e)=@_;
   $err=$e if $e; # possibly OR it for more information than MOST RECENT?
   $tmp="\x07 ***".$tmp;
   $tmp=~s/\n(?!\Z)/\n    /g;
   $tmp=~s/([^\n])\Z/$1\n/g;
   print main::STDERR $tmp;
}

sub verbose {
   my($tmp)=@_;
   $tmp=~s/([^\n])\Z/$1\n/g;
   print main::STDERR "V: $tmp" if $verbose;
   return($_[0]);
}

sub sq{
   my($tmp)=@_;
   $tmp=~s/'/'"'"'/g; # \\ doesn't work!?
   return($tmp);
}
