#!/usr/bin/perl
# #!perl # -Sx: line count is one off; -w: tested.
# eval 'exec perl -Sx $0 ${1:+"$@"}'
#   if 0;

# version 1.6pj 1997-07-03 jakobi@acm.org
# generate display of a directory tree as a html page


# See also: HTMLCHEK4's makemenu `find...` to build a tree acc. on the title/Hx values


###
### netscape3 file:/home/users/jakobi/sites/hpspies1/gi/gi-html/other/vrgi/vrgfiles.html
### cd /home/jakobi/sites/gi/gi-html/other/vrgi
###
### (( gfind  . -follow -print | sort ) ; ( gfind  ../vrg -follow -print | sort )) | grep -v RCS | grep -v OLD | /usr/proj/gi/bin/dir2html.p -t -m -d > vrgfiles.html
###


# NOTES:
# - duplicate '/' in input and sort afterwards: directories are listed first :)
# - surprise: A/, A/B, A.x with find|sort is indeed sorted as A, A.X, A/B
# - if you do not want to use db_cgi.p, comment out the 2 lines containing db_cgi
#   (ATTN: afterwards, use only absolute http links!)

# BUGS:
# - this beast has considerable grown beyond it's original purpose - it may be
#   time for a complete rewrite...


$newperiod=31*24*3600; 
$new         ="<TT>&#160;*&#160;</TT>"; # when & what to display for changed files
$new_default=""; # so much for inline fixed width fonts...
$now=time;
$onlyentries=0;

$date=`/bin/date +"%d%b%y"`;
$date=~s/[\n]//g;
$head="<HTML>\n<HEAD><TITLE>Directory tree</TITLE></HEAD>\n<BODY>\n<H2>Directory tree</H2>\n\Generated on $date<BR>\n<A HREF=\"../\">Parent directory</A>\n<HR>\n";
$tail="</BODY>\n</HTML>\n";

# control files we're going to use
$suffix=""; # actually a prefix for the suffix...
$list_head="head";
$list_tail="tail";
$list_par ="par";
$list_name="name";
$list_skip="skip";

$i=0;
$LIST=0;
$indent="  ";
$|=1;
$describe=1;
$none="";
$cellmax=8; # if table: number of cells per row
# you can strip this if you remove any db_cgi dependency (i.e. the url rewriting)
$0=~/(.*)\/[^\/]+$/;
push @INC, "$ENV{HOME}/bin", "$ENV{HOME}/.cgi-bin", "$ENV{HOME}/cgi-bin", "/usr/proj/gi/cgi-bin/GIwais", "$1";
require "db_cgi.p"; &db_cgi::setup; 

