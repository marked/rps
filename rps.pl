#!/usr/bin/perl
use warnings;
use strict;

my @lines;
if (scalar @ARGV > 0) {
  my $HOST = shift (@ARGV);
  my $PORT = 25007;
  if (scalar @ARGV > 0) {
    $PORT = shift (@ARGV);
  } 
  @lines = `echo "GRAB" | nc $HOST $PORT`;
} else {
  @lines = <>;
}
  

my $total_proc = 0;
my @procs;  # array of hash refs
my @procs_children;  # array of array refs

my $line_num = 0;
my $cur_proc_num = 0;
my $spacer;
my $tmp_hash;
foreach my $l (@lines) {
  chomp $l;
  if ($line_num % 9 == 0) { # new proc
    if ($l =~ "GRAB") {
      last;
    }
    $total_proc++;
    $tmp_hash = {};
  }
  my $int_line = $line_num % 9;
  
  # Store all lines by default
  $tmp_hash->{$int_line} = denull($l);
  
  # Parse some line formats
  if ($int_line == 2) {
    if ($l =~ /^[0-9]+ /) {
      my ($tpid, $tname, $tcode, $tppid, $tjunk) = split ( / /, $l );
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
  if ($int_line == 7) {
    if ($l =~ /E/) {
      my($tname7, $junk2) = split ( /E/, $l );
      $tmp_hash->{'name7'} = denull($tname7);
    } else { dump_input() ; die "Expecting line $line_num ($int_line) /E/ Found $l\n"; };
  }
  $line_num++;
}

# OUTPUT

# Linear
if (0) {
  foreach my $p (@procs) {
    if (defined $p) {
      print "--\n";
      dump_proc($p);
      print "\n";
      pretty_dump_proc($p);
    }
  }
} 

# Recursive
r_pretty_dump(1, 0);

print "Total: $total_proc\n";

# SUBS

sub r_pretty_dump{
  my $pid  = shift(@_);
  my $depth = shift(@_);
  for(my $s = 0; $s < $depth; $s++) {
    print '  ';
  }
  pretty_dump_proc($procs[$pid]);
  foreach my $c (@{$procs_children[$pid]}) {
    r_pretty_dump( $c, $depth+1 );
  }
}

sub pretty_dump_proc {
  my $p = shift(@_);
  if (defined $p) {
    print "$p->{'pid'} $p->{'name2'} $p->{'name7'}\n";
    foreach my $c (@{$procs_children[$p->{'pid'}]}) {
      #print "child : $c\n";
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
  print FD join("\n", @lines);
  close FD;
}
