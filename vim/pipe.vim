#!/usr/bin/perl

# usage: cmd | $0 [-silent] | cmd

# implant an editor session into a pipe, allowing a 
# fallback to also forwarding the unmodified contents
# even if the user already saved a modified buffer to disk.

# created     PJ 20090803 jakobi@acm.org
# last change PJ 20090806
# copyright:  (c) 2009 jakobi@acm.org, GPL v3 or later
my $version="0.1";


# editor requirements: 
# ability to  read and write from tty redirection. Test with
# 'echo | ($EDITORPIPED /etc/hosts </dev/tty >/dev/tty;echo dummy) | wc -l'. 
# This must both allow an editor session and have wc -l see exactly 1 line.
# Use shell variable $EDITORPIPED to avoid editor guessing.

# vim tips:
#
# to just edit a bunch of files with a bufferlist in buffer 1,
# using gf to switch to the file under the cursor:
# find | sort | vim - # this '-' is half-magic, just like '.'
#
# if the file contains arbitrary characters, use Vgf to treat
# the whole line as the filename to jump to in a new buffer.
#
# vim -g and vim -remote with 2>/dev/null allow doing this 
# without a temp file when used with :w >>/dev/stdout | :q 
# to exit  [the >> is required, as vim assumes plain files
# and throws errors otherwise. Likewise, a mere :wq fails 
# and might think it fun to create a spurious '-' file 
# somewhere hidden in the fs]

$Me=$0; $Me=~s@.*/([^/]+)$@$1@;
$silent=shift if $ARGV[0]=~/^--?silent$/;
@vimargs=@ARGV; @ARGV=();
if ($ENV{EDITORPIPED}) {
   $EDITOR=$ENV{EDITORPIPED};
} else {
   # prefer vim, otherwise try guessing
   $EDITOR=$tmp if chomp($tmp=`which vim`) and not $?;
   $EDITOR=$ENV{EDITOR} if not -x $EDITOR;
   $EDITOR=$ENV{VISUAL} if not    $EDITOR;
   $EDITOR="vi" if not $EDITOR;
}
chomp($tmpname =`mktemp -q /tmp/bufpipe.$$.XXXXXX`); 
($? or $tmpname  eq "") and die "# $Me: cannot create tmpfile\n";


# read all the input from STDIN and invoke the editor
warn <<EOF if not $silent;

# $Me: pipe.vim - edit a pipe (version $version)
#
# $Me: Please edit the pipe's contents, then save.
# 
# $Me: You can break the pipe by using a non-zero exit code.
# $Me: If you already updated the file, you can still fall back
# $Me: to the original filelist by deleting all lines and
# $Me: entering a single line of #PASS, #ORIGINAL or #ORG.
# $Me: A single line of #FAIL N will not print anything and 
# $Me: exit with a non-zero rc.

# $Me: - To peek at a file in vim use gf or Vgf. 
# $Me: - use :ViewHtml to view html files / :setl noro
# $Me: (:com! ViewHtml exe "%!lynx -dump -force_html /dev/stdin" | setl ro)

EOF
$time=time;
undef $/; $_=<>;
open(FH,">",$tmpname) and print FH $_ and close FH or 
   do{unlink $tmpname; die "# ERR $Me: cannot write tmpfile\n" };


sleep 2 if time-$time<3 and not $silent;
# with useless cat to also protect against <() 
system "bash", "-c", $EDITOR.' "$@" </dev/tty >/dev/tty | cat', 
                     "$Me:$EDITOR", 
                     @vimargs, $tmpname;
$rc=$?>>8;


if (not $rc) {
   $tmp=`cat $tmpname`;
	if    ($tmp=~/\A#[\t ]*(?:FAIL|EXIT)(?:[\t ](\d+))?([\t ].*|)\Z/) {
           $rc=20; $rc=$1 if $1;
           warn "# ERR $Me: setting rc to $rc as requestion - suppressing output\n";
        } elsif ($tmp=~/\A#[\t ]*(ORG|ORIGINAL|PASS)([\t ].*|)\Z/) {
           warn "# $Me: passing on pre-editor pipe contents as requested\n";
           print $_; 
        } else {
           $tmp=~/\A\s*\z/ and $tmp=""; # spurious empty line due to broken editor?
           print $tmp;
        }
} else {
   warn "# ERR $Me: editor returned $rc - suppressing output\n";
}
unlink($tmpname);
exit($rc);
