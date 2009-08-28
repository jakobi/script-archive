#!/usr/bin/perl

# 30.09.93 TC        tom christiansen's rewrite of grep / grep.pl / tcgrep / tcgrep.pl
# ...                (forked off around 1997, I think)
# 00.05.07 PJ        replaced $* by modifier m 
# 10.07.08 PJ  0.2   added boolean regex (-b / -B), context (-C)
# 25.07.09 PJ  0.3   added -f / -F / --include / --exclude / --perl / eval_.* hooks
#                    added synonyms and basic stemming for english: -X
# 06.08.09 PJ        added -o, --count-sum, --split, --binary, use strict
# 08.08.09 PJ  0.4   restructure as perl module and renaming to Grep.pm / Compact_pm::Grep
#                    (retaining package vars to allow for simple user-provided
#                    evals (no $self->... on the command line))
# 12.08.09 PJ        allow context mode to "> "-flag matching records, --show-files

# (c) 2007-2009 PJ, placed under GPL v3
# archive:   http://jakobi.github.com/script-archive-doc/
my $version="0.4";

# Bugs:
# - utf?
# - utf! expansyn/stemming does allow for umlauts/... in words/stems
#        [use a local-depending charclass as subst for [a-z]?]


# if these collide with using eval_hooks, disable them:
use strict;
use vars;
use warnings;


package Grep; 
our @ISA=qw(Compact_pm::Grep);
sub import {
   shift;
   local($Exporter::ExportLevel)=1;
   Exporter::import("Compact_pm::Grep",@_);
}


package Compact_pm::Grep;

 
# use main:: variables: $/, $|, $., @ARGV


our(%Compress)=();                                             # input filters for gzip, ...
our(%opt0)=();                                                 # option defaults
our($Me)=("");                                                 # script name
our($matchpattern)=("");
our($matchhlexprg)=("");
our($substhlexprg)=("");
our($module_use)=(0);
our($module_print)=(1);
our($module_init_ok)=(undef);
our($module_stdout)=(undef);
our($module_stderr)=([]);

 
our($Errors, $Grand_Total)=(0,0);                              # global counters
our(%opt)=();                                                  # argument option hash
our($EXPR,$HLEXPR,$SO,$SE)=("","","","");                      # disjunction of used regexes, terminal hl strings
our($eval_finishedfile, $eval_newfile,                         # keep these global, to allow user access
   $eval_input2, $eval_input1, $eval_input, 
   $eval_finished, $eval_output)=("","","","","","","");
our($matches, $total)=(0,0);                                   # file-specific counters
our($active, $file, $name, $ext)=("","", "", "");              # active file, file, alternate file name, extension
our($tmp,$len)=("",0);
our($offset,$lineoffset,$lineoffset0)=(0,0,0);
our($remnantprev,$remnantnext,$recordlines)=("","","");              
our($dash_printed, $pass)=(undef,0);                           # context-end flag (global!), pass state
our(%F, %FF, %F1)=();                                          # optional user pass state hashes
our($data)=("");                                               # the data buffered, cache for pass 2
our($buf, $bufl, $buflen, $contextstart)=("", "","");          # optional input ring buffer  / optional context buffer
our(@buf,@bcontext,@data)=();
our($files_seen,$files_read)=(0,0);


######################################################################################################

if (not caller) {
   $|=1;
   &init;
   &parse_args;
   &matchfile(@ARGV);
   exit(2) if $Errors;
   exit(0) if $Grand_Total;
   exit(1);
} else {
   $module_use=1;
   &init;
}

# the following functions are available after "do 'THISFILE'"
# and wrap parse_args, matchfile. You may call init or reinit
# to reset some variables between matches.
#
# Notes on module usage:
# - set opt{nl} explicitely if not module_print 
# - bugs and warnings are way off when being invoked by "do FILE".
#   -> run as a command to see the real problem.
# - it might help to avoid strict/vars when using eval_hooks

sub grep_p { # similar to the shell usage (true/false/false-with-$@), 
             # input from FS, output to stdout/stderr
             # Compact_pm::Grep::greparg(qw@ -H localhost /dev/null /etc/hosts /etc/passwd@);
             # customize in caller with $Compact_pm::Grep::Me="caller's name for Grep";
   local($|, $/, @ARGV)=(1, $/, @_);
   $@=undef;
   my $rc;
   $module_print=1;
   $module_stdout=undef;
   $module_stderr=[];
   $module_init_ok=undef;
   eval {&parse_args};
   $module_init_ok=1 if not $@;
   eval {&matchfile(@ARGV)} if not $@;
   return(undef) if $@;
   return(1) if $Grand_Total;
   return(0);
}

sub grep_np { # similar, but returns the array ref, 
              # without actual printing of matches or warnings;
   local($|,$/,@ARGV)=(1,$/,@_);
   $@=undef;
   $module_print=0;
   $module_stdout=[];
   $module_stderr=[];
   $module_init_ok=undef;
   eval {&parse_args};
   $module_init_ok=1 if not $@;
   eval {&matchfile(@ARGV)} if not $@;
   return(undef) if $@;
   return($module_stdout)
}

sub grep_np_args { # just the initialization from grep_np
   local($|,$/,@ARGV)=(1,$/,@_);
   $@=undef;
   $module_print=0;
   $module_stdout=[];
   $module_stderr=[];
   $module_init_ok=undef;
   eval {&parse_args};
   return(undef) if $Errors or $@;
   $module_init_ok=1;
   return($module_stdout)
}

sub grep_np_match { # just the actual matching from grep_np
   local($|,$/,@ARGV)=(1,$/,@_);
   $@=undef;
   # $module_stderr=[]; # reset or collect?
   $module_stdout=[];
   if($module_init_ok) {
      eval {&matchfile(@ARGV)} if not $@;
      return(undef) if $Errors or $@;
      return($module_stdout)
   } else {
      $@="# $Me previous parse_args failed - ABORTING\n";
      return(undef);
   }
}




######################################################################################################

sub init {

    &reinit;

    %opt0=(n_pad0=>1,             # zero-padded line numbers
           N_tolerance=>100,      # buffer: number of bytes to allow beyond line (-N)
           implicit_and=>"and",
           matcher_mod=>"mo",     # pattern modifiers for matcher
                                  # (m is required as we can no longer set $*)
           noheader=>0,           # suppress output of headers
           binary=>0,             # --binary
           count=>0,              # --count
           countsum=>0,           # --count-sum
           nl=>"",                # add missing line end
           mult=>"",              # multiple files flag - aka --show-files
           C_mark=>"",            # diff-style marking the match line for -C
           filter=>"",            # --cmd
           include=>"",           # --include
           exclude=>"",           # --exclude
           stemming=>-1,          # -X: -1 no stemming, just quotemeta
           bufbytes_p=>0,         # from -N 
           bufbytes_n=>0,
           buflines_p=>0,
           buflines_n=>0,
           filemax=>0,            # from -M
           offset=>0,             # --byte-offsets
           lineoffset=>0,
           show1=>0,
           shown=>0,
          );

    %Compress = (                 # file extensions and program names for uncompressing
	Z   => 'zcat %%',
	z   => 'zcat %%',         
	gz  => 'zcat %%',
	bz2 => 'bzcat %%',
	bz  => 'bzcat %%',
	zip => 'unzip -c %%',
    );

    ($eval_finishedfile, $eval_newfile,                         # keep these global, to allow user access
     $eval_input2, $eval_input1, $eval_input, 
     $eval_finished, $eval_output)=("","","","","","","");

    ($Me = $0) =~ s!.*/!!;    # script name
    $Me="Compact_pm::Grep.pm" if $module_use;
    
    $matchpattern=$matchhlexprg=$substhlexprg="";
}

