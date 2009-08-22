#!/usr/bin/perl
#htmlchek.pl: Syntactically checks HTML files for a number of possible errors.
#
# Typical use:
#
#   perl htmlchek.pl [options] infile.html > outfile.check
#
#   Where options have the form "option=value", and are detailed in the
# documentation.
#
#   This program is a port to perl of the original htmlchek.awk (the port was
# fairly mechanical, so programming style and efficency may not be high).
#
# Copyright H. Churchyard 1994, 1995 -- freely redistributable.
#
#  Version 2.0 11/17/94 -- Ported from awk to perl, with some help from Charlie
# Stosser <charless@sco.com>.
#
#  Version 4.1 2/20/95 -- Many enhancements.
#
eval "exec /usr/local/dist/bin/perl -S $0 $*"
    if $running_under_some_shell; # This emulates #! processing on NIH machines
#
#List of known HTML tagwords, divided into pairing tags, <X>...</X>, and
#non-pairing tags -- those where <X> occurs without a following </X>.
#Pairing tags are further classified into list tags, and those tags which
#do not self-nest, etc.
#
#Non-pairing:
#
$unpair{'!--'} = 1; $unpair{'!DOCTYPE'} = 1; $unpair{'BASE'} = 1;
$unpair{'BR'} = 1; $unpair{'COMMENT'} = 1; $unpair{'HR'} = 1;
$unpair{'IMG'} = 1; $unpair{'INPUT'} = 1; $unpair{'ISINDEX'} = 1;
$unpair{'LINK'} = 1; $unpair{'META'} = 1; $unpair{'NEXTID'} = 1;
#
#Optionally-pairing:
#
$canpair{'DD'} = 1; $canpair{'DT'} = 1; $canpair{'LI'} = 1;
$canpair{'OPTION'} = 1; $canpair{'P'} = 1; $canpair{'PLAINTEXT'} = 1;
#
#Pairing:
#
$pair{'A'} = 1; $pair{'ADDRESS'} = 1; $pair{'B'} = 1; $pair{'BLOCKQUOTE'} = 1;
$pair{'BODY'} = 1; $pair{'CITE'} = 1; $pair{'CODE'} = 1; $pair{'DFN'} = 1;
$pair{'DIR'} = 1; $pair{'DL'} = 1; $pair{'EM'} = 1; $pair{'FORM'} = 1;
$pair{'H1'} = 1; $pair{'H2'} = 1; $pair{'H3'} = 1; $pair{'H4'} = 1;
$pair{'H5'} = 1; $pair{'H6'} = 1; $pair{'HEAD'} = 1; $pair{'HTML'} = 1;
$pair{'I'} = 1; $pair{'KBD'} = 1; $pair{'KEY'} = 1; $pair{'LISTING'} = 1;
$pair{'MENU'} = 1; $pair{'OL'} = 1; $pair{'PRE'} = 1; $pair{'S'} = 1;
$pair{'SAMP'} = 1; $pair{'SELECT'} = 1; $pair{'STRONG'} = 1;
$pair{'TEXTAREA'} = 1; $pair{'TITLE'} = 1; $pair{'TT'} = 1; $pair{'U'} = 1;
$pair{'UL'} = 1; $pair{'VAR'} = 1; $pair{'XMP'} = 1;
#
# The union of the set of tags in ``pair'' with the sets of tags in ``unpair''
# and ``canpair'' is the set of all tags known to this program.
#
#Deprecated:
#
$deprec{'COMMENT'} = 1; $deprec{'LISTING'} = 1; $deprec{'PLAINTEXT'} = 1;
$deprec{'XMP'} = 1;
#
#These tags are proposed and/or used, but are are not part of the HTML 1.24 DTD:
#
$nonstd{'DFN'} = 1; $nonstd{'KEY'} = 1; $nonstd{'U'} = 1; $nonstd{'S'} = 1;
#
#Allowed in the <head>...</head> element:
#
$inhead{'ISINDEX'} = 1; $inhead{'HEAD'} = 1; $inhead{'!--'} = 1;
#
#.. and also not allowed in <body>...</body>:
#
$headonly{'BASE'} = 1; $headonly{'LINK'} = 1; $headonly{'META'} = 1;
$headonly{'NEXTID'} = 1; $headonly{'TITLE'} = 1;
#
#Allowed only in context of form -- OPTION only in context of SELECT:
#
$formonly{'INPUT'} = 1; $formonly{'SELECT'} = 1; $formonly{'TEXTAREA'} = 1;
#
#Lists -- all <LI> must be first order daughter of these and vice versa:
#
$list{'DIR'} = 1; $list{'MENU'} = 1; $list{'OL'} = 1; $list{'UL'} = 1;
#
#Lists that do not involve <LI> -- this is almost only used for the "Maximum
#depth of list embedding" diagnostic:
#
$nonlilist{'DL'} = 1;
#
#Lists whose <LI> can only contain low-level markup.
#
$lowlvlist{'DIR'} = 1; $lowlvlist{'MENU'} = 1;
#
#These elements can't contain _any_other_ tags within them.
#
$pcdata{'TITLE'} = 1; $pcdata{'OPTION'} = 1; $pcdata{'TEXTAREA'} = 1;
#
#These tags require the presence of some option -- A is checked separately:
#
$rqopt{'BASE', 'HREF'} = 1; $rqopt{'IMG', 'SRC'} = 1;
$rqopt{'LINK', 'HREF'} = 1; 
#$rqopt{'META', 'CONTENT'} = 1;
$rqopt{'NEXTID', 'N'} = 1; $rqopt{'SELECT', 'NAME'} = 1;
$rqopt{'TEXTAREA', 'NAME'} = 1; $rqopt{'TEXTAREA', 'ROWS'} = 1;
$rqopt{'TEXTAREA', 'COLS'} = 1;
#
#Allowed options; if $opt{'TAG','OPTION'}=1, then that option does not require
#a value.
#
$opt{'A','HREF'} = 2; $opt{'A','METHODS'} = 2; $opt{'A','NAME'} = 2;
$opt{'A','REL'} = 2; $opt{'A','REV'} = 2; $opt{'A','TITLE'} = 2;
$opt{'A','URN'} = 2; $opt{'BASE','HREF'} = 2; $opt{'DIR','COMPACT'} = 1;
$opt{'DL','COMPACT'} = 1; $opt{'FORM','ACTION'} = 2;
$opt{'FORM','ENCTYPE'} = 2; $opt{'FORM','METHOD'} = 1;
$opt{'HTML','VERSION'} = 2; $opt{'IMG','ALIGN'} = 2; $opt{'IMG','ALT'} = 2;
$opt{'IMG','ISMAP'} = 1; $opt{'IMG','SRC'} = 2; $opt{'INPUT','ALIGN'} = 2;
$opt{'INPUT','CHECKED'} = 1; $opt{'INPUT','MAXLENGTH'} = 2;
$opt{'INPUT','NAME'} = 2; $opt{'INPUT','SIZE'} = 2; $opt{'INPUT','SRC'} = 2;
$opt{'INPUT','TYPE'} = 2; $opt{'INPUT','VALUE'} = 2; $opt{'LINK','HREF'} = 2;
$opt{'LINK','METHODS'} = 2; $opt{'LINK','REL'} = 2; $opt{'LINK','REV'} = 2;
$opt{'LINK','TITLE'} = 2; $opt{'LINK','URN'} = 2; $opt{'MENU','COMPACT'} = 1;
$opt{'META','CONTENT'} = 2; $opt{'META','HTTP-EQUIV'} = 2;
$opt{'META','NAME'} = 2; $opt{'NEXTID','N'} = 2; $opt{'OL','COMPACT'} = 1;
$opt{'OPTION','SELECTED'} = 1; $opt{'OPTION','VALUE'} = 2;
$opt{'PRE','WIDTH'} = 2; $opt{'SELECT','MULTIPLE'} = 1;
$opt{'SELECT','NAME'} = 2; $opt{'SELECT','SIZE'} = 2;
$opt{'TEXTAREA','COLS'} = 2; $opt{'TEXTAREA','NAME'} = 2;
$opt{'TEXTAREA','ROWS'} = 2; $opt{'UL','COMPACT'} = 1;
#
#These elements -- and also <LI> in MENU or DIR -- can only contain low-level
#markup (ADDRESS is hard-wired separately because it can contain <P>):
#
$text{'DT'} = 1; $text{'H1'} = 1; $text{'H2'} = 1; $text{'H3'} = 1;
$text{'H4'} = 1; $text{'H5'} = 1; $text{'H6'} = 1; $text{'PRE'} = 1;
#
#These low-level markup elements can only contain other low-level mark-up.
#Special coding to allow headings in <A> and <HR> in <PRE>.
#
$lowlv{'A'} = 1; $lowlv{'B'} = 1; $lowlv{'CITE'} = 1; $lowlv{'CODE'} = 1;
$lowlv{'DFN'} = 1; $lowlv{'EM'} = 1; $lowlv{'I'} = 1; $lowlv{'KBD'} = 1;
$lowlv{'S'} = 1; $lowlv{'SAMP'} = 1; $lowlv{'STRONG'} = 1; $lowlv{'TT'} = 1;
$lowlv{'U'} = 1; $lowlv{'VAR'} = 1;
#
#Non-pairing low-level markup tags:
#
$lwlvunp{'BR'} = 1; $lwlvunp{'IMG'} = 1; $lwlvunp{'!--'} = 1;
#
#Pairing but non-self-nesting tags -- i.e. one occurrence of <x>...</x> can
#never occur inside another occurrence of <x>...</x>, no matter how many
#intervening levels of embedding.  I'm actually stricter than the standard
#here, since such self-nesting is almost certain to be by mistake, and this
#is a powerful error-detecting technique.
#
#In official specification:
$nonnest{'A'} = 1; $nonnest{'ADDRESS'} = 1; $nonnest{'FORM'} = 1;
$nonnest{'DIR'} = 1; $nonnest{'H1'} = 1; $nonnest{'H2'} = 1;
$nonnest{'H3'} = 1; $nonnest{'H4'} = 1; $nonnest{'H5'} = 1; $nonnest{'H6'} = 1;
$nonnest{'HTML'} = 1; $nonnest{'MENU'} = 1; $nonnest{'PRE'} = 1;
$nonnest{'SELECT'} = 1; $nonnest{'TEXTAREA'} = 1; $nonnest{'TITLE'} = 1;
#Added by me:
$nonnest{'B'} = 1; $nonnest{'CITE'} = 1; $nonnest{'CODE'} = 1;
$nonnest{'DFN'} = 1; $nonnest{'EM'} = 1; $nonnest{'I'} = 1;
$nonnest{'KBD'} = 1; $nonnest{'LISTING'} = 1; $nonnest{'S'} = 1;
$nonnest{'SAMP'} = 1; $nonnest{'STRONG'} = 1; $nonnest{'TT'} = 1;
$nonnest{'U'} = 1; $nonnest{'VAR'} = 1; $nonnest{'XMP'} = 1;
#
#$nonnest{'BODY'}=1;$nonnest{'HEAD'}=1; #Separate checks for these
#Document-enclosing tag:
$html{'HTML'} = 1;
#Default declarations, to keep -w option happy:
$X = 0; $append = 0; $arena = ''; $configfile = '';
$clo[++$X] = 'append'; $clo[++$X] = 'arena'; $clo[++$X] = 'configfile';
        $deprecated = ''; $dirprefix = ''; $html3 = '';
