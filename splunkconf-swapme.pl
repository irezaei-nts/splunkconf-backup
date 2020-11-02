#!/usr/bin/perl -w

# splunkconf-swapme.pl
# Matthieu Araman, Splunk
# This script will try to increase swap to 
# - allow the os to move unused thing to swap
# - give flexibility to the os memory management to avoid killing processes too early , especially when there are temporary burs
# System should not be swapping permanently of course, use Splunk monitoring Console or OS tools to monitor usaget 
# This should be part of global strategy on ressource management that is multiple things working together  :
# - correctly sized instance
# - WLM
# - user profiles
# - Splunk memory management 
# - Scheduling tuning
# - Search slots tuning

use strict;
use List::Util qw[min max];


my $MEM=`free | grep ^Mem: | perl -pe 's/Mem:\\s*\\t*(\\d+).*\$/\$1/' `;
my $SWAP=`free | grep ^Swap: | perl -pe 's/Swap:\\s*\\t*(\\d+).*\$/\$1/'`;
my $TOTALMEM=`free -t | grep ^Total: | perl -pe 's/Total:\\s*\\t*(\\d+).*\$/\$1/'`;


my $PARTITIONFAST="/";

if (@ARGV>=1) {
  $PARTITIONFAST=$ARGV[0];
  print "using partition from arg partitionfast=$PARTITIONFAST \n";
  if ( -e $PARTITIONFAST ) {
    print "partitioncheck ok \n";
  } else {
    print "Exiting ! wrong partition name !!!!\n";
    exit 1;
  }
} else {
  print "no arg, using / partition\n";
}

my $TAILLE=`df -k ${PARTITIONFAST}| tail -1| perl -pe 's/^[^\\s]+\\s+(\\d+).*\$/\$1/'`;
my $AVAIL=`df -k ${PARTITIONFAST}| tail -1| perl -pe 's/^[^\\s]+\\s+(\\d+)\\s+(\\d+)\\s+(\\d+).*\$/\$3/'`;

chomp($MEM);
chomp($SWAP);
chomp($TOTALMEM);
chomp($TAILLE);
chomp($AVAIL);

my $WANTED=100000000-$SWAP;
my $WANTED2=4*$MEM-$SWAP;
my $MINFREE=10000000;
my $AVAIL2=$AVAIL-$MINFREE;
my $WANTED3=min($WANTED,$WANTED2);
my $WANTED4=min($WANTED3,$AVAIL2);
print("MEM=$MEM, SWAP=$SWAP, TOTAL=$TOTALMEM, TAILLE=$TAILLE, AVAIL=$AVAIL, WANTED=$WANTED, WANTED2=$WANTED2, WANTED3=$WANTED3, WANTED4=$WANTED4, AVAIL2=$AVAIL2\n");
# logic is to be able to burst with a reduced oom risk 
# max size for prod env
if ($WANTED<=0){
   print ("swap space looks fine (check on size)! all good \n");
   exit 0;
}
# max size relative to allocated mem (will de facto reduce for test env or management component while still having enough size
if ($WANTED2<=0){
   print ("swap space looks fine (check on relative mem size)! all good \n");
   exit 0;
}
if ($WANTED4<=10000) {
  print (" about enough swap space, doing nothing \n");
  exit 0;
}
# try not to fill disk , inform admin that we are blocked
if ($AVAIL2<=0) {
  print (" not enough free space to add swap, please consider adding more disk space to reduce oom risk \n");
  exit 1;
}



print "trying to create a swapfile at $PARTITIONFAST/swapfile with size $WANTED4\n";
if (-e "$PARTITIONFAST/swapfile") {
  print "swapfile already exist , doing nothing\n";
} else {
  my $WANTED5=1024*$WANTED4;
  `fallocate -l $WANTED5 $PARTITIONFAST/swapfile`;
  `chmod 600 $PARTITIONFAST/swapfile`;
  `mkswap $PARTITIONFAST/swapfile`;
  `swapon $PARTITIONFAST/swapfile`;
   $SWAP=`free | grep ^Swap: | perl -pe 's/Swap:\\s*\\t*(\\d+).*\$/\$1/'`;
   $TOTALMEM=`free -t | grep ^Total: | perl -pe 's/Total:\\s*\\t*(\\d+).*\$/\$1/'`;
   print("after swapfile creation MEM=$MEM, SWAP=$SWAP, TOTAL=$TOTALMEM");
}