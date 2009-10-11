#!/usr/bin/perl -w

# created     GR 2007     Guide De Rosa
# last change PJ 20090615
# copyright: see below.

# unescape.pl
# Copyright (C) 2007 Guido De Rosa <guido_derosa*libero.it>
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.



# See script(1), @BUGS
# This program aims to properly handle escape character and sequences
# giving something more human-readable than typescript logs ..
# Usage: unescape.pl < typescript > typescript.out


# further information
# -> script, scriptreplay, teseq
# -> http://invisible-island.net/xterm/ctlseqs/ctlseqs.html


#pj 20090601 jakobi@acm.org
#
# hints for improved usability of typescript logs
# - to improve usability, define a easy-to-guess prompt 
# - have your shell print the command after editing/before execution
# - it helps to change the window title, as the OSC sequences
#   usually do define reasonable points to consider ending/starting 
#   a block or line-edit-simulation.
# - you need to shorten/edit/rename the transcript anyway ...

# not yet implemented
# - there should be an option to guess prompt strings and
#   add white space around them. [if PS1 is messing with
#   the window title, this already happens]
# - should we really try to outguess \r and $COLUMNS instead
#   of giving up very early and report partial line edits 
#   via line()'s $history?
# - there should be some way to mark or optionally remove stretches
#   with just mc / mutt / vi / less / more output, as currently
#   the only way to shorten the log is editing it.
#
#   In case VIM itself sets the default window title, removing
#   most of the edit sessions is as simple as mangling the
#   region start points and then deleting from each start
#   to the next OSC 2 command (which might fail if 
#   a subshell is opened within the vim session)
#   sed 's/^:   2;.*VIM.*/:A/g; /^:A/,/^:   2;/d'
#
#   vi/less/man ... session detection may also be done as catching
#   suspicious commands as the first word after prompts,
#   and ending on the next prompt (give or take suspend
#   headaches).
#
#   for friendly-territory admin usage, wrapping vi/vim with a
#   script giving out a unified diff at the end (plus a 
#   dated backups) on changes might be nice.
#   note that script isn't really suitable and complete for
#   semi-trusted foreign root admin shells... - sudo changed to
#   keep a copy of the executed script might help as long as 
#   both shells and any scripts are disallowed. hmmm. usually
#   way to painful and slow for non-trivial work.

use strict;
my $VERSION = "0.01pj";
print STDERR "$0 ver $VERSION\n\n";
my $DEBUG = 0;

sub line($);
sub history(@);
sub debug(); 



# set these for some best effort promt guessing
my $promptre='jakobi\@anuurn.*?[\$\>\#]';

my $rmvim=1; # try stripping vim sessions, it might even work sanely

my $rmmc=0;  # try stripping  mc sessions, NOT YET IMPLEMENTED
             # and the mc subshell by default doesn't chnage the
             # title. Thus above windows title trick fails just as 
             # it would for more, less or original vi.



# global variables used in functions
my(@outchars, $inptr, $outptr, $history, $lineprefix, $contprefix);
my($prefixre,$text,$p1,$p2);

# 4 char limit hardcoded in e.g. osc flagging
$lineprefix="    ";    # prefix for new lines
$contprefix=">   ";    # prefix for reporting partial line buffers
$prefixre='(?:\A|\n)[>= ]   '; # regex for skipping above



$text="";
foreach(@ARGV){s/^(\s+)/.\/$1/;s/^/< /;$_.=qq/\0/}; # MAGIC <> INSECURE MESS
while(<>) { # SECURE:OK
   $text.=line($_);
}
$_=$text;