sub reinit {
    # it should be sufficient to call this function between
    # calls to matchfile; with $., $/, $| suitably localized
    # ($SO,$SE)=("","");                                        # possibly reuse from last run, when user
    ($module_stdout)=(undef);
    ($module_stderr)=([]);
}


###################################

sub usage { 
   warn <<EOF if not $module_use;

       $Me [OPTIONS] REGEX FILE ...
find | $Me [OPTIONS] -e REGEX -e REGEX -

version: $version

This  commands  is  a  fork of perl  tcgrep  heritage.  It  implements
perl-based  regular  expressions,  directory  recursion,   transparent
decompression  and  optional input filter (--cmd) as well  as  context
grep (-C) and filename-based inclusion/exclusion.

Grepping  only the first or last N lines or bytes is implemented (-M),
as  is grepping against the previous and/or future N lines surrounding
the  current  line  (-N). 

The   -b/-B  options  improve  on  the  -e  regular   expressions   by
implementing  boolean  expressions on top of regular  expressions  (or
arbitrary perl scraps).

If  expansyn  is available, -X expands regex paren groups or  branches
containing  just  words  consisting only of [A-Z0-9-_] to  also  match
their  known synonyms. Use -X-1, -X0, -X1, -X2 to override the default
stemming ($opt{stemming}).

For  configuration, use the TCGREP environment variable or the  --perl
FILE / --perl PERL option. 

Non-plain non-binary files are skipped by default. Remember to use the
-a  option  when  grepping e.g. input from named pipes.  The  compiled
matcher  consists  of  the  optionally  negated  (-v)  disjunction  of
m{REGEX}$opt{matcher_mod} perl regex match expressions.


$Me -b 'REGEX and not  (  REGEX or REGEX  )'    FILE ...
$Me -B  REGEX and not '(' REGEX or REGEX ')' -- FILE ...

The  -b  option  implements  boolean expressions  on  top  of  regular
expressions:  The  string  is split by looking  for  boolean  keywords
(parentheses,  and,  or,  not)  surrounded  by  whitespace.  Remaining
substrings  are  used  as regular expressions. Finally  everything  is
compiled  into a matcher. The scope of the boolean regular expressions
is  limited  to  the  current  record, just  as  with  normal  regular
expressions.  -B  skips the splitting and instead uses  all  arguments
until the next option argument, otherwise until the next filename.

To  embed  a  perl scrap in the matcher, use "do{...}" in place  of  a
regex match expression m{REGEX}. In both cases, the expression's value
is  used  in  the  boolean expression.  Issue --examples for more.


Options:
  Multiple simple options can be combined (excluding -/-e/-b/-B/-X).
  Options with argument can be given as --cmd=foo or --perl bar
  
  --       last argument
  -q       quiet about failed file and dir opens
  -s       silent mode
  -V       verbose
  --help   usage and help; too much help: try --examples
  --cmd  S run command S to filter input
  --perl S eval file or string S

  # file selection
  -        last argument and STDIN as first file
  -a       grep all files incl. binary files and devices
  -R/-r    recursive on directories or dot if none
  -t       process directories in `ls -t` order
  --binary also grep binary files (subset of -a)
  --exclude REGEX - skips matching files (against full path)
  --include REGEX - skips non-matching files

  # input record handling
  -0       0-terminated input/output
  -p       paragraph mode (actually a -2 zerowidth --split)
           Use -C 0 -p to separate paragraphs with dashes.
           Use -2 --split '\\n\\s*\\n\\K' instead of -p to split
           on stretches of whitespace lines.
  -P S     ditto, but specify separator string S in perl;
           both options print a line of dashes between records
           see --examples for more information
  -M N     grep only in the first N records (bytes if Nc or Nb; i
           negative numbers grep in the last N records, implying -2)
  --split REGEX -- split() input with REGEX, implies -2 pass mode.
           Note that the non-zerowidth examples actually delete
           characters from input and will throw off --offset and
           possibly also --linecount! 
           ^    \\n     - lines (2nd example eats \\n)
           ^\$   \\n\\n+  - paragraphs (2nd example eats 2+ \\n)
           SEP         - eat/split at SEP
           \\n\\s*\\n     - eat/split at end of 1+ whitespace lines
           \\n\\s*\\n\\K   - zerowidth version, retains whitespace
           END\\K       - split after  END, zerowidth
           (?<=END)    - the same, but END must be fixed-length
           (?=START)   - split before START of record, zerowidth
           

  # reporting / output record handling (\\n is appended if req.)
  # Note: -H/-o/--count use the disjunction of all regexes from 
  # options -e and -b, ignoring negation and excluding perl scraps.
  -1       1 match per file 
  -A       print all text (for highlighting)
  -c       give count of lines matching
  -C N     context lines, prints dash-separator between matches
           use -C 0   to print separators with 0 context lines
           use -C 00  to also add a line end after file:line:
           if negative, flag matches (similar to diff -u)
  -H       highlight matches 
  -h       hide filenames 
  -l       just list matching filenames
  -n       include record numbers (records are lines by default)
  -N N[:M] have \$buf contain the previous N (or e.g. somewhat more than
           250 Bytes in case of -N 250b) plus current records. If N is 
           negative, retain all previous records. If M is specified,
           also add the future M records or bytes (implies -2). 
           \$buf guarantees a \\n (or \\0 if -0) between records.
           \$bufl is s/[\\r\\n\\0]+/ /g, with the outer ones being stripped.
           Use -N 5 -B do{\$buf=~/MULTILINEREGEX.*\\Z/m} to report the 
           containing line of the end of a multi-line match. 
           See --examples
  -N N:M   similar but also the future M lines or bytes; implies -2.
  -o       only matches: report stretch from first to end of last match.
           In case of no match: print whole record
  -u       underline matches
  --count  implies -c allowing for multiple matches per record
  --count-sum -- implies -c, but only report sum of counts
  --offset use byte offset for -n (do use zero-width record splitting
           for valid offsets; be careful with -P settings, perl might e.g.
           suppress excess newlines automatically).
  --show-files / --hide-files (-h) 
           (also: --perl '\$opt{mult}=1' / adding /dev/null to files)
  
  # For records other than lines:
  --lineoffset -- use the start line number of the record for -n;
           the same restrictions as with --offset apply. When used
           with zerowidth --split, any record with incomplete start or
           end line will be extended on printout to full input lines.
  --show1  print only the first line of the record
  --shown  print the file and or number prefix for each line of the record

  # matching 
  -2       two pass mode for side-effects with -b and do{} perl scraps
  -v       invert search: EXPR -> not ( EXPR )
  # modifiers (also consider (?imsx-imsx) or [\\l\\u] [\\L\\U\\E])
  -i       case insensitive 
  -w       word matches only -- wrap in word boundaries
  -x       line matches only -- anchor with ^...\$
  -X       run patterns and words through expansyn to expand synonyms
           (stemming modus can be changed by -X-1..-X2; default $opt{stemming})
  --or     change boolean matcher to use 'or' for implied conjunctions
  
  # expressions to match (if missing, uses first non-option as regex)
  # multiple EXPR are combined into a disjunction.
  -b E     match boolean expression E
  -B S ... similar, but first collect following non-option/non-file 
           arguments into boolean expression E
  -e R     match regular expression R
  -f S     read regex from file S (skipping comments/whitespace)
  -F S     read boolean expressions from file S

EOF
}