args: while(@ARGV){
   if ($ARGV[0] eq '-v'){ shift @ARGV; $verbose = $verbose | 1; }
   elsif ($ARGV[0] eq '-b'){ shift @ARGV; $flag_base=1; }
   elsif ($ARGV[0] eq '-B'){ shift @ARGV; $flag_basename=1; }
   elsif ($ARGV[0] eq '-d'){ shift @ARGV; $flag_dir=1; }
   elsif ($ARGV[0] eq '-D'){ shift @ARGV; $skipendofdir=1; }
   elsif ($ARGV[0] eq '-D0'){ shift @ARGV; $skipdir0=1; }
   elsif ($ARGV[0] eq '-t'){ shift @ARGV; $terse=1; }
   elsif ($ARGV[0] eq '-n'){ shift @ARGV; $describe=0; }
   elsif ($ARGV[0] eq '-N'){ shift @ARGV; $nodescribeanchor=1; }
   elsif ($ARGV[0] eq '-p'){ shift @ARGV; $addpars=1; }
   elsif ($ARGV[0] eq '-l'){ shift @ARGV; $onlyentries=1; }
   elsif ($ARGV[0] eq '-i'){ shift @ARGV; $inline=1; }
   elsif ($ARGV[0] eq '-multi'){ shift @ARGV; $multilevel=1; $table=0;}
   elsif ($ARGV[0] eq '-table'){ shift @ARGV; $multilevel=0; $table=1;}
   elsif ($ARGV[0] eq '-table2'){ shift @ARGV; $tabledetailcol=1; $multilevel=0; $table=1;}
   elsif ($ARGV[0] eq '-newt'){ shift @ARGV; $newperiod=$ARGV[0]*24*3600; shift }
   elsif ($ARGV[0] eq '-news'){ shift @ARGV; $new=$ARGV[0]; shift }
   elsif ($ARGV[0] eq '-nonewdir'){ shift @ARGV; $nonewdir=1 }
   elsif ($ARGV[0] eq '-not'){ shift @ARGV; $not=$ARGV[0]; shift }
   elsif ($ARGV[0] eq '-reset'){ shift @ARGV; $reset=$ARGV[0]; shift }
   elsif ($ARGV[0] eq '-read_par' ){ shift @ARGV; $head_par=&read(shift, $none); $file_head_par=1}
   elsif ($ARGV[0] eq '-read_head'){ shift @ARGV; $head    =&read(shift, $none); $file_head    =1}
   elsif ($ARGV[0] eq '-read_tail'){ shift @ARGV; $tail    =&read(shift, $none); $file_tail    =1}
   elsif ($ARGV[0] eq '-prefix'){ shift @ARGV; $suffix=$ARGV[0]; shift }
   elsif ($ARGV[0] eq '-set_head'){ shift @ARGV; $list_head.=":".shift }
   elsif ($ARGV[0] eq '-set_tail'){ shift @ARGV; $list_tail.=":".shift }
   elsif ($ARGV[0] eq '-set_par' ){ shift @ARGV; $list_par .=":".shift }
   elsif ($ARGV[0] eq '-set_name'){ shift @ARGV; $list_name.=":".shift }
   elsif ($ARGV[0] eq '-set_skip'){ shift @ARGV; $list_skip.=":".shift }
   elsif ($ARGV[0] eq '-clr_head'){ shift @ARGV; $list_head="" }
   elsif ($ARGV[0] eq '-clr_tail'){ shift @ARGV; $list_tail="" }
   elsif ($ARGV[0] eq '-clr_par' ){ shift @ARGV; $list_par ="" }
   elsif ($ARGV[0] eq '-clr_name'){ shift @ARGV; $list_name="" }
   elsif ($ARGV[0] eq '-clr_skip'){ shift @ARGV; $list_skip="" }
   elsif ($ARGV[0] eq '-root'){ shift; $rold=shift; $rnew=shift; }
   elsif ($ARGV[0] eq '-h'){ shift @ARGV; &help(); exit 1;}
   else { last args; }
}


# control files - init
$qsuffix=quotemeta($suffix);
$_="head";
@{"list_$_"}=split(/[: ,]+/, ${"list_$_"}); ${"list_$_"}=""; foreach $i (@{"list_$_"}) { ${"list_$_"}.=quotemeta($i)."|" if $i} ; ${"list_$_"}=qq#(?:${"list_$_"}\\/dev\\/null)#;
$_="par" ; 
@{"list_$_"}=split(/[: ,]+/, ${"list_$_"}); ${"list_$_"}=""; foreach $i (@{"list_$_"}) { ${"list_$_"}.=quotemeta($i)."|" if $i} ; ${"list_$_"}=qq#(?:${"list_$_"}\\/dev\\/null)#;
$_="tail"; 
@{"list_$_"}=split(/[: ,]+/, ${"list_$_"}); ${"list_$_"}=""; foreach $i (@{"list_$_"}) { ${"list_$_"}.=quotemeta($i)."|" if $i} ; ${"list_$_"}=qq#(?:${"list_$_"}\\/dev\\/null)#;
$_="name"; 
@{"list_$_"}=split(/[: ,]+/, ${"list_$_"}); ${"list_$_"}=""; foreach $i (@{"list_$_"}) { ${"list_$_"}.=quotemeta($i)."|" if $i} ; ${"list_$_"}=qq#(?:${"list_$_"}\\/dev\\/null)#;
$_="skip";
@{"list_$_"}=split(/[: ,]+/, ${"list_$_"}); ${"list_$_"}=""; foreach $i (@{"list_$_"}) { ${"list_$_"}.=quotemeta($i)."|" if $i} ; ${"list_$_"}=qq#(?:${"list_$_"}\\/dev\\/null)#;


