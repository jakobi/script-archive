#!/usr/local/dist/bin/gawk -f
#htmlchek.awk: Syntactically checks HTML files for a number of possible errors.
#
# Typical use:
#
#   awk -f htmlchek.awk [options] infile.html > outfile.check
#
#   Where options have the form "option=value", and are detailed in the
# documentation.
#
#   This program is written in the ``awk'' programming language (on Sun systems
# and some others, non-archaic ``awk'' is called ``nawk'', so that ``nawk''
# should be used instead of ``awk'').  Also, a freely-redistributable ``awk''
# interpreter called ``gawk'', which is free of the bugs that some of the
# vendor-supplied ``awk''/``nawk'' programs suffer from, is available for most
# platforms, and as source from the FSF GNU project.  Use the separate file
# htmlchek.sh, distributed with the htmlchek package, to avoid running this
# program under incompatible ``old awk'' on Unix.
#
# Copyright H. Churchyard 1994 -- freely redistributable.
#
# Version 1.0 10/15/94 -- Tested with gawk 2.15 and nawk on SunOS, gawk 2.14
# and nawk on DEC Alpha OSF/1, and gawk 2.11 on 16-bit MS-DOS.
#
# Version 1.1 10/25/94 -- Fixed a tag option parsing bug that I had detected,
# but not corrected, before posting 1.0.  Added checks against <head>-only
# elements in <body>...</body>, against <dd> and <dt> not in <dl>..</dl>, and
# for the presence of <title> and <h1>, and <img> with ``alt'' option.  A user
# has reported success with gawk 2.15 on VMS.  Multiple files on the command
# line are now supported, and the syntax ``<A B = "c">'' generates a warning,
# rather than errors.
#
# Version 1.2 10/30/94 -- Some code cleanup, was too restrictive on possible
# ampersand codes.  Handle <head>...<body>...</body> syntax, support <!doctype>
# and <meta> tags, warn about whitespace after ``<'' (and after ``>'' of some
# opening pairing tags), warn about some empty <X></X> elements.  Almost too
# big for 16-bit MS-DOS.
#
# Version 2.0 11/20/94 -- Clarified status of U and DFN tags, added rudimentary
# cross-reference checking ability, support HTMLPlus and Netscape extensions,
# added checks for location option values which are null or missing or have
# embedded whitespace, check tag names with embedded `=' or `"', miscellaneous
# non-whitespace and <dl> checks, separated docs from program source, improved
# docs, added perl port and Unix shell scripts.
#
#  Version 3.0 12/1/94 -- Added automatic file-local reference checking,
# recognize separate behavior of optionally-pairing and obligatorily-pairing
# tags, allow redefinition of the language checked for through command-line
# switches or an external configuration file, cut down on some repeated
# redundant error messages, updated HTML 3.0 preliminary specification that
# is checked for, do not treat `<' followed by whitespace as a tag beginning,
# check for allowed and required tag options, check for quoted URL's, numerous
# minor fixes and enhancements.  Tested under VMS Posix.
#
BEGIN{#List of known HTML tagwords, divided into pairing tags, <X>...</X>, and
      #non-pairing tags -- those where <X> occurs without a following </X>.
      #Pairing tags are further classified into list tags, and those tags which
      #do not self-nest, etc.
#
#Non-pairing:
#
unpair["!--"]=1;unpair["!DOCTYPE"]=1;unpair["BASE"]=1;unpair["BR"]=1;
unpair["COMMENT"]=1;unpair["HR"]=1;unpair["IMG"]=1;unpair["INPUT"]=1;
unpair["ISINDEX"]=1;unpair["LINK"]=1;unpair["META"]=1;unpair["NEXTID"]=1;
#
#Optionally-pairing:
#
canpair["DD"]=1;canpair["DT"]=1;canpair["LI"]=1;canpair["OPTION"]=1;
canpair["P"]=1;canpair["PLAINTEXT"]=1;
#
#Pairing:
#
pair["A"]=1;pair["ADDRESS"]=1;pair["B"]=1;pair["BLOCKQUOTE"]=1;pair["BODY"]=1;
pair["CITE"]=1;pair["CODE"]=1;pair["DFN"]=1;pair["DIR"]=1;pair["DL"]=1;
pair["EM"]=1;pair["FORM"]=1;pair["H1"]=1;pair["H2"]=1;pair["H3"]=1;
pair["H4"]=1;pair["H5"]=1;pair["H6"]=1;pair["HEAD"]=1;pair["HTML"]=1;
pair["I"]=1;pair["KBD"]=1;pair["KEY"]=1;pair["LISTING"]=1;pair["MENU"]=1;
pair["OL"]=1;pair["PRE"]=1;pair["S"]=1;pair["SAMP"]=1;pair["SELECT"]=1;
pair["STRIKE"]=1;pair["STRONG"]=1;pair["TEXTAREA"]=1;pair["TITLE"]=1;
pair["TT"]=1;pair["U"]=1;pair["UL"]=1;pair["VAR"]=1;pair["XMP"]=1;
#
# The union of the set of tags in ``pair'' with the sets of tags in ``unpair''
# and ``canpair'' is the set of all tags known to this program.
#
#Deprecated:
#
deprec["COMMENT"]=1;deprec["LISTING"]=1;deprec["PLAINTEXT"]=1;deprec["XMP"]=1;
#
#These tags are proposed and/or used, but are are not part of the HTML PUBLIC
#"-//IETF//DTD HTML Level 2//EN//2.0" standard v. 1.21:
#
nonstd["DFN"]=1;nonstd["KEY"]=1;nonstd["U"]=1;nonstd["S"]=1;nonstd["STRIKE"]=1;
#
#Allowed in the <head>...</head> element:
#
inhead["ISINDEX"]=1;inhead["HEAD"]=1;inhead["!--"]=1;
#
#.. and also not allowed in <body>...</body>:
#
headonly["BASE"]=1;headonly["LINK"]=1;headonly["META"]=1;headonly["NEXTID"]=1;
headonly["TITLE"]=1;
#
#Allowed only in context of form -- OPTION only in context of SELECT:
#
formonly["INPUT"]=1;formonly["SELECT"]=1;formonly["TEXTAREA"]=1;
#
#Lists -- all <LI> must be first order daughter of these and vice versa:
#
list["DIR"]=1;list["MENU"]=1;list["OL"]=1;list["UL"]=1;
#
#Lists that do not involve <LI> -- this is almost only used for the "Maximum
#depth of list embedding" diagnostic:
#
nonlilist["DL"]=1;
#
#Lists whose <LI> can only contain low-level markup.
#
lowlvlist["DIR"]=1;lowlvlist["MENU"]=1;
#
#These tags require the presence of some option -- A is checked separately:
#Minor bug: can't specify more than one required option.
#
rqopt["BASE"]="HREF";rqopt["IMG"]="SRC";rqopt["LINK"]="HREF";
rqopt["META"]="CONTENT";rqopt["NEXTID"]="N";rqopt["SELECT"]="NAME";
rqopt["TEXTAREA"]="NAME";
#
#Allowed options; if opt["TAG","OPTION"]==1, then that option does not require
#a value.
#
opt["A","HREF"]=2;opt["A","METHODS"]=2;opt["A","NAME"]=2;opt["A","REL"]=2;
opt["A","REV"]=2;opt["A","TITLE"]=2;opt["A","URN"]=2;opt["BASE","HREF"]=2;
opt["DIR","COMPACT"]=1;opt["DL","COMPACT"]=1;opt["FORM","ACTION"]=2;
opt["FORM","ENCTYPE"]=2;opt["FORM","METHOD"]=1;opt["HTML","VERSION"]=2;
opt["IMG","ALIGN"]=2;opt["IMG","ALT"]=2;opt["IMG","ISMAP"]=1;opt["IMG","SRC"]=2;
opt["INPUT","ALIGN"]=2;opt["INPUT","CHECKED"]=1;opt["INPUT","MAXLENGTH"]=2;
opt["INPUT","NAME"]=2;opt["INPUT","SIZE"]=2;opt["INPUT","SRC"]=2;
opt["INPUT","TYPE"]=2;opt["INPUT","VALUE"]=2;opt["LINK","HREF"]=2;
opt["LINK","METHODS"]=2;opt["LINK","REL"]=2;opt["LINK","REV"]=2;
opt["LINK","TITLE"]=2;opt["LINK","URN"]=2;opt["MENU","COMPACT"]=1;
opt["META","CONTENT"]=2;opt["META","HTTP-EQUIV"]=2;opt["META","NAME"]=2;
opt["NEXTID","N"]=2;opt["OL","COMPACT"]=1;opt["OPTION","SELECTED"]=1;
opt["OPTION","VALUE"]=2;opt["PRE","WIDTH"]=2;opt["SELECT","MULTIPLE"]=1;
opt["SELECT","NAME"]=2;opt["SELECT","SIZE"]=2;opt["TEXTAREA","COLS"]=2;
opt["TEXTAREA","NAME"]=2;opt["TEXTAREA","ROWS"]=2;opt["UL","COMPACT"]=1;
#
#These elements -- and also <LI> in MENU or DIR -- can only contain low-level
#markup:
#
text["DT"]=1;text["H1"]=1;text["H2"]=1;text["H3"]=1;text["H4"]=1;text["H5"]=1;
text["H6"]=1;text["PRE"]=1;
#
#These low-level markup elements can only contain other low-level mark-up;
#also, give whitespace warning after <x> and before </x>.  Special coding
#to allow headings in <A> and <HR> in <PRE>.
#
lowlv["A"]=1;lowlv["B"]=1;lowlv["CITE"]=1;lowlv["CODE"]=1;lowlv["DFN"]=1;
lowlv["EM"]=1;lowlv["I"]=1;lowlv["KBD"]=1;lowlv["S"]=1;lowlv["SAMP"]=1;
lowlv["STRIKE"]=1;lowlv["STRONG"]=1;lowlv["TT"]=1;lowlv["U"]=1;lowlv["VAR"]=1;
#
#Non-pairing low-level markup tags:
#
lwlvunp["BR"]=1;lwlvunp["IMG"]=1;
#
#Pairing but non-self-nesting tags -- i.e. one occurrence of <x>...</x> can
#never occur inside another occurrence of <x>...</x>, no matter how many
#intervening levels of embedding.  I'm actually stricter than the standard
#here, since such self-nesting is almost certain to be by mistake, and this
#is a powerful error-detecting technique.
#
nonnest["A"]=1;nonnest["ADDRESS"]=1;nonnest["B"]=1;nonnest["CITE"]=1;
nonnest["CODE"]=1;nonnest["DFN"]=1;nonnest["DIR"]=1;nonnest["EM"]=1;
nonnest["FORM"]=1;nonnest["H1"]=1;nonnest["H2"]=1;nonnest["H3"]=1;
nonnest["H4"]=1;nonnest["H5"]=1;nonnest["H6"]=1;nonnest["HTML"]=1;
nonnest["I"]=1;nonnest["KBD"]=1;nonnest["LISTING"]=1;nonnest["MENU"]=1;
nonnest["PRE"]=1;nonnest["S"]=1;nonnest["SAMP"]=1;nonnest["SELECT"]=1;
nonnest["STRIKE"]=1;nonnest["STRONG"]=1;nonnest["TEXTAREA"]=1;
nonnest["TITLE"]=1;nonnest["TT"]=1;nonnest["U"]=1;nonnest["VAR"]=1;
nonnest["XMP"]=1;
#
#nonnest["BODY"]=1;nonnest["HEAD"]=1; #Separate checks for these
#Document-enclosing tag:
html["HTML"]=1}
function startit() {
 xxllm="(which should only include low-level markup)";
 initscalrs();
#Configuration file
 if (configfile)
   {readit=0;
    while ((status=(getline configline < configfile))==1)
         {readit=1;gsub(/[ \t]*/,"",configline);x=split(configline,cfgarr,"=");
          if (x==2) {setoption(cfgarr[1],cfgarr[2])}
            else {if (x>2) {print "Invalid line in config file:",configline}}};
    if ((status==-1)||(readit==0))
      {print "Error opening configuration file!";err=1;exit(1)}}
#
# HTML 3.0 extensions according to Arena document:
#
#idlgc["TAG"]=1 means that "ID", "LANG", and "CHARSET" and "STYLE" are
# allowed options.
#
 if (((arena)||(html3)||(htmlplus))&&(!((html3=="off")||(htmlplus=="off")||(arena=="off"))))
   {pair["ABBREV"]=1;pair["ABOVE"]=1;pair["ACRONYM"]=1;pair["ARRAY"]=1;
    pair["AU"]=1;pair["BELOW"]=1;pair["BIG"]=1;pair["BOX"]=1;pair["BQ"]=1;
    pair["CAPTION"]=1;pair["DFN"]=1;pair["FIG"]=1;pair["LANG"]=1;
    pair["MATH"]=1;pair["NOTE"]=1;pair["PERSON"]=1;pair["Q"]=1;
    pair["ROOT"]=1;pair["S"]=1;pair["SMALL"]=1;pair["SUB"]=1;pair["SUP"]=1;
    pair["TABLE"]=1;pair["U"]=1;unpair["ATOP"]=1;unpair["LEFT"]=1;
    unpair["OVER"]=1;unpair["OVERLAY"]=1;unpair["RIGHT"]=1;unpair["TAB"]=1;
    canpair["AROW"]=1;canpair["ITEM"]=1;canpair["LH"]=1;canpair["TD"]=1;
    canpair["TH"]=1;canpair["TR"]=1;lowlv["ABBREV"]=1;lowlv["ACRONYM"]=1;
    lowlv["AU"]=1;lowlv["BIG"]=1;lowlv["LANG"]=1;lowlv["PERSON"]=1;
    lowlv["Q"]=1;lowlv["SMALL"]=1;lowlv["SUB"]=1;lowlv["SUP"]=1;
    lwlvunp["TAB"]=1;text["LH"]=1;text["CAPTION"]=1;opt["A","BASE"]=2;
    opt["A","PRINT"]=2;opt["A","SHAPE"]=2;opt["A","TEXTSEARCH,"]=2;
    opt["A","TO"]=2;opt["ABOVE","SYMBOL"]=2;opt["ARRAY","COLDEF"]=2;
    opt["ARRAY","DELIM"]=2;opt["ARRAY","LABELS"]=1;opt["BASE","BASE"]=2;
    opt["BELOW","SYMBOL"]=2;opt["BODY","POSITION"]=2;opt["BOX","DELIM"]=2;
    opt["BOX","SIZE"]=2;opt["BR","ALIGN"]=2;opt["CAPTION","ALIGN"]=2;
    opt["FIG","ALIGN"]=2;opt["FIG","BASE"]=2;opt["FIG","HEIGHT"]=2;
    opt["FIG","HSPACE"]=2;opt["FIG","ISMAP"]=1;opt["FIG","SRC"]=2;
    opt["FIG","URN"]=2;opt["FIG","VSPACE"]=2;opt["FIG","WIDTH"]=2;
    opt["H1","ALIGN"]=2;opt["H1","NOFOLD"]=1;opt["H1","NOWRAP"]=1;
    opt["H2","ALIGN"]=2;opt["H2","NOFOLD"]=1;opt["H2","NOWRAP"]=1;
    opt["H3","ALIGN"]=2;opt["H3","NOFOLD"]=1;opt["H3","NOWRAP"]=1;
    opt["H4","ALIGN"]=2;opt["H4","NOFOLD"]=1;opt["H4","NOWRAP"]=1;
    opt["H5","ALIGN"]=2;opt["H5","NOFOLD"]=1;opt["H5","NOWRAP"]=1;
    opt["H6","ALIGN"]=2;opt["H6","NOFOLD"]=1;opt["H6","NOWRAP"]=1;
    opt["HR","ALIGN"]=2;opt["HR","BASE"]=2;opt["HR","SRC"]=2;
    opt["HR","URN"]=2;opt["HR","WIDTH"]=2;opt["IMG","BASE"]=2;
    opt["IMG","HEIGHT"]=2;opt["IMG","URN"]=2;opt["IMG","WIDTH"]=2;
    opt["INPUT","BASE"]=2;opt["INPUT","BUT"]=2;opt["INPUT","URN"]=2;
    opt["ISINDEX","HREF"]=2;opt["ISINDEX","PROMPT"]=2;opt["ITEM","ALIGN"]=2;
    opt["ITEM","COLSPAN"]=2;opt["ITEM","ROWSPAN"]=2;opt["LI","BASE"]=2;
    opt["LI","BULLET"]=2;opt["LI","LABEL"]=2;opt["LI","SKIP"]=2;
    opt["LI","URN"]=2;opt["LINK","TEXTSEARCH,"]=2;opt["LINK","TO"]=2;
    opt["MATH","ID"]=2;opt["MATH","MODEL"]=2;opt["NOTE","BASE"]=2;
    opt["NOTE","ROLE"]=2;opt["NOTE","SRC"]=2;opt["NOTE","URN"]=2;
    opt["OL","CONTINUE"]=1;opt["OL","INHERIT"]=1;opt["OL","START"]=2;
    opt["OL","TYPE"]=2;opt["OPTION","SHAPE"]=2;opt["OVER","SYMBOL"]=2;
    opt["OVERLAY","BASE"]=2;opt["OVERLAY","HEIGHT"]=2;opt["OVERLAY","SEQ"]=2;
    opt["OVERLAY","SRC"]=2;opt["OVERLAY","UNITS"]=2;opt["OVERLAY","URN"]=2;
    opt["OVERLAY","WIDTH"]=2;opt["OVERLAY","X"]=2;opt["OVERLAY","Y"]=2;
    opt["P","ALIGN"]=2;opt["P","NOFOLD"]=1;opt["P","NOWRAP"]=1;
    opt["ROOT","ROOT"]=2;opt["SELECT","BASE"]=2;opt["SELECT","SRC"]=2;
    opt["SELECT","URN"]=2;opt["SUB","ALIGN"]=2;opt["SUP","ALIGN"]=2;
    opt["TAB","AFTER"]=2;opt["TAB","BEFORE"]=2;opt["TAB","ID"]=2;
    opt["TAB","RIGHT"]=1;opt["TAB","TO"]=2;opt["TABLE","BORDER"]=1;
    opt["TD","ALIGN"]=2;opt["TD","COLSPAN"]=2;opt["TD","NOWRAP"]=1;
    opt["TD","ROWSPAN"]=2;opt["TD","VALIGN"]=2;opt["TD","WIDTH"]=2;
    opt["TH","ALIGN"]=2;opt["TH","COLSPAN"]=2;opt["TH","NOWRAP"]=1;
    opt["TH","ROWSPAN"]=2;opt["TH","VALIGN"]=2;opt["TH","WIDTH"]=2;
    opt["TR","ID"]=2;opt["UL","BASE"]=2;opt["UL","BULLET"]=2;
    opt["UL","PLAIN"]=1;opt["UL","TYPE"]=2;opt["UL","URN"]=2;
    opt["UL","WRAP"]=2;rqopt["ARRAY"]="COLDEF";rqopt["FIG"]="SRC";
    rqopt["NOTE"]="SRC";rqopt["OVERLAY"]="SRC";idlgc["U"]=1;idlgc["S"]=1;
    idlgc["TT"]=1;idlgc["B"]=1;idlgc["I"]=1;idlgc["BIG"]=1;idlgc["SMALL"]=1;
    idlgc["EM"]=1;idlgc["STRONG"]=1;idlgc["CODE"]=1;idlgc["SAMP"]=1;
    idlgc["KBD"]=1;idlgc["VAR"]=1;idlgc["CITE"]=1;idlgc["Q"]=1;
    idlgc["LANG"]=1;idlgc["AU"]=1;idlgc["DFN"]=1;idlgc["PERSON"]=1;
    idlgc["ACRONYM"]=1;idlgc["ABBREV"]=1;idlgc["SUB"]=1;idlgc["SUP"]=1;
    idlgc["BR"]=1;idlgc["A"]=1;idlgc["IMG"]=1;idlgc["P"]=1;idlgc["H1"]=1;
    idlgc["H2"]=1;idlgc["H3"]=1;idlgc["H4"]=1;idlgc["H5"]=1;idlgc["H6"]=1;
    idlgc["PRE"]=1;idlgc["DL"]=1;idlgc["DT"]=1;idlgc["DD"]=1;idlgc["OL"]=1;
    idlgc["UL"]=1;idlgc["LH"]=1;idlgc["LI"]=1;idlgc["BODY"]=1;
    idlgc["BLOCKQUOTE"]=1;idlgc["BQ"]=1;idlgc["ADDRESS"]=1;idlgc["INPUT"]=1;
    idlgc["SELECT"]=1;idlgc["OPTION"]=1;idlgc["TEXTAREA"]=1;
    idlgc["CAPTION"]=1;idlgc["TABLE"]=1;idlgc["TH"]=1;idlgc["TD"]=1;
    idlgc["FIG"]=1;idlgc["NOTE"]=1;txtf["BR"]=1;txtf["P"]=1;txtf["HR"]=1;
    txtf["H1"]=1;txtf["H2"]=1;txtf["H3"]=1;txtf["H4"]=1;txtf["H5"]=1;
    txtf["H6"]=1;txtf["PRE"]=1;txtf["DL"]=1;txtf["DT"]=1;txtf["DD"]=1;
    txtf["OL"]=1;txtf["UL"]=1;txtf["LI"]=1;txtf["BLOCKQUOTE"]=1;
    txtf["BQ"]=1;txtf["ADDRESS"]=1;txtf["TABLE"]=1;txtf["FIG"]=1;
    txtf["NOTE"]=1;inidlgc["ID"]=1;inidlgc["LANG"]=1;inidlgc["CHARSET"]=1;
    inidlgc["STYLE"]=1;intxtf["CLEAR"]=1;intxtf["NEED"]=1;intxtf["UNITS"]=1;
    html["HTMLPLUS"]=1;deprec["HTMLPLUS"]=1;deprec["DIR"]=1;deprec["MENU"]=1;
    deprec["NEXTID"]=1;for (x in nonstd) {delete nonstd[x]}};
#
#Netscape extensions (I go strictly by the documentation, so no BLINK):
#
 if ((netscape)&&(netscape!="off"))
   {pair["CENTER"]=1;pair["NOBR"]=1;canpair["FONT"]=1;unpair["BASEFONT"]=1;
    unpair["WBR"]=1;opt["ISINDEX","PROMPT"]=1;opt["HR","SIZE"]=2;
    opt["HR","WIDTH"]=2;opt["HR","ALIGN"]=2;opt["HR","NOSHADE"]=1;
    opt["UL","TYPE"]=2;opt["OL","TYPE"]=2;opt["OL","START"]=2;
    opt["LI","TYPE"]=2;opt["LI","VALUE"]=2;opt["IMG","WIDTH"]=2;
    opt["IMG","HEIGHT"]=2;opt["IMG","BORDER"]=2;opt["IMG","VSPACE"]=2;
    opt["IMG","HSPACE"]=2;opt["BR","CLEAR"]=2;opt["FONT","SIZE"]=2;
    opt["BASEFONT","SIZE"]=2;lwlvunp["WBR"]=1;lowlv["NOBR"]=1};
#
 if (nonrecurpair) {setoption("nonrecurpair",nonrecurpair)};
 if (strictpair) {setoption("strictpair",strictpair)};
 if (loosepair) {setoption("loosepair",loosepair)};
 if (nonpair) {setoption("nonpair",nonpair)};
 if (nonblock) {setoption("nonblock",nonblock)};
 if (lowlevelpair) {setoption("lowlevelpair",lowlevelpair)};
 if (lowlevelnonpair) {setoption("lowlevelnonpair",lowlevelnonpair)};
 if (deprecated) {setoption("deprecated",deprecated)};
 if (tagopts) {setoption("tagopts",tagopts)};
 if (reqopts) {setoption("reqopts",reqopts)};
 if (refsfile)
   {currf[1]=(refsfile ".SRC");currf[2]=(refsfile ".NAME");
    currf[3]=(refsfile ".HREF");
    if (append)
      {for (i=1;i<=3;++i) {print "" >> currf[i]}}
     else {for (i=1;i<=3;++i) {print "" > currf[i]}}};
 for (x in unpair) {if (x in pair)
{print "Internal logical inconsistency:",x,"defined as both pairing and non-pairing tag";
                       err=1;exit(1)}}}