sub examples {
   warn <<EOF;

On using this script as a perl module

See  the moduletest script as well as the scripts source, look for the
string caller.


On using perl scraps and side-effects within boolean expressions:

Instead  of  regular  expressions, you can provide raw perl  by  using
'do{}', but you may need to protect the boolean keywords like this: &&
||  !  ,and ,or not(). Perl scraps can be used to e.g. set  and  abuse
side  effects.  Variables of interest: \%F, \%FF are reset for each  new
file.  With option -2 \%FF is also reset when entering pass 2, while \%F
is copied to \%F1. \$_ is the current record, \$name the filename, \$. the
"line"  number (1-based). \$opt_n_pad0 controls 0-padding line numbers.
\$data  and  \@data  (0-based)  are  the  file  contents.  Various  hook
variables are available, e.g. \$eval_input, which is invoked just after
reading a record into \$_. To use or instead of end for missing boolean
operators,  use  \$opt{implicit_and}. \$len is the length of the sum  of
all seen records for a file, \$offset the offset of the current record.

Perl scraps are not considered/updated by expansyn (-X), highlightling
(-H) and only-matches (-o).

However  also consider the simpler alternatives: 
  - $Me -P undef with a disjunction of zerowidth patterns and 
    control verbs (if the regex needs to span less than 64K)
  - perl with -0777ne or a separate script



On splitting into arbitrary records:

By default, the file is read line by line. Use -0 to switch
to \\0 based line ends or -p split on empty lines (/^\$/).

Use -P SEP to specify separator string SEP:
   -P undef  for slurping the whole file
   -P '\\60' for fixed 60-byte records
   -P '""'   for paragraph mode    (short: -P ''; see -p)
   -P '"\\n"' for line mode         (default mode)   
   -P '"\\0"' for \\0-based "lines"  (-0)

This option also prints a dash-separator between records.
If -p is also specified as well, translate \\r and \\n to blanks.

To omit the separator, just say
    --perl '\$/="SEP"'

To split on regular expressions, combine 2-pass mode and slurp 
the file (hook \$eval_newfile), while \$eval_input1 uses pass1
to split the file, overriding the internal cache \@data.
   -2 --perl '\$eval_newfile=q!\$/=undef!;
      \$eval_input1=q!do{s/\\n/ /g; \@data=split /[\\.\\s]/, \$_;}!'
Which is pretty much what --split does.

Also consider
   - context -C 0 to print dash-separators between records
   - conversion to use \\0 as record separator.
   - using external programs as for record splitting
     cat0par... |$Me -0                           | cat0 -nl 
     find ...   |$Me -0 --cmd 'cat0par -nore ...' | cat0 -nl -nore
     use a pipe with tr '\\0' ' ' or cat0par -nore to
     ensure that there are no embedded '\\0' in the file
     that could be confused with the new output record
     end of '\\0'



On matching over multiple buffered lines with -N N[:M] and -b/-B:

\@buf  contains  the N previous records plus the current one, \$buf  the
joined  string  for \@buf, \$bufl the same with \\r, \\n, \\0  replaced  by
blanks.  If N is being followed by b or c, \$buf is shortended to a bit
more  than the previous NUM bytes plus current line. If N is negative,
records  are not removed from \@buf, turning \$buf into the sum of  seen
records  plus the current record. If M is specified, two pass mode  -2
is  implied, and \$buf (not \@buf) also contains the future M records or
bytes.

Example:  Look  back to the previous 3 lines and the current line  and
report  matching lines starting with REGEX1 and ending with REGEX2  in
the  current line. If the pattern does not care about newlines and  is
non-zero-width (.+ below is sufficient), the expression can be further
simplified by using \$bufl.

$Me -N 3 -B 'do{\$buf =~/^.*?(REGEX1[\\S\\s]+?REGEX2).*\\Z/m 
                and do{\$_=\$&;s/\\n/ /g;1}}'
$Me -N 3 -B 'do{\$bufl=~/^.*?(REGEX1.+?REGEX2).*\\Z/m and \$_=\$&}'

The next example is once again simplified by using a hook to copy \$buf
to  \$_, thus all matches will default to the buffer contents. However,
this  will now report the whole of the buffer for a match. Thus we use
a  second  --perl with a different s/regex// to shorten  the  reported
matches.  Note  that  we now use -e for matching against  the  buffer,
which was not possible before.

$Me -N 4 --perl '\$eval_input=q!\$_=\$bufl'
         --perl '\$eval_output='s/STRIPNOISE//!'
         -e 'REGEX1.+?REGEX2'


               
On two pass mode (option -2):

Pass  1  only  prepares the record and buffering  upto  \$eval_input  /
\$eval_input1,  then iterates before evaluating the boolean  expression
generated from -e/-b-/B.



More examples of using do{}:

$Me -2 -b 'do{/verbatim\\.sty/,and \$F{X}=1;1} and 
              /documentstyle/ and do{\$F{X}}' *.tex

Above  example  reports  documentstyle lines for  documents  that  use
verbatim.sty:  The  first condition is always true, but sets the  side
effect  \$F{X}  tested  by  the  real  condition  '/documentstyle/  and
do{\$F{X}}'.  When  using  two pass mode (-2), verbatim.sty  may  occur
anywhere,  even  later than documentstyle. 

Another use is restricting the set of matches and modifying the output
record  as  shown in the second line below; commands  3-6  demonstrate
printing  the first few lines of matching files. &printlines can  also
report  lines matching a list of regex or rewrite records if its first
argument is a string containing a 'do{}' code scrap. Combination of -2
-P undef and the eval_input hook can also be used to split a file into
records  by regular expression, as demonstrated by printing the record
(word) number and matching words of command 7.

f=/etc/hosts
1. $Me     -b 'ip6 and do{/[-\\w]*local[-\\w]*/ ,and "\$_=\$&" }' \$f
2. $Me     -b 'ip6 and do{/[-\\w]*local[-\\w]*/ ,and  \$_=\$&  }' \$f
3. $Me -2  -b 'ip6 and do{if(not(\$FF{0}),and \$FF{0}=1){
      foreach \$X (0..4){print "\$name:\$data[\$X]"}}
   } and (?!)' \$f
4. $Me -2  -b 'ip6 and do{&printlines(1..5)} and (?!)' \$f
5. $Me -2  -b 'ip6 and do{&printlines("host","l\\S+net")} and (?!)' \$f
6. $Me -2  -b 'ip6 and do{&printlines(q!do{s/l/x/}!,"host")} and (?!)' \$f
7. $Me -2n -b host --perl '\$eval_newfile=q!\$/=undef!; \$opt_n_pad0=undef;
   \$eval_input1=q!do{s/\\n/ /g; \@data=split /[\\.\\s]/, \$_;}!' \$f

If  you  regularly need to use a multitude of  such  side-effect-based
reconfigurations,  consider  placing them inside conditionals  in  say
~/.tcgreprc  and  use  e.g.  the  \$eval_newfile  hook  for  additional
extension-based  reconfiguration  or  file exclusion  when  performing
"TASK":