$LI   ="<LI><!-- STARTOFENTRY -->";
$FI   =" ";
$FIEND=" ";
$LIEND="<!-- ENDOFENTRY -->";
$UL   ="<UL>";
$ULEND="</UL>";

if ($table) {
   $LI   ="<TR><!-- STARTOFENTRY -->";
   $LIEND="</TR>";
   $FI   ="<TD>";
   $FIEND="</TD>"; 
   $UL   ="";
   $ULEND="";
}


$h0=&db_cgi::parseurl($rnew);
$h1=&db_cgi::parseurl("");    # use "" to fix dir-relative filenames of .name /... files

$index ="";
$index.="$head\n<A NAME=\"list\"></A>\n<!-- BEGINOFLISTING -->\n" if $file_head and not $onlyentries;


# loop over input
# prepare one entry per file in directory tree
$i=0;
file: while(<>) {
  
   # verbatim html inclusion
   if (s/^-(html)\s//i) {
      # a pseudo file name containing some html to include more or less verbatim
      &html($_,$1);
      next;
   }
   
   $orig=$_;
   $stat="";
   chop; 

print main::STDERR "File $_\n" if $verbose;
   
   # strip dir2html file suffixes
   $_="." if s/(\.leaf)?($qsuffix)?\.($list_head|$list_tail|$list_par|$list_name|$list_skip)$//o and not $_;

   #s/^\.\/(\S)/$1/; # allows using 'find .' to properly keep stuff together...
   s/\/\/+/\//g;

   # strip trailing /
   s/\/+$//g;     

   next if /^#/;
   next if not /\S/;
   next if exists $DONE{$_} and $DONE{$_};
   # test whether we've an entry from an already SKIPped directory...
   $tmp=$_; while ($tmp=~s/(\/)[^\/]+\/*?$//o) {
      if (exists $DONE{$tmp}) {
         next file if 2==$DONE{$tmp};
         last      if $DONE{$tmp};
      }
   }
   $DONE{$_}=1;

print main::STDERR "ENTRY0 $_\n" if $verbose;
   
   # remember path for processing end of directory 
   if (/\/[^\/]*$/) { $path=$` } else { $path="" }
   ($pathlast,$pathcurrent)=($pathcurrent,$path);
   
   # skip files/directories with a .skip file of the same basename
   $tmp=&test($_, \@list_skip); 
   # new: $_.leaf (for directories: in parent dir; not tested for in the $_ dir itself)
   $tmp=&test("$_.leaf", \@list_skip) if not $tmp;
   $DONE{$_}=2 if $tmp;                         # skip dir contents
   next if $tmp and not $tmp=~/(\/|\.leaf)($qsuffix)?\.$list_skip$/; # skip current entry unless it's X/.skip (then list dir)
   next if $tmp and -d $_ and grep(/($qsuffix)?\.$list_skip$/, glob("$_*")); # special case: two skips??
print main::STDERR "ENTRY1 $_\n" if $verbose;

   # skip common backup files, ...
   next file if /\.(bak|swp|original|backup|back|arb|%|~|old)$/;
   next file if /(%|~)$/;

   # skip dirs
   next file if /(^|\/)OLD|RCS|SCCS\//;

   # skip dir2html control files - default or userdefined
   next file if /^(.*\/)?\.($list_head|$list_tail|$list_par|$list_name|$list_skip|ht[^\/\s]*|head|tail|skip|name)$/;

   # skip httpd files; usually starting with .ht* (htpasswd/...)
   next file if /(^\.ht|\/.ht)[^\/\s]*$/;

   # increment file counter
   $i++;
print main::STDERR "ENTRY2 $_\n" if $verbose;

   # first entry in list - if it's a directory, check for html header and footer
   if ($i==1) {
      if ( -d $_ ) {
         # print customized document heading / footer
	 if (not $file_head_par)  { $tmp =&read("$_/", \@list_par);  $head_par=$tmp if $LAST_TEST; }
         if (not $file_head    )  { $tmp =&read("$_/", \@list_head); $head    =$tmp if $LAST_TEST; }
	 if (not $file_tail    )  { $tmp =&read("$_/", \@list_tail); $tail    =$tmp if $LAST_TEST; }
      }
      # expand variables in header/... (esp. $date)
      replacement: while(1) {
         last if not $head=~/[\$][A-Za-z_]+/ ;
	 $pre=$`; $post=$';
         $match=eval('$'."$2");
	 $head=$pre.$match.$post;
      }
      $index.="$head\n<A NAME=\"list\"></A>\n<!-- BEGINOFLISTING -->\n" if not $onlyentries and not $file_head;
      next if $skipdir0;
   } 
   
   # exclude files acc. to user regexp
   if ($not) {
      next if /$not/;
      print main::STDERR "dir2html-regexp error for $not:\n$?\n" if $?;
   }

   if ($table==1) { $table=2; $index.= "<TABLE WIDTH=\"98%\" COLS=$cellmax BORDER=1>\n"; }
 
   # skip directories? even if we may see no files?
   if ( -d $_ ) { 
      next file if not $flag_dir and not &test($_, \@list_name); 
      
      # add trailing slash
      $_.='/';
   }
   # directory level / directory comment
   $DIRNAME=""; $BASENAME=$_;
   if (/([^\/]*)([\/]*)?$/) {
      $BASENAME="$1$2";
      $DIRNAME=$`;
      $DIRNAME=~s/\/\/*/\//g; # remove multiple 
   }
   # we do not consider .. here
   $tmp=$DIRNAME;    $DIRLEVEL=$tmp=~s/\///go;     # current  level
   $tmp=$OLDDIRNAME; $OLDDIRLEVEL=$tmp=~s/\///go;  # previous level
   $COMMONNAME=$OLDDIRNAME;                        # how many levels up in 
                                      # hierarchy? e.g. tmp/x/y/z to tmp/a/b
   if (0==index($DIRNAME, $COMMONNAME)) {
      ;
   } else {
      common: while($COMMONNAME=~s/((\/)\/*)?[^\/]+\/*$/$2/go) {
         if (0==index($DIRNAME, $COMMONNAME)) {
	    last common;
         }
      }
   }
   $tmp=$COMMONNAME; $COMMONLEVEL=$tmp=~s/\///go;  # base level
   
   if (not $multilevel and ($COMMONLEVEL!=$OLDDIRLEVEL or $COMMONLEVEL!=$DIRLEVEL)) {
      $tmp=$LIST;
   } else {
      $tmp=$OLDDIRLEVEL-$COMMONLEVEL;
   }
   
   # mark end of subdir
   $endofdir=0; $endofdir=$LIST if $tmp>0 and $LIST and not $DIRNAME=~/$qOLDDIRNAME/ and not $multilevel and not $terse;
   if ($endofdir and not $skipendofdir) {
      $tmp=$FI; $tmp=~s/<TD>/<TD colspan=$cellmax bgcolor="#CCCCCC">/oi;
      $index.= $indent x $LIST . "$LI $tmp .. <BR>$FIEND $LIEND\n";
   }

   # ../DIRs are independent directory entries, thus we start at level 0
   if (/^\.\.\// and (not $COMMONNAME or $COMMONNAME=~/^\.\.\/?$/) and not ($DIRNAME and $DIRNAME eq $OLDFILENAME) 
       or $reset and /^(?:\.\/)?$reset\/?$/ ) {
      while($LIST>0) { $endofdir=$LIST if not $endofdir; $LIST--; $index.= $indent x $LIST . "$ULEND\n"; }
   }
   
   # also reset if we're at list level 0
   if ($LIST eq 0) {
      $OLDDIRLEVEL=$tmp=$LIST=$DIRLEVEL=$COMMONLEVEL=0;
   }

   if (not $skipendofdir or $multi) {
      while($tmp>0 and $LIST) { $endofdir=$LIST if not $endofdir; $tmp--; $LIST--; $index.= $indent x $LIST . "$ULEND\n"; }
      $tmp=$DIRLEVEL-$COMMONLEVEL;
      up: while($tmp>0 and ( $multilevel or not $LIST )) { $index.= $indent x $LIST . "$UL\n"; $tmp--; $LIST++; last up if not $multilevel; }
   }
   $OLDDIRNAME=$DIRNAME; $qOLDDIRNAME=quotemeta($OLDDIRNAME); $OLDFILENAME=$_;
   
   # get datestamp, size and description
   $newstamp=$new_default; $headline=0;
   $headline=1 if not $multilevel and -d $_;
   $url=""; $size=0;
   @stat=(); @time=(0,0,0,0,-1,0,0,0,0,0,0,0);
   
   $detail=&read("$_", \@list_name);
   $detailfile=$LAST_TEST;
   next if $detailfile and not $detail=~/\S/;
  
   $newstamp="";
   $newstamp=" $new" if $now-$stat[9]<$newperiod and @stat and not ($nonewdir and -d $_);
   if (-r $_) {
      @stat=stat($_); $size=$stat[7]; $url=$_;
      @time=localtime($stat[9]);
   }
   # newstamp for new description OR for new file...
   $newstamp=" $new" if $now-$stat[9]<$newperiod and @stat and not ($nonewdir and -d $_);
   $stat=sprintf("%04dk %02d%02d%02d$newstamp", $size/1000+0.999, $time[5]%100, $time[4]+1, $time[3]);
   $detail.="<p>" if $addpars and not $detail=~m!</?p>\s*$!io;

   # which url to link to in listing? no link if empty.
   #- begins with \'<A HREF="URL">LINK</A>\' and whitespace or
   $url=$2 if $detail=~s!^\s*<A\s[^>]*HREF=(["'])?(\S*)\1\s?[^>]*>LINK</A>\s*!!io; 

## PJ: parse meta headers in first few KBytes if /\..?html?$/i ? Slow down! Untested/unused.
   #- a META Location Header: <META HTTP-EQUIV="LOCATION" content="/new"> or
   # $url=$4 if $detail=~m!\s*<META\s[^>]+?HTTP-EQUIV=(["'])?LOCATION\1(VALUE|CONTENT)=(["'])?(\S+)\3\s?[^>]*>\s*$!io; 
   #- a META Refresh Header: <META HTTP-EQUIV=REFRESH CONTENT="0; URL=/new">
   # $url=$4 if $detail=~m!^\s*<META\s[^>]+?HTTP-EQUIV=(["'])?REFRESH\1(VALUE|CONTENT)=(["'])?0;\s*URL=(\S+)\3\s?[^>]*>\s*$!io; 
   
   # strip empty anchors (allow user to extend description, see below)
   $detail=~s!^\s*<A\s*(HREF=(["'])?\2)?\s*>!!io;
   
   # link detection seems broken... with perl5.001m/linux
   $stat.=" SYMLINK " if -l $_;
   $stat.=" DIR "     if -d $_;

   # file comment defined
   $detail="" if not $describe;

print main::STDERR "ENTRY3 $_\n" if $verbose;

   # verbatim html inclusion?
   if ($detail=~s/^<!--\s+(html)\s+-->//i) {
      &html($detail,$1);
      next;
   }
   
   # verbatim html file inclusion
   if ($detail=~s/^<!--\s+(htmlfile)\s+(\S+)\s+-->//i) {
      local ($/); undef $/;
      $key=$1; $htmlfile=$2;
      $detailfile=~/[^\/]*$/;
      $htmlfile=db_cgi::rawpathjoin_rel($`, $htmlfile);
      $detail=&read($htmlfile, $none);
      next if not $detail=~/\S/;
      &html($detail,$key);
      next;
   }
   
   if ( $detail ) {
      $detail=~s/^ *([\s\S]*?)[ \t\n]*$/$1/g;
      # if ( $table or $stat+length($_)+length($detail) > 100 and not $terse ) { $detail="<BR>".$detail; }
      if ( $table and not $terse and not $tabledetailcol) { $detail="<BR>".$detail; }
   } else {
      if ($terse) {$detail="($stat $_)"}
   }
   if ($terse) {$stat=""}
   $newstamp="" if not $terse;


   # start list / print list item
   if (not $LIST) { $index.=  "$UL\n"; $LIST++;}
   # if ($LIST and $headline) { $index.= "$ULEND\n"; $LIST--;} # headline is incompatible with multiline
   # newstamp copy is used only if terse output is used.
   $string="";
   $string.= $indent x $LIST . $LI if not $headline;
   $string.= $LI if $headline and $table;
   $string.=" $FI $newstamp $stat $FIEND $FI " if $table;
   $string=~s/<TD>/<TD nowrap>/i if $table; # nowrap firsth cell
   $string.="<H3>" if $headline and not $detail=~/<H\d/i;
   $string.=" $newstamp $stat " if not $table;
   
   $name=$url;
   $name=$_ if $flag_base;
   $name=~s"^.*?([^/]+/?)$"$1" if $flag_basename;
   $url="#" if $flag_base and not $url; # flag for missing files
   $string.= "<A HREF=\"$url\">" if $url;
   
   # print: where/how to anchor the link ($aend = </a> tag placement and string)
   # when flag_base is set: end link always, ignore possible spurious </a>
   $aend=""; $aend="</A>"  if $url      and (not $detail=~/^((?!<A)[\s\S])*<\/A/i or $$nodescribeanchor) or $flag_base;
   $hend=""; $hend="</H3>" if $headline and (not $detail=~/<H\d/i and not $detail=~/^((?!<H\d)[\s\S])*<\/H3/i or $nodescribeanchor);
   $name="" if $terse;
   $name="LINK" if ($url and $terse and length($detail)>50 and not $detail=~/<\/A[\s>]/i); 
   if ($name) { 
      $string.= "$name$aend"; $aend=""; 
      $string.=" -" if $detail;
      $string.=" ";
   }

   # hack... - usually correct
   $detail=~s/(<\/H3)/$aend$1/ if $headline and $aend and not $hend;

# PJ
   if ($table and $tabledetailcol and not $aend and not $hend and $url and $string=~/<TD/i) {
      $string.="<TD width='50\%'>$detail&nbsp;</TD>$aend$hend ";
   } else {
      $string.="$detail$aend$hend ";
   }
   
   # hack... - strip superflous closing anchor tag
   $string=~s#(</a(\s[^>]*?)?>(?:(?!<a).)*?)</a(\s[^>]*?)?>#$1#io; # additional, spurious second closing tags?
   $string=~s#</a(\s[^>]*?)?>##io if not $string=~m#<a(\s|>)#io; # strip closing tag when there is no anchor at all...
   
   $string.="<BR>" if not $string=~/(<BR>|<\/?P>)\s*\Z/i and not $tabledetailcol;
   $string.="$FIEND \n";
   
   # PJ: HACK
   if ($headline and $table) {
      $string=~s/(<\/?T)D/$1H/g;
      $string=~s/<\/?H3>/ /g; 
   }

   $colspan=$cellmax-1-$tabledetailcol; $colspan=" colspan=$colspan "; # one cell for size and date
   $string=~s#(<t[dh])([\s>])(?![\s\S]*?<t[dh][\s>])#$1$colspan$2#i if $table and not $detail=~/<t[dh][\s>]/i;
   
   $index.= $string;
   $index.=$indent x $LIST . $LIEND . "\n" if $LIEND;
}

# finish html page
while($LIST>0) {
   $LIST--;
   $index.= $indent x $LIST . "$ULEND\n";
   if ($table==2) { $index.= "</TABLE>\n"; }
}
$index.= "<!-- ENDOFLISTING -->\n$tail\n" if not $onlyentries;

# global rooting of results?
$output=$index;
$output=&db_cgi::changeurls($h0, $index, "", $rold, "") if $rnew;


print "$output\n";
exit;


#############################################################################################

sub read {
   # read dir2html special files allowing different defaults (languages, ...)
   local($base, $sfx)=@_;
   local($tmp,$_,$/)=("","","","","");
   undef $/;
   
   $tmp=&test($base,$sfx);
   @stat=();

   if ($tmp) {
      @stat=stat($tmp);
      open(TMP, "<$tmp"); $tmp=<TMP>; close TMP;
   } 

   if ($tmp) {
      $tmp=&db_cgi::changeurls($h1, $tmp, $LAST_TEST, "", "");
      $tmp=~s/^\s*//o; $tmp=~s/\s*$//o;
      # strip embedded table subtags if not table and no embedded local table
      # (this allows the use of additional <td> tags in an entry for additional
      #  structuring - but may terribly mess up the remaining table rows.
      #  Note: as of 970912 - the interface does not use tables for parsing, so
      #  the possibly spurious td's are stripped when working ...)
      $tmp=~s!<t[dh][\s\S]*?>! !i if not $table and not $tmp=~/<table/i;
   }

print main::STDERR "$inline - $tmp - $base \n";
   if ($inline and not $tmp and -f $base and -r $base and open(TMP,"<$base")) {
      $tmp=<TMP>; close TMP;
      if ($tmp=~/<H1>([\s\S]*?)<\/H1>/i or $tmp=~/<H2>([\s\S]*?)<\/H2>/i or $tmp=~/<TITLE>([\s\S]*?)<\/TITLE>/i) {
         $tmp="$1";
	 $tmp.="</A>" if not $tmp=~/<A/i;
      } else {
         $tmp="";
      }
   }
   
   return $tmp;
}

sub test {
   # test existance of a file
   local($base, $list)=@_;
   local($tmp,$_,$done)=("","","");

   $base.="/" if (-d $base) and not $base=~/\/$/;

   if ($base and $list and @$list) {
      foreach $tmp (@$list) {
         $_="$base$suffix.$tmp"; if (-r $_) { $done=$_; last }
         $_="$base.$tmp";        if (-r $_) { $done=$_; last }
      }
      if (not $done and $base=~s/\/+$//) {
         foreach $tmp (@$list) {
            $_="$base$suffix.$tmp"; if (-r $_) { $done=$_; last }
            $_="$base.$tmp";        if (-r $_) { $done=$_; last }
         }
      }
   } else {
      if (-r $base) { $done=$base; }
   }
   
   $LAST_TEST=$done;
   return $done;
}
  
sub html {
   # print a (hopefully terse) description
   local($_, $mode)=@_;
   $_="<!-- STARTOFENTRY -->$_\n<!-- ENDOFENTRY -->";
   local($tmp)="";
   # 64K limit here
   while(/<!--\s+DIR2HTMLCUT\s+-->([\s\S]*?)<!--\s+DIR2HTMLENDCUT\s+-->/gio) { $tmp.=$1."\n"; };
   $_=$tmp if $tmp;
   s/<HEAD[\s\S]*?>[\s\S]*?<\/HEAD[\s\S]*?>//gio;
   s/<\/?(META|BASE|LINK|HTML|BODY)[\s\S]*?>//gio;
   $tmp=$LIST; while($mode=~/^HTML/ and $tmp>0)     { $tmp--; $index.= $indent x $tmp . "$ULEND\n"; }
   if ($table) {
      $colspan=""; $colspan=" colspan=$cellmax " if not $_=~/<t[dh][\s>]/i;
      $index.= "<TR><TD $colspan>$_<BR></TD></TR>\n";
   } else {
      $index.= "<BR>$_"; 
      $index.= "<BR>" if /<p>/i;
      $index.= "\n";
   }
   while($mode=~/^HTML/ and $tmp<$LIST)             { $tmp++; $index.= $indent x $tmp . "$UL\n"; }
}   
   

sub help {
   print stderr 'Example usage:
gfind . -follow -print | sort | dir2html.p > index.html
( echo . ; gfind . -name .name -or -name \*.html -print ) | sort | dir2html.p > index.html

dir2html.p generates a html page for a given list of filenames.

Options: 
 -B                list basefile names with directory components removed
 -b	           always list basefile name X in the output even for redirected
                   or missing hyperlinks
 -d                include directory entries even if no X/.name (or X.name) exists
 -D                skip end of dir markers
 -D0               skip printing of the first directory entry
 
 -i                if .name does not exist, try h1/h2 or title for a description
 -l                print only entries, but skip html template (.head/.tail)
 -n	           no description
 -N                do not extend anchors into description
 -p                end each entry with <p> tag if missing
 -t                "terse":  print only descriptions
 
 -multi            multilevel lists instead of directory blocks
 -table	           use tables instead of lists (implies NOT -multi)
 
 -news             string to flag new/changed entries
 -newt	           interval to flag new entries [days]
 -nonewdir         do not flag directories as new?

 -not regexp       skip these filenames
 ­reset regexp     reset list depth for directory trees beginning with a filename
                   exactly matching this (anchored) regexp

 -root rold url    substitute rold in urls by url

setting header/footer for generated listing (XXX is by default head/tail/par):
 -read_XXX file    explicitly read the file, skip using the corresponding
                   file for the first filename given on stdin

setting control file extensions (XXX is one of head,tail,name,skip,par):
 
 -clr_XXX          clear previous XXX extensions 
 -set_XXX string   add XXX extensions (suffix strings separated with [ ,:])
 -prefix  string   prefix to use before .head/...: e.g. ".e" tries first reading
		   .e.head, then .head (used only for .head/.tail/.name type
		   extensions)


dir2html.p control files:

.skip/X.skip  skip file/directory

In  the  next two cases, the -s option can be used to define an optional
prefix to the suffix.

.head/.tail   in the first directory define the html template

To use the templates .head/.tail, the first filename given should be the
path   of  the  basedirectory  for  this  listing,  which  contains  the
.head/.tail files. See usage example 2 above.

.name/X.name  html description of file/directory      

The .name files for directories must be explicitely included in the list
of filenames given on stdin.

If  X.name  begins  with \'<A HREF="URL">LINK</A>\' and whitespace, this
URL is used for the hyperlink instead of the file\'s real URL.   If  the
URL  is  the  empty  string,  the hyperlink code is omitted.  X.name may
contain a </A> tag without a preceding opening <A> tag as its first  use
of  <A>/</A>  allowing  users  to extend the link description (<A> or <A
HREF=""> tags at the very beginning of X.name  will  be  stripped).   If
redirected as described, X should be a symlink to X.name (or - depending
on find parameters - it may be even missing).

If  X.name  begins  with  \'<--  html  -->\', the contents of X.name are
included verbatim into the generated listing.  If \'HTML\' is written in
uppercase, the text is written at list depth 0. This is identical to the
use of pseudo filenames starting with \'-html \' or \'-HTML \'.

Similarly, if X.name begins with \'<-- htmlfile file -->\', the contents
of  this  file are used instead (the header and meta/body/base/link tags
are stripped.  If pairs of  dir2htmlcut/dir2htmlendcut  comments  occur,
only text enclosed within each pair is used.

Notes:

-  Directory descriptions are done using <H3> unless -multi is set.  The
description is used as <H3> directory heading, unless you use  </H3>  to
restrict the headline or provide a complete headline yourself.

- ./ and ../ components in input are not resolved.

- An empty description file skips printing the basefile\'s entry.

- Use of relative links in X.name require the file to be placed  in 
  the current directory...

- For -table, 8 cells per row are assumed. If a description contains  a
  <td>, it must handle colspan      itself. For files,  one cell is used
  to display file size and date. Use the width attribute  to adjust cell
  size. The description is appended with a <BR> after the file link, with
  -table2 it is a table cell of the same table row as the file.

'; }