# some global cleanup for readability
s/\x0d\x0a/\x0a/go; s/\x0d/\x0a/go; s/\x0a\x0a+/\x0a/go; # crlf
# BUG: terminals ain't lineprinters, so this probably won't be required
s/_\x08//go; s/\x08_//go;                    # backspace and _; 
while(s/[^\x0a\x08]\x08//go){;}; s/\x08//go; # backspace

# ok, this is officially weak, but this just happens to add newlines
# before the prompt in case PS1 does suitably mangle the terminal title
s/${prefixre}OSC: (.*)/\n:   $1/go;           # mark OSC
s/(\A|\n)([^:\n][^\S\n]*\S.*\n):   /$1$2\n:   /go; # and add \n before
s/(\A|\n):   (.*)\n(?!:)/$1:   $2\n\n/gi;     # and after one or more OSC



s/^    [ \t]*$//mgo;                          # shouldn't be required



# optionally try turning matches into separated paragraphs
if ($promptre) {
   # force things looking like promptre to start on a new line
   s/((?!\n    )[\s\S]{5})($promptre)/$1\n$lineprefix$2/go;
   # if missing, add an empty line in front for all prompt matches
   s/(\A|[^\n])(\n    )($promptre)/$1\n$2$3/go;
}



# optionally try stripping vim sessions from the log,
# assuming vim sets a window title until it is reset
# roughly similar to e.g. 
# sed 's/^:   2;.*VIM.*/:A/g; /^:A/,/^:   2;/d'
if ($rmvim) {
   s/^:   2;.*VIM.*/:A/mgo; # OSC 2 windows title set by vim
   while(/^:A\n/mgo) { # region start - title set by VIM
      $p1=pos; $p1-=3;
      $p2=pos if /^:   2;.*/mgo;
      if ($p2) {
         # region end: title restored/changed w/o VIM string
         substr($_,$p1,$p2-$p1)=""; # strip region
         pos=$p1;
      }
   }
}



# mc and mutt might be also be somewhat strippable with customizations
# 
# NOT YET IMPLEMENTED, similar to above; maybe generalize above to
# :A, :B, :C, ...



# BUG there are e.g. some printable ALT-GR chars removed by this...
s/[^[:print:]\s]//g; 

print;


#####################################################################33

sub debug() {
return unless ($DEBUG);
print STDERR @outchars, " inptr=$inptr outptr=$outptr\n"; #DEBUG       
}

# maintain history of partial buffer contents for current 
# readline simulation (so basically provide partial buffers
# to the user if fully simulating the terminal gets too hard
# to guess)
sub history(@) {
   my($mode)=shift @_;
   my($tmp)=join("",@_);

   if ($tmp=~/\S/o) {

      if ($history=~/\n\Z/o) {
         if ($mode eq "n") {
            $history.="\n"
         }
         $history.="$lineprefix"
      } elsif ($history) {
         if ($mode eq "c") {
            $history.="\n$contprefix"
         } else {
            $history.="\n$lineprefix"
         }
      } else {
         $history=$lineprefix
      }

      $history.=$tmp;

      if ($mode eq "n") {
         $history.="\n";
      }

   } else { # $tmp empty or WS
      if ($mode eq "n") {
         $history.="\n"
      } elsif ($mode eq "") {
         $history.="\n" if not $history=~/\n\Z/o;
      }
   }

   return($history);
}

# simulate and perform in-line editing enough for guessing
# command lines
# 
# BUGS: 
# - we ignore anything but the most common CSI single char moves used
#   by e.g. bash readline line editing for _short_ single-terminal
#   line lines)
# - mere appends to end of line are seen trigger \n and thus are
#   seen only at the next invocation of this function, i.e. we miss
#   the fact that multiple invocations might actually be part of
#   e.g. the same readline session
# - thinking of ksh editing longish lines in a single screen line
#   makes me shudder
# - we do NOT try to guess COLUMNS for computing the new $outptr
#   position on \e[A up and \r, instead we just collect and print
#   partial buffers we find upto these situations ($history).
# - should be rewritten in native perl to use pos() 
# - handle non-printables, from bell to xon ...
# - heuristic guesswork like vi ~-empty lines really shouldn't be 
#   place into line()...
# - outchars may still contain unparsed csi/osc/... sequences
#   which throw of positioning (even if those tend to be rare
#   in e.g. bash readline). So the regex to strip most csi/osc
#   should be run first, while only keeping the known good csi 
#   sequences for readline.
#
#   [An occurance of \e[A implies a line longer than $COLUMNS; 
#     considering <\e1P|\b> \e[A <string with \b,\e[C, maybe one
#     changed char and a _really_printable_ substring already 
#     part of $history.join("",@outchars)>, we might indeed be 
#     able to guess $COLUMNS.
#
#     Another way to guess $COLUMNS might be the _really_printable_
#     position of the first \r encountered.
#
#     (While bash e.g. seems to reprint strings to end of screenline,
#      it still seems to _SHIFT_ chars after that, incl. even shifting
#      chars with \e[1@<CHAR> onto the next screen line, w/o reprinting!?)]
#       
sub line($) { 
   my($inline,$inlen,$scanptr,$flag,@inchars,$tmp);
   $inline=$_[0];
   chomp $inline;

   $inline=~s/\x9b/\e\[/go;            # translate 8bit CSI control sequence introducer
   $inline=~s/\x9c/\e\\/go;            # translate 8bit ST  string terminator
   $inline=~s/\x9d/\e\]/go;            # translate 8bit OSC operating system command
   $inline=~s/\x9e/\e\^/go;            # translate 8bit PM  privacy message
   $inline=~s/\x9f/\e\_/go;            # translate 8bit APC application program command

   #$inline=~s/\e\].{0,120}?(\e\\|\a)//go;   # strip all OSC sequences until bell or ST
                                       # hopefully, there's no escaping mechanism to allow
                                       # \e occuring in an OSC sequence...
   $inline=~s/\e\](.{0,120}?)(\e\\|\a)/\nOSC: $1\n/go; # or report OSC COMMAND
   
   # strip most of stretches of empty lines with ~-mark from vim output
   $inline=~s/\e\[\d+;\d+H~ +(\e\[\d+;\d+H~ +)+//go;

   push @inchars, ( " ", " ", " " );   # add some blanks to allow for CSI length ptr moves

   $inlen=length($inline);
   @inchars = split(//,$inline); 

   $history="";
   @outchars = ();
   $outptr=0;
   for ($inptr=0;$inptr<$inlen;$inptr++) {
      if ($inchars[$inptr] eq "\n" ) {     # newline
         $outptr = 0;
         history("n",@outchars);
         @outchars=();
      } elsif ($inchars[$inptr] eq "\a") { # skip non printable alarm bell
         ;
      } elsif ($inchars[$inptr] eq "\r") { # carriage return:->beginning of line
         # strangely, when a bash line becomes multiple screen lines
         # I only see a single (useless?) \r in typescript as indicator
         $outptr = 0;
         history("c",@outchars);
         @outchars=();
      } elsif ($inchars[$inptr] eq "\b") { # backspace (with no deletion)
         $outptr--;
         $outptr = 0 if ($outptr < 0);

      } elsif ($inchars[$inptr] eq "\e") { # escape character (^[)
         $inptr++;
         if ($inchars[$inptr] eq "\\") {   # skip non-printable ST - oops?
            ;
         } elsif ($inchars[$inptr] eq "[") {
            $inptr++;
            if ($inchars[$inptr] eq "C") { # ^[[C right
               $outptr++;
               # move right but char not yet seen in line:
               $outchars[$outptr-1]=" " if $outptr>$#outchars+1; 
            } elsif ($inchars[$inptr] eq "A") { #^[[A up
               # e.g. bash readline multiple-screen-line-editing
               # for now just emit to history instead of trying to guess
               # $COLUMNS and new outptr
               $outptr = 0;
               history("c",@outchars);
               @outchars=();
            } elsif ($inchars[$inptr] eq "1") {
               $inptr++;
               if ($inchars[$inptr] eq "P") { # ^[[1P delete
                  splice @outchars, $outptr, 1;
                  debug();
               } elsif ($inchars[$inptr] eq "@") { # ^[[1@ insert
                  $inptr++;
                  splice @outchars, $outptr, 0, $inchars[$inptr] ;
                  $outptr++;
                  debug();
               } else {
                  # skip to end of sequence or emit unknown sequence 
                  for ($flag=0,$scanptr=$inptr;$scanptr<$inlen;$scanptr++) {
                     if ($inchars[$scanptr]=~/[a-z\@\{\|]/oi) {
                        $flag=1; last
                     }
                  }
                  if ($flag) {
                     $inptr=$scanptr
                  } else {
                     $outchars[$outptr++] = "\e";
                     $outchars[$outptr++] = "\[";
                     $outchars[$outptr++] = "1";
                     $outchars[$outptr++] = $inchars[$inptr];
                  }
                  debug();
               }
            } elsif ($inchars[$inptr] eq "K") { # ^[K delete
               splice @outchars, $outptr, 1;
               debug();
            } else {
               # skip to end of sequence or emit unknown sequence 
               for ($flag=0,$scanptr=$inptr;$scanptr<$inlen;$scanptr++) {
                  if ($inchars[$scanptr]=~/[a-z\@\{\|]/oi) {
                     $flag=1; last
                  }
               }
               if ($flag) {
                  $inptr=$scanptr
               } else {
                  $outchars[$outptr++] = "\e";
                  $outchars[$outptr++] = "\[";
                  $outchars[$outptr++] = $inchars[$inptr];
               }
               debug();
            }

         } else {
            if ($inchars[$inptr]=~/[#\%\(\)\*\+]/o and $inchars[$inptr+1]=~/[^\]\[\s]/o) { 
               # skip \eXX
               $inptr+=1;
            } elsif ($inchars[$inptr]=~/[^\]\[\s]/o) {
               # skip \eX
            } else {
               # unknown partial sequence, emit it and hope for the best
               $outchars[$outptr++] = "\e"; 
               $outchars[$outptr++] = $inchars[$inptr];
            }
            debug();
         }
      } else {
         $outchars[$outptr++] = $inchars[$inptr];
         debug();
      }
   }
   return(history("n",@outchars));
}