$Me --perl '\$cfg="TASK"' --perl ~/.tcgreprc ...



See also:
  - cat0par, cat0 for record splitting and easy dealing with \\0-lines
  - expansyn returns synonyms from lists/regex to lists/regex
  - tagls: tags upto boolean regex, incl. stemming for tags/synonyms



Alternative perl greps:
  - ack: another perl-based grep, albeit without boolean extensions;
    ack offers a subset similar to above features, already preconfigured  
    for e.g. grepping within a version control tree.
  - hlgrep: simple grep with highlighting
  - peg: similar to ack and $Me, more extensive (available as cpan script)
    coloring, more modern perl incl. using the IO layer.
  - perl   -lne  'print "\$ARGV: \$_\\n" if EXPR' FILE ...   
  - perl   -00ne 'print "\$ARGV\\n"     if EXPR' FILE ... | sort -u 
  - perl -0777ne 'print "\$ARGV\\n"     if EXPR' FILE ...   
  - tcgrep: simple grep from which this one is forked

EOF
}

###################################

sub parse_args {
    use Getopt::Std;

    my(@ARGVPOST,%opt2,%opt3);
    
    %opt=%opt0;       # seed %opt with a copy of the default options and run flags
    $HLEXPR=$EXPR=""; # clear disjunction and matcher scrap
    $SO=$SE="";       # highlighting terminal sequences

    if ($_ = $ENV{TCGREP}) {
        s/^[^\-]/-$&/;
        unshift(@ARGV, $_);
    } 

    # pass1 - getopts cannot deal with multiple occurances or varargs
    #         place overrides to getopts in %opt3
    my(@a,@b,@bb);
    while(@ARGV) {
       $_=shift @ARGV;
       /^-?-$/                  and do { push @a, $_, @ARGV; last};
       /^-?-help$/              and do { &usage; mydie("\n") };
       /^-?-examples?$/         and do { &examples; mydie("\n")};
       /^-?-or$/                and do { $opt{implicit_and}="or"; next}; 
       /^-?-binary$/            and do { $opt{binary}=1; next}; 
       /^-?-count$/             and do { $opt{count}=1; next}; 
       /^-?-count[-_]?sum$/     and do { $opt{countsum}=1; next}; 
       /^-?-show[-_]?files?$/   and do { $opt{mult}=1; next}; 
       /^-?-hide[-_]?files?$/   and do { $opt{mult}=""; $opt3{h}=1; next}; 
       /^-X(-?\d+)?$/           and do { $opt{X}=1; $opt{stemming}=$1 if defined $1 and $1 ne ""; next}; 
       /^-?-cmd(?:=(.+))?$/     and do { $_= (defined $1 and $1 ne "") ? $1 : shift @ARGV; $_="" if not defined $_;
                                         $opt{filter}=$_;next};
       /^-?-split(?:=(.+))?$/   and do { $_= (defined $1 and $1 ne "") ? $1 : shift @ARGV; $_="" if not defined $_;
                                         $opt{split}=$_; unshift @ARGV, "-2"; $/=undef ;next};
       /^-?-offsets?$/          and do { $opt{offset}=1; next};
       /^-?-lineoffsets?$/      and do { $opt{lineoffset}=1; next};
       /^-?-show1$/             and do { $opt{show1}=1; next};
       /^-?-shown$/             and do { $opt{shown}=1; next};
       /^-?-perl(?:=(.+))?$/    and do { $_= (defined $1 and $1 ne "") ? $1 : shift @ARGV; $_="" if not defined $_;
                                         -f $_ and do{do $_;1} or eval($_); mydie("# $Me --perl: ".$@) if $@; next}; 
       /^-?-include(?:=(.+))?$/ and do { $_= (defined $1 and $1 ne "") ? $1 : shift @ARGV; $_="" if not defined $_;
                                         $opt{include}=$_; next};
       /^-?-exclude(?:=(.+))?$/ and do { $_= (defined $1 and $1 ne "") ? $1 : shift @ARGV; $_="" if not defined $_;
                                         $opt{exclude}=$_; next};
       /^-e(.*)$/               and do { $_= (defined $1 and $1 ne "") ? $1 : shift @ARGV; $_="" if not defined $_;
                                         push @ARGVPOST, "-e", "$_"; next};
       /^-b(.*)$/               and do { $_= (defined $1 and $1 ne "") ? $1 : shift @ARGV; $_="" if not defined $_;
                                         push @ARGVPOST, "-b", "$_"; next};
       /^-B(.*)/                and do { # ugly: vararg magic for detecting end of arg list for -b (array version)
                                         @bb=@b=();
                                         push @b, $1 if defined $1 and $1 ne "";
                                         # collect all args until OPTION OR FILE
                                         while(defined $ARGV[0] and $ARGV[0] ne "" and $ARGV[0]!~/^-/ and not -f $ARGV[0]) {
                                            push @b, shift @ARGV;
                                         }
                                         # however extend until OPTION IFF there is a subsequent one
                                         while(defined $ARGV[0] and $ARGV[0] ne "" and $ARGV[0]!~/^-/) {
                                            push @bb, shift @ARGV;
                                         }
                                         if (defined $ARGV[0] and $ARGV[0]=~/^-/) { 
                                            push @b,@bb;
                                         } else {
                                            unshift @ARGV, @bb
                                         }
                                         push @ARGVPOST, "-B", @b;  next};

       # remaining options (plus -/--) are handled by getopts.pl
       /()/                     and do { push @a, $_; next};
    }
    @ARGV=@a; @a=@b=@bb=undef;

    # pass2 - getopts
    my($optstring,$zeros,$empties,$undefs,@opt);
    $optstring = '012AacFHhilnopqRrstuVvwxC:f:M:N:P:';
    $zeros     = '012AacHhilnopqRrstuVvwxbf';
    $empties   = 'FpfMN';            
    $undefs    = 'CP';
    @opt{ split //, $zeros   } = ( 0 )     x length($zeros);
    @opt{ split //, $empties } = ( '' )    x length($empties);
    @opt{ split //, $undefs } =  ( undef ) x length($undefs);

    getopts($optstring, \%opt2)		or do{usage(); mydie("# $Me invalid options\n")};
    %opt=(%opt, %opt2, %opt3);
       
    # pass3 of argument parsing - ARGVPOST, depending on previous switches
    while(@ARGVPOST) {
       $_=shift @ARGVPOST;
       /^-e$/     and do { $_=shift @ARGVPOST; $_="" if not defined $_; 
                     ($EXPR,$HLEXPR)=&parsearray( $EXPR,$HLEXPR,$_); next};
       /^-b$/     and do { $_=shift @ARGVPOST; $_="" if not defined $_;
                     ($EXPR,$HLEXPR)=&parsestring($EXPR,$HLEXPR,$_); next};
       /^-B$/     and do { @bb=@b=();
                     while(defined $ARGVPOST[0] and $ARGVPOST[0] ne "" and $ARGVPOST[0]!~/^-/) { 
                        push @b, shift @ARGVPOST; 
                     }
                     ($EXPR,$HLEXPR)=&parsearray($EXPR,$HLEXPR,@b); next};
       /()/       and do { mydie("cannot happen: argument $_"); next };
    }
    @b=@bb=undef;


    # finish the matcher $EXPR (perl scrap) and $HLEXPR (disjunction of all regexes)
    if ($opt{f}) {
        foreach (&readfiletoarray($opt{f})) {
           ($EXPR,$HLEXPR)=&parsearray($EXPR,$HLEXPR,$_);
        }
    }
    if ($opt{F}) {
        foreach (&readfiletoarray($opt{F})) {
           ($EXPR,$HLEXPR)=&parsestring($EXPR,$HLEXPR,$_);
        }
    }
    if (not defined $EXPR or $EXPR eq "") {
       $_=shift @ARGV;
       ($EXPR,$HLEXPR)=&parsearray($EXPR,$HLEXPR,$_) if defined $_ and $_ ne "";
    }
    do{&usage; mydie("# $Me expression missing\n")} if not defined $EXPR or $EXPR eq "";
    $EXPR='not ( ' . $EXPR . ')' if $opt{v};
    
    # PERL BUG: use strict vars warnings leads leads to a spurious warning
    #   5.10    when invoked with do FILE and functions invoked from outside 
    #           our namespace, unless I use the value just before the eval? 
    #           "variable is not available"
    #           worse, with strict refs, it leads to an abort when trying
    #           to call the referenced function. 
    #           Can't use string ("") as a subroutine ref while "strict refs"
    #           Funny, if using warn on the var, it's still a code ref...
    my $PERLBUG=$matchpattern.$matchhlexprg.$substhlexprg;
    
    eval '$matchpattern=sub{'.  $EXPR  .'}; 
          $matchhlexprg=sub{m{$HLEXPR}mgo};
          $substhlexprg=sub{s{$HLEXPR}{${SO}$&${SE}}mgo}'; 
    mydie("# $Me matcher: ".$@) if $@;


    mywarn("# $Me exclude: $opt{exclude}\n") if $opt{V} and $opt{exclude};
    mywarn("# $Me include: $opt{include}\n") if $opt{V} and $opt{include};
    mywarn("# $Me matcher: $EXPR\n") if $opt{V};
    mywarn("# $Me hlexpr:  $HLEXPR\n") if $opt{V} and $opt{H};


    if ($opt{H} || $opt{u}) {
        ($SO, $SE) =  $opt{H} ? (`tput smso`,`tput rmso`) : (`tput smul`,`tput rmul`);
        chomp($SO,$SE);
    }

    # -p/-P did set the global $*=1 in the original tcgrep 
    if ($opt{p}) {
       # $/ = '';          # this eats excess newlines from \n\n+ stretches, thus use
       $/=undef;           # a zerowidth -2 --split '(?<=\n\n)(?=[^\n])' instead
       $opt{p}=0;          # 22 lines, 2*1 empty lines, 1*2 empty lines:
       $opt{2}=1;          # with perl -ne 'BEGIN{$/ = ""}; print;' /etc/hosts
                           # $/='':      21 # detects records correctly, eats excess nl
                           # $/="\n\n":  22 # but also detects 'empty records and may 
                           #                  start a record with a newline
       $opt{split}='(?<=\n\n)(?=[^\n])';
    } 
    if (defined $opt{P}) {
       $opt{P}='"'.$opt{P}.'"' if $opt{P}=~/^\\[a-z][\\a-z]*$|^$/oi;
       eval('$/ = '.$opt{P}); mydie("# $Me -P: ".$@) if $@;
    } else {
       $opt{P}="";
    }

    $opt{r} = $opt{R} = $opt{r} + $opt{R};
    $opt{1} += $opt{l};
    $opt{H} += $opt{u};
    $opt{c} += $opt{count} + $opt{countsum};
    $opt{s} += $opt{c};
    $opt{1} += $opt{s} && !$opt{c};


    @ARGV = ($opt{r} ? '.' : '-') if not @ARGV and not $module_use;

    $opt{r} = 1 if !$opt{r} && grep(-d, @ARGV) == @ARGV;

    $opt{C} = undef if $opt{A} and 0 != $opt{C};
    do{$opt{C_mark}=1; $opt{C}=$1} if defined $opt{C} and $opt{C}=~/\A-(\d+)\z/;

    if ($opt{N}) {
       if      ($opt{N}=~s/:(\d+)[bc]$//o) {
          $opt{bufbytes_n}=$1; $opt{2}=1;
       } elsif ($opt{N}=~s/:(\d+)$//o) {
          $opt{buflines_n}=$1; $opt{2}=1;
       }
       if      ($opt{N}=~s/^-.*$//o) {
          $opt{buflines_p}=-1;
       } elsif ($opt{N}=~s/^(\d+)[bc]$//o) {
          $opt{bufbytes_p}=$1;
       } elsif ($opt{N}=~s/^(-?\d+)$//o) {
          $opt{buflines_p}=$1;
       }

       if (not $opt{N} and ($opt{bufbytes_n} or $opt{bufbytes_p} or $opt{buflines_n} or $opt{buflines_p})) {
          $opt{N}="active";
          $opt{V} and mywarn("# making \$buf/\$buf available -- use with -b/-B 'do{\$buf=~/regex/}'".
             " ($opt{buflines_p}/$opt{bufbytes_p}:$opt{buflines_n}/$opt{bufbytes_n})\n");
       } else {
          mywarn("# ERR bad arguments for -N (parsed $opt{buflines_p}/$opt{bufbytes_p}:".
             "$opt{buflines_n}/$opt{bufbytes_n})");
          $opt{N}=$opt{bufbytes_n}=$opt{bufbytes_p}=$opt{buflines_n}=$opt{buflines_p}=0;
       }
    }
    $opt{M}=~/^(-?\d+)[bc]/o and $opt{filemax}=$1 and $opt{filemax}<0 and $opt{filemax}=-$opt{filemax};
    $opt{2}=1 if $opt{M}=~/^-/;
    $opt{2} and $opt{V} and mywarn("# two pass mode active, matching and reporting only in second pass\n");
    
    # lineend to use for stdout
    $/="\0" if $opt{0};
    $opt{nl} = ($opt{0} ? "\0" : "\n") if not $module_use or $module_use and $module_print;
    
    mywarn("\n") if $opt{V};
}

###################################

sub matchfile{
   local($.);
   $files_seen=$files_read=$Errors=$Grand_Total=0;
   $opt{mult} = 1 if not $opt{h} and ($opt{r} or @_ > 1 or defined $_[0] and -d $_[0]);
   $opt{mult} = 0 if     $opt{h};
   my($iter,$iterindex,$itercount);

FILE: while (@_)  {

        $name = $file = shift(@_);
        $files_seen++;
        
        if ($tmp=ref $file) {
           if ($tmp ne "ARRAY") {
              mywarn("# $Me: can only process ARRAY references: $file\n");
              next FILE;
           }
           $name="ARRAYREF".$itercount++;
           $iterindex=0;
           $iter=sub{ # iterator returning next record in case of array refs
               my $record=undef;
               $.=$iterindex;
               if ($iterindex<=$#{$file}){
                  $record=${$file}[$iterindex++];
                  $record="" if not defined $record;
               }
               return $record;
           };
        }elsif ($opt{exclude} and $file=~/$opt{exclude}/) {
           next FILE;
        }elsif ($opt{include} and $file!~/$opt{include}/) {
           next FILE;
        }elsif (-d $file) {
            if (-l $file && @ARGV != 1) {
                mywarn("# $Me: \"$file\" is a symlink to a directory\n")
                    if $opt{V};
                next FILE;
            } 
            if (!$opt{r}) {
                mywarn("# $Me: \"$file\" is a directory, but no -r given\n")
                    if $opt{V};
                next FILE;
            } 
            if (!opendir(DIR, $file)) {
                unless ($opt{q}) {
                    mywarn("$Me: can't opendir $file: $!\n");
                    $Errors++;
                }
                next FILE;
            } 
            my @list = ();
            for (readdir(DIR)) {
                push(@list, "$file/$_") unless /^\.{1,2}$/;
            } 
            closedir(DIR);
            if ($opt{t}) {
                my(@dates);
                for (@list) { push(@dates, -M) } 
                @list = @list[sort { $dates[$a] <=> $dates[$b] } 0..$#dates];
            } else {
                @list = sort @list;
            } 
            unshift @_, @list;
            next FILE;
        }elsif ($file eq '-' or $file eq "/dev/stdin" or $file eq "/dev/fd/0") {
            mywarn("# $Me: reading from stdin\n") if -t main::STDIN && !$opt{q};
            $name = $file;
            mywarn("# $Me: checking type 1 $file\n") if $opt{V};
            $tmp=$file; $tmp="$opt{filter} $file |" if $opt{filter};
            if (!open(FILEH, $tmp)) {
                unless ($opt{q}) { mywarn("$Me: $file: $!\n"); $Errors++; }
                next FILE;
            } 
        } else {

            unless (-e $file) {
                mywarn(qq(# $Me: no such file "$file"\n));
                next FILE;
            }

            unless (-f $file or $opt{a}) {
                mywarn(qq(# $Me: skipping non-plain file "$file"\n)) if $opt{V};
                next FILE;
            }

            ($ext) = $file =~ /\.([^.]+)$/;
            if (defined $ext and $Compress{$ext}) {
                $ENV{file}=$file;
                $file = $Compress{$ext}; $file=~s/\%\%/\$file/g;
                mywarn("# $Me: checking type 2 $file\n") if $opt{V};
                $tmp="$file |"; $tmp.="$opt{filter} |" if $opt{filter};
                if (!open(FILEH, $tmp)) {
                    unless ($opt{q}) { mywarn("$Me: $file: $!\n"); $Errors++; }
                    next FILE;
                } 
            } elsif (! ($opt{a} or $opt{binary} or -T $file)) {
                mywarn(qq(# $Me: skipping binary file "$file"\n)) if $opt{V};
                next FILE;
            } else {
                mywarn("# $Me: checking type 3 $file\n") if $opt{V};
                if ($opt{filter}) {
                   $ENV{file}=$file;
                   if (!open(FILEH, "$opt{filter} \$file |")) {
                      unless ($opt{q}) { mywarn("$Me: $file: $!\n"); $Errors++}
                      next FILE;
                   } 
                } else {
                   if (!open(FILEH,"<",$file)) {
                      unless ($opt{q}) { mywarn("$Me: $file: $!\n"); $Errors++}
                      next FILE;
                   } 
                }
            }
        }

        $files_read++;
        $offset=$lineoffset=1;
        $.=0;
        $dash_printed=undef;
        $lineoffset0=$len=$total=$matches=0;

        $pass=0; $pass=1 if $opt{2};
        @data=%F1=%F=%FF=();

        $buflen=$total=$contextstart=0;
        $buf=$bufl=$data="";
        @bcontext=@buf=();

        eval($eval_newfile) if $eval_newfile; mydie("# $Me newfile: ".$@) if $@;
        $active=$file;
    

LINE:  while (1) {

            # implement input or two pass handling from lines buffered in first pass
            # also implements -M maximum offsets from either start or end of file 
            if      (not $pass) {

               if (($opt{filemax} and $len>$opt{filemax}) or 
                   ($opt{M} and not $opt{filemax} and $.>=$opt{M})) {
                  last
               }
               if (ref $file) {
                  $_=&$iter;
               } else {
                  $_=<FILEH>;
               }
               last if not defined $_;

            } elsif (1==$pass) {

               if (($opt{filemax} and $len>$opt{filemax}) or
                   ($opt{M} and not $opt{filemax} and $.>=$opt{M})) {
                  do{$pass=2; $.=0; next LINE} if not $opt{M}=~/^-/;
               }
               if (ref $file) {
                  $_=&$iter;
               } else {
                  $_=<FILEH>;
               }
               # we read at least TWICE from FILEH, also in slurp mode for FIFOs, 
               # which indeed does work: like with while(<>) (*) we see the defined
               # $_ with records, and then a single undef (suppressed by *), which 
               # also closes the file.
               # Any further reads return either undef (explicit open/FH use)
               # or in case of <> the records from further files in @ARGV, and
               # finally (unless *) from main::STDIN until the user is annoyed
               # and enters EOF.
               do{$pass=2; $.=0; next LINE} if not defined $_;
               $data.=$_; push @data, $_;

            } elsif  (2==$pass) {

               # read from @data -- no need to check limits
               if (0==$.) {
                  if ($opt{M}=~/^-/) {
                     # reposition relative to EOF
                     if ($opt{filemax}) {
                        # -M=-200c -> start with the line contain byte EOF-200
                        if ($opt{filemax}<$len) {
                           # -M=-200c: include enough lines from EOF for len>200
                           $.=$#data; $len=0; # temporarily count with len from EOF
                           while($len<$opt{filemax} and -1!=$.) {
                              $len+=length($data[$.--]);
                           }
                           $.=0 if $.<0;
                        } # else NOP
                     } else {
                        # -M=-2 -> only previous and last line
                        $.=$#data + $opt{M}; 
                        $.=0 if $.<0;
                     }
                     # $. is found, now restore sematics of $len
                     $lineoffset=1;
                     $len=0; 
                     for(my $i=0;$i<$.;$i++) {
                        $len+=length($data[$i]);
                        $lineoffset+=$data[$i]=~tr/\n/\n/;
                     } 
                  } else {
                     # no -M, start at SOF
                     $len=0;
                     $lineoffset=1;
                  }
                  # reset total and remember a copy of value for pass1
                  $total=0;
                  $lineoffset0=0;
                  %F1=%F;
               }
               do{$pass=1; last} if $.>$#data;
               $_=$data[$.++];
            }
            

            $matches = 0;
            $offset=$offset=$len+1;
            $len+=length($_); # actual file length seen


            # note that the lineoffset does not account for lines 
            # removed by non-zerowidth split patterns
            $lineoffset+=$lineoffset0; $lineoffset0=tr/\n/\n/;
            # warn "Lineoffset $offset:$.:$lineoffset -- $lineoffset0\n";


            # recordlines: extend the record to full lines (for -2 --split /regex/)
            $remnantprev=$remnantnext="";
            if ($pass==2 and $opt{split} and @data) {
                my($i,$j);
                for($i=$.-2;;$i--) {
                   last if $i<0;
                   $remnantprev=$data[$i].$remnantprev; 
                   $j=rindex($remnantprev,"\n");
                   next if $j==-1;
                   $remnantprev=substr($remnantprev,$j+1);
                   last;
                }
                for($i=$.;;$i++) {
                   last if $i>$#data;
                   $remnantnext.=$data[$i]; 
                   $j=index($remnantnext,"\n");
                   next if $j==-1;
                   $remnantnext=substr($remnantnext,0,$j+1);
                   last;
                }
            }
            $recordlines=$remnantprev.$_.$remnantnext;


            # remember last N lines for matching in $buf, $bufl (string with/without \n)
            # for now, explicitely HAVE \n at each record END
            # skip in pass1 if possible.
            if ($opt{N} and (1!=$pass or ($eval_input or $eval_input1))) {
               $buf="";
               # 1. collect old lines incl. the new line
               if($opt{bufbytes_p}) {
                  # $buflen is the combined length of previous records in @buf
                  my($l,$b) = (0, $_ . ( /$opt{nl}\z/ ? "" : $opt{nl} )); # Q: or use $/ or SEP or ...

                  while ($l=length($buf[0]), $l and $buflen - $l>$opt{bufbytes_p}) {
                     shift @buf; $buflen -= $l;
                  }
                  $buf=join("",@buf);
                  $l=length($buf) - $opt{bufbytes_p};
                  if ($l > $opt{N_tolerance}) {
                     $l=0 if $l<0;
                     #mywarn("trunc: ", $l," of ", length($buf),"\n");
                     substr($buf,0,$l)="" if $l;
                  }
                  push @buf, $b; $buflen+=length($b);
                  $buf.=$b;
               } elsif ($opt{buflines_p}) {
                  shift @buf if $opt{buflines_p}>0 and $#buf +1 > $opt{buflines_p};
                  push @buf, $_ . ( /$opt{nl}\z/ ? "" : $opt{nl} ); # Q: or use $/ or SEP or ...
                  $buf=join("",@buf);
               } else {
                  $buf=$_; @buf=($buf);
               }
               # 2. add future new lines from @data (pass2)
               if ($opt{bufbytes_n}) {
                   my $l=$opt{bufbytes_n};
                   my $bufn;
                   for (my $i=$.; $i<=$#data and $l>0; $i++) {
                      $bufn.=$data[$i];
                      $l -= length($data[$i]);
                   }
                   if (length($bufn) > $opt{bufbytes_n}+$opt{N_tolerance}) {
                      $bufn=substr($bufn,0,$opt{bufbytes_n});
                   }
                   $buf .= ( $buf=~/$opt{nl}\z/ ? "" : $opt{nl} );
                   $buf .= $bufn;
               } elsif ($opt{buflines_n}) {
                   $buf .= ( $buf=~/$opt{nl}\z/ ? "" : $opt{nl} );
                   for (my $i=$.; $i<=$. + $opt{buflines_n} -1; $i++) {
                      $buf.=$data[$i];
                   }
               }
               $bufl=$buf; $bufl=~s/\A[\r\n\0]+//g; $bufl=~s/[\r\n\0]+\z//g; $bufl=~s/[\r\n\0]/ /g;
            }
            

            eval($eval_input1) if $eval_input1 and $pass==1; mydie("# $Me input1: ".$@) if $@;
            eval($eval_input2) if $eval_input2 and $pass==2; mydie("# $Me input2: ".$@) if $@;
            eval($eval_input)  if $eval_input;               mydie("# $Me input: ". $@) if $@;


            # splitting into records: for -2 --split with $/=undef
            if ($pass==1 and $opt{split}) { 
               eval "\@data=split(m($opt{split})m,\$_)"; mydie("# $Me: fatal error for --split: ".$@) if $@;
            }
               
            
            # two pass mode: matching with &matchpattern, reporting, etc is only performed 
            #                during pass2
            next if 1==$pass;


            # finally try matching $EXPR
            if (&$matchpattern) {
               if ($opt{count}) {
                  /\A/; $matches++ while &$matchhlexprg;
               } else {
                  $matches++;
               }
               $contextstart=$.;
               $total += $matches;
            }

            
            do{myprint("$name",$opt{nl});last} if $opt{l} and $matches;


            # maintain context and print
            if ($opt{A}) {
               # ignore context - we print all input anyway
               $matches=1
            } elsif (defined $opt{C} and 0 != $opt{C}) {
               if ($opt{C_mark}) {
                  # Q: flag each line or a record or only the start?? For now, each line
                  $matches ? s/^/> /mg : s/^/  /mg;; 
               }
               push  @bcontext,$_; 
               shift @bcontext if $#bcontext>$opt{C};
               $matches=1 if $contextstart and $.<=$contextstart+$opt{C}
            }


            if ($matches) {            
               if (@bcontext) {
                  my $oldpos=$.;
                  $.=$. - $#bcontext; 
                  foreach(@bcontext) { &printmatch($_); $.++} # I seem to be unable to localize $.
                  @bcontext=();
                  $.=$oldpos;
               } else {
                  &printmatch($_);
               }
            }


            # context/-p/-P modes: print a separator between _spans_ of matching records
            # -p / -P ... / -C 0 / -C 00: print dashes between all records.
            # -C N        : print dashes, when context buffer was flushed in this iteration
            if (not $dash_printed and
                not $opt{s}    and (    defined $opt{C} or $opt{P} or $opt{p}) and 
                ($matches      and (not defined $opt{C} or  0 == $opt{C}) or 
                 not $matches  and (    defined $opt{C} and 0 != $opt{C}) and 
                     $contextstart and -1+$.==$contextstart+$opt{C})) {            
               myprint('-'x20, $opt{nl});
               $dash_printed=1;
            }

            last FILE if $opt{1} and $matches;
        }  
    } continue { # FILE
        if ($active eq $file and $active ne "") {
           close FILEH;
           
           # insert a blank line for readability
           mywarn("\n") if $total and $opt{V} and not $opt{s} and not $opt{l} and not $opt{c} and not $opt{h};

           $Grand_Total += $total;
           myprint($opt{mult}  && "$name:", $total, "\n") if $opt{c} and not $opt{countsum};
           $total=0;

           eval($eval_finishedfile) if $eval_finishedfile;
           mydie("# $Me finishedfile: ".$@) if $@;
       }
    } 
    eval($eval_finished)     if $eval_finished; 
    mydie("# $Me finished: ".$@) if $@;
    mywarn("# $Me: all input files skipped - consider option -a?\n") 
       if not $opt{a} and 0==$files_read and $files_seen;
    myprint($Grand_Total, "\n") if $opt{c} and $opt{countsum};
}

sub printmatch {
   local($_)=shift;
   my($offset,$hdr)=($offset,"");
   mydie("# $Me too many arguments\n") if $#_>-1;
   if ($pass!=1 and not $opt{s} and $_ ne "") {
      if ($opt{P}) {
         s/[\r\n]/ /g if $opt{p};
      } elsif ($opt{p}) {
         s/\n{2,}$/\n/m;
      }

      if ($opt{o}) { # restrict to first and last match in record by using 
                     # the disjunction in HLEXPR
         if (/\A/, &$matchhlexprg) {
            my $j=pos();
            my $i=$j-length($&);
            while(&$matchhlexprg){$j=pos()}
            $_=substr($_,$i,$j-$i);
            $offset+=$i;
         }
      }
      
      eval($eval_output) if $eval_output; mydie("# $Me output: ".$@) if $@;

      &$substhlexprg if $opt{H}; # opt{i} is embedded into the regex

      # split AND lineoffset: ensure we've the full line even if it
      # means going back before the record start (--split MUST BE ZEROWIDTH
      # FOR PROPER OFFSET/LINEOFFSET REPORTING; -p e.g. IS NOT)
      my($offset)=$offset;
      if ($opt{lineoffset} and $opt{split}) {
         $offset-=length($remnantprev);    # in case I'll change from lineoffset 
                                           # to an explicit switch to report 
         $_=$recordlines;                  # the record extended to lineends
      }

      $_=$& if $opt{show1} and /.*\n?/;
      if (not $opt{noheader}) {
         $hdr=sprintheader($.,$offset,$lineoffset);
         # --shown: report header for all lines of the record
         my $lineoffset=$lineoffset+1;
         s/\n(?!\z)/"\n".sprintheader($.,$offset+pos(),$lineoffset++)/ge;
      }
      if (defined $opt{C} and $opt{C} eq "00") {
         # in this case print only one record header until the
         # next dash separator has been printed. Incompatible with --shown
         $hdr.=$opt{nl} if $hdr;
         $hdr="" if defined $dash_printed and not $dash_printed;
      }
      $dash_printed=0;

      myprint($hdr, $_, /$opt{nl}\z/ ? "" : $opt{nl});
   }
}

sub sprintheader {
   # return the output record header if any
   my($srecordoffset,$sbyteoffset,$slineoffset)=@_;
   $srecordoffset=$.        if not defined $srecordoffset;
   $sbyteoffset=$offset     if not defined $sbyteoffset;
   $slineoffset=$lineoffset if not defined $slineoffset;
   my $hdr="";
   if      ($opt{offset}) {
      $hdr=($opt{n_pad0} ? sprintf("%08d:", $sbyteoffset)   : $sbyteoffset .":");
   } elsif ($opt{lineoffset}) {
      $hdr=($opt{n_pad0} ? sprintf("%04d:", $slineoffset)   : $slineoffset .":");
   } elsif ($opt{n}) {
      $hdr=($opt{n_pad0} ? sprintf("%04d:", $srecordoffset) : $srecordoffset .":");
   }
   $hdr="$name:$hdr" if $opt{mult};
   $hdr.=" " if $hdr and $opt{C_mark};
   return $hdr;
}
    
# read file, skipping whitespace lines and comments
sub readfiletoarray {
   my @a=(); 
   local($/)=$/;
   $/="\n" if not $/=~/\n/;
   if (open(FH, "<", $_[0])) {
       while(<FH>) {
          next if not /\S/;
          next if /^#/;
          chomp($_);
          push @a,$_;
       }
       close FH;
   } else {
       mydie("cannot open $_[0]\n");
   }
   return @a;
}

sub printlines {
   # user-callable function, otherwise unused: 
   # printlines(   [do{...}]   line number|regex,   ...   )
   if (2==$pass and not $FF{"printed:@_"} and $FF{"printed:@_"}=1) {
      my($i,$j,$k,@a,@b)=(-1,-1,"",()); 
      my($rewrite)="";
      local($_);
      if ($_[0]=~/^do\{/) {
         $rewrite=shift if $_[0]=~/^do\{/;
         eval($rewrite); mydie("# $Me printlines argument: ".$@) if $@;
      }
      while (@_) {
         $i=shift;
         if ($i!~/\A\d+\z/) {
            @b=();
            foreach $j (0..$#data) {
               push @b, $j+1 if $data[$j]=~/$i/;
            }
            unshift @_,@b;
            next;
         }
         next if $i<1 or $i>$#data;
         $_=$data[$i-1];
         eval($rewrite) if $rewrite; mydie("# $Me printlines argument: ".$@) if $@;
         $_=sprintheader($i) . $_;
         push @a, $_;
      }
      my $noheader=$opt{noheader};
      $opt{noheader}=1; # do not add a 2nd set of line numbers
      foreach(@a) {
         printmatch($_);
         
      }
      $opt{noheader}=$noheader;
   }
}

sub sq{ # escape hack for single-quoting
   my($tmp)=@_;
   $tmp=~s/'/'"'"'/g;
   return($tmp);
}


# subroutines for boolean regex -------------------------------------------

sub parsestring {
   my @args;
   @args=split /(?:\A|\s+)(\(|\)|and|or|not)(?:\s+|\z)/o, $_[2];
   return parsearray($_[0],$_[1],@args);
}

sub parsearray { 
   my $oldexpr=shift;
   my $hlexpr=shift;
   local($_);
   my($expr,$and,$tmp);
   $and=""; # changed to "and " if an implicit and is possible
   $expr="";
   while(@_){
      $_=shift;
      /^$/o         and do {mydie("# $Me illegal operator/argument in expression\n")};
      # syntactic sugar
      /^not$/o      and do {$expr.=$and  ."not "; $and=""; next};
      /^and$/o      and do {$expr.="and ";        $and=""; next};
      /^or$/o       and do {$expr.="or ";         $and=""; next};
      /^\($/o       and do {$expr.=$and."( ";     $and=""; next};
      /^\)$/o       and do {$expr.=") ";                                         $and="$opt{implicit_and} "; next};
      # default
      1             and do {$tmp=&newregex($_);
                            $hlexpr.="|" if $hlexpr=~/\S/;
                            $hlexpr.='(?:'.$tmp.')';
                            $expr.=$and.&newexpr($_).' ';                        $and="$opt{implicit_and} "; next };
      next;         # never reached
   }
   $expr=~s/ \z//;
   if ($expr=~/\S/) {
      $expr='(' . $expr . ')'
   }
   if ($oldexpr=~/\S/ and $expr=~/\S/) {
      $expr=$oldexpr . ' or ' . $expr;
   } elsif ($oldexpr=~/\S/) {
      $expr=$oldexpr;
   }
   return ($expr,$hlexpr);
}

sub newregex {
   local($_)=@_;
   return $_ if not defined $_ or $_ eq "";
   if (/^do\{/) {
      $_='(?!)'
   } else {
      if ($opt{X}) {
         my $epat=sq($_);
         $_=`expansyn -stem $opt{stemming} -pcre -isregex '$epat'`;
         chomp($_);
      }
      $opt{i} and $_ = '(?i)' . $_;
      $opt{w} and $_ = '\b(?:' . $_ . ')\b';
      $opt{x} and $_ = '^(?:'  . $_ . ')\$';
   }
   return $_;
}

sub newexpr {
   local($_)=@_;
   if (/^do\{/) {
      ;
   } else {
      $_=newregex($_);
      $_="m{$_}$opt{matcher_mod}";
   }
   return $_;
}

sub mydie {
   my $msg;
   if ($module_use) {
     $msg=join("", @_); 
     push @$module_stderr, $msg . ($msg=~/\n\z/ ? "" : "\n") if $module_stderr;
     $@=$msg;
     die;
   } else {
     die @_ 
   }
}

sub mywarn {
   my $msg;
   if ($module_use) {
     $msg=join("", @_); 
     push @$module_stderr, $msg . ($msg=~/\n\z/ ? "" : "\n") if $module_stderr;
     warn $msg if $module_print;
   } else {
     warn @_;
   }
}

sub myprint {
   my $msg;
   if ($module_use) {
     $msg=join("", @_); 
     push @$module_stdout, $msg . ($msg=~/\n\z/ ? "" : "\n") if $module_stdout;
     print $msg if $module_print;
   } else {
     print @_;
   }
}

1;

__END__

vim:filetype=perl
