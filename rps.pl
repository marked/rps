#!/usr/bin/perl
use warnings;
use strict;
my $DEBUG = 0;

### ARG's ###

if (@ARGV==0) {
  print STDERR " Usage: rps.pl HOST_IP
 Usage: rps.pl HOST_IP PORT_IP
 Usage: rps.pl -
 Usage: rps.pl - FILENAME\n";
 exit(-1);
}

my (@lines, $HOST, $PORT);
my $arg = shift (@ARGV);

if ($arg =~ /^-/) {
  if (@ARGV) {
    print STDERR "Reading from files\n";
  }
  else {
    print STDERR "Reading from STDIN\n";
  }
  @lines = <>;
}
else {
  $HOST = $arg;
  $PORT = 25007;
  if (@ARGV) {
    $PORT = shift (@ARGV);
  } 
  @lines = `echo "GRAB" | nc $HOST $PORT`;
}

### PARSE ###

my @orig_input = @lines;  # backup input for debugging
chop @lines;

my $total_proc = 0;
my @procs;  # array of hash refs of parsed details
my @procs_children;  # array of array refs containing pids of children

my $line_num = 0;
my $cur_proc_num = 0;
my $tmp_hash;
foreach my $l (@lines) {
  if ($line_num % 9 == 0) {  # new proc frame
    if ($l =~ "^GRAB") {     # or notice of end
      last;
    }
    $total_proc++;
    $tmp_hash = { 'printed' => 0 };
  }
  my $int_line = $line_num % 9;
  
  # Store all lines by default
  $tmp_hash->{$int_line} = denull($l);
  
  # Parse some line formats
  if ($int_line == 2) { # 1102 (tivoApplication) S 702 1102 702 0 -1 4202816 29656 27015 2...
    if ($l =~ /^[0-9]+ /) {
      #print "$l\n";
      $l =~ m/^([0-9]+) ([(].*[)]) (.) ([0-9]+)/;
      my ($tpid, $tname, $tcode, $tppid) = ($1, $2, $3, $4);
      ($cur_proc_num) = ($tpid);
      ($tmp_hash->{'pid'}, $tmp_hash->{'ppid'}, $tmp_hash->{'name2'}) = ($tpid, $tppid, $tname);
      $procs[$tpid] = $tmp_hash; 
      if ($tpid != 1) { # not init
        if (! defined ($procs_children[$tppid]) ) { # missing child array
          $procs_children[$tppid] = [];
        }
        push(@{$procs_children[$tppid]}, $tpid); 
      } 
    } else { dump_input() ; die "Expecting line $line_num ($int_line) /^[0-9]+ / Found $l\n"; };
  }
  if ($int_line == 7) { # SystemServices^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@E      949
    if ($l =~ /E/) {
      my($tname7, $junk2) = split ( /E/, $l );
      $tmp_hash->{'name7'} = denull($tname7);
    } else { dump_input() ; die "Expecting line $line_num ($int_line) /E/ Found $l\n"; };
  }
  $line_num++;
}

if ($DEBUG) {
  dump_input();
}

### OUTPUT ###

# Linear
if ($DEBUG) {
  foreach my $p (@procs) {
    if (defined $p) {
      print "--\n";
      dump_proc($p);
      print "\n";
      #pretty_dump_proc($p);
    }
  }
} 

# Recursive
foreach my $p (@procs) {
  if (defined $p && $p->{'printed'} == 0 ) {
    r_pretty_dump($p->{'pid'}, 0);
  }
}

print "Total: $total_proc\n";

### SUBS ###

sub r_pretty_dump{
  my $pid  = shift(@_);
  my $depth = shift(@_);
  for(my $s = 0; $s < $depth; $s++) {
    print '  ';
  }
  pretty_dump_proc($procs[$pid]);
  $procs[$pid]->{'printed'} = 1;
  foreach my $c (@{$procs_children[$pid]}) {
    r_pretty_dump( $c, $depth+1 );
  }
}

sub pretty_dump_proc {
  my $p = shift(@_);
  if (defined $p) {
    print "$p->{'pid'} $p->{'name2'} $p->{'name7'}\n";
    if ($DEBUG) {
      foreach my $c (@{$procs_children[$p->{'pid'}]}) {
        print "child : $c\n";
      }
    }
  }
}

sub denull {
  my $str = shift(@_);
  $str =~ tr/\0/ /;
  return ($str);
}

sub dump_proc {
  my $p = shift(@_);
  if (defined $p)  {
    print "0: $p->{0}\n";
    print "1: $p->{1}\n";
    $p->{2} =~ s/(^[^ ]* [^ ]* [^ ]* [^ ]*).*/$1/g;
    print "2: $p->{2}\n";
    print "3: $p->{3}\n";
    print "4: $p->{4}\n";
    print "5: $p->{5}\n";
    print "6: $p->{6}\n";
    print "7: $p->{7}\n";
    print "8: $p->{8}\n";
  }   
}

sub dump_input {
  open (FD, ">procdump.txt");
  print FD @orig_input;
  close FD;
}