$clo[++$X] = 'deprecated'; $clo[++$X] = 'dirprefix'; $clo[++$X] = 'html3';
        $htmlplus = ''; $loosepair = '';
$clo[++$X] = 'htmlplus'; $clo[++$X] = 'loosepair';
        $lowlevelnonpair = ''; $lowlevelpair = '';
$clo[++$X] = 'lowlevelnonpair'; $clo[++$X] = 'lowlevelpair';
        $netscape = ''; $nonblock = ''; $nonpair = '';
$clo[++$X] = 'netscape'; $clo[++$X] = 'nonblock'; $clo[++$X] = 'nonpair';
        $nonrecurpair = ''; $nowswarn = 0; $refsfile = '';
$clo[++$X] = 'nonrecurpair'; $clo[++$X] = 'nowswarn'; $clo[++$X] = 'refsfile';
        $reqopts = ''; $strictpair = ''; $sugar = 0;
$clo[++$X] = 'reqopts'; $clo[++$X] = 'strictpair'; $clo[++$X] = 'sugar';
        $tagopts = ''; $usebase = 0; $dlstrict = 0;
$clo[++$X] = 'tagopts'; $clo[++$X] = 'usebase'; $clo[++$X] = 'dlstrict';
        $novalopts = ''; $xref = 0; $subtract= '';
$clo[++$X] = 'novalopts'; $clo[++$X] = 'xref'; $clo[++$X] = 'subtract';
        $map = 0; $metachar = 0; $nogtwarn = 0;
$clo[++$X] = 'map'; $clo[++$X] = 'metachar'; $clo[++$X] = 'nogtwarn';
        $cf = ''; $lf = ''; $listfile = ''; $inline = 0;
