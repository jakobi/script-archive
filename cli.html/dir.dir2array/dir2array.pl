#!/usr/bin/perl

# usage: 

# find . -type l -xtype l | grep . >/dev/null && echo '*** WARNING *** - BROKEN LINKS'
# find | sort | perl dir2array 


# BUGS: 
# - use of name/skip/leaf might be different from dir2html

use strict;
use vars;
use warnings;

use Data::Dumper;

my($new,$start);
my($file,@time);
my (@array,%skipdir,%leafdir);

# config
$new=32*24*3600; # new files are less than 1 month old
$start=time;

file: while(<>) {
   $file={};
   chomp;
   s!^\.\/!!g; s!/+\.?(?=/)!!g; s!/+($)!!; 

   if (-d $_) {                       # skip dirs
      # note that these depend on children coming later in sorted input...
      $leafdir{$_}=1          if -e "$_/.leaf" or -e "$_.leaf";
      do{$skipdir{$_}=1;next} if -e "$_/.skip" or -e "$_.skip";
      next                    if not -e "$_/.name" and not -e "$_.name";
   }
   #                                  # skip if in a skipped dir
   for my $d (sort keys %leafdir) { next file if m!^\Q$d\E/.*?/!};
   for my $d (sort keys %skipdir) { next file if m!^\Q$d\E/!};
   next if not -r $_;                 # skip on bad perm
   next if -e "$_.skip";              # skip files
   next if m!^(.*/)?(\.|\.\.)($)!;    # skip . / ..
   next if /\.name$|\.skip$|\.leaf$/; # skip on meta files

   $file->{name}=$_;

   $file->{time}=(stat($_))[9];

   @time=localtime($file->{time});
   $file->{date8}=sprintf("%04d-%02d-%02d", $time[5]+1900, $time [4]+1, $time[3]);
   $file->{time6}=sprintf("%02d:%02d:%02d", @time[2,1,0]);
   $file->{flags}= ($start - $file->{time} - $new < 0 ) ? "*" : "";
   
   $file->{sizek}=$file->{size}=-s $_; 
   $file->{sizek}+=512; $file->{sizek}/=1024; 
   if ($file->{sizek}>=1024) { 
      $file->{sizek}+=512; $file->{sizek}/=1024; $file->{sizek}.="M" 
   } else { 
      $file->{sizek}.="K" 
   };
   $file->{sizek}=~s/\.\d*//;

   $ENV{file}=$_;
   $file->{desc}=`cat \$file.name 2>/dev/null`; 
   $file->{desc}="" if $file->{desc}!~/\S/; 
   $file->{desc}=~s/\n+\z//; 
   
   push @array, $file;
# warn "$_\n";
}
print Dumper(\@array);
