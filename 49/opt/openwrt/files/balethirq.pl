#!/usr/bin/perl

use strict;
our %map;

&read_data;
if($map{eth0}) {
    &update_smp_affinity($map{eth0}, 'c');
} elsif($map{eth1}) {
    &update_smp_affinity($map{eth1}, '3');
}
exit(0);

sub read_data {
    my $fh;
    open $fh, "<", "/proc/interrupts" or die $!;
    while(<$fh>) {
	    chomp;
	    my @raw = split;
	    my $irq = $raw[0];
  	    $irq =~ s/://;
	    if($raw[-1] eq 'eth0') {
		$map{eth0} = $irq;
	    } elsif($raw[-1] =~ m/xhci-hcd/) {
		$map{eth1} = $irq;
	    }
    }
    close $fh;
}

sub update_smp_affinity {
    my($irq, $value) = @_;
    my $fh;
    open $fh, ">", "/proc/irq/$irq/smp_affinity" or die $!;
    print $fh "$value\n";
    close $fh;
}
