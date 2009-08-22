#!/usr/bin/perl

# trace one command (assuming sufficently large trace buffer, etc)
# USAGE: $0 [-e PERLREGEX] [-E PERLEXPR] /ABSOLUTE/PATH/TO/COMMAND COMMAND/ARGUMENTS

# PJ20020128, roughly based on AIX Survivalguide p345.

# BUGS:
# - does not add -f/-F options to automatically select/follow forks
# - does not do concurrent tracing
# - does not do -p PID (use /usr/bin/sleep instead and grep for 
#   processes of interest)

$|=1;
args: while (1) {
   if ($ARGV[0] eq '-')    { shift; last args}
   elsif ($ARGV[0] eq '-E'){ shift; do "$ARGV[0]"; die "$@" if $@; shift}
   elsif ($ARGV[0] eq '-e'){ shift; $REGEX=$ARGV[0]; eval{/$REGEX/}; die "$@" if $@; shift}
   elsif ($ARGV[0] eq '-h'){ shift; &help; exit 1}
   else{ last args; }
}

   $FILE_HOOKS="107,12E,130,15B,163,19C";
$SYSCALL_HOOKS="101";
 $KERNEL_HOOKS="134,135,139";
        $HOOKS=join(",", $FILE_HOOKS, $SYSCALL_HOOKS, $KERNEL_HOOKS);
  $REPORT_OPTS="ids=off,exec=on,pid=on,svc=on,pagesize=0,timestamp=3";
 $REPORT_FLAGS="-v -x";

# default, unless -e: look for lines starting with basename of program
$REGEX="^".quotemeta($1) if not $REGEX and $ARGV[0]=~m@.*/(.*)@;

$date=`date +%Y%m%d%H%M%S`; chomp $date;
$TMP="/tmp/tracelog.$date";
print "LOG: $TMP\n";
print "\n";

system("trace -a -d -j $HOOKS; trcon");
system @ARGV; # tough, I am just too lazy to requote the args we got...
system("trcstop");
system("echo; trcrpt $REPORT_FLAGS -O $REPORT_OPTS > $TMP");

system("head -12 $TMP");
open(FH, "<$TMP") or die "no trace file";
while(<FH>) {
   next if /^trace/o;
   next if /^trcstop/o;
   next if $REGEX and not /$REGEX/o;
   print
}
close FH;

exit 0;

########################################
sub help { system "grep US"."AGE $0"; exit 1}


