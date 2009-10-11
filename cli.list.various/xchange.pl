#!/usr/bin/perl

# perl script to replace text strings using std perl wildcards
# -s / -sf use quotemeta and thus require perl 5. You may want to comment out this statement

my $version="2.2";
# 1993XXXX PJ   0.1  jakobi@acm.org initial version, perl4 HPUX / Amiga / SunOS
# 19960830 PJ   2.1  
# 200XXXXX PJ        backup only changed files, fixed symlink handling
# 20090801 PJ   2.2  small fixes, sqfilename
#
# copyright:  (c)1993-2009 PJ, GPL v3 or later
# archive:    http://jakobi.github.com/script-archive-doc/

# pj2000: could stand a number of speedups: 
# - using pos to avoid $`, et al
# - using precompiled subs to speedup looping over expressions for each line for each file
# - passing file contents by reference
# - make -m the default (the major speedup :)

&Init;
&Commandline;

# any work to do?
if (($#substitution == -1) || (($#ARGV == -1) && ($teststring eq ""))) { die "Nothing to do.\n";}

# test expressions first?
if ($teststring ne "") {
   for($i=0;$i<=$#ARGV;$i++) { print "inputfile $ARGV[$i]\n"; }
   $line = &Substitute($teststring);
   print "input : $teststring\noutput: $line\n";
   exit(0);
}

# real processing
file: while($#ARGV>-1) {
   $filename=shift(@ARGV);
   $sqfilename=sq($filename);

   # 1.1   check for existance
   if (! -f $filename) {
      print stderr "* !!! Cannot stat file. Skipping $filename.\n";
      next file;
   }
   

   if ($filename=~/[\xa\xd]/) { warn "skipping illegal filename $filename\n"; next }
   
   $filetype0=`file '$sqfilename'`;

   # 1.2   check for binary files (occurence of 0x00)
   if (open(infh, "<",$filename) == 0) {
      print stderr "* !!! Cannot open file for input. Skipping $filename.\n";
      next file;
   }
   read(infh,$block,512,0);
   close(infh);
   $l=length($block);   
   $i=index($block,pack("c",0));
   if(($i<0) || ($i>$l)) { $filetype="text"; }
   else { $filetype="data"; }

#   $filetype=`file -m /dev/null '$sqfilename'`;
#   $filetype=~s/.*(data)[\n]+$/$1/;

   if ($filetype eq "data") {
      if ($opt_accept_binary_files) {
         print stderr "* ! Processing binary file $filename\n";
      } else {
         print stderr "* ! Skipping binary file $filename\n";
         next file;
      }
   }

   # 1.3   check for empty files
   if ($l<=0) {
      print stderr "* ! Skipping empty file $filename.\n";
      next file;
   }

   # 1.4   process file
   if (open(infh ,"<",$filename)  == 0) {
      print stderr "*** !!! Cannot open file for input. Skipping $filename.\n";
      next file;
   }
   print stderr "* Processing file $filetype0" if $verbose;
   $lineno=1;
   $out="";
   $changes=0;
   while(<infh>){
      $out.=&Substitute($_);
      $lineno++;
   }

   # 1.4   write and backup files (a sorry hack...)
   if ($changes) {
      print stderr "# file changed: $filetype0\n";
      system ("cp -p '$sqfilename' '$sqfilename'.original");
      if ($?) {
         print stderr "*** !!! Cannot backup file for processing. Skipping $filename.\n";
         next file;
      }
      if (open(outfh,">",$filename) == 0) {
         print stderr "*** !!! Cannot open file for output. Skipping $filename.\n";
         close(infh);
         next file;
      }
      print outfh $out;
   }
   
   close(infh); close(outfh);
   system("mv '$sqfilename'.original '$sqfilename'") if ($opt_no_exec);

}
   
exit(0);

# SUBROUTINES ##################################################

sub Init {
   $teststring=""; 
   $efile=""; $vfile="";
   $mode_e=1; $mode_v=2;
   $mode_r=3; $mode_s=4;
   $opt_single_match_per_line=0;
   $opt_accept_binary_files=0;
   $opt_verbose=0;
   $opt_no_exec=0;
}

sub Commandline {
   if ( $#ARGV < 1 || $ARGV[0] eq "-h" ) { &Usage; } 
   args: while(1){
      if    ($ARGV[0] eq '-V'){  shift @ARGV; $opt_verbose = $opt_verbose | 1; }
      elsif ($ARGV[0] eq '-VV'){ shift @ARGV; $opt_verbose = $opt_verbose | 2; }
      elsif ($ARGV[0] eq '-1'){  shift @ARGV; $opt_single_match_per_line=1; }
      elsif ($ARGV[0] eq '-b'){  shift @ARGV; $opt_accept_binary_files=1; }
      elsif ($ARGV[0] eq '-m'){  shift @ARGV; undef $/; }
      elsif ($ARGV[0] eq '-n'){  shift @ARGV; $opt_no_exec=1; }
      elsif ($ARGV[0] eq '-t'){  shift @ARGV; $teststring=shift(@ARGV); }
      elsif ($ARGV[0] eq '-e'){  shift @ARGV; $substitution[$#substitution+1]=shift(@ARGV); $mode[$#mode+1]=$mode_e; }
      elsif ($ARGV[0] eq '-r'){  shift @ARGV; $substitution[$#substitution+1]=shift(@ARGV); $mode[$#mode+1]=$mode_r; }
      elsif ($ARGV[0] eq '-s'){  shift @ARGV; $substitution[$#substitution+1]=shift(@ARGV); $mode[$#mode+1]=$mode_s; }
      elsif ($ARGV[0] eq '-v'){  shift @ARGV; $substitution[$#substitution+1]=shift(@ARGV); $mode[$#mode+1]=$mode_v; }
      elsif ($ARGV[0] eq '-ef'){ shift @ARGV; &GetSubstitutions($efile,$mode_e); }
      elsif ($ARGV[0] eq '-vf'){ shift @ARGV; &GetSubstitutions($efile,$mode_v); }
      elsif ($ARGV[0] eq '-rf'){ shift @ARGV; &GetSubstitutions($efile,$mode_r); }
      elsif ($ARGV[0] eq '-sf'){ shift @ARGV; &GetSubstitutions($efile,$mode_s); }
      else { last args; }
   }
}

sub Usage {
   print "
$0 [OPTIONS] files

version: $version

applies the perl substitution patterns on each line of every file. 
The original files are saved using the extension .original.
Most binary files will be skipped by default. Add i after the 
pattern for case insignificant substitution. 

* Hardlinks to original files are not set to modified files.

Options
   -1          only apply first matching substitution command 
               for each line of input
   -m          merge file into a single line for matching (slurp)
   -b          do not skip binary files
   -h          this text
   -V,VV       verbose
   -n          test substitution on files (restoring original files)
   -t string   test substitution on string 

   -s s1++s2    *globally* replace string1 by string2 
               (no regexp, uses quotemeta for string1 and
	        quotes / in string2; case sensitive)
   -sf file    as above, one replacement command per line
   -r exp      perl 4 or perl 5 expression 
               (e.g. -r 's/OLD/NEW/ig'
                  or -r 'eval(\"s/\".quotemeta(\"OLD\").\"/NEW/ig\")'
		variables: \$filename - file
		           \$_        - active line)
   -rf file    as above, one replacement command per line

   (the old options -e, -ef, -v, -vf are obsolete)
";

#   [ obsolete commands (s<SUBST>g):
#     -e exp      substitution string pair
#     -v exp      perl statements evalutating to a substituation pair
#     -ef file    input file containing one substitution per line
#     -vf file    dito. (strings are checked before evaluated strings)
#   ]
#
#
# example for -v:
#- patching binaries (ATTN: don't change the length of the file!)
#         perl  xchange.p -v '\"/COMMAND/cmd\".pack(\"c\",0).\"123/\"' Dir/*
#         use correct architecture! using tcsh:
#	 rcp sj18:/usr/local/dist/DIR/bin/vim .
#         xchange.p -b -m -v '\"/\\\\/usr\\\\/local\\\\/dist\\\\/DIR\\\\/vim-3.0\\\\/lib\\\\/vim.hlp/\\\\/u\\\\/coders\\\\/jakobi\\\\/etc\\\\/vim.hlp\".pack(\"c\",0).\"0123456789/\"' vim
#         chmod 755 vim
   exit (1);
}

# substitute text within a line
# bug: amiga 4.036: local invalidates parameter passing! - is $line a special variable?
sub Substitute {
# amiga work around
   $substitute_line=shift(@_);
   local($_,$i,$line,$rc,$_); 
   $line=$substitute_line;
# unix:
# local($_,$i,$line,$rc); 
# $line=shift(@_);

   print "#$lineno: $line" if (!($opt_verbose^3));
   $rc1=0;
   match: for ($i=0; $i<=$#substitution; $i++) {
      $rc=0;
      if ($mode[$i] eq $mode_s) { # transform string to regexp
	 $s1=$substitution[$i]; $s2="";
	 if ($s1=~/\+\+/) {
            $s1=$`;
	    $s2=$';
	 }
	 $substitution[$i]=join("", 's/', quotemeta($s1), '/', quotemeta($s2), '/g');
         $mode[$i]=$mode_r;
      }
      if ($mode[$i] eq $mode_v) { # perl regex substitution
         eval( '$rc = $line=~s'.$substitution[$i].'g' ); 
      } elsif ($mode[$i] eq $mode_e) { # perl eval statement substitution
         eval( '$rc = $line=~s'.eval($substitution[$i]).'g' ); 
      } elsif ($mode[$i] eq $mode_r) { # raw perl expression
         $_=$line;
	 eval($substitution[$i]);
         $rc = ( $_ ne $line); 
         $line=$_ if ($rc);
      } else {
         warn "Unknown substitution mode\n";
      }
      if ( $@ ne "" ) { print stderr "* !!! Pattern error: $@ - skipping\n"; } 
      $rc1+=$rc;
      last match if ($rc && $opt_single_match_per_line);
   }
   print "#$lineno#$rc1#\n" if ($rc1 && $opt_verbose);
   print "$line" if ($rc1 && $opt_verbose&2);
   $changes+=$rc1;
   return($line);
}

# get substitutions from file?
sub GetSubstitutions {
   local($f,$m,$_);
   $f=shift(@_);
   $m=shift(@_);

   if ($f ne "") {
      open(fh,"<",$f) || die "Cannot open expression file $f for input.\n";
      while(<fh>) {
         chop;
         $substitution[$#substitution+1]=$_;
         $mode[$#mode+1]=$m;
      }
      close(fh);
   }
}

sub sq{
   my($tmp)=@_;
   $tmp=~s/'/'"'"'/g; # \\ doesn't work!?
   return($tmp);
}

# vim:ft=perl