#
# Main
#
{if (FNR==1) {if (NR!=1) {endit();
                          print "\n========================================\n"}
                else {startit()};
              fn=FILENAME;
              # Next line is Unix-specific
              sub(/^\.\//,"",fn);
              nampref=(dirprefix fn "\043");lochpref=(dirprefix fn);
              if (fn~/.\//) {fromroot=fn;sub(/\/[^\057]*$/,"/",fromroot)}
               else {fromroot=""};fromroot=(dirprefix fromroot);
              if (fn!="-") {print "Diagnostics for file \042" fn "\042:"}};
 if (sugar) {s=(fn ": " FNR ": ")};
 lastbeg=0;currsrch=1;txtbeg=1;
 while (match(substr($0,currsrch),/[<>]/)!=0)
      {currsrch=(currsrch+RSTART);
       if (substr($0,(currsrch-1),1)=="<")
         {if (state) {print s "Multiple `<' without `>' ERROR!",crl()}
          else {if ((currsrch>length($0))||(substr($0,currsrch,1)~/^[ \t]$/))
{print s "Whitespace after `<': Incorrect SGML syntax ERROR!",crl() ",Ignoring";
             wastext=1}
          else {if (!wastext)
                 {if (substr($0,txtbeg,(currsrch-(txtbeg+1)))!~/^[ \t]*$/)
                    {wastext=1}};
               if (wastext)
                {headbody=hedbodarr[hedbodvar];
if ((!bodywarn)&&(!headbody)&&((!nestvar)||(nestarr[nestvar]=="HTML")))
{print s "Was non-whitespace outside <body>...</body> Warning!",crl();
                    bodywarn=1}
                  else {if ((headbody=="HEAD")&&(nestarr[nestvar]=="HEAD"))
{print s "Was non-whitespace in <head>...</head> outside any element ERROR!",crl()}}};
               if ((currsrch==2)||(substr($0,(currsrch-2),1)~/^[ \t]$/))
                 {prews=1};
               lastbeg=currsrch;state=1;prevtag=lasttag;lasttag="";lastopt=""}}}
        else {if (substr($0,(currsrch-1),1)==">")
                {if (state==0)
                   {print s "`>' without `<' ERROR!",crl()}
                  else {parsetag(currsrch-1);
                        if ((inquote)||(inequal)) {malft()};
                        if (optfree) {misstest()};
                        if ((lasttag=="!--")&&(lastcomt!="--"))
{print s "!-- comment not terminated by \042--\042 ERROR!",crl()};
                        if ((lasttag=="IMG")&&(alt==0))
{print s "IMG tag without ALT option Warning!",crl();++wasnoalt};
                        if ((lasttag=="LINK")&&(linkone==1)&&(linktwo==1))
                          {++linkrmhm};
                        if ((lasttag=="A")&&(!wasname)&&(!washref))
{print s "<A> tag occurred without reference (NAME,HREF,ID) option ERROR!",crl()};
                        if ((lasttag in rqopt)&&(!rqsatis))
{print s "<" lasttag "> tag occurred without",rqopt[lasttag],"option ERROR!",crl()};
                        if ((wasname>1)||(washref>1))
{print s "Multiple reference (NAME,ID;HREF,SRC,BULLET) options ERROR!",crl(),"on tag",lasttag};
                        if ((!wastext)&&(lasttag==("/" prevtag)))
{print s "Empty <X>...</X> element Warning!",crl(),"on tag",lasttag};
if ((lasttag in lowlv)&&((currsrch>length($0))||(substr($0,currsrch,1)~/^[ \t]$/))&&(!nowswarn))
{print s "Whitespace after `>' of low-level markup opening tag Warning!",crl(),"on tag",lasttag;
                           ++wswarn};
                        wastext=0;txtbeg=currsrch;prews=0;
                        state=0;continuation=0}}
               else {print s "Internal error",crl(),"ignore"}}};
 if ((state==1)||((lastbeg==0)&&(continuation==1)))
   {parsetag(length($0)+1);continuation=1}
  else {if ((!state)&&($0!~/^[ \t]*$/)&&($0!~/>[ \t]*$/))
          {wastext=1}};
 if ($0~/&/)            # Don't actually check against the list of &xxx; codes.
   {gsub(/&[A-Za-z][A-Za-z]*[0-9]*;/,"");gsub(/&\043[0-9][0-9]*;/,"");
    if ($0~/&/)
      {print s "Apparent non-complying ampersand code ERROR!",crl()}}}
#
#
# parsetag() communicates with main() through these global variables:
# - lastbeg (zero if no `<' ocurred on line, otherwise points to character
#   immediately after the last `<' encountered).
# - state (one if unresolved `<', zero otherwise).
# - continuation (one if unresolved `<' from previous line, zero otherwise),
# - inquote (one if inside option quotes <tag opt="....">).
#
function parsetag(inp) {
 if (!lastbeg) {lastbeg=1};
 numf=split(substr($0,lastbeg,(inp-lastbeg)),arr);
 if (numf==0)
   {if (!continuation)
      {print s "Blank <> ERROR!",crl();state=0};
    return}
  else {if (!continuation)
          {arr[1]=upcase(arr[1]);if (arr[1]~/^!--/) {raw=arr[1];arr[1]="!--"}
                                   else {raw=""};
           if (arr[1]~/[=\042]/)
             {print s "Bad tag name ERROR!",crl(),"on tag",arr[1]};
           lasttag=arr[1];alt=0;
           if (arr[1]~/^\//)                                      # </TAG> found
             {sub(/^\//,"",arr[1]);
              if ((prews)&&(arr[1] in lowlv)&&(!nowswarn))
{print s "Whitespace before `<' of low-level markup closing tag Warning!",crl(),"on tag",lasttag;
                 ++wswarn};
              if (arr[1] in unpair)
{print s "Closing tag on empty element (non-pairing tag) ERROR!",crl(),"on tag /" arr[1]}
               else {if ((arr[1] in pair)||(arr[1] in canpair))
                       {if ((nestvar<=0)||(lev[arr[1]]<=0))
{print s "Extraneous /" arr[1],"tag without preceding",arr[1],"tag ERROR!",crl() ", Ignoring"}
                         else {if (nestarr[nestvar]!=arr[1])
                                 {if ((nestvar>2)&&(nestarr[(nestvar-2)]==arr[1]))
{if ((nestarr[nestvar] in canpair)&&((nestarr[(nestvar-1)]=="LI")||(nestarr[(nestvar-1)]~/^D[TD]$/)))
                                       {--lev[nestarr[nestvar]];--nestvar}};
                                  if ((nestvar>1)&&(nestarr[(nestvar-1)]==arr[1]))
                                    {if (!(nestarr[nestvar] in canpair))
                                     # Implicit end of optionally-pairing element
{print s "Missing /" nestarr[nestvar],"tag (should be located before /" arr[1],"tag) ERROR!",crl()};
                                     --lev[nestarr[nestvar]];
                                     --nestvar;--lev[arr[1]]}
                                   else
{print s "Improper nesting ERROR!",crl() ": /" nestarr[nestvar],"expected, /" arr[1],"found";
                                         --lev[arr[1]]}}
                                else {--lev[arr[1]]};
                               if ((nestarr[nestvar] in list)&&(!isli[nestvar]))
{print s "Empty list (without <LI>) ERROR!",crl(),"on tag /" arr[1]};
                               if ((nestarr[nestvar]=="DL")&&(!isdtdd[nestvar]))
{print s "Empty DL list (without <dt>/<dd>) ERROR!",crl()};
                               --nestvar}}
                     else {revusarr[arr[1]]=1;
                           if ((!lev[arr[1]])||(lev[arr[1]]<=0))
{print s "Extraneous closing tag </X> ERROR!",crl(),"on unknown tag /" arr[1]}
                            else {--lev[arr[1]]}}};
              if (arr[1]=="HEAD")
                {if (title==0)
                   {print s "No <TITLE> in <head>...</head> ERROR!",crl()};
                 base=0;title=0;--hedbodvar};
              if (arr[1]=="BODY")
                {if (headone==0)
                   {print s "No <H1> in <body>...</body> Warning!",crl()};
                 headone=0;bodywarn=0;--hedbodvar};
              if ((arr[1] in list)||(arr[1] in nonlilist))
                 {--listdep}}
            else
                 {if (arr[1] in html) {++lev["HTML"]}              # <TAG> found
                   else {++lev[arr[1]]};
                  if ((arr[1] in pair)||(arr[1] in canpair)||(arr[1] in unpair))
                    {known=1}
                   else {known=0};
                  if (!((arr[1] in lowlv)||(arr[1] in lwlvunp)))
                    {curnest="";
if ((nestvar>1)&&(arr[1]!="LI")&&(nestarr[nestvar]=="LI")&&(nestarr[(nestvar-1)] in lowlvlist))
                       {curnest=("LI in " nestarr[(nestvar-1)])}
                      else
{if ((nestarr[nestvar] in text)||(nestarr[nestvar] in lowlv))
{if ((arr[1]~/^H[1-6]$/)&&(nestarr[nestvar]=="A"))
{print s arr[1],"heading in <A>...</A> element Warning!",crl()}
                          else
{if ((arr[1]!=nestarr[nestvar])&&(!((arr[1]=="HR")&&(nestarr[nestvar]=="PRE"))))
                                  {curnest=nestarr[nestvar]}}}};
                     if (curnest)
                       {if (known)
                          {if (!((arr[1]=="DD")&&(nestarr[nestvar]=="DT")))
{print s arr[1],"tag, which is not low-level markup, nested in",curnest,"element ERROR!",crl()}}
                         else
{print s "Unknown tag",arr[1],"nested in",curnest, "element",xxllm,"Warning!",crl()}}};
                  if ((arr[1] in formonly)&&(nestarr[nestvar]!="FORM"))
{print s "<" arr[1] "> outside of <form>...</form> ERROR!",crl()};
if ((arr[1]=="OPTION")&&(nestarr[nestvar]!="SELECT")&&(nestarr[nestvar]!="OPTION"))
{print s "<" arr[1] "> outside of <select>...</select> ERROR!",crl()};
                  if (nestarr[nestvar] in list)
                    {if (wastext)
{print s "Non-whitespace outside <LI> in list ERROR!",crl(),"on tag",arr[1]};
                     if ((arr[1]!="LI")&&(arr[1]!="LH"))
{print s "Tag in list occurred outside <LI> ERROR!",crl(),"on tag",arr[1]}};
                  if (nestarr[nestvar]=="DL")
                    {if (wastext)
{print s "Non-whitespace outside <dt>/<dd> in <dl> list ERROR!",crl(),"on tag",arr[1]};
                     if ((arr[1]!~/^D[DT]$/)&&(arr[1]!="LH"))
{print s "Tag in <dl> list occurred outside <dt>/<dd> ERROR!",crl(),"on tag",arr[1]}};
                  headbody="";implicit=0;
                  if ((arr[1] in pair)||(arr[1] in canpair))
                    {if ((arr[1]=="HEAD")||(arr[1]=="BODY"))
                       {if ((!("HTML" in lev))||(lev["HTML"]==0))
{print s "HEAD or BODY outside of <HTML>...</HTML> Warning!",crl()};
                        if (hedbodvar>0)
                          {if ((hedbodarr[hedbodvar]=="HEAD")&&(arr[1]=="BODY"))
                             {hedbodarr[hedbodvar]=arr[1];--lev["HEAD"];
print s "Assumed an implicit `</HEAD>' before <BODY> Warning!",crl();
                              if ((nestarr[nestvar]!="HEAD")&&(nestarr[nestvar]in pair))
{print s "Improper nesting on implicit </HEAD> ERROR!",crl() ", tag /" nestarr[nestvar],"expected"};
                              nestarr[nestvar]=arr[1];implicit=1;
                              if (title==0)
{print s "No <TITLE> in <head>...</head> ERROR!",crl()}}
                           else
{print s "HEAD or BODY nested inside HEAD or BODY element ERROR!",crl()}}
                         else {if ((nestvar>0)&&(nestarr[nestvar]!="HTML"))
{print s "HEAD or BODY contained inside non-HTML element ERROR!",crl()}};
                        hbwarn=0;base=0;title=0;headone=0;
                        if (!implicit) {++hedbodvar;
                                        hedbodarr[hedbodvar]=arr[1]}};
                     if (!implicit)
{if ((!(nestarr[nestvar] in canpair))||(!(arr[1] in canpair)))
                          {++nestvar}
                         else
{if (((nestarr[nestvar]=="LI")&&(arr[1]!="LI"))||((nestarr[nestvar]~/^D[TD]$/)&&(arr[1]!~/^D[TD]$/)))
                                 {++nestvar}
                                else
{if ((nestvar>2)&&((nestarr[(nestvar-1)]=="LI")||(nestarr[(nestvar-1)]~/^D[TD]$/)))
{if (((nestarr[nestvar]!="LI")&&(arr[1]=="LI"))||((nestarr[nestvar]!~/^D[TD]$/)&&(arr[1]~/^D[TD]$/)))
                                    {--nestvar}}}};
                       if (arr[1] in html) {nestarr[nestvar]="HTML"}
                        else {nestarr[nestvar]=arr[1]}};
                     isli[nestvar]=0;isdtdd[nestvar]=0;isdt[nestvar]=0};
                  if (hedbodvar) {headbody=hedbodarr[hedbodvar]};
                  if ((arr[1] in list)||(arr[1] in nonlilist))
                    {++listdep;if (listdep>maxlist) {maxlist=listdep}};
                  if (arr[1]=="LI")
                    {isli[(nestvar-1)]=1;
                     if ((nestvar<2)||(!(nestarr[(nestvar-1)] in list)))
                       {print s "<LI> outside of list ERROR!",crl()}};
                  if (arr[1]~/^D[DT]$/)
                    {isdtdd[(nestvar-1)]=1;
                     if ((nestvar<2)||(nestarr[(nestvar-1)]!="DL"))
{print s "<dt>/<dd> outside of <dl> list ERROR!",crl(),"on tag",arr[1]}
                      else {if (arr[1]=="DT")
                              {isdt[(nestvar-1)]=1}
                             else {if (!isdt[(nestvar-1)])
                                     {isdt[nestvar-1]=1;#Reduce repeat errormsgs
print s "<DD> without preceding <DT> in <DL> list Warning!",crl()}}}};
                  if (!headbody)
{if ((lasttag!="!--")&&(lasttag!="!DOCTYPE")&&(!(lasttag in html))&&(!hbwarn))
{print s "Tag outside of HEAD or BODY element Warning!",crl(),"on tag",arr[1];
                     hbwarn=1}}
                   else {if (arr[1]=="PLAINTEXT")
{print s "<PLAINTEXT> in <head>...</head> or <body>...</body> ERROR!",crl()}};
                  if (headbody=="HEAD")
                    {if (!((arr[1] in inhead)||(arr[1] in headonly)))
{print s "Disallowed tag in <head>...</head> ERROR!",crl(),"on tag",arr[1]};
                     if (arr[1]=="TITLE")
                       {++title;
                        if (title>1)
{print s "Multiple <TITLE> tags in <head> ERROR!",crl()}}
                     if (arr[1]=="BASE")
                       {++base;
                        if (base>1)
{print s "Multiple <BASE> tags in <head> Warning!",crl()}}};
                  if (headbody=="BODY")
                    {if (arr[1] in headonly)
{print s "Disallowed tag in <body>...</body> ERROR!",crl(),"on tag",arr[1]}};
                  if (arr[1]~/^H[1-6]$/)
                    {newheadlev=substr(arr[1],2,1);
                     if (newheadlev>(headlevel+1))
{print s "Warning! Jump from header level H" headlevel, "to level H" newheadlev,crl()};
                     headlevel=newheadlev;
                     if (headlevel==1)
                       {++headone;
                        if (headone>1)
                          {print s "Multiple <H1> headings Warning!",crl()}}};
                  if ((arr[1]=="!DOCTYPE")&&(nestvar))
{print s "<!DOCTYPE...> enclosed within <x>...</x> ERROR!",crl()};
                  if (arr[1] in html) {if (nestvar>1)
{print s "<HTML> enclosed within <x>...</x> ERROR!",crl()};
                                       bodywarn=0;hbwarn=0;headone=0};
                  if ((arr[1] in nonnest)&&(lev[arr[1]]>1))
{print s "Self-nesting of unselfnestable tag ERROR!",crl() ", of level",lev[arr[1]],"on tag",arr[1]}};
           if (arr[1] in html) {usarr["HTML"]=1}
            else {usarr[arr[1]]=1};
           startf=2;inquote=0;inequal=0;optfree=0;wasopt=0;linkone=0;linktwo=0;
           rqsatis=0;wasname=0;washref=0}
         else {startf=1};
        if (lasttag!~/^!/)          # Remainder of stuff in <...> after tag word
          {for (i=startf;i<=numf;++i)
              {if ((!inequal)&&(!inquote))
{if ((arr[i]~/^[^=\042]*(=\042[^\042]*\042)?$/)||(arr[i]~/^[^=\042]*=(\042)?[^\042]*$/))
{if ((optfree)&&((arr[i]~/^=[^=\042][^=\042]*$/)||(arr[i]~/^=\042[^\042]*\042$/)))
                      {if (!malftag) {sub(/^\075/,"",arr[i]);
                                      if (arr[i]~/\042/)
                                        {optvalproc(arr[i],1)}
                                       else {optvalproc(arr[i],0)}};
                       optfree=0;++tagwarn}
else {if ((optfree)&&((arr[i]~/^=\042/)||(arr[i]=="="))) {inequal=1;++tagwarn};
                           split(arr[i],arr2,"=");
                           if (arr2[1]=="")
                             {if (!inequal)
{print s "Null tag option ERROR!",crl(),"on tag",lasttag;malftag=1}}
                            else {if (optfree) {misstest()};
                                  arr2[1]=upcase(arr2[1]);optfree=1;++wasopt;
                                  malftag=0;optvalstr="";
                                  if (lasttag~/^\//)
{print s "Option on closing tag",lasttag,"Warning!",crl()}
                                   else {optarr[lasttag,arr2[1]]=1;
                                         lastopt=arr2[1];
if ((lasttag in rqopt)&&(arr2[1]==rqopt[lasttag]))
                                         {rqsatis=1};
                                   if ((known)&&(!((lasttag,lastopt) in opt)))
{if (!(((lasttag in idlgc)&&(lastopt in inidlgc))||((lasttag in txtf)&&(lastopt in intxtf))))
{print s lastopt,"not recognized as an option for",lasttag,"tag Warning!",crl()}};
                                         if ((lasttag=="IMG")&&(arr2[1]=="ALT"))
                                           {alt=1}}};
                           if (arr[i]~/^[^=\042][^=\042]*=$/)
                             {inequal=1;++tagwarn};
                           if (arr[i]~/[\075]/) {optvalstr=arr[i];
                                                  gsub(/^[^=]*=/,"",optvalstr)};
                           q=gsub(/\042/,"",arr[i])
                           if (q==1)
                             {inquote=1};
                           if ((optvalstr)&&(!inequal)&&(!inquote))
                             {optfree=0;
                              if (!malftag) {optvalproc(optvalstr,q)}}}}
                         else {malft()}}
                else {if ((inequal)&&(!inquote))
                        {++tagwarn;
                         if (arr[i]~/\042/)
                           {if (arr[i]~/^\042[^\042]*(\042)?$/)
                              {if (gsub(/\042/,"",arr[i])==2)
                                 {if (!malftag) {sub(/^\075/,"",arr[i]);
                                                 optvalproc(arr[i],1)};
                                  inequal=0;optfree=0}
                               else {optvalstr=arr[i];inquote=1}}
                             else {malft()}}
                          else {if (arr[i]!~/\075/)
                                  {if (!malftag) {optvalproc(arr[i],0)};
                                   inequal=0;optfree=0}
                                 else {malft()}}}
                       else {if (arr[i]~/\042/)
                               {inquote=0;inequal=0;optfree=0;
                                if (arr[i]!~/^[^\042]*\042$/)
                                  {malft()}
                                 else {optvalstr=(optvalstr " " arr[i]);
                                       if (!malftag) {optvalproc(optvalstr,1)}}}
                        else {optvalstr=(optvalstr " " arr[i])}}}}}
         else {if (lasttag=="!--")
                 {if ((numf==1)&&(!continuation)) {sub(/!--/,"",raw);
                                                   arr[1]=raw};
                    if (arr[numf]~/--$/)
                      {lastcomt="--"}
                     else {lastcomt=""}}};
        return}}
#
#
# Return as much location information as possible in diagnostics:
#
# Current location:
function crl() {if ((fn)&&(fn!="-"))
                      {return ("at line " FNR " of file \042" fn "\042")}
                     else {return ("at line " NR)}}
# End of file location:
function ndl() {if ((fn)&&(fn!="-"))
                     {return ("at END of file \042" fn "\042")}
                    else {return "at END"}}
#
#
# Error message returned from numerous places in the program...
#
function malft()
{print s "Malformed tag option ERROR!",crl(),"on tag",lasttag;malftag=1}
#
#
#Check for non-kosher null options:
#
function misstest()
{if (((lasttag=="A")&&(lastopt=="NAME"))||(lastopt=="HREF")||(lastopt=="ID"))
{print s "Missing reference option value",crl(),"on tag",lasttag ", option",lastopt}
   else
{if (opt[lasttag,lastopt]==2)
{print s "Missing option value",crl(),"on tag",lasttag ", option",lastopt}
           else
{if (((lasttag in idlgc)&&(lastopt in inidlgc))||((lasttag in txtf)&&(lastopt in intxtf)))
{print s "Missing option value",crl(),"on tag",lasttag ", option",lastopt}}}}
#
#
#Set property arrays from command line variable or configuration file.
#
function setoption(inname,invalu,invarr) {
 #allow command line options to override config file
 if (inname=="htmlplus")
   {if (htmlplus) {return}
     else {htmlplus=invalu;return}};
 if (inname=="html3")
   {if (html3) {return}
     else {html3=invalu;return}};
 if (inname=="arena")
   {if (arena) {return}
     else {arena=invalu;return}};
 if (inname=="netscape")
   {if (netscape) {return}
     else {netscape=invalu;return}};
 if (invalu~/\075/)
   {print "Invalid syntax on",inname "= configuration option, ignoring"}
  else {if ((inname=="tagopts")||(inname=="reqopts"))
          {numf=split(invalu,invarr,":");
           for (i=1;i<=numf;++i)
              {numf2=split(invarr[i],invarr2,",")
               if (numf2!=2)
{print "Invalid syntax on",inname "= configuration option, ignoring"}
                else {if (inname=="tagopts")
                        {opt[upcase(invarr2[1]),upcase(invarr2[2])]=1}
                       else {rqopt[upcase(invarr2[1])]=upcase(invarr2[2])}}}}
         else {numf=split(invalu,invarr,",")
               for (i=1;i<=numf;++i)
                  {invarr[i]=upcase(invarr[i]);
                   if (inname=="nonrecurpair")
                     {pair[invarr[i]]=1;strictclean(invarr[i]);
                      nonnest[invarr[i]]=1}
                   else {if (inname=="strictpair")
                     {pair[invarr[i]]=1;strictclean(invarr[i]);
                      delete nonnest[invarr[i]]}
                   else {if (inname=="loosepair")
                     {if (notredef(invarr[i]))
                        {canpair[invarr[i]]=1;delete unpair[invarr[i]];
                         nonstrictclean(invarr[i])}}
                   else {if (inname=="nonpair")
                     {if (notredef(invarr[i]))
                        {unpair[invarr[i]]=1;delete canpair[invarr[i]];
                         nonstrictclean(invarr[i])}}
                   else {if (inname=="nonblock") {text[invarr[i]]=1;
                                                  delete unpair[invarr[i]]}
                   else {if (inname=="lowlevelpair") {lowlv[invarr[i]]=1;
                                                      strictclean(invarr[i])}
                   else {if (inname=="lowlevelnonpair")
                           {if (notredef(invarr[i])) {text[invarr[i]]=1;
                                                     nonstrictclean(invarr[i])}}
                   else {if (inname=="deprecated") {deprec[invarr[i]]=1}
                   else {print "Unrecognized configuration option",inname;
                         return}}}}}}}}}}}}
#
function strictclean(param) {
 delete nonstd[param];
 delete unpair[param];delete canpair[param];delete lwlvunp[param]}
#
function nonstrictclean(param) {
 delete nonstd[param];
 delete pair[param];delete nonnest[param];delete lowlv[param]}
#
#Stuff which has special hard-wired processing; don't allow user to redefine
#
function notredef(param) {
 if ((param in list)||(param in nonlilist)||(param in html)||(param=="HEAD")||(param=="BODY"))
  {return 0}
  else {return 1}}
#
#
# This subroutine receives the raw option value string, for every tag option
# that does have a value.  It does some errorchecking and cleanup, and writes
# to the .NAME, .HREF, and .SRC files when requested.
#
function optvalproc(val,quoted)
{currfn=0;if (quoted) {gsub(/\042/,"",val);sub(/^ /,"",val);sub(/ $/,"",val)};
 if (lasttag=="LINK")
   {xxx=upcase(val);
    if ((lastopt=="REV")&&(xxx~/^MADE/)) {++linkone};
    if ((lastopt=="HREF")&&(xxx~/^MAILTO:/)) {++linktwo}};
 if ((usebase)&&(lasttag=="BASE")&&(lastopt=="HREF"))
   {if ((quoted)&&(val)&&(val!="=")&&(val!~/[^ ] [^ ]/))
      {nampref=(val "\043");lochpref=val;
       if (val~/.\//) {fromroot=val;sub(/\/[^\057]*$/,"/",fromroot)}
        else {fromroot=""}}
     else {print s "Bad <BASE HREF=\042...\042>",crl() ", Ignoring"}}
  else {if (((lasttag=="A")&&(lastopt=="NAME"))||(lastopt=="ID"))
          {currfn=2;++wasname;
           if ((val)&&(val!="="))
             {if (("\043" val) in namearr)
{print s "Duplicate location \042\043" val "\042 ERROR!",crl(),"on tag",lasttag,"option",lastopt}
               else {if (val~/^\043/)
{print s "Invalid \043-initial location \042" val "\042 ERROR!",crl(),"on tag",lasttag,"option",lastopt}
                      else {namearr[("\043" val)]=1}}}}
         else {if ((lastopt=="SRC")||(lastopt=="BULLET"))
                 {currfn=1;++washref}
                else {if (lastopt=="HREF")
                    {currfn=3;++washref;
                     if (val~/^\043/)
                       {loclhrefarr[val]=1}}}}};
 if (currfn)
   {if (!quoted)
{print s "Unquoted reference option value Warning!",crl(),"on tag",lasttag ", option",lastopt};
    if (val~/[^ ] [^ ]/)
{print s "Whitespace in reference option value Warning!",crl(),"on tag",lasttag ", option",lastopt}
      else {if (val=="")
{print s "Null reference option value ERROR!",crl(),"on tag",lasttag,"option",lastopt}
             else {
                   # Skip the residue of Malformed Tag Option cases;  OK to do
                   # this, since "=" is not a valid URL;  However, a minor bug
                   # is that <A NAME="="> will not be checked, and will not
                   # result in any errormessage.
                   if ((refsfile)&&(val!="="))
                     {if (currfn==2) {val=(nampref val)}
                        else {if ((currfn==3)&&(val~/^\043/))
                                {val=(lochpref val)}
                               else {if (val~/^http:[^\057]*$/)
                                     sub(/^http:/,"",val);
                                     if ((val!~/^[^\057]*:/)&&(val!~/^\//))
                                       {if (val~/^~/)
{print s "Relative URL beginning with '~' Warning!",crl(),"on tag",lasttag,"option",lastopt}
                                        else {val=(fromroot val)}}}};
                      # This monstrosity supports "../" in URL's:
                      while (val~/\057[^\057]*[^\057]\057\.\.\057/)
                           {sub(/\057[^\057]*[^\057]\057\.\.\057/,"\057",val)};
                      if ((val~/[:\057]\.\.\057/)||(val~/^\.\.\057/))
{print s "Unresolved \042../\042 in URL Warning!",crl(),"on tag",lasttag,"option",lastopt};
                      print val > currf[currfn]}}}}
  else {if ((!quoted)&&(val!="\075")) {unqopt[(lastopt "=" upcase(val))]=1}}}
#
#
# Start each file with a clean slate.
#
function initscalrs() {
 state=0;continuation=0;nestvar=0;bodywarn=0;maxlist=0;listdep=0;headone=0;
 headlevel=0;br=0;wasnoalt=0;tagwarn=0;wswarn=0;hedbodvar=0;linkrmhm=0;
 wastext=0;prevtag="";hbwarn=0;s="";prews=0}
#
#
# Uppercasing routine; in GAWK can replace upcase() with built-in function
# toupper() for a speed boost.
#
BEGIN{
upc["a"]="A";upc["b"]="B";upc["c"]="C";upc["d"]="D";upc["e"]="E";upc["f"]="F";
upc["g"]="G";upc["h"]="H";upc["i"]="I";upc["j"]="J";upc["k"]="K";upc["l"]="L";
upc["m"]="M";upc["n"]="N";upc["o"]="O";upc["p"]="P";upc["q"]="Q";upc["r"]="R";
upc["s"]="S";upc["t"]="T";upc["u"]="U";upc["v"]="V";upc["w"]="W";upc["x"]="X";
upc["y"]="Y";upc["z"]="Z";
}
#
function upcase(upcins,k) {
 if (upcins~/[a-z]/)
   {for (k in upc) {if (upcins~k) {gsub(k,upc[k],upcins)}}};
 return upcins}
#
#
# End-of-file routine.
#
END{if ((NR>0)&&(!err)) {endit()}}
#
# File-final global errors and tag diagnostics.
#  Information is passed here through arrays:
# - usarr[x]:    The tag <x> was used.
# - revusarr[x]: The reverse tag </x> was used.
# - lev[x]:      Current degree of self-nesting of paired tag <x>...</x>.
# - optarr[x,y]: The option y was used with tag <x>.
#and also through the variables maxlist and continuation.
#
function endit() {
 if ((currf[2])&&(refsfile)) {print lochpref > currf[2]};
 if (sugar) {s=(fn ": END: ")};
 if (continuation)
   {print s "Was awaiting a `>' ERROR!",ndl()};
 if ((wastext)&&(!bodywarn))
   {print s "File-final uncontained non-whitespace Warning!",ndl()};
 for (x in usarr)
    {if ((x in pair)&&(lev[x]>0))
{print s "Pending unresolved <x> without </x> ERROR! of level",lev[x],ndl(),"on tag",x}};
if (!("HTML" in usarr)) {print s "<HTML> not used in document Warning!",ndl()};
 if (!("HEAD" in usarr)) {print s "<HEAD> not used in document Warning!",ndl()};
 if (!("BODY" in usarr)) {print s "<BODY> not used in document Warning!",ndl()};
 if (linkrmhm==0)
{print s "<LINK REV=\042made\042 HREF=\042mailto:...\042> not used in document Warning!",ndl()}
  else {if (linkrmhm>1)
{print s "<LINK REV=\042made\042 HREF=\042mailto:...\042> used",linkrmhm,"(>1) times Warning!",ndl()}};
if (!("TITLE" in usarr)) {print s "<TITLE> not used in document ERROR!",ndl()};
 if (wasnoalt)
{print s "<IMG> tags were found without ALT option",wasnoalt,"times Warning!",ndl();
print "Advice: Add ALT=\042\042 to purely decorative images, and meaningful text to others."};
 if (wswarn)
{print s "Whitespace separated low-level markup from enclosed element",wswarn,"times Warning!",ndl();
print "Advice: Change ``<X> text </X>'' syntax to preferred ``<X>text</X> syntax.''"};
 if (tagwarn)
{print "Aesthetic:`=' was separated by whitespace from tag option or value",tagwarn,"times";
print "Aesthetic: ``<X Y=\042z\042>'' syntax may be clearer than ``<X Y = \042z\042>'' syntax."};
 for (x in loclhrefarr)
    {if (!(x in namearr))
       {print s "Was a dangling file-local reference \042" x "\042 ERROR!",ndl()}};
 for (x in unqopt)
    {if (!br) {printf "\nUnquoted tag option=value pairs:";br=1};
     printf " %s",x};
 if (br) {printf "\n"};
 for (x in usarr)
    {options="";head=("^" x SUBSEP);
     for (z in optarr)
        {if (z~head)
           {split(z,optx,SUBSEP);
            options=(options " " optx[2])}};
     unknown=0;if (!br) {print "";br=1};
     printf "%s %s %s","Tag",x,"occurred";
     if (options)
       {printf "%s%s",", with options",options};
     if (!((x in pair)||(x in canpair)||(x in unpair)))
       {printf "; Warning! tag is unknown";unknown=1
        if (x!~/^[-A-Z0-9][-A-Z0-9]*$/)
          {printf "; Warning! tag is not alphanumeric"}};
     if (x in deprec)
       {printf "; Warning! tag is obsolescent and deprecated"}
      else {if (x in nonstd)
              {printf "; Warning! tag is not (yet) a part of HTML standard"}};
     if ((unknown)&&(x in revusarr)&&(lev[x]!=0))
{printf ("; Closing tag </" x "> of unknown tag " x " encountered and ");
printf ("balance of <" x "> minus </" x "> nonzero (" lev[x] ") Warning!",ndl())};
     printf "\n"};
 if (maxlist) {print "Maximum depth of list embedding was",maxlist};
#Reinitialize for next file
 initscalrs();
 for (x in         lev) {delete         lev[x]};
 for (x in       usarr) {delete       usarr[x]};
 for (x in      optarr) {delete      optarr[x]};
 for (x in      unqopt) {delete      unqopt[x]};
 for (x in     namearr) {delete     namearr[x]};
 for (x in    revusarr) {delete    revusarr[x]};
 for (x in loclhrefarr) {delete loclhrefarr[x]}}
#-=-  -=-  -=-  -=-  -=-  -=-  -=-  -=-  -=-  -=-  -=-  -=-  -=-  -=-  -=-  -=-
##EOF
