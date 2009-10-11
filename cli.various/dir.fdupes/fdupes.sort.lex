#!/usr/bin/perl -00
foreach(@ARGV){s/^(\s+)/.\/$1/;s/^/< /;$_.=qq/\0/}; # MAGIC <> INSECURE MESS
while(<>){ # SECURE:OK
   $limit=4;
   /(?!^\d* bytes? each:\n)^(.+)\n/m or next;
   $lex{$1}.=$_;
}
print $lex{$_} foreach (sort {$a cmp $b} keys %lex);
