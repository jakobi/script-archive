#!/usr/bin/perl -00
while(<>){
   $limit=4;
   /(?!^\d* bytes? each:\n)^(.+)\n/m or next;
   $lex{$1}.=$_;
}
print $lex{$_} foreach (sort {$a cmp $b} keys %lex);