$clo[++$X] = 'cf'; $clo[++$X] = 'lf'; $clo[++$X] = 'listfile';
$clo[++$X] = 'inline';
$clostr = (join('=|',@clo) . '=');
#
#process any FOO=bar switches
eval '$'.$1.'$2;' while $ARGV[0] =~ /^($clostr)(.*)/o && shift;
$[ = 1;                 # set array base to 1
$, = ' ';               # set output field separator
$\ = "\n";              # set output record separator
foreach $X (@ARGV) {
    if ($X =~ /^[^=]+=/) {
        print STDERR "Apparent misspelled or badly-placed command-line option $&";
        print STDERR "Attempting to continue anyway...";}}
#List file
$stuperlRS = $/;
if ($lf) {
    if ($listfile) {
        die 'Error: both lf= and listfile= specified';}
    else {
        $listfile = $lf;}}
if ($listfile) {
    $args = 0;
    if (!(open(LSF,('<'.$listfile)))) {
        die 'Error opening list file!';}
    while (<LSF>) {
        if ($_ =~ /$stuperlRS$/o) {chop;}
        ++$args;
        $_ =~ s/[ \t]+$//;
        $_ =~ s/^[ \t]+//;
        $ARGV[$args] = $_;}
    if ($. > 0) {
        close(LSF);
        $#ARGV = $args;}
    else {die 'Empty list file!';}}
#
$xxllm = '(which should only include low-level markup)';
&initscalrs();
#Configuration file
if ($cf) {
    if ($configfile) {
	die 'Error: both cf= and configfile= specified';}
    else {
	$configfile = $cf;}}
if ($configfile) {
    if (!(open(CFG,('<'.$configfile)))) {
        die 'Error opening configuration file!';}
    while (<CFG>) {
         if ($_ =~ /$stuperlRS$/o) {chop;}
         $_ =~ s/[ \t]+//g;
         $X = (@cfgarr = split(/=/, $_, 3));
         if ($X == 2) {
             &setoption($cfgarr[1], $cfgarr[2]);}
         else {
             if ($X > 2) {
                 print STDERR 'Invalid line in config file:', $_;}}}
    if ($. > 0) {close(CFG);}
    else {die 'Empty configuration file!';}}
#
# HTML 3.0 extensions according to Jan. 19 1995 Arena document:
#
#idlgs["TAG"]=1 means that "ID", "LANG", and "CLASS" are allowed options.
#
$h3 = 0; #controls LH allowed in lists
if ((($arena) || ($html3) || ($htmlplus)) && (!(($html3 eq 'off') ||
  ($htmlplus eq 'off') || ($arena eq 'off')))) {
    $pair{'ABBREV'} = 1; $pair{'ABOVE'} = 1; $pair{'ACRONYM'} = 1;
    $pair{'ARRAY'} = 1; $pair{'AU'} = 1; $pair{'BELOW'} = 1; $pair{'BIG'} = 1;
    $pair{'BOX'} = 1; $pair{'BQ'} = 1; $pair{'CAPTION'} = 1; $pair{'DFN'} = 1;
    $pair{'FIG'} = 1; $pair{'FN'} = 1; $pair{'LANG'} = 1; $pair{'MATH'} = 1;
    $pair{'NOTE'} = 1; $pair{'PERSON'} = 1; $pair{'Q'} = 1; $pair{'ROOT'} = 1;
    $pair{'S'} = 1; $pair{'SMALL'} = 1; $pair{'SUB'} = 1; $pair{'SUP'} = 1;
    $pair{'TABLE'} = 1; $pair{'U'} = 1; $unpair{'ATOP'} = 1;
    $unpair{'LEFT'} = 1; $unpair{'OVER'} = 1; $unpair{'OVERLAY'} = 1;
    $unpair{'RIGHT'} = 1; $unpair{'TAB'} = 1; $canpair{'AROW'} = 1;
    $canpair{'ITEM'} = 1; $canpair{'LH'} = 1; $canpair{'TD'} = 1;
    $canpair{'TH'} = 1; $canpair{'TR'} = 1; $lowlv{'ABBREV'} = 1;
    $lowlv{'ACRONYM'} = 1; $lowlv{'AU'} = 1; $lowlv{'BIG'} = 1;
    $lowlv{'LANG'} = 1; $lowlv{'PERSON'} = 1; $lowlv{'Q'} = 1;
    $lowlv{'SMALL'} = 1; $lowlv{'SUB'} = 1; $lowlv{'SUP'} = 1;
    $lwlvunp{'TAB'} = 1; $text{'LH'} = 1; $text{'CAPTION'} = 1; $idlgs{'A'} = 1;
    $idlgs{'ABBREV'} = 1; $idlgs{'ACRONYM'} = 1; $idlgs{'ADDRESS'} = 1;
    $idlgs{'AU'} = 1; $idlgs{'B'} = 1; $idlgs{'BIG'} = 1;
    $idlgs{'BLOCKQUOTE'} = 1; $idlgs{'BODY'} = 1; $idlgs{'BQ'} = 1;
    $idlgs{'BR'} = 1; $idlgs{'CAPTION'} = 1; $idlgs{'CITE'} = 1;
    $idlgs{'CODE'} = 1; $idlgs{'DD'} = 1; $idlgs{'DFN'} = 1; $idlgs{'DL'} = 1;
    $idlgs{'DT'} = 1; $idlgs{'EM'} = 1; $idlgs{'FIG'} = 1; $idlgs{'FN'} = 1;
    $idlgs{'H1'} = 1; $idlgs{'H2'} = 1; $idlgs{'H3'} = 1; $idlgs{'H4'} = 1;
    $idlgs{'H5'} = 1; $idlgs{'H6'} = 1; $idlgs{'I'} = 1; $idlgs{'IMG'} = 1;
    $idlgs{'INPUT'} = 1; $idlgs{'KBD'} = 1; $idlgs{'LANG'} = 1;
    $idlgs{'LH'} = 1; $idlgs{'LI'} = 1; $idlgs{'NOTE'} = 1; $idlgs{'OL'} = 1;
    $idlgs{'OPTION'} = 1; $idlgs{'P'} = 1; $idlgs{'PERSON'} = 1;
    $idlgs{'PRE'} = 1; $idlgs{'Q'} = 1; $idlgs{'S'} = 1; $idlgs{'SAMP'} = 1;
    $idlgs{'SELECT'} = 1; $idlgs{'SMALL'} = 1; $idlgs{'STRONG'} = 1;
    $idlgs{'SUB'} = 1; $idlgs{'SUP'} = 1; $idlgs{'TABLE'} = 1; $idlgs{'TD'} = 1;
    $idlgs{'TEXTAREA'} = 1; $idlgs{'TH'} = 1; $idlgs{'TR'} = 1;
    $idlgs{'TT'} = 1; $idlgs{'U'} = 1; $idlgs{'UL'} = 1; $idlgs{'VAR'} = 1;
    $opt{'A','BASE'} = 2; $opt{'A','MD'} = 2; $opt{'A','SHAPE'} = 2;
    $opt{'ABOVE','SYMBOL'} = 2; $opt{'ARRAY','COLDEF'} = 2;
    $opt{'ARRAY','DELIM'} = 2; $opt{'ARRAY','LABELS'} = 1;
    $opt{'BASE','ID'} = 2; $opt{'BELOW','SYMBOL'} = 2;
    $opt{'BODY','POSITION'} = 2; $opt{'BOX','DELIM'} = 2;
    $opt{'BOX','SIZE'} = 2; $opt{'BR','ALIGN'} = 2;
    $opt{'CAPTION','ALIGN'} = 2; $opt{'FIG','ALIGN'} = 2;
    $opt{'FIG','BASE'} = 2; $opt{'FIG','HEIGHT'} = 2;
    $opt{'FIG','HSPACE'} = 2; $opt{'FIG','ISMAP'} = 1; $opt{'FIG','MD'} = 2;
    $opt{'FIG','SRC'} = 2; $opt{'FIG','UNITS'} = 2; $opt{'FIG','URN'} = 2;
    $opt{'FIG','VSPACE'} = 2; $opt{'FIG','WIDTH'} = 2; $opt{'H1','ALIGN'} = 2;
    $opt{'H1','NOFOLD'} = 1; $opt{'H1','NOWRAP'} = 1; $opt{'H2','ALIGN'} = 2;
    $opt{'H2','NOFOLD'} = 1; $opt{'H2','NOWRAP'} = 1; $opt{'H3','ALIGN'} = 2;
    $opt{'H3','NOFOLD'} = 1; $opt{'H3','NOWRAP'} = 1; $opt{'H4','ALIGN'} = 2;
    $opt{'H4','NOFOLD'} = 1; $opt{'H4','NOWRAP'} = 1; $opt{'H5','ALIGN'} = 2;
    $opt{'H5','NOFOLD'} = 1; $opt{'H5','NOWRAP'} = 1; $opt{'H6','ALIGN'} = 2;
    $opt{'H6','NOFOLD'} = 1; $opt{'H6','NOWRAP'} = 1; $opt{'HR','ALIGN'} = 2;
    $opt{'HR','BASE'} = 2; $opt{'HR','MD'} = 2; $opt{'HR','SRC'} = 2;
    $opt{'HR','URN'} = 2; $opt{'HR','WIDTH'} = 2; $opt{'IMG','BASE'} = 2;
    $opt{'IMG','HEIGHT'} = 2; $opt{'IMG','MD'} = 2; $opt{'IMG','UNITS'} = 2;
    $opt{'IMG','URN'} = 2; $opt{'IMG','WIDTH'} = 2; $opt{'INPUT','BASE'} = 2;
    $opt{'INPUT','MD'} = 2; $opt{'INPUT','URN'} = 2;
    $opt{'ISINDEX','HREF'} = 2; $opt{'ISINDEX','PROMPT'} = 2;
    $opt{'ITEM','ALIGN'} = 2; $opt{'ITEM','COLSPAN'} = 2;
    $opt{'ITEM','ROWSPAN'} = 2; $opt{'LI','BASE'} = 2;
    $opt{'LI','DINGBAT'} = 2; $opt{'LI','MD'} = 2; $opt{'LI','SKIP'} = 2;
    $opt{'LI','SRC'} = 2; $opt{'LI','URN'} = 2; $opt{'MATH','ID'} = 2;
    $opt{'MATH','MODEL'} = 2; $opt{'NOTE','BASE'} = 2; $opt{'NOTE','MD'} = 2;
    $opt{'NOTE','ROLE'} = 2; $opt{'NOTE','SRC'} = 2; $opt{'NOTE','URN'} = 2;
    $opt{'OL','CONTINUE'} = 1; $opt{'OL','INHERIT'} = 1;
    $opt{'OL','START'} = 2; $opt{'OL','TYPE'} = 2; $opt{'OPTION','SHAPE'} = 2;
    $opt{'OVER','SYMBOL'} = 2; $opt{'OVERLAY','BASE'} = 2;
    $opt{'OVERLAY','HEIGHT'} = 2; $opt{'OVERLAY','ISMAP'} = 1;
    $opt{'OVERLAY','MD'} = 2; $opt{'OVERLAY','SEQ'} = 2;
    $opt{'OVERLAY','SRC'} = 2; $opt{'OVERLAY','UNITS'} = 2;
    $opt{'OVERLAY','URN'} = 2; $opt{'OVERLAY','WIDTH'} = 2;
    $opt{'OVERLAY','X'} = 2; $opt{'OVERLAY','Y'} = 2; $opt{'P','ALIGN'} = 2;
    $opt{'P','NOFOLD'} = 1; $opt{'P','NOWRAP'} = 1; $opt{'ROOT','ROOT'} = 2;
    $opt{'SELECT','BASE'} = 2; $opt{'SELECT','MD'} = 2;
    $opt{'SELECT','SRC'} = 2; $opt{'SELECT','URN'} = 2;
    $opt{'SUB','ALIGN'} = 2; $opt{'SUP','ALIGN'} = 2; $opt{'TAB','AFTER'} = 2;
    $opt{'TAB','BEFORE'} = 2; $opt{'TAB','CENTER'} = 1; $opt{'TAB','ID'} = 2;
    $opt{'TAB','RIGHT'} = 1; $opt{'TAB','TO'} = 2; $opt{'TABLE','ALIGN'} = 2;
    $opt{'TABLE','BORDER'} = 1; $opt{'TABLE','COLSPEC'} = 2;
    $opt{'TABLE','UNITS'} = 2; $opt{'TD','ALIGN'} = 2; $opt{'TD','AXES'} = 2;
    $opt{'TD','AXIS'} = 2; $opt{'TD','COLSPAN'} = 2; $opt{'TD','NOWRAP'} = 1;
    $opt{'TD','ROWSPAN'} = 2; $opt{'TD','VALIGN'} = 2; $opt{'TH','ALIGN'} = 2;
    $opt{'TH','AXES'} = 2; $opt{'TH','AXIS'} = 2; $opt{'TH','COLSPAN'} = 2;
    $opt{'TH','NOWRAP'} = 1; $opt{'TH','ROWSPAN'} = 2;
    $opt{'TH','VALIGN'} = 2; $opt{'TR','ALIGN'} = 2; $opt{'TR','VALIGN'} = 2;
    $opt{'UL','BASE'} = 2; $opt{'UL','DINGBAT'} = 2; $opt{'UL','MD'} = 2;
    $opt{'UL','PLAIN'} = 1; $opt{'UL','SRC'} = 2; $opt{'UL','URN'} = 2;
    $opt{'UL','WRAP'} = 2; $txtf{'ADDRESS'} = 1; $txtf{'BLOCKQUOTE'} = 1;
    $txtf{'BQ'} = 1; $txtf{'BR'} = 1; $txtf{'DD'} = 1; $txtf{'DL'} = 1;
    $txtf{'DT'} = 1; $txtf{'FIG'} = 1; $txtf{'H1'} = 1; $txtf{'H2'} = 1;
    $txtf{'H3'} = 1; $txtf{'H4'} = 1; $txtf{'H5'} = 1; $txtf{'H6'} = 1;
    $txtf{'HR'} = 1; $txtf{'LI'} = 1; $txtf{'NOTE'} = 1; $txtf{'OL'} = 1;
    $txtf{'P'} = 1; $txtf{'PRE'} = 1; $txtf{'TABLE'} = 1; $txtf{'UL'} = 1;
    $rqopt{'ARRAY','COLDEF'} = 1; $rqopt{'FIG','SRC'} = 1;
    $rqopt{'NOTE','SRC'} = 1; $rqopt{'OVERLAY','SRC'} = 1; $inidlgs{'ID'} = 1;
    $inidlgs{'LANG'} = 1; $intxtf{'CLEAR'} = 1; $intxtf{'NEEDS'} = 1;
    $html{'HTMLPLUS'} = 1;
#latest HTML3 patches
    $inidlgs{'CLASS'} = 1; $headonly{'STYLE'} = 1; $headonly{'STYLES'} = 1;
    $pcdata{'STYLE'} = 1; $pair{'STYLES'} = 1; $canpair{'STYLE'} = 1;
    $opt{'BODY', 'BACKGROUND'} = 2; $opt{'IMG', 'BASELINE'} = 2;
    $opt{'STYLE', 'ID'} = 2; $opt{'STYLES', 'NOTATION'} = 2;
    $opt{'HTML', 'ROLE'} = 2; $opt{'HTML', 'URN'} = 2;
    $reqopt{'STYLE', 'ID'} = 1; $reqopt{'STYLES', 'NOTATION'} = 1;
#
    $deprec{'HTMLPLUS'} = 1;
    $deprec{'DIR'} = 1; $deprec{'MENU'} = 1; $deprec{'NEXTID'} = 1;
    $deprec{'BLOCKQUOTE'} = 1; $lwlvunp{'MATH'} = 1; $lwlvunp{'FN'} = 1;
    $h3 = 1; undef %nonstd;}
#
#Netscape extensions (I go strictly by the documentation,such as there is, so
#no BLINK):
#
if (($netscape) && ($netscape ne 'off')) {
    $pair{'CENTER'} = 1; $pair{'NOBR'} = 1; $pair{'FONT'} = 1;
    $canpair{'BASEFONT'} = 1; $unpair{'WBR'} = 1; $opt{'ISINDEX','PROMPT'} = 1;
    $opt{'HR','SIZE'} = 2; $opt{'HR','WIDTH'} = 2; $opt{'HR','ALIGN'} = 2;
    $opt{'HR','NOSHADE'} = 1; $opt{'UL','TYPE'} = 2; $opt{'OL','TYPE'} = 2;
    $opt{'OL','START'} = 2; $opt{'LI','TYPE'} = 2; $opt{'LI','VALUE'} = 2;
    $opt{'IMG','WIDTH'} = 2; $opt{'IMG','HEIGHT'} = 2;
    $opt{'IMG','BORDER'} = 2; $opt{'IMG','VSPACE'} = 2;
    $opt{'IMG','HSPACE'} = 2; $opt{'BR','CLEAR'} = 2; $opt{'FONT','SIZE'} = 2;
    $opt{'BASEFONT','SIZE'} = 2; $opt{'P','ALIGN'} = 2;
    $opt{'H1', 'ALIGN'} = 2; $opt{'H2', 'ALIGN'} = 2; $opt{'H3', 'ALIGN'} = 2;
    $opt{'H4', 'ALIGN'} = 2; $opt{'H5', 'ALIGN'} = 2; $opt{'H6', 'ALIGN'} = 2;
    $opt{'IMG','LOWSRC'} = 2; $lwlvunp{'WBR'} = 1; $lwlvunp{'CENTER'} = 1;
    $lowlv{'FONT'} = 1; $lowlv{'NOBR'} = 1;}
#
if ($nonrecurpair) {&setoption('nonrecurpair',$nonrecurpair);}
if ($strictpair) {&setoption('strictpair',$strictpair);}
if ($loosepair) {&setoption('loosepair',$loosepair);}
if ($nonpair) {&setoption('nonpair',$nonpair);}
if ($nonblock) {&setoption('nonblock',$nonblock);}
if ($lowlevelpair) {&setoption('lowlevelpair',$lowlevelpair);}
if ($lowlevelnonpair) {&setoption('lowlevelnonpair',$lowlevelnonpair);}
if ($deprecated) {&setoption('deprecated',$deprecated);}
if ($tagopts) {&setoption('tagopts',$tagopts);}
if ($novalopts) {&setoption('novalopts', $novalopts);}
if ($reqopts) {&setoption('reqopts',$reqopts);}
if (!$dlstrict) {$dlstrict = 1;}
else {
    if ($dlstrict !~ /^[123]$/) {
        die 'Config error: dlstrict= must be 1, 2, or 3';}}
if (!$metachar) {$metachar = 2;}
else {
    if ($metachar !~ /^[123]$/) {
        die 'Config error: metachar= must be 1, 2, or 3';}}
#
if ($refsfile) {
    if ($append) {
        $openstr = '>>';}
    else {
        $openstr = '>';}
    if (!(open(SRC,($openstr . $refsfile . '.SRC')) &&
      open(NAM,($openstr . $refsfile . '.NAME')) &&
      open(HRF,($openstr . $refsfile . '.HREF')) &&
      ((!(($xref) && ($map))) || open(MAP,($openstr . $refsfile . '.MAP'))))) {
        die "Error opening output files!";}
    else {
        print SRC ''; print NAM ''; print HRF '';
        $currf[1] = SRC; $currf[2] = NAM; $currf[3] = HRF;
        if (($xref) && ($map)) {print MAP ''; $currf[4] = MAP;}}}
foreach $X (keys %unpair) {
    if (defined $pair{$X}) {
        die "Internal logical inconsistency: $X defined as both pairing and non-pairing tag";}}
#
#
# Main
#
while (<>) {
    if ($_ =~ /$stuperlRS$/o) { # strip record separator, allow for last line to
        chop;}                  # be unterminated.  I love that /$/$/ syntax,
    #@Fld is unneeded           # but perl doesn't.
    if (($.-$FNRbase) == 1) {
        if ($. != 1) {
            &endit();
            print "\n========================================\n";}
        $fn = $ARGV;
        # Next line is Unix-specific
        $fn =~ s/^\.\///;
        if ($subtract) {
            if (index($fn, $subtract) == 1) {
                $fn = substr($fn, (length($subtract) + 1));}
            else {
                die "Filename $fn does not have \042$subtract\042 prefix specified in subtract= option\n".
                  'Exiting prematurely...';}}
        $nampref = ($dirprefix . $fn . '#');
        $lochpref = ($dirprefix . $fn);
        if ($fn =~ /.\//) {
            $fromroot = $fn; $fromroot =~ s/\/[^\057]*$/\//;}
        else {
            $fromroot = '';}
        $fromroot=($dirprefix . $fromroot);
        if ($fn ne '-') {
            if ($inline) {printf 'HTMLCHEK:';}
            print ("Diagnostics for file \"" . $fn . "\":");}}
    if ($inline) {
        print $_;
        $S = 'HTMLCHEK:';}
    else {
        if ($sugar) {$S = ($fn . ': ' . ($.-$FNRbase) . ': ');}}
    $lastbeg = 0; $currsrch = 1; $txtbeg = 1;
    while ((((substr($_, $currsrch) =~ /[<>]/) eq 1) &&
      ($RSTART = length($`)+1)) != 0) {
        $currsrch = ($currsrch + $RSTART);
        if (substr($_, ($currsrch - 1), 1) eq '<') {
            if ($state) {
                &parsetag($currsrch - 1);
                $lastbeg = ($currsrch - 1);
                $state = 1; $continuation = 1;
                if (!$nxrdo) {$Redo = 1;}
                if (($metachar != 3) || ((!$inquote) && ($lasttag ne '!--'))) {
                    print $S . "Multiple `<' without `>' ERROR!", &crl();}}
            else {
                if (($currsrch > length($_)) ||
                  (substr($_, $currsrch, 1) =~ /^[ \t]$/)) {
                    print $S .
                      "Whitespace after `<': Incorrect SGML tag syntax ERROR!",
                      &crl() . ',Ignoring';
                    $wastext = 1;}
                else {
                    if (!$wastext) {
                        if (substr($_, $txtbeg,
                          ($currsrch - ($txtbeg + 1))) !~ /^[ \t]*$/) {
                            $wastext = 1;}}
                    if ($wastext) {
                        $headbody = $hedbodarr{$hedbodvar};
                        if ((!$bodywarn) && (!$headbody) && ((!$nestvar) ||
                          ($nestarr{$nestvar} eq 'HTML'))) {
                            print $S .
                              'Was non-whitespace outside <body>...</body> Warning!',
                              &crl();
                            $bodywarn = 1;}
                        else {
                            if (($headbody eq 'HEAD') &&
                              ($nestarr{$nestvar} eq 'HEAD')) {
                                print $S .
                                  'Was non-whitespace in <head>...</head> outside any element ERROR!',
                                  &crl();}}}
                    if (($currsrch == 2) ||
                      (substr($_, ($currsrch - 2), 1) =~ /^[ \t]$/)) {
                        $prews = 1;}
                    $lastbeg = $currsrch; $state = 1; $prevtag = $lasttag;
                    $lasttag = ''; $lastopt = '';}}}
        else {
            if (substr($_, ($currsrch - 1), 1) eq '>') {
                if ($state == 0) {
                    if (!$nogtwarn) {
                         print $S . "`>' without `<' Warning!", &crl();}
                    $wastext = 1;}
                else {
                    &parsetag($currsrch - 1);
                    if (($metachar == 3) && (($inquote) || (($lasttag eq '!--') &&
                      (!$comterr) && ($lastcomt ne '--')))) {
                        $lastbeg = ($currsrch - 1);
                        $continuation = 1;
                        if (!$nxrdo) {$Redo = 1;}}
                    else {
                         if (($inquote) || ($inequal)) {
                             &malft();}
                         if ($optfree) {
                             &misstest();}
                         if (($lasttag eq '!--') && ($lastcomt ne '--')) {
                             print $S .
                               "!-- comment not terminated by \042--\042 ERROR!",
                               &crl();}
                         if (($lasttag eq 'IMG') && ($alt == 0)) {
                             print $S . 'IMG tag without ALT option Warning!',
                             &crl();
                             ++$wasnoalt;}
                         if (($lasttag eq 'LINK') && ($linkone == 1) &&
                           ($linktwo == 1)) {
                             ++$linkrmhm;}
                         if (($lasttag eq 'A') && (!$wasname) && (!$washref)) {
                             print $S .
                               '<A> tag occurred without reference (NAME,HREF,ID) option ERROR!',
                               &crl();}
                         $head = ('^' . $lasttag . $;);
                         foreach $X (sort(keys %rqopt)) {
                             if ($X =~ $head) {
                                @optx = split($;, $X, 2);
                                if (!(defined $curtagopts{$optx[2]})) {
                                    print $S .
                                      "<$lasttag> tag occurred without $optx[2] option ERROR!",
                                      &crl();}}}
                         if (($wasname > 1) || ($washref > 1)) {
                             print $S .
                               'Multiple reference (NAME,ID;HREF,SRC,BULLET) options ERROR!',
                               &crl(), 'on tag', $lasttag;}
                         if ((!$wastext) && ($lasttag eq ('/' . $prevtag)) &&
                           ($lasttag ne '/TEXTAREA')) {
                             print $S . 'Null <x>...</x> element Warning!',
                               &crl(), "on tag $lasttag";}
                         if (($lasttag =~ /^[AU]$/) &&
                           (($currsrch > length($_)) ||
                           (substr($_, $currsrch, 1) =~ /^[ \t]$/)) &&
                           (!$nowswarn)) {
                             print $S .
                               "Whitespace after `>' of underline markup opening tag Warning!",
                               &crl(), 'on tag', $lasttag;
                             ++$wswarn;}
                         $wastext = 0 ; $txtbeg = $currsrch; $prews = 0;
                         $state = 0; $continuation = 0;}}}
            else {
                print $S . 'Internal error', &crl(), 'ignore';}}}
    if (($state == 1) || (($lastbeg == 0) &&
      ($continuation == 1))) {
        &parsetag(length($_) + 1);
        $continuation = 1;}
    else {
        if ((!$state) && ($_ !~ /^[ \t]*$/) && ($_ !~ />[ \t]*$/)) {
          $wastext = 1;}}
    if ($_ =~ /&/) {
        s/&[A-Za-z][-A-Za-z0-9.]*;//g;
        s/&[\043][0-9][0-9]*;//g;
        $X = 0;
        $X = s/&+[^a-zA-Z&]//g;
        $X = ($X + s/&+$//g);
        if ($X) {print 'Loose ampersand (may be OK) Warning!', &crl();}
        if ($_ =~ /&/) {
            print $S . 'Apparent non-complying ampersand code ERROR!', &crl();}}}
continue {
    $FNRbase = $. if eof;}
#
# End-of-file routine.
#
if ($. > 0) {
    &endit();
    if ($xref) {
        foreach $X (keys %xhrefarr) {
            if (defined $xnamearr{$X}) {
                delete $xhrefarr{$X}; delete $xnamearr{$X};}}
        if ($map) {
            foreach $X (sort(keys %xmaparr)) {
                @mapx = split($;, $X, 2);
                $xdeparr{$mapx[1]} = ($xdeparr{$mapx[1]} . "\n\t" . $mapx[2]);}}
        if ($refsfile) {
            foreach $X (sort(keys %xnamearr)) {print NAM $X;}
            foreach $X (sort(keys %xhrefarr)) {print HRF $X;}
            foreach $X (sort(keys %xsrcarr))  {print SRC $X;}
            if ($map) {
                foreach $X (sort(keys %xdeparr)) {
                    print MAP 'File', $X, 'references:' . $xdeparr{$X};}}}
        else {
            print "\n========================================\n";
            print "<A NAME=\042...\042> and ID=\042...\042 locations not " .
              "referenced from within the files checked:\n";
            foreach $X (sort(keys %xnamearr)) {
                print $X;}
            print "\n----------------------------------------\n";
            print "HREF=\042...\042 references not found in the files checked:\n";
            foreach $X (sort(keys %xhrefarr)) {
                print $X;}
            print "\n----------------------------------------\n";
            print "SRC=\042...\042 (and BULLET=\042...\042) references:\n";
            foreach $X (sort(keys %xsrcarr)) {
                print $X;}
            if ($map) {
                print "\n----------------------------------------\n";
                print "Reference dependencies:\n";
                foreach $X (sort(keys %xdeparr)) {
                    print 'File', $X, 'references:' . $xdeparr{$X};}}}}}
#
#
# parsetag() communicates with main() through these global variables:
# - $lastbeg (zero if no `<' ocurred on line, otherwise points to character
#   immediately after the last `<' encountered).
# - $state (one if unresolved `<', zero otherwise).
# - $continuation (one if unresolved `<' from previous line, zero otherwise),
# - $inquote (one if inside option quotes <tag opt="....">).
#
sub parsetag {
    local($inp) = @_;
    if (!$lastbeg) {
        $lastbeg = 1;}
    $numf = (@arr = split(' ', substr($_, $lastbeg, ($inp - $lastbeg))));
    if (substr($_, $lastbeg, ($inp - $lastbeg)) =~ /[ \t]$/) {
        $nxrdo = 1;}
    else {
        $nxrdo = 0;}
    if ($numf == 0) {
        if (!$continuation) {
            print $S . 'Null tagname ERROR!', &crl();
            $state = 0;
            $inquote = 0; $inequal = 0; $optfree = 0; $wasopt = 0; $linkone = 0;
            $linktwo = 0; $wasname = 0; $washref = 0; undef %curtagopts;}
        return;}
    else {
        if (!$continuation) {
            $arr[1] =~ tr/a-z/A-Z/;
            if ($arr[1] =~ /^!--/) {
                $raw = $arr[1]; $arr[1] = '!--';}
            else {
                $raw = '';}
            if ($arr[1] =~ /[=\042]/) {
                print $S . 'Bad tagname ERROR!', &crl(), "on tag $arr[1]";}
            $lasttag = $arr[1]; $alt = 0;
            if ($arr[1] =~ /^\//) {
                # </TAG> found
                $arr[1] =~ s/^\///;
                if (($prews) && ($arr[1] =~ /^[AU]$/) && (!$nowswarn)) {
                    print $S .
                      "Whitespace before `<' of underline closing tag Warning!",
                      &crl(), 'on tag', $lasttag;
                    ++$wswarn;}
                if (defined $unpair{$arr[1]}) {
                    print $S .
                      'Closing tag on empty element (non-pairing tag) ERROR!',
                      &crl(), 'on tag /' . $arr[1];}
                else {
                    $poppdstak = 0;
                    if ((defined $pair{$arr[1]}) || (defined $canpair{$arr[1]})) {
                        if (($nestvar <= 0) || ($lev{$arr[1]} <= 0)) {
                            print $S . 'Extraneous /' . $arr[1],
                              'tag without preceding', $arr[1], 'tag ERROR!',
                              &crl() . ', Ignoring';}
                        else {
                            if ($nestarr{$nestvar} ne $arr[1]) {
                                if (($nestvar > 2) &&
                                  ($nestarr{($nestvar - 2)} eq $arr[1])) {
                                    if ((defined $canpair{$nestarr{$nestvar}}) &&
                                      (($nestarr{($nestvar - 1)} =~ /^L[HI]$/) ||
                                      ($nestarr{($nestvar - 1)} =~ /^D[TD]$/))) {
                                        --$lev{$nestarr{$nestvar}};
                                        --$nestvar; $poppdstak = 1;}}
                                if (($nestvar > 1) &&
                                  ($nestarr{($nestvar - 1)} eq $arr[1])) {
                                    if (!(defined $canpair{$nestarr{$nestvar}})) {
                                    # Implicit end of optionally-pairing element
                                        print $S . 'Missing /' .
                                          $nestarr{$nestvar},
                                          'tag (should be located before /' .
                                          $arr[1], 'tag) ERROR!', &crl();}
                                    --$lev{$nestarr{$nestvar}}; --$nestvar;
                                    $poppdstak = 1; --$lev{$arr[1]};}
                                else {
                                    print $S . 'Improper nesting ERROR!',
                                      &crl() . ': /' . $nestarr{$nestvar},
                                      'expected, /' . $arr[1], 'found';
                                    --$lev{$arr[1]};}}
                            else {
                                --$lev{$arr[1]};}
                            if (defined $list{$nestarr{$nestvar}}) {
                                if (!$isli{$nestvar}) {
                                    print $S . 'Empty list (without <LI>) ERROR!',
                                      &crl(), 'on tag /' . $arr[1];}
                                if (($wastext) && (!$poppdstak)) {
                                    print $S . 'Non-whitespace outside <LI> in list ERROR!',
                                      &crl(), 'on tag', $arr[1];}}
                            if ($nestarr{$nestvar} eq 'DL') {
                                if (!$isdtdd{$nestvar}) {
                                    print $S . 'Empty DL list (without <dt>/<dd>) ERROR!',
                                      &crl();}
                                if (($wastext) && (!$poppdstak)) {
                                    print $S .
                                      'Non-whitespace outside <dt>/<dd> in <dl> list ERROR!',
                                      &crl(), 'on tag', $arr[1];}}
                            --$nestvar;}}
                    else {
                        $revusarr{$arr[1]} = 1;
                        if ((!$lev{$arr[1]}) || ($lev{$arr[1]} <= 0)) {
                            print $S . 'Extraneous closing tag </x> ERROR!',
                              &crl(), 'on unknown tag /' . $arr[1];}
                        else {
                            --$lev{$arr[1]};}}}
                if ($arr[1] eq 'HEAD') {
                    if ($title == 0) {
                        print $S . 'No <TITLE> in <head>...</head> ERROR!',
                        &crl();}
                    $base = 0; $title = 0; --$hedbodvar;}
                if ($arr[1] eq 'BODY') {
                    if ($headone == 0) {
                        print $S .
                          'No <H1> in <body>...</body> Warning!', &crl();}
                    $headone = 0; $bodywarn = 0; --$hedbodvar;}
                if ((defined $list{$arr[1]}) || (defined $nonlilist{$arr[1]})) {
                    --$listdep;}}
            else {
                # <TAG> found
                if ((defined $pcdata{$nestarr{$nestvar}}) &&
                  ($arr[1] ne $nestarr{$nestvar})) {
                    print $S . 'Tag inside', $nestarr{$nestvar},
                      'element ERROR!', &crl(), 'on tag', $lasttag;}
                if ((defined $pair{$arr[1]}) || (defined $canpair{$arr[1]}) ||
                  (defined $unpair{$arr[1]})) {
                    $known = 1;}
                else {
                    $known = 0;}
                if (!((defined $lowlv{$arr[1]}) || (defined $lwlvunp{$arr[1]}))) {
                    $curnest = '';
                    if (($nestvar > 1) && ($arr[1] ne 'LI') &&
                      ($nestarr{$nestvar} eq 'LI') &&
                      (defined $lowlvlist{$nestarr{($nestvar - 1)}})) {
                        $curnest = ('LI in ' . $nestarr{($nestvar - 1)});}
                    else {
                        if ((defined $text{$nestarr{$nestvar}}) ||
                          (defined $lowlv{$nestarr{$nestvar}})) {
                            if (($arr[1] =~ /^H[1-6]$/) &&
                              ($nestarr{$nestvar} eq 'A')) {
                                print $S . $arr[1],
                                  'heading in <A>...</A> element Warning!',
                                  &crl();}
                            else {
                                if (($arr[1] ne $nestarr{$nestvar}) &&
                                  (!(($arr[1] eq 'HR') &&
                                  ($nestarr{$nestvar} eq 'PRE')))) {
                                    # inclusion exceptions
                                    if (!((defined $formonly{$arr[1]}) &&
                                      ($lev{'FORM'} > 0))) {
                                         $curnest = $nestarr{$nestvar};}}}}
                        else {
                            if (($arr[1] ne 'P') && ($lev{'ADDRESS'} > 0)) {
                                $curnest = 'ADDRESS';}}}
                    if ($curnest) {
                        if ($known) {
                            if (!((($arr[1] eq 'LI') ||
                              ($arr[1] =~ /^D[DT]$/)) &&
                              (($nestarr{$nestvar} eq 'DT') ||
                              ($nestarr{$nestvar} eq 'LH')))) {
                                print $S . $arr[1],
                                  'tag, which is not low-level markup, nested in',
                                  $curnest, 'element ERROR!', &crl();}}
                        else {
                            print $S . 'Unknown tag', $arr[1], 'nested in',
                              $curnest, 'element', $xxllm, 'Warning!', &crl();}}}
                if (defined $html{$arr[1]}) {
                    ++$lev{'HTML'};}
                else {
                    ++$lev{$arr[1]};}
                # Not necessarily immediately contained in FORM
                if ((defined $formonly{$arr[1]}) &&
                  ($lev{'FORM'} <= 0)) {
                    print $S . '<' . $arr[1] . '> outside of <form>...</form> ERROR!',
                      &crl();}
                if (($arr[1] eq 'OPTION') && ($nestarr{$nestvar} ne 'SELECT') &&
                  ($nestarr{$nestvar} ne 'OPTION')) {
                    print $S . '<' . $arr[1] .
                      '> outside of <select>...</select> ERROR!', &crl();}
                if (($arr[1] eq 'STYLE') && ($nestarr{$nestvar} !~ /^STYLES?$/)) {
                    print $S . '<' . $arr[1] .
                      '> outside of <styles>...</styles> ERROR!', &crl();}
                if (defined $list{$nestarr{$nestvar}}) {
                    if ($wastext) {
                        print $S . 'Non-whitespace outside <LI> in list ERROR!',
                          &crl(), "on tag $arr[1]";}
                    if (($arr[1] ne 'LI') && (!(($arr[1] eq 'LH') && ($h3))) &&
                      ($arr[1] ne '!--')) {
                        print $S . 'Tag in list occurred outside <LI> ERROR!',
                          &crl(), 'on tag', $arr[1];}}
                if ($nestarr{$nestvar} eq 'DL') {
                    if ($wastext) {
                        print $S .
                          'Non-whitespace outside <dt>/<dd> in <dl> list ERROR!',
                          &crl(), "on tag $arr[1]";}
                    if (($arr[1] !~ /^D[DT]$/) && (!(($arr[1] eq 'LH') &&
                      ($h3))) && ($arr[1] ne '!--')) {
                        print $S .
                          'Tag in <dl> list occurred outside <dt>/<dd> ERROR!',
                          &crl(), 'on tag', $arr[1];}}
                $headbody = ''; $implicit = 0;
                if ((defined $pair{$arr[1]}) || (defined $canpair{$arr[1]})) {
                    if (($arr[1] eq 'HEAD') || ($arr[1] eq 'BODY')) {
                        if ((!(defined $lev{'HTML'})) || ($lev{'HTML'} == 0)) {
                            print $S .
                              'HEAD or BODY outside of <HTML>...</HTML> Warning!',
                              &crl();}
                        if ($hedbodvar > 0) {
                            if (($hedbodarr{$hedbodvar} eq 'HEAD') &&
                              ($arr[1] eq 'BODY')) {
                                $hedbodarr{$hedbodvar} = $arr[1];
                                --$lev{'HEAD'};
                                print $S .
                                  "Assumed an implicit `</HEAD>' before <BODY> Warning!",
                                  &crl();
                                if (($nestarr{$nestvar} ne 'HEAD') &&
                                  (defined $pair{$nestarr{$nestvar}})) {
                                    print $S .
                                      'Improper nesting on implicit </HEAD> ERROR!',
                                      &crl() . ", tag /$nestarr{$nestvar} expected";}
                                $nestarr{$nestvar} = $arr[1]; $implicit = 1;
                                if ($title == 0) {
                                    print $S .
                                      'No <TITLE> in <head>...</head> ERROR!',
                                      &crl();}}
                            else {
                                print $S .
                                  'HEAD or BODY nested inside HEAD or BODY element ERROR!',
                                  &crl();}}
                        else {
                            if (($arr[1] eq 'BODY') && (!(defined $usarr{'HEAD'}))) {
                                print '<body> without preceding <head>...</head> Warning!',
                                  &crl();}
                            if (($nestvar > 0) && ($nestarr{$nestvar} ne 'HTML')) {
                                print $S .
                                  'HEAD or BODY contained inside non-HTML element ERROR!',
                                  &crl();}}
                        $hbwarn = 0; $base = 0; $title = 0; $headone = 0;
                        $loosbtag = 0;
                        if ($arr[1] eq 'HEAD') {++$numheads;}
                        if (!$implicit) {
                            ++$hedbodvar;
                            $hedbodarr{$hedbodvar} = $arr[1];}}
                    if (!$implicit) {
                        if ((!(defined $canpair{$nestarr{$nestvar}})) ||
                          (!(defined $canpair{$arr[1]}))) {
                            ++$nestvar;}
                        else {
                            if ((($nestarr{$nestvar} eq 'LH') &&
                              ($arr[1] ne 'LI') && ($arr[1] !~ /^D[TD]$/)) ||
                              (($nestarr{$nestvar} eq 'LI') &&
                              ($arr[1] ne 'LI')) ||
                              (($nestarr{$nestvar} =~ /^D[TD]$/) &&
                              ($arr[1] !~ /^D[TD]$/))) {
                                ++$nestvar;}
                            else {
                                if (($nestvar > 2) &&
                                  (($nestarr{($nestvar - 1)} =~ /^L[HI]$/) ||
                                  ($nestarr{($nestvar - 1)} =~ /^D[TD]$/))) {
                                    if ((($nestarr{$nestvar} ne 'LI') &&
                                      ($arr[1] eq 'LI')) ||
                                      (($nestarr{$nestvar} !~ /^D[TD]$/) &&
                                      ($arr[1] =~ /^D[TD]$/))) {
                                        --$nestvar;}}}}
                        if (defined $html{$arr[1]}) {
                            $nestarr{$nestvar} = 'HTML';}
                        else {
                            $nestarr{$nestvar} = $arr[1];}}
                    $isli{$nestvar} = 0; $isdtdd{$nestvar} = 0;
                    $isdt{$nestvar} = 0;}
                if ($hedbodvar) {
                    $headbody = $hedbodarr{$hedbodvar};}
                if ((defined $list{$arr[1]}) || (defined $nonlilist{$arr[1]})) {
                    ++$listdep;
                    if ($listdep > $maxlist) {
                        $maxlist = $listdep;}}
                if ($arr[1] eq 'LI') {
                    $isli{($nestvar - 1)} = 1;
                    if (($nestvar < 2) ||
                      (!(defined $list{$nestarr{($nestvar - 1)}}))) {
                        print $S . '<LI> outside of list ERROR!', &crl();}}
                if ($arr[1] =~ /^D[DT]$/) {
                    $isdtdd{($nestvar - 1)} = 1;
                    if (($nestvar < 2) || ($nestarr{($nestvar - 1)} ne 'DL')) {
                        print $S . '<dt>/<dd> outside of <dl> list ERROR!',
                          &crl(), 'on tag', $arr[1];}
                    else {
                        if ($arr[1] eq 'DT') {
                            $isdt{($nestvar - 1)} = 1;}
                        else {
                            if ($dlstrict > 1) {
                                if (!$isdt{($nestvar - 1)}) {
                                print $S . '<DD> without preceding <DT> in <DL> list Warning!',
                                  &crl();}
                                if ($dlstrict > 2) {
                                    $isdt{$nestvar - 1} = 0;}
                                else {
                                    $isdt{$nestvar - 1} = 1;}}}}}
                if (!$headbody) {
                    if (($lasttag ne '!--') && ($lasttag ne '!DOCTYPE') &&
                      (!(defined $html{$lasttag})) && (!$hbwarn)) {
                        print $S . 'Tag outside of HEAD or BODY element Warning!',
                          &crl(), 'on tag', $arr[1];
                        $hbwarn = 1;}}
                else {
                    if ($arr[1] eq 'PLAINTEXT') {
                        print $S .
                          '<PLAINTEXT> in <head>...</head> or <body>...</body> ERROR!',
                          &crl();}}
                if ($headbody eq 'HEAD') {
                    if (!((defined $inhead{$arr[1]}) ||
                      (defined $headonly{$arr[1]}))) {
                        print $S . 'Disallowed tag in <head>...</head> ERROR!',
                          &crl(), 'on tag', $arr[1];}
                    if ($arr[1] eq 'TITLE') {
                        ++$title;
                        if ($title > 1) {
                            print $S . 'Multiple <TITLE> tags in <head> ERROR!',
                              &crl();}}
                    if ($arr[1] eq 'BASE') {
                        ++$base;
                        if ($base > 1) {
                            print $S . 'Multiple <BASE> tags in <head> Warning!',
                              &crl();}}}
                if (defined $headonly{$arr[1]}) {
                    if ($headbody eq 'BODY') {
                        print $S .
                          'Disallowed tag in <body>...</body> ERROR!', &crl(),
                          'on tag', $arr[1];}
                    else {
                        if (($headbody ne 'HEAD') && ($loosbtag)) {
                            print $S . 'Tag', $arr[1],
                              'that belongs in HEAD occurred after a tag that belongs in BODY ERROR!',
                              &crl();}}}
                else {
                    if ((!(defined $inhead{$arr[1]})) && (!$headbody) &&
                      ($known) && ($arr[1] ne '!DOCTYPE')) {
                        $loosbtag = 1;}}
                if ($arr[1] =~ /^H[1-6]$/) {
                    $newheadlev = substr($arr[1], 2, 1);
                    if ($newheadlev > ($headlevel + 1)) {
                        print $S . 'Warning! Jump from header level H' .
                          $headlevel, 'to level H' . $newheadlev, &crl();}
                    $headlevel = $newheadlev;
                    if ($headlevel == 1) {
                        ++$headone;
                        if ($headone > 1) {
                            print $S . 'Multiple <H1> headings Warning!',
                            &crl();}}}
                if (($arr[1] eq '!DOCTYPE') && ($nestvar)) {
                    print $S . '<!DOCTYPE...> enclosed within <x>...</x> ERROR!',
                      &crl();}
                if (defined $html{$arr[1]}) {
                    if ($nestvar > 1) {
                        print $S . '<HTML> enclosed within <x>...</x> ERROR!',
                        &crl();}
                    $bodywarn = 0; $hbwarn = 0; $headone = 0; $loosbtag = 0;}
                if ((defined $nonnest{$arr[1]}) && ($lev{$arr[1]} > 1)) {
                    print $S . 'Self-nesting of unselfnestable tag ERROR!',
                      &crl() . ", of level $lev{$arr[1]} on tag $arr[1]";}}
            if (defined $html{$arr[1]}) {
                $usarr{'HTML'} = 1;}
            else {
                $usarr{$arr[1]} = 1;}
            if ($arr[1] eq '!--') {
                $startf = 1; $comterr = 0; $cmplxcmt = 0; $lastcomt = '';}
            else {
                $startf = 2;}
            $inquote = 0; $inequal = 0; $optfree = 0; $wasopt = 0; $linkone = 0;
            $linktwo = 0; $wasname = 0; $washref = 0; undef %curtagopts;}
        else {
            $startf = 1;}
        # Remainder of stuff in <...> after tag word
        if ($lasttag !~ /^!/) {
            for ($i = $startf; $i <= $numf; ++$i) {
                if ((!$inequal) && (!$inquote)) {
                    if (($arr[$i] =~
                      /^[^=\042]*(=\042[^\042]*\042)?$/) ||
                      ($arr[$i] =~ /^[^=\042]*=(\042)?[^\042]*$/)) {
                        if (($optfree) &&
                          (($arr[$i] =~ /^=[^=\042][^=\042]*$/) ||
                          ($arr[$i] =~ /^=\042[^\042]*\042$/))) {
                            if (!$malftag) {
                                $arr[$i] =~ s/^\075//;
                                if ($arr[$i] =~ /\042/) {
                                    &optvalproc($arr[$i],1);}
                                else {&optvalproc($arr[$i],0);}}
                            $optfree = 0;}
                        else {
                            if (($optfree) && (($arr[$i] =~ /^=\042/) ||
                              ($arr[$i] eq '='))) {
                                $inequal = 1;}
                            @arr2 = split(/=/, $arr[$i], 2);
                            if ($arr2[1] eq '') {
                                if (!$inequal) {
                                    print $S . 'Null tag option ERROR!',
                                      &crl(), "on tag $lasttag";
                                $malftag = 1;}}
                            else {
                                if ($optfree) {
                                    &misstest();}
                                $arr2[1] =~ tr/a-z/A-Z/;
                                $optfree = 1; ++$wasopt;
                                $malftag = 0; $optvalstr = ''; $Redo = 0;
                                if ($lasttag =~ /^\//) {
                                    print $S . 'Option on closing tag',
                                    $lasttag, 'ERROR!', &crl();}
                                else {
                                    $optarr{$lasttag, $arr2[1]} = 1;
                                    $lastopt = $arr2[1];
                                    if (($lastopt !~ /^[A-Z][-A-Z0-9.]*$/) &&
                                      ($lastopt ne '<')) {
                                        print $S .
                                          "Option name \042$lastopt\042 is not alphanumeric Warning!",
                                           &crl(), 'on tag', $lasttag;}
                                    $curtagopts{$lastopt} = 1;
                                    if (($known) &&
                                      (!(defined $opt{$lasttag,$lastopt}))) {
                                        if (!(((defined $idlgs{$lasttag}) &&
                                          (defined $inidlgs{$lastopt})) ||
                                          ((defined $txtf{$lasttag}) &&
                                          (defined $intxtf{$lastopt})))) {
                                            print $S . $lastopt,
                                              'not recognized as an option for',
                                              $lasttag, 'tag Warning!', &crl();}}
                                    if (($lasttag eq 'IMG') &&
                                      ($arr2[1] eq 'ALT')) {
                                        $alt = 1;}}}
                            if ($arr[$i] =~ /^[^=\042][^=\042]*=$/) {
                                $inequal = 1;}
                            if ($arr[$i] =~ /[\075]/) {
                                $optvalstr = $arr[$i];
                                $optvalstr =~ s/^[^=]*=//;}
                            $stuperltmp = $arr[$i];
                            $Q = ($stuperltmp =~ s/\042//g);
                            if ($Q == 1) {
                                $inquote = 1;}
                            if (($optvalstr)&&(!$inequal)&&(!$inquote)) {
                                $optfree = 0;
                                if (!$malftag) {
                                    &optvalproc($optvalstr,$Q);}}}}
                    else {
                        &malft();}}
                else {
                    if (($inequal) && (!$inquote)) {
                        if ($arr[$i] =~ /\042/) {
                            if ($arr[$i] =~ /^\042[^\042]*(\042)?$/) {
                                $stuperltmp = $arr[$i];
                                if (($stuperltmp =~ s/\042//g) == 2) {
                                    if (!$malftag) {
                                        $stuperltmp =~ s/^\075//;
                                        &optvalproc($stuperltmp,1);}
                                    $inequal = 0; $optfree = 0;}
                                else {
                                    $optvalstr = $arr[$i];
                                    $inquote = 1;}}
                            else {
                                &malft();}}
                        else {
                            if ($arr[$i] !~ /[\075]/) {
                                if (!$malftag) {
                                    &optvalproc($arr[$i],0);}
                                $inequal = 0; $optfree = 0;}
                            else {
                                &malft();}}}
                    else {
                        if ($arr[$i] =~ /\042/) {
                            $inquote = 0; $inequal = 0; $optfree = 0;
                            if ($arr[$i] !~ /^[^\042]*\042$/) {
                                &malft();}
                            else {
                                if ($Redo) {
                                    $optvalstr = ($optvalstr . $arr[$i]);
                                    $Redo = 0;}
                                else {
                                    $optvalstr = ($optvalstr . ' ' . $arr[$i]);}
                                if (!$malftag) {
                                  &optvalproc($optvalstr,1);}}}
                        else {
                            if ($Redo) {
                                $optvalstr = ($optvalstr . $arr[$i]);
                                $Redo = 0;}
                            else {
                                $optvalstr = ($optvalstr . ' ' . $arr[$i]);}}}}}}
        else {
            if ($lasttag eq '!--') {
                if (!$continuation) {
                    $raw =~ s/^!--//; $arr[1] = $raw;}
                else {
                    if (($metachar == 1) && (!$cmplxcmt)) {
                        print $S . 'Complex comment Warning!', &crl();
                        $cmplxcmt = 1;}
                    if ($lastcomt eq '--') {
                        print $S . "Apparent \042--\042 embedded in comment Warning!",
                          &crl();
                        $comterr = 1;}}
                for ($i = $startf; $i <= $numf; ++$i) {
                    if ((($arr[$i] =~ /--/) && ($i < $numf)) ||
                      (($arr[$i] =~ /--./) && ($i == $numf))) {
                        print $S . "Apparent \042--\042 embedded in comment Warning!",
                          &crl();
                        $comterr = 1;}}
                if ($arr[$numf] =~ /--$/) {
                    $lastcomt = '--';}
                else {
                    $lastcomt = '';}}}
        return;}}
#
#
# Return as much location information as possible in diagnostics:
#
# Current location:
sub crl {
    if (($fn)&&($fn ne '-')) {
        return ('at line ' . ($.-$FNRbase) . " of file \042" . $fn . "\042");}
    else {
        return ('at line ' . $.);}}
#
# End of file location:
sub ndl {
    if (($fn)&&($fn ne '-')) {
        return ("at END of file \042" . $fn . "\042");}
    else {
        return 'at END';}}
#
# Error message returned from numerous places in the program...
#
sub malft {
    print $S . 'Malformed tag option ERROR!', &crl(), 'on tag', $lasttag;
    $malftag = 1;}
#
#
#Check for non-kosher null options:
#
sub misstest {
    if ((($lasttag eq 'A') && ($lastopt eq 'NAME')) || ($lastopt eq 'HREF') ||
      ($lastopt eq 'ID')) {
        print $S . 'Missing reference option value ERROR!', &crl(),
          "on tag $lasttag, option $lastopt";}
    else {
        if (($opt{$lasttag, $lastopt} == 2) ||
          ((defined $idlgs{$lasttag}) && (defined $inidlgs{$lastopt})) ||
          ((defined $txtf{$lasttag}) && (defined $intxtf{$lastopt}))) {
            print $S . 'Missing option value ERROR!', &crl(),
              "on tag $lasttag, option $lastopt";}}}
#
#
#Set property arrays from command line variable or configuration file.
#
sub setoption {
    local($inname, $invalu)  = @_;
    # allow command line options to override config file
    if ($inname eq 'htmlplus') {
        if ($htmlplus) {return;}
        else {$htmlplus = $invalu; return;}}
    if ($inname eq 'html3') {
        if ($html3) {return;}
        else {$html3 = $invalu; return;}}
    if ($inname eq 'arena') {
        if ($arena) {return;}
        else {$arena = $invalu; return;}}
    if ($inname eq 'netscape') {
        if ($netscape) {return;}
        else {$netscape = $invalu; return;}}
    if ($inname eq 'dlstrict') {
        if ($dlstrict) {return;}
        else {$dlstrict = $invalu; return;}}
    if ($inname eq 'metachar') {
        if ($metachar) {return;}
        else {$metachar = $invalu; return;}}
    if ($inname eq 'nogtwarn') {
        $nogtwarn = $invalu; return;}
    if ($inname eq 'nowswarn') {
        $nowswarn = $invalu; return;}
    if ($invalu =~ /\075/) {
        print STDERR
          "Invalid syntax on $inname\= configuration option, ignoring";}
    else {
        if (($inname eq 'novalopts') || ($inname eq 'tagopts') ||
          ($inname eq 'reqopts')) {
            $numf = (@invarr = split(/:/, $invalu));
            for ($i = 1; $i <= $numf; ++$i) {
                $numf2 = (@invarr2 = split(/,/, $invarr[$i], 3));
                if ($numf2 != 2) {
                    print STDERR
                      "Invalid syntax on $inname\= configuration option, ignoring";}
                else {
                    $invarr2[1] =~ tr/a-z/A-Z/;
                    $invarr2[2] =~ tr/a-z/A-Z/;
                    if ($inname eq 'novalopts') {
                        $opt{$invarr2[1], $invarr2[2]} = 1;}
                    else {
                        if ($inname eq 'reqopts') {
                            $rqopt{$invarr2[1], $invarr2[2]} = 1;}
                        $opt{$invarr2[1], $invarr2[2]} = 2;}}}}
        else {
            $numf = (@invarr = split(/,/, $invalu));
            for ($i = 1; $i <= $numf; ++$i) {
                $invarr[$i] =~ tr/a-z/A-Z/;
                if ($inname eq 'nonrecurpair') {
                    $pair{$invarr[$i]} = 1;
                    &strictclean($invarr[$i]);
                    $nonnest{$invarr[$i]} = 1;}
                elsif ($inname eq 'strictpair') {
                    $pair{$invarr[$i]} = 1;
                    &strictclean($invarr[$i]);
                    delete $nonnest{$invarr[$i]};}
                elsif ($inname eq 'loosepair') {
                    if (&notredef($invarr[$i])) {
                        $canpair{$invarr[$i]} = 1;
                        delete $unpair{$invarr[$i]};
                        &nonstrictclean($invarr[$i]);}}
                elsif ($inname eq 'nonpair') {
                    if (&notredef($invarr[$i])) {
                        $unpair{$invarr[$i]} = 1;
                        delete $canpair{$invarr[$i]};
                        &nonstrictclean($invarr[$i]);}}
                elsif ($inname eq 'nonblock') {
                    $text{$invarr[$i]} = 1;
                    delete $unpair{$invarr[$i]};}
                elsif ($inname eq 'lowlevelpair') {
                    $lowlv{$invarr[$i]} = 1;
                    &strictclean($invarr[$i]);}
                elsif ($inname eq 'lowlevelnonpair') {
                    if (&notredef($invarr[$i])) {
                        $text{$invarr[$i]} = 1;
                        &nonstrictclean($invarr[$i]);}}
                elsif ($inname eq 'deprecated') {
                    $deprec{$invarr[$i]} = 1;}
                else {print STDERR 'Unrecognized configuration option', $inname;
                    return;}}}}}
#
sub strictclean {
    local($param) = @_;
    delete $nonstd{$param};
    delete $unpair{$param};
    delete $canpair{$param};
    delete $lwlvunp{$param};}
#
sub nonstrictclean {
    local($param) = @_;
    delete $nonstd{$param};
    delete $pair{$param};
    delete $nonnest{$param};
    delete $lowlv{$param};}
#
#Stuff which has special hard-wired processing; don't allow user to redefine
#
sub notredef {
    local($param) = @_;
    if ((defined $list{$param}) || (defined $nonlilist{$param}) ||
      (defined $html{$param}) || ($param eq 'HEAD') || ($param eq 'BODY')) {
        return 0;}
    else {
return 1;}}
#
#
# This subroutine receives the raw option value string, for every tag option
# that does have a value.  It does some errorchecking and cleanup, and writes
# to the .NAME, .HREF, and .SRC files when requested.
#
sub optvalproc {
    local($val, $quoted) = @_;
    $currfn = 0;
    if ($quoted) {
        $val =~ s/\042//g; $val =~ s/^ //; $val =~ s/ $//;}
    if ($lasttag eq 'LINK') {
        if (($lastopt eq 'REV')&&($val =~ /^MADE$/i)) {
            ++$linkone;}
        if (($lastopt eq 'HREF')&&($val =~ /^mailto:/)) {
            ++$linktwo;}}
    if (($usebase) && ($lasttag eq 'BASE') && ($lastopt eq 'HREF')) {
        if (($quoted) && ($val) && ($val ne '=') && ($val !~ /[^ ] [^ ]/)) {
            $nampref = ($val . '#'); $lochpref = $val;
            if ($val =~ /.\//) {
                $fromroot = $val;
                $fromroot =~ s/\/[^\057]*$/\//;}
            else {
                $fromroot = '';}}
        else {
            print $S . "Bad <BASE HREF=\042...\042>", &crl() . ', Ignoring';}}
    else {
        if ((($lasttag eq 'A') && ($lastopt eq 'NAME')) || ($lastopt eq 'ID')) {
            $currfn = 2; ++$wasname;
            if (($val) && ($val ne '=')) {
                if (defined $namearr{('#' . $val)}) {
                    print $S . "Duplicate location \042#" . $val .
                      "\042 ERROR!", &crl(), 'on tag', $lasttag, 'option',
                      $lastopt;}
                else {
                    if ($val =~ /^#/) {
                        print $S . "Invalid #-initial location \042" .
                          $val . "\042 ERROR!", &crl(), 'on tag', $lasttag,
                          'option', $lastopt;}
                    else {
                        $namearr{('#' . $val)} = 1;}}}}
        else {
            if (($lastopt eq 'SRC') || ($lastopt eq 'BULLET')) {
                $currfn = 1; ++$washref;}
            else {
                if ($lastopt eq 'HREF') {
                    $currfn = 3; ++$washref;
                    if ($val =~ /^#/) {
                        $loclhrefarr{$val} = 1;}}}}}
    if ($currfn) {
        if ($val =~ /[^-a-zA-Z0-9._]/) { # PJ: add _
            if (!$quoted) {
                print $S .
                  'Unquoted non-alphanumeric reference option value ERROR!',
                  &crl(), 'on tag', $lasttag . ', option', $lastopt;}
            else {
                if ($currfn == 2) {
                    print $S .
                      "Character other than `A-Z', `a-z', `0-9', `-', or `.' in location name Warning!",
                      &crl(), 'on tag', $lasttag . ', option', $lastopt;}}}
        else {
            if (!$quoted) {
                print $S . 'Unquoted reference option value Warning!', &crl(),
                  'on tag', $lasttag . ', option', $lastopt;}}
        if ($val =~ /[^ ] [^ ]/) {
            print $S . 'Whitespace in reference option value Warning!',
              &crl(), "on tag $lasttag, option $lastopt";}
        else {
            if ($val eq '') {
                print $S . 'Null reference option value ERROR!', &crl(),
                  "on tag $lasttag, option $lastopt";}
            else {
                # Skip the residue of Malformed Tag Option cases;  OK to do
                # this, since "=" is not a valid URL;  However, a minor bug
                # is that <A NAME="="> will not be checked, and will not
                # result in any errormessage.
                if ((($refsfile) || ($xref)) && ($val ne '=')) {
                    if ($currfn == 2) {
                        $val = ($nampref . $val);}
                    else {
                        if (($currfn == 3) && ($val =~ /^#/)) {
                            $val = ($lochpref . $val);}
                        else {
                            if ($val =~ /^http:[^\057]*$/) {
                                $val =~ s/^http://;}
                            if (($val !~ /^[^\057]*:/) && ($val !~ /^\//)) {
                                if ($val =~ /^~/) {
                                    print $S .
                                      "Relative URL beginning with '~' Warning!",
                                      &crl(),"on tag $lasttag option $lastopt";}
                                else {
                                    $val = ($fromroot . $val);}}}}
                    # This monstrosity supports "../" in URL's:
                    while ($val =~ /\057[^\057]*[^\057]\057\.\.\057/) {
                        $val =~ s/\057[^\057]*[^\057]\057\.\.\057/\057/;}
                    if (($val =~ /[:\057]\.\.\057/) || ($val =~ /^\.\.\057/)) {
                        print $S . "Unresolved \042../\042 in URL Warning!",
                          &crl(), "on tag $lasttag option $lastopt";}
                    if (!$xref) {
                        $stuperltmp =  $currf[$currfn];
                        print $stuperltmp $val;}
                    else {
                        if ($currfn == 1) {
                            $xsrcarr{$val} = 1;
                            if ($map) {
                                $xmaparr{$lochpref, $val} = 1;}}
                        else {
                            if ($currfn == 2) {
                                $xnamearr{$val} = 1;}
                            else {
                                if ($currfn == 3) {
                                    $xhrefarr{$val} = 1;
                                    if ($map) {
                                        if ($val =~ /#[^\057#]*$/) {
                                            $val =~ s/#[^\057#]*$//;}
                                        $xmaparr{$lochpref, $val} = 1;}}}}}}}}}
    else {
        if ((!$quoted) && ($val ne '=')) {
            if ($val =~ /[^-a-zA-Z0-9.]/) {
                print $S . "Unquoted non-alphanumeric option value \042" .
                  $val . "\042 Warning!", &crl(), 'on tag option', $lastopt;}
            else {
                if ($val =~ /[^-0-9.]/) {
                    $val =~ tr/a-z/A-Z/;
                    $unqopt{($lastopt . '=' . $val)} = 1;}}}}}
#
#
# Start each file with a clean slate.
#
sub initscalrs {
    $state = 0; $continuation = 0; $nestvar = 0; $bodywarn = 0; $maxlist = 0;
    $listdep = 0; $headone = 0; $headlevel = 0; $br = 0; $wasnoalt = 0;
    $loosbtag = 0; $wswarn = 0; $hedbodvar = 0; $linkrmhm = 0;
    $wastext = 0; $prevtag = ''; $hbwarn = 0; $S = ''; $prews = 0;
    $numheads = 0; $lasttag = '';}
#
#
# File-final global errors and tag diagnostics.
#  Information is passed here through arrays:
# - $usarr{$x}:     The tag <x> was used.
# - $revusarr{$x}:  The reverse tag </x> was used.
# - $lev{$x}:       Current degree of self-nesting of paired tag <x>...</x>.
# - $optarr{$x,$y}: The option y was used with tag <x>.
#and also through the variables $maxlist and $continuation.
#
sub endit {
    if (!$xref) {
        if ($refsfile) {
            print NAM $lochpref;}}
    else {
        $xnamearr{$lochpref} = 1;}
    if ($inline) {
        $S = 'HTMLCHEK:';}
    else {
        if ($sugar) {
            $S = ($fn . ': END: ');}}
    if ($continuation) {
        print $S . "Was awaiting a `>' ERROR!", &ndl();}
    if (($wastext) && (!$bodywarn)) {
        print $S . 'File-final uncontained non-whitespace Warning!',&ndl();}
    foreach $X (sort(keys %usarr)) {
        if ((defined $pair{$X}) && ($lev{$X} > 0)) {
                print $S . 'Pending unresolved <x> without </x> ERROR! of level',
                  $lev{$X}, &ndl(), 'on tag', $X;}}
    if (!(defined $usarr{'HTML'})) {
        print $S . '<HTML> not used in document Warning!', &ndl();}
    if (!(defined $usarr{'HEAD'})) {
        print $S . '<HEAD> not used in document Warning!', &ndl();}
    if (!(defined $usarr{'BODY'})) {
        print $S . '<BODY> not used in document Warning!', &ndl();}
    if ($linkrmhm == 0) {
        print $S . "<LINK REV=\"made\" HREF=\"mailto:...\"> not used in document Warning!",
          &ndl();}
    if ($numheads > 1) {
        print $S . '<HEAD> used multiple (' . $numheads . ') times ERROR!',
          &ndl();}
    if (!(defined $usarr{'TITLE'})) {
        print $S . '<TITLE> not used in document ERROR!', &ndl();}
    if ($wasnoalt) {
        print $S . '<IMG> tags were found without ALT option', $wasnoalt,
          'times Warning!', &ndl();
        print
          "Advice: Add ALT=\042\042 to purely decorative images, and meaningful text to others.";}
    if ($wswarn) {
        print $S . 'Whitespace separated underlining tags from enclosed element',
          $wswarn, 'times Warning!', &ndl();
        print
          "Advice: Change ``<X> text </X>'' syntax to preferred ``<X>text</X>'' syntax.";}
    foreach $X (sort(keys %loclhrefarr)) {
        if (!(defined $namearr{$X})) {
            print $S . "Was a dangling file-local reference \042$X\042 ERROR!",
              &ndl();}}
    foreach $X (sort(keys %unqopt)) {
        if (!$br) {
            printf "\n";
            if ($inline) {printf 'HTMLCHEK:';}
            printf "Unquoted tag option=value pairs:";
            $br = 1;}
        printf ' %s', $X;}
    if ($br) {
        printf "\n";}
    foreach $X (sort(keys %usarr)) {
        $options = ''; $head = ('^' . $X . $;);
        foreach $Z (sort(keys %optarr)) {
            if ($Z =~ $head) {
                @optx = split($;, $Z, 2);
                $options = ($options . ' ' . $optx[2]);}}
        $unknown = 0;
        if (!$br) {
            print '';
            $br = 1;}
        if ($inline) {printf 'HTMLCHEK:';}
        printf '%s %s %s', 'Tag', $X, 'occurred';
        if ($options) {
            printf '%s%s', ', with options', $options;}
        if (!((defined $pair{$X}) || (defined $canpair{$X}) ||
             (defined $unpair{$X}))) {
            printf '%s%s', '; Warning! tag is unknown ', &ndl();
            $unknown = 1;
            if ($X !~ /^[A-Z!][-A-Z0-9.]*$/) {
                printf '%s%s', "; Warning! tag is not alphanumeric ", &ndl();}}
        if (defined $deprec{$X}) {
            printf '%s%s', '; Warning! tag is obsolescent and deprecated ', &ndl();}
        else {
            if (defined $nonstd{$X}){
                printf '%s%s',
                  "; Warning! tag is not (yet) a part of HTML standard ", &ndl();}}
        if (($unknown) && (defined $revusarr{$X}) && ($lev{$X} != 0)) {
            printf '%s%s%s%s%s%s%s%s%s%s%s%s', '; Closing tag </', $X,
              '> of unknown tag ', $X, ' encountered and balance of <', $X,
              '> minus </', $X, '> nonzero (', $lev{$X}, ') Warning! ', &ndl();}
        printf "\n";}
    if ($maxlist) {
        if ($inline) {printf 'HTMLCHEK:';}
        print 'Maximum depth of list embedding was', $maxlist;}
    #Reinitialize for next file
    &initscalrs();
    undef %unqopt; undef %namearr; undef %loclhrefarr;
    undef %lev; undef %usarr; undef %optarr; undef %revusarr;}
#-=-  -=-  -=-  -=-  -=-  -=-  -=-  -=-  -=-  -=-  -=-  -=-  -=-  -=-  -=-  -=-
##EOF
