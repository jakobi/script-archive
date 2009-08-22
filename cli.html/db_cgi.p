
# distributed under GNU Copyleft
# jakobi@acm.org (was jakobi@informatik.tu-muenchen.de)
#
# History
# Version 1.1     960906    first release
#         1.2     961012    modified url parsion to allow simple url?text 
#                           style queries, added form encoding,
#                           added partial mime multipart parsing into %multipart (see RFC 1867)
#         1.3	  970527    small bugfixes (PJ970527 disabled)
#         1.4     970705    some url parsing and umlaut translation
# Copyright 1996-2009 jakobi@acm.org, placed under GPL v2 or higher

# some convenience functions for cgi usage (by DBFW and other scripts)

# these functions predate LWP and survive on various heterogenous
# hosts, where sometimes only an old perl version is installed with
# only the basic packages...

# Bugs:
# - multiparts hangs before start of script: Apache/Netscape, when uploading a directory.
# - we handle just the common cases, this is no real parser for the full specification!

package db_cgi;

1;


sub setup {
   $pat_varname  ='[A-Za-z_][A-Za-z0-9_]*';
   $pat_filename ='[A-Za-z0-9_\/+\-\.]+';
   $pat_rregexp  ='[\$\^A-Za-z0-9_\/+\-\.\[\]\*\+]+';
   $pat_variable ='[A-Za-z_][A-Za-z0-9_\{\}\[\]]*';
   $pat_cr       ="((\x0d\x0a)|\x0a|\x0d)";
   $pat_cr2      ="(\x0d\x0a\x0d\x0a|\x0a\x0a|\x0d\x0d)";
   $special_chars='[\@\%\$\\\"]';

   # for cgi use
   $pat_cgi_acceptable=<<'EOF';
      $rc=((/^\/tmp/) || (/^\~\/html\/sources\//) || (/^\/tmp/));
EOF
   # cgi stuff - use these variables in forms, etc (or override them in the source)
   $maintainer="jakobi\@wwwjessen.informatik.tu-muenchen.de";
   $localhost="wwwjessen.informatik.tu-muenchen.de";
   $hostname=`hostname`; chop $hostname;
   # MIME return type default
   $httptype="text/html";
   $httpline=0;
}


# startup from shell or cgi processing
# returns 2 for forms containing data
sub main {


   
   # httpd (get/post)?
   $main::ENV{'REQUEST_METHOD'}="" if not exists $main::ENV{'REQUEST_METHOD'};
   $main::ENV{'QUERY_STRING'}  ="" if not exists $main::ENV{'QUERY_STRING'};
   $main::ENV{'CONTENT_LENGTH'}="" if not exists $main::ENV{'CONTENT_LENGTH'};
   if ($main::ENV{'REQUEST_METHOD'} eq "GET") {
      $multipart_string="";
      $query_string=$main::ENV{'QUERY_STRING'};
      # PJ: this is A BUG but avoids ampersand warnings within URLs
      # during HTML checking... (sigh) 
      $query_string=~s/\%26/\&/g; 
      &wwwrequest();
      return(1);
   } elsif (($main::ENV{'REQUEST_METHOD'} eq "POST") &&
      ($main::ENV{'CONTENT_TYPE'} eq "application/x-www-form-urlencoded")) {
      $multipart_string=$query_string="";
      if ((!(eof STDIN)) && ($main::ENV{'CONTENT_LENGTH'}>0)) {
         read(STDIN,$query_string,$main::ENV{'CONTENT_LENGTH'});
         &wwwrequest();
         return(2);
      } else {
         alarm 5;
	 # AFAIK, this should not happen
         print main::STDOUT "ERROR\n";
	 print main::STDERR "db_cgi - POST / x-www-form-urlencoded / else\n";
         return(0);
      }
   } elsif (($main::ENV{'REQUEST_METHOD'} eq "POST") &&
      ($main::ENV{'CONTENT_TYPE'}=~/^multipart\/form-data/)) {
      $query_string="";
      if ((!(eof STDIN)) && ($main::ENV{'CONTENT_LENGTH'}>0)) {
         read(STDIN,$multipart_string,$main::ENV{'CONTENT_LENGTH'}); 
         &wwwrequest();
         return(2);
      } else {
	 alarm 5;
         print main::STDOUT "ERROR\n";
	 print main::STDERR "db_cgi - POST / multipart\/form-data / else\n";
         return(0);
      }
   } elsif ($main::ENV{'REQUEST_METHOD'} eq "HEAD") {
      return(0);
   } else {
      return(-1);
   }
#  &wwwrequest();
   return(0); # no data...
}


###
### cgi processing ############################################################
###

# for dry testing with tcsh, use
# setenv REQUEST_METHOD GET
# setenv QUERY_STRING "FILE=test1.e.html"
#
# set allowed paths for httpd-requested files in &setup

# parse httpd arguments - returns $file, %args
sub wwwrequest {
   local($lang, $cgi, $key,$value);
   # return hashes with uppercase keys; keep a backup in _case hashes
   %args=%args_case=%multipart=%multipart_case=(); $id=1; $cgi=1; $status="";

   # evaluate httpd args
   # PJ970527 disabled
   #$query_string=~s/\%26/\&/g; # PJ: this is inconsistent, but avoids ampersand warnings during HTML checking...
                               #     & rarely occurs in the patterns anyway
   @fields=(split(/\&/,$query_string),split(/\//,$main::ENV{'PATH_INFO'}));
   foreach (@fields) {
      if ( /=/ && ($key=$`) ) {
         $value=$';
         $key =~ s/\+/ /go;
         $key =~ s/\%([0-9a-f]{2})/pack(C,hex($1))/eig;
         $value =~ s/\+/ /go;
         $value =~ s/\%([0-9a-f]{2})/pack(C,hex($1))/eig;
         $args{"\U$key\E"}=$args_case{$key}=$value if ($value!~/^\s*$/);
      }
   }


   # allow for script?simple-query type urls
   @fields=split(/\&/,$query_string);
   foreach (@fields) {
      if ((!/=/) && (!($args{"SEARCH"}))) {
	 s/\+/ /go;
         s/\%([0-9a-f]{2})/pack(C,hex($1))/eig;
         $args{"SEARCH"}=$_;
      }
   }

   # extract multipart_case args into %multipart_case
   # PJ: this is an incomplete hack...
   # CONTENT_TYPE=multipart/form-data; boundary=-------------------876168622...
   if ($multipart_string && $main::ENV{"CONTENT_TYPE"}=~/boundary=\s*(((?!;)\S)+)/i){
      $boundary=$1; $qboundary=quotemeta($boundary);
      @fields=(split(/-*?$qboundary-*[\t ]*$pat_cr/, $multipart_string));
      field: foreach(@fields) {
         next field if !(/\S/);
	 next field if !(/$pat_cr2/);
         $head=$`; $_=$';
	 $key="_anon_$id";
	 $key=$2 if $head=~/(^|\s|;)name="?([^\x0d\x0a"';]+)"?/i;
	 $key.="_$id" if exists $multipart_case{$key};
	 $multipart_case{$key}=$_." "; $multipart_case{$key}=~s/$pat_cr $//;
	 # get remaining attributes
         line: foreach(split(/$pat_cr/, $head)) {
	    next line if !(/\S/);
	    next line if !(/^(\S+?)\s*:\s*(((?!;)\S)+?)\s*(;\s*|$)/);
            $keyl="$key;$1"; 
	    $attrib=$';
	    $multipart_case{$keyl}=$2; $multipart_case{$keyl}=~s/\s$//g;
	    attrib: foreach(split(/\s*;\s*/, $attrib)) {
               next attrib if !(/\s*=\s*/);
               $keyla="$keyl;$`";
	       $multipart_case{$keyla}=$'; 
	       $multipart_case{$keyla}=~s/^["']//;
	       $multipart_case{$keyla}=~s/["']$//;
            }
         }
      }
      $id++; # in case there are unnamed multipart_case elements...
   }
   foreach (keys %multipart_case) {$multipart{"\U$_\E"}=$multipart_case{$_}}
   

   # extract (acceptable) file argument
   $file=$main::ENV{'PATH_INFO'};
   $file=~s/\%([0-9a-f]{2})/pack(C,hex($1))/eig;
   if ($file=~/\=/) { 
      $file=$`;
      $file=~s/[^\/]+$//;
   }
   $file=$args{'FILE'} if ($args{'FILE'});
   # filename safe?
   $file_orig=$file;
   $file=&acceptable_allowed_path($file);

#print main::STDERR "Querystring: $query_string\n";
#do { foreach (sort keys %args) { print main::STDERR "$_: $args{$_}\n"; } } ;
#print main::STDERR "File: $file (was: $file_orig)\n" ;


# HTTP line not necessary for modern servers: 
   print main::stdout "HTTP/1.0 200 Document follows\r\n" if $httpline;
   print main::stdout <<EOF if $httptype;
MIME-Version: 1.0\r
Content-Type: $httptype\r
\r
EOF
}


###
### cgi subroutines ###########################################################
###

# check for acceptable names and arguments supplied via http/html forms
# use the return value as value, not as boolean flag, as it may change the value!
sub acceptable_filename {
   local($_)=@_;
   $_=&acceptable_path($_);
   if (!(/^[A-Za-z0-9+_\-\~][\.A-Za-z0-9+_\-\~]*$/o)) {$_=''}
   s/^\.\.$//o;
   return($_);
}
sub acceptable_quoted_argument { # no ', no backslash sequences, ... allowed
   local($_)=@_; 
   $_='' if (!( /^[^'"\\\x00-\x1f\x7f-\xff]*$/o )); # maybe allow single backslashed values
   return($_);
}
sub acceptable_allowed_path {
   local($_)=@_;
   $_=&acceptable_path($_);
   if ((/^\.\./o) || (/\/\.\.+\//o) || (/\/\//o)) {$_=''}; # no updirs or strange dirs
   if ( (/^\//o) || (/^~/o) ) {				# one of the allowed absolute dirs?
      eval ($pat_cgi_acceptable);
      if ($@) { warn "\$pat_cgi_acceptable contains errors..."; $_=''}
      if (!($rc)) { $_='';}
   }
   return($_);
}
sub acceptable_path {
   local($_)=@_;
   s/\s//go;
   # restrict allowed path
   if (!(/^[A-Za-z0-9+_\-\~\.\/]+$/o)) {$_=''}
   return($_);
}
sub acceptable_dirrelative_path {
   local($_)=@_;
   s!//*!/!go; # no slash sequences, updirs, ...
   if (/^\/|^\.\.\/|\/\.\.\/|\/\.\.$|^\.\.$/o) {$_=''}
   return($_);
}
sub rawpathjoin_rel {
   local($a, $b);
   @args=@_; @_=();
   foreach (@args) { 
      while(m#(?!://)[^/]/#o) {
         push @_, $`.$&; $_=$';
      }
      push @_, $_ if $_;
   } # ham-fisted approach to deal with embedded ../
   $a=""; $a=shift @_ if @_;
   $a=&pathclean($a);
   $olda=$a;
   while(@_) {
      $a.="/" if $a and not $a=~/\/$/o;
      $b=shift @_;
#print main::STDERR "PATHJOIN: A $a + B $b =";
      $b.="/" if $b and $b=~/(^|\/)(\.|\.\.|)$/o; 
      while($b=~s/^\.\.(\/+|$)//o) { 
         if ($a=~/^(\.\.\/)*$/o) {
	    $a.="../";
	 } elsif ($a eq '/') {
	    $a="../";
	 } else {
            $a=~s/[^\/]+\/?$//o; 
         }
      }
      $a.="/" if $a and not $a=~/\/$/o;
      $a=~s/\/$//o if $a=~/\/$/ and $b=~/^\//o;
      $b=~s/^\///o if $a eq "" and $b=~/^\//o and not $olda=~/^\//o;
      $a="$a$b";
#print main::STDERR " $a = ";
      $a=&pathclean($a);
#print main::STDERR " $a\n";
   }
   return $a;
}
sub rawpathjoin {
   # default/failure: empty string.
   # given a valid, safe $a, change the path, but never escape (*) beyond 
   # the root node of $a in the filesystem
   #
   # BUG: '..' in first argument $a can be canceled by ../ in second arg $b
   # (otherwise, we'd violate (*) - we have to fail somehow anyway)
   local($a, $b, @args);
   $a=""; $a=shift @_ if @_;
   @args=@_; @_=();
   foreach (@args) { 
      $_=&pathclean($_);
      while(m#(?!://)[^/]/#o) {
         push @_, $`.$&; $_=$';
      }
      push @_, $_ if $_;
   } # ham-fisted approach to deal with embedded ../
   $a=&pathclean($a);
   while(@_) {
      $a.="/" if $a and not $a=~/\/$/o;
      $b=shift @_;
      $b.="/" if $b and $b=~/(^|\/)(\.|\.\.|)$/o and not $b=~/\/$/o; 
      while($b=~s/^\.\.\/*//o) { $a=~s/[^\/]+\/?$//o; };
      $a.="/" if $a and not $a=~/\/$/o;
      $a=~s/\/$//o if $a=~/\/$/o and $b=~/^\//o;
      $a="$a$b";
      $a=&pathclean($a);
   }
   return $a;
}
sub pathclean {
      local($_); $_=""; $_=shift(@_) if @_;
      local($tmp,$tmp1);
      s/\s//go;
      s!//+!do{ $tmp=$&; $tmp="/" if not $`=~/^[A-Z]{0,7}:$/oi or not $tmp=~/\/{2,3}/o; $tmp }!geo; # allow http:// in urls
      s!/\.(?=/)!!go;
      s!^\./!!go;
      s!^\.$!!o;
      return $_;
}
sub pathjoin {
   # build a secure path from relative components, resolving glueing '..' parts. validate results.
#print main::STDERR "ACTIVE\n";
   local($a);
   $a=&rawpathjoin(@_);
   return(&acceptable_dirrelative_path(&acceptable_path($a)));
}



# notification via email (a la Hans Maurer)
sub mail {
      local($subject, $ident, $host, $i);
      $subject=shift @_;
      
      $ident = $main::ENV{'REMOTE_IDENT'} || "<Someone>";
      $host = $main::ENV{'REMOTE_HOST'} || "<Somewhere>";

      open(MAIL, "| /usr/lib/sendmail -t -i");
      print MAIL <<EOF;
To:     $maintainer
Subject: $subject $args{LOCALSESSIONID}

*** db_cgi notification $args{"LOCALSESSIONID"} 
*** script http://$localhost$main::ENV{'SCRIPT_NAME'}
*** message was submitted by $ident \@ $host

*** [Proofread URLs ($url) and pathes against hostile characters!]

EOF
      foreach (sort(keys %args))
      {
         $val=$args{$_};
         s/\B(.)/\L$1\E/go;
         print MAIL "*** $_: $val\n";
      }
      print MAIL "\n$text\n\n";
      # append %main::ENV
      foreach $i (sort (keys %main::ENV)) {
         print MAIL "\$main::ENV{$i}: $main::ENV{$i}\n";
      }
      print MAIL "\n";
      close(MAIL);
}


# encode special chars into html entities
sub encodehtml{
   # note that &#xFF; seems legal now, too
   local($_)=@_;
   #   <   >   &   "   '
   s/([\x3c\x3e\x26\x22\x27])/"&#".ord($1).";"/geo;
   $_
}

# encode non-standard chars for urls
sub encodeurl {
   local($_)=@_;
   s/([^_\+\-A-Za-z0-9\/])/"%".unpack(H2,$1)/geo;
   $_
}

# some standard conversions for patterns
# (ARG1) , [(ARGG3)] : search string 
# (ARG2)     (action)
# - *:       disallow escaping perl 
# - WORD:    add word boundaries (match a sequence of words: A B matches A D B)
# - SUBWORD: add glue characters (match a sequence of substrings)
# escapes special characters for use in a regexp disabling some
# dangerous chars, for use in strings, etc. However - don't trust users!
# Don't use directly in eval'd strings!
sub acceptablepattern{
   local($pat)=@_;
   # [\+\?\.\*\^\$\(\)\[\]\{\}\|\\\#\:\=\!A-Z0-9] - regex chars - do not use these for quoting!
   $pat=~s!([^\t \+\?\.\*\^\(\)\[\]\{\}\|\#\:\=\!A-Z0-9])!do { '\x'.uc(unpack(H2,$1)) }!gei; # encode 
   $pat=~s!\\x24!\$!go; # unencode $ once
   $pat=~s!\\x5C!\\!go; # unencode \ once
   $pat=~s#\((?!\?[:=!])([\#\?\*\+])#do { '(\x'.uc(unpack(H2,$1)) }#gei; # disallow most extended regexp (esp. the embedded perl features for 5.05)
# print main::STDERR "accepted pattern: $pat\n";
   return($pat); 
}
sub preprocpattern{
   # PJ: use raw if we quotemeta the pattern anyway...
   local($pat,$mode,$raw)=@_;
   $raw=$pat if (!($raw));
   if ($mode eq "WORD") {
      $pat=$raw;
      $pat=~s/\s+/ /go;
      $pat=~s/([^A-Z0-9 ])/\\$1/goi if $pat ne "."; # quotemeta no blanks
      $pat=~s/(\S+)/\\b$1\\b/go;
      $pat=~s/\\ /\[\\s\\S\]\+\?/go;
   } elsif ($mode eq "SUBWORD") {
      $pat=$raw;
      $pat=~s/\s+/ /go;
      $pat=quotemeta($pat) if $pat ne ".";
      $pat=~s/\\ /\[\\s\\S\]\+\?/go;
   } else {
      ;
   }
   return("($pat)");
}

# hidden fields - first remove the fields to skip! (except search\d*, mode fields)
sub hidefields{
   local(%args)=@_;
   local($form,$name,$value);
   arg: foreach (sort keys %args) {
      next arg if /^(search\d*)|(mode)$/oi;  # skip search or mode strings
      next arg if $args{$_}!~/\S/o;          # skip empty args
      $name =&encodehtml($_);
      $value=&encodehtml($args{$_});
      $form.="<INPUT TYPE=\"HIDDEN\" NAME=\"$name\" VALUE=\"$value\">\n";
   }
   return($form);
}

# primitive parsing of common urls... 
sub parseurl {
   # 1. host, ... components.
   # 2. url       component groups; data is NOT necessarily kept uptodate.
   # 3. *_*       convenience parsing; data is NOT necessarily valid or kept uptodate.
   # NOTES:
   # - see various IETF drafts on URLs
   # - special chars (e.g. & separating arguments) may not be encoded
   #   (if separators are encoded to keep htmlcheck or similar happy, 
   #    the receiving script needs to decode accordingly)
   # - each part (e.g. a single argument) is encoded at most once
   # - I prefer the possibly incorrect url#local_anchor?args ..., as the most variable part comes last...
   # - we return nil for URLs we cannot parse... (calling routine should simply use the original URL in that case)
   local($h)={};
   local($u)=@_;
   return $h if not $u;
   local($char,$char1,$char2,$char3)=
         ('\w','[\w\-\.]',
                      '[^\s"\'>&\?\x7f-\xff\x00-\x1f]',
                      '[^\s"\'>\x7e-\xff\x00-\x1f]');
   if (not $u=~m"\A 
      (                         (?# 1  urlroot  http;//www.x.com)
      (?:((?:$char){2,7}:))?    (?# 2  protocol http:)

      (\/\/                     (?# 3  urlhost)
         (?:($char*)?           (?# 4  user)
            (?:(\:$char*))?\@)? (?# 5  :pw)
         (?:(?:($char1+))       (?# 6  host)
            (?:(\:\d+))?)?)?    (?# 7  :port)
      )?

      ($char2*?)?		(?# 8  file; actually, we include the parameters - ;type=en, ... - in the filename )
      (                         (?# 9  \#url\?arg\&arg or \?arg\&arg\#url - which I consider to be equivalent )
         (?:(\#$char2*?))?      (?# 10 \#local)
         (?:([\?\&]$char3+?))?  (?# 11 \?arg\&arg)
         (?:(\#$char3*))?       (?# 12 \#local)
      )
   \s*?\Z"sxio) { 
      # cannot parse url, so return nil (to be ignored or used as error indication - if not ref...)
      return ""
   };
   $h->{urlroot}  = $1;
   $h->{protocol} = $2;
   $h->{urlhost}  = $3;
   $h->{user}     = $4;
   $h->{pw}       = $5; 
   $h->{host}     = $6;
   $h->{port}     = $7; 
   $h->{file}     = $8;
   $h->{urlargs}  = $9;
   # allow for both orderings
   $h->{local}    = $10; $h->{args} = $11; $h->{local} = $12 if $12;
   
   # _d: use this only for string matching... 
   $h->{host_d}   = &decodeurl($h->{host});
   $h->{host_D}   = uc($h->{host});
   $h->{file_d}   = &decodeurl($h->{file});
   $h->{args_d}   = &decodeurl($h->{args}); 
   $h->{args_h}   = &spliturl($h->{args}) if $h->{args}=~/\S/o;
   if ($h->{args_h}) {
      foreach (keys %{$h->{args_h}}) {
         $h->{args_H}->{uc($_)}=$h->{args_h}->{$_};
      }
   }
   return $h;
}

# perl -e 'require "db_cgi.p"; $a="http://www13/gi/#x"; $h=&db_cgi::parseurl($a); print &db_cgi::dumphashref($h),"\n\n",db_cgi::dumphashref($h->{args_h})'

sub decodeurl {
   local($_)=@_;
   # ATTN: $_[] works inplace...
   $_=~s/\%([0-9a-f]{2})/pack(C,hex($1))/eigo;
   return ($_);
}

sub spliturl {
   local($url)=@_; 
   local(@fields)=split(/\&/,$url);
   local($key,$value)=("","");
   local($h)={};

   foreach (@fields) {
      if ( /=/ && ($key=$`) ) {
         $value=$';
         $key =~ s/\+/ /go;
         $key =~ s/\%([0-9a-f]{2})/pack(C,hex($1))/eigo;
         $value =~ s/\+/ /go;
         $value =~ s/\%([0-9a-f]{2})/pack(C,hex($1))/eigo;
         $h->{$key}=$value if ($value!~/^\s*$/o);
      } else {
         s/\+/ /go;
         s/\%([0-9a-f]{2})/pack(C,hex($1))/eigo;
         $h->{SEARCH}=$_;
      }
   }
   return $h;
}

sub dumphashref {
   local($out);
   local($h)=@_;
   foreach (sort keys %{$h}) {
      $out.="$_ = \"$h->{$_}\"\n";
   }
   return $out;
}

sub dumpurl {
   # return a string for an url hash
   my($h)=@_;
   my($url)="";
   if (not ($h->{host} or $h->{port} or $h->{protocol})) {
      $url=$h->{urlroot}
   } else {
      $url =$h->{protocol};
      $url.="//" if $h->{host} or $h->{port}; 
      $url.=$h->{user};
      $url.=$h->{pw};
      $url.="@" if $h->{pw} or $h->{user};
      if (not ($h->{host} or $h->{port})) {
         # user resets user/pw if urlhost contains already a user...
         $url.=$h->{urlhost};
      } else {
         $url.=$h->{host};
         $url.=$h->{port};
      }
   }
   # do we need to fix the url here if we have an hostname?
   $url.="/" if not $h->{file}=~/^\//o and ($h->{host} or $h->{urlhost});
   $url.=$h->{file}; 
   $url.=$h->{local};
   $url.=$h->{args};
   $url.=$h->{urlargs} if not ( $h->{local} or $h->{args} );
   $url=$h->{prefix}."$url" if $h->{prefix};
   return $url; 
}

sub changeurl {
   # convert url acc. to new root
   my ($root_ref, $url, $f, $subst, $mode)=@_;
   my ($url_ref);
   $url_ref=&parseurl($url);
   if (not ref $url_ref) {
      # return if the url is strange...
      print main::STDERR "!! Error: db_cgi cannot parse $url\n"; 
      return $url;
   }
   $url_ref=&changeurlref($root_ref, $url_ref, $f, $subst, $mode);
   return &dumpurl($url_ref);
}

sub changeurlref {
   my ($h0, $h, $f, $subst, $mode)=@_;
   my ($path,$tmp,$lasttmp,$tmpfile,$up,$tmppath)=("","","","","","");
   # allow this only for http-type urls (no mailto translation (shudder)!)
   return $h if $h0->{protocol} and not $h0->{protocol}=~/^(http|ftp|shttp|file):?$/io or
                $h->{protocol}  and not $h->{protocol}=~/^(http|ftp|shttp|file):?$/io;
   $subst="^" if not $subst;
   $h->{prefix}.= $h0->{prefix} if $h0->{prefix};
   # urls to absolute files
   if ($h->{file}=~/^\//o) {
      $path= $h->{file}
   } elsif ( $h->{file} ) {
      $path="";
      $path= &rawpathjoin_rel($f,"") if $f;
      $path= &rawpathjoin_rel($path, '..') if $f;
      $path.="/" if $path and not $path=~/\/$/o;
      $path=~s!//+!/!go;
#print main::STDERR "PATH $path\n";
      $path=~s!$subst!$h0->{file}!;
      $path= &rawpathjoin_rel($path,"");
#print main::STDERR "PATH $path\n";
      if (not ($path eq "" and $h->{file}=~/^(\.|\.\/)$/o)) {
         $path= &rawpathjoin_rel($path, $h->{file}) ;
         $path= &pathclean($path);
      } else {
         $path="./";
      }
#print main::STDERR "PATH $path: $h->{file}\n";
      if ($h0->{file}) {
         while($path=~s!^(/*)\.\.(/?)!$1$2!g) { ; }
      }
      $path=~s!//+!/!go;
   } else {
      # empty files must be extended manually if $f must be considered!
      $path = $h0->{file} if not $mode=~/keeplocal/io;
   }
#print main::STDERR "PATH $path: $h->{file} - $h0->{file} - $f - $subst\n";
   if ($mode=~/uselocalfiles/io and not $h->{host} and $h->{file}) {
      # use old url if file exists in filesystem 
      # (caller's PWD should be in sync with the given filename here...)
# mode uselocalfiles             - don't change $h if file exists
# mode uselocalfilespwdrelative  - in addition, make $h->{file} relative to pwd
      # return for existing relative files
      $tmp=&rawpathjoin_rel($f,"..",$h->{file});
#print main::STDERR "UseLocal... $h->{file} $tmp\n";
      if ($h->{file} and $h->{file}=~/^[^\/]/o and -r $tmp) {
         $h->{file}=$tmp if $mode=~/pwdrelative/io;
         return $h;
      }
      # return for existing absolute files
      # assumption: absolute url filename exists exactly in local filesystem
      # so this must fail, if the file lies outside the subtree copied to
      # the local file system (guessing might work for some restricted subset only)
      if ($h->{file}=~/^[\/]/o) {
	 $up=""; 
	 $tmp=$f; $tmp=&rawpathjoin($ENV{PWD}, $tmp) if not $tmp=~/^\//o; 
	 $lasttmp="$tmp.$tmp"; 
         while(1) {
	    # file system name
	    $tmpfile=&rawpathjoin_rel($f, $up, $h->{file}); 
	    $tmpfile=~s!//+!/!go;
            # would-be translated url
            $tmppath= $tmpfile; $tmppath=~s!$subst!$h0->{file}!; 
	    $tmppath=&rawpathjoin_rel($tmppath, "");
	    $tmppath=~s!^/+!!o; $tmppath=quotemeta($tmppath);
#print main::STDERR "UseLocalAbs $path : tmpfile: $tmpfile --- $tmppath\n";
            # return if match and file exists
	    if ($path=~/^\/*$tmppath\/*$/ and -r $tmpfile) {
	       $h->{file}=$tmpfile if $mode=~/pwdrelative/io;
               return $h
	    }
	    # loop!
	    $tmp=&rawpathjoin($tmp, ".."); last if $tmp eq $lasttmp; 
	    $lasttmp=$tmp;
	    $up.="../"; 
         }
      }
      # "empty files" are returned correctly when keeplocal
   }
   $h->{file}    = $path;
   $h->{local}   = $h0->{local} if not $h->{local}; # h overrides h0
   $h->{args}    = $h0->{args}  if not $h->{args};  # h overrides h0
   if (not $h->{host} and ($h->{file} or not $mode=~/keeplocal/io)) {
      $h->{user}    = $h0->{user}     if not $h->{user};
      $h->{pw}      = $h0->{pw}       if not $h->{pw};
      $h->{host}    = $h0->{host}; 
      $h->{port}    = $h0->{port}     if not $h->{port};
      $h->{protocol}= $h0->{protocol} if not $h->{protocol};
   }
   $h->{urlargs} = "$h->{local}$h->{args}";
   $h->{urlhost} = "$h->{user}$h->{pw}";
   $h->{urlhost}.= "@" if $h->{urlhost};
   $h->{urlhost}.= "$h->{host}$h->{port}";
   $h->{urlroot} = "$h->{protocol}";
   $h->{urlroot}.= "//" if $h->{urlhost};
   $h->{urlroot}.= "$h->{urlhost}";
   return $h;
}

sub changeurls {
   # frames, etc are not considered
   # 1. new root url object 
   # 2. html text to relocate
   # 3. path (filesystem or url filename)
   # 4. regexp (match is substituted by the root url object's path; defaults to "^" - prepend)
   # 5. mode (keeplocal - keep "" / "?..." / "#..."-type urls without modification of host/path)
   #         (skipTAG - skip this tag)
   #         (uselocalfiles - don't convert url if file exists locally)
   my ($root_ref, $text, $filename, $old_path_regexp,$mode)=@_;
   my ($tags, $tmp, $url, $tage)=("","","","");
   $old_path_regexp="^" if not $old_path_regexp;
   $text=~s!(<(A|IMG)(?:\s[^<>]*?\s|\s+)(?:HREF|SRC)\s*=\s*([\"\']?))([^\$\"\'\s>][^\"\'\s>]*|)(\3(?:[>]|\s[\s\S]*?>))!do {
      $tags=$1; $url=$4; $tage=$5; $skip=$2;
      $url=&changeurl($root_ref, $url, $filename, $old_path_regexp, $mode) if not $mode=~/skip$skip(\s|$)/io;
      $tmp="$tags$url$tage";
      $tmp
   }!geio;
   return $text;
}

sub deumlaut {
   # bugs 
   # - doesn't honor tags in replacement...
   # - /3 replacement may be troublesome - removed
   
   my(@replacements, %replacements, $text, $umltex, $umlhtml,$umllatin1,$s,$key,$rkey);
   local($_);
   ($text, $_)=@_;
   $umltex =1 if /tex/io;
   $umlhtml=1 if /html/io;
   $umllatin1=1 if /latin1/io;

   # just the most common ones for me... - applied in order of definition
   #   latin1   pc      html               tex/pictures
   # note that &#xFF; seems legal now, too

                                                                   $s='ae'; $s='&auml;' if $umlhtml; $s='ä' if $umllatin1;
   $_='ä      | \\x84 | &auml;  | &#228; | \\\\"a          '; push @replacements, $_; $replacements{$_}=$s;
   do {$_='                                "a | a"         '; push @replacements, $_; $replacements{$_}=$s; } if $umltex;
   
                                                                   $s='oe'; $s='&ouml;' if $umlhtml; $s='ö' if $umllatin1;
   $_='ö      | \\x94 | &ouml;  | &#246; | \\\\"o          '; push @replacements, $_; $replacements{$_}=$s;
   do {$_='                                "o | o"         '; push @replacements, $_; $replacements{$_}=$s; } if $umltex;
   
                                                                   $s='ue'; $s='&uuml;' if $umlhtml; $s='ü' if $umllatin1;
   $_='ü      | \\x81 | &uuml;  | &#252; | \\\\"u          '; push @replacements, $_; $replacements{$_}=$s;
   do {$_='                                "u | u"         '; push @replacements, $_; $replacements{$_}=$s; } if $umltex;
   
                                                                   $s='Ae'; $s='&Auml;' if $umlhtml; $s='Ä' if $umllatin1;
   $_='Ä      | \\x8e | &Auml;  | &#196; | \\\\"A          '; push @replacements, $_; $replacements{$_}=$s;
   do {$_='                                "A | A"         '; push @replacements, $_; $replacements{$_}=$s; } if $umltex;
                                                                   
                                                                   $s='Oe'; $s='&Ouml;' if $umlhtml; $s='Ö' if $umllatin1;
   $_='Ö      | \\x99 | &Ouml;  | &#214; | \\\\"O          '; push @replacements, $_; $replacements{$_}=$s; 
   do {$_='                                "O | O"         '; push @replacements, $_; $replacements{$_}=$s; } if $umltex;
                                                                   
                                                                   $s='Ue'; $s='&Uuml;' if $umlhtml; $s='Ü' if $umllatin1;
   $_='Ü      | \\x9a | &Uuml;  | &#220; | \\\\"U          '; push @replacements, $_; $replacements{$_}=$s; 
   do {$_='                                "U | U"         '; push @replacements, $_; $replacements{$_}=$s; } if $umltex;
                                                                
                                                                   $s='ss'; $s='&szlig;' if $umlhtml; $s='ß' if $umllatin1;
   $_='ß      | \\xe1 | &szlig; | &#223; | \\\\"s          '; push @replacements, $_; $replacements{$_}=$s; 
   do {$_='                                "s | s"         '; push @replacements, $_; $replacements{$_}=$s; } if $umltex;
                                                                
                                                                   $s=' ';
   $_='                           &#32;                    '; push @replacements, $_; $replacements{$_}=$s;
                                                                
                                                                   $s=' '; $s='&nbsp;' if $umlhtml;
   $_='                 &nbsp;  | &#160;                   '; push @replacements, $_; $replacements{$_}=$s;
                                                                   $s='"';
   $_='                 &quot;  | &#34;                    '; push @replacements, $_; $replacements{$_}=$s;

   foreach $key (@replacements) {
      $rkey=$key; $rkey=~s/\s//g;
      $text=~s/$rkey/$replacements{$key}/g;
   }
   return($text);
}

# we need to run in callers scope, so we eval ourselves into current scope
sub install_expandvars {
   local($_);
   $_=<<'EOF';
sub expandvars {
   # expand simple scalars and hash variables
   local($_, $tmp, $txt);
   ($txt)=@_;
   $txt=~s!(\$[a-z0-9_]+({"?[\$a-z0-9_]+"?})?)!do{$tmp=""; eval(q/$tmp=/.$1); $tmp}!egio;
   return($txt);
}
EOF
return $_;
}

# read/write a simple, small database file with locking
# the callback is given a reference to the data string
# note that we change the date if $tmp exists 
# (being lazy and using +>>)
# set tmp to " " or similar to "delete" it
sub rwdb {
   local ($err, $tmp)=("","");
   local  ($DB)  = shift; # database name
   local  ($BAK) = shift; # database backup file
   local  ($fu)  = shift; # optional: callback for writing

   # read data
   $err = "db_cgi: cannot open $DB" if not open(FH, "+>>$DB");
   if (not $err) {
      flock FH, 2; seek FH, 0, 0;
      local($/); undef $/; $tmp=<FH>;
   }
   if (not $err and $tmp and $BAK) {
      system("cp -p $DB $BAK >/dev/null 2>&1");
      $err="Cannot backup $file to $BAK!\n" if $?;
   }
   
   # allow processing by the user
   if (not $err and $fu) {
      $tmp=&$fu(\$tmp);
      $tmp=$$tmp if ref $tmp;
   } else {
      $tmp="";
   }
   
   if (not $err and $tmp) {
      truncate FH,0; seek FH, 0, 0;
      print FH $tmp;
   }   
   
   # Q: Alarm?  

   flock FH, 8;
   close FH;
   return $err;
}

# expand variables @@$variable;
sub install_m5expandvars {
   local($_);
   $_=<<'EOF';
sub m5expandvars {
   local($value,$flags)=@_;
   local($var_name,$var_urlencode,$var_htmlencode,$tmp)=("","","","");
   $value=~s/\@\@\\?([\%\$\@])($db_cgi::pat_variable)[;]?/do{
      $var_name="$1$2"; $var_urlencode=$var_htmlencode=0;
      $var_urlencode=1  if $var_name=~s!^(.)u:!$1!i;
      $var_htmlencode=1 if $var_name=~s!^(.)h:!$1!i;
      eval('$tmp="'.$var_name.'";');
      $tmp=&db_cgi::encodeurl($tmp)  if $var_urlencode;
      $tmp=&db_cgi::encodehtml($tmp) if $var_htmlencode;
      $tmp=~s!($db_cgi::special_chars)!\\$1!go if $flags=~m!escvar!i;
      $tmp;
   }/ge; # s//$1\{$2\}/go is faster?
   return $value;
}
EOF
   return($_);
}

sub transferglobal {
   # encode global and localized variables as perl string 
   # (include package name!)
   local($transfer,$transfertmp, $transferr)=("","",'([a-z_0-9]+(::[a-z_0-9]+)+)');
   foreach (@_) {
      if (/^\$($transferr)/i) {
         $transfer.="\$$1=\"". &transferencode(${$1}) ."\";\n";
      } elsif (/^\@($transferr)/i) {
         for ($i; $i<=@{$1}; $i++) {
            $transfer.="\${$1}[$i]=\"". &transferencode(${$1}[$i]) ."\";\n";
         }
      } elsif (/^\%($transferr)/i) {
         foreach (sort keys %{$1}) {
            $transfer.="\${$1}{\"". &transferencode($_) ."\"}=\"". &transferencode(${$1}{$_}) ."\";\n";
         }
      } else {
         print main::STDERR "$0:\nCANNOT TRANSFER $_\n\n";
      }
   }
   return($transfer)
}
sub transferencode {
   local($_)=@_;
   s/([^A-Z0-9_\+\*\-\(\)\[\]\{\} ])/do {"\\x".unpack(H2,$1)}/oige;
   return $_;
}


sub quotesafe (@) { # protect for one-time use in bourne shell double quotes
   return map {local($_)=$_;s/["`\\\$]/\\$&/g;"$_"} @_;
}
sub quotesafe1 ($) {
   return((quotesafe(@_))[0])
}

sub squotesafe (@) { # protect for one-time use in bourne shell single quotes
   return map {local($_)=$_;s/[']/'"'"'/g;"$_"} @_;
}
sub squotesafe1 ($) {
   return((squotesafe(@_))[0])
}     


1;

