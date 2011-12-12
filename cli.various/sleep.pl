#!/usr/bin/perl

# $0 [SECONDS(float)] # subsecond sleep

select(undef,undef,undef,$ARGV[0]);
# note that ping -i 0.2 as the lowest also works.
# note that gnu sleep supports this trick as well.
