#!/usr/bin/perl

use strict;
our %irq_map;
our %cpu_map;

&read_config();
&read_irq_data();
&update_smp_affinity();
exit(0);

############################## sub functions #########################
sub read_config {
    my $cpu_count = &get_cpu_count();
    my $fh;
    my $config_file = "/etc/config/balance_irq";
    if( -f $config_file) {
    	open $fh, "<", $config_file or die $!;
    	while(<$fh>) {
		chomp;
		my($name, $cpu) = split;
		if($cpu > $cpu_count) {
			$cpu = $cpu_count;	
		} elsif($cpu < 1) {
			$cpu = 1;
		}
		$cpu_map{$name} = $cpu;
	}	
    	close $fh;
    } 
}

sub get_cpu_count {
    my $fh;
    open $fh, "<", "/proc/cpuinfo" or die $!;
    my $count=0;
    while(<$fh>) {
	    chomp;
	    my @ary = split;
	    if($ary[0] eq "processor") {
		    $count++;
	    }
    }
    close $fh;
    return $count;
}

sub read_irq_data {
    my $fh;
    open $fh, "<", "/proc/interrupts" or die $!;
    while(<$fh>) {
	    chomp;
	    my @raw = split;
	    my $irq = $raw[0];
  	    $irq =~ s/://;
	    my $name = $raw[-1];

	    if(exists $cpu_map{$name}) {
		$irq_map{$name} = $irq;
	    }
    }
    close $fh;
}

sub update_smp_affinity {
    for my $key (sort keys %irq_map) {
    	my $fh;
	my $irq = $irq_map{$key};
	my $cpu = $cpu_map{$key};
	my $smp_affinity = sprintf("%0x", 1 << ($cpu-1));
    	open $fh, ">", "/proc/irq/$irq/smp_affinity" or die $!;
	print "irq name:$key, irq:$irq, affinity:$smp_affinity\n";
	print $fh "$smp_affinity\n";
    	close $fh;
    }
}
