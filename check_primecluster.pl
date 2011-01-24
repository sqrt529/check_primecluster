#!/usr/bin/perl
# check_primecluster.pl - Checks Fujitsu PrimeCluster application status (hvdisp -T userApplication)
# 
# Copyright (C) 2010 Joachim "Joe" Stiegler <blablabla@trullowitsch.de>
# 
# This program is free software; you can redistribute it and/or modify it under the terms
# of the GNU General Public License as published by the Free Software Foundation; either
# version 3 of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with this program;
# if not, see <http://www.gnu.org/licenses/>.
#
# --
# 
# Version: 1.0 - 2010-10-13

use warnings;
use strict;
use Getopt::Std;
use Sys::Hostname;
use File::Basename;

our ($opt_v, $opt_h);

my $hostname = hostname."RMS";

my $hvdisp = "/opt/SMAW/bin/hvdisp";
my $reliantpath = "/usr/opt/reliant/build/wizard.d/";

sub usage {
	print "Usage $0 [-v]\n";
	print "-v: Verbose output\n";
	exit (1);
}

if ( (!(getopts("vh"))) or (defined($opt_h)) ) {
	usage();
}

my @hvinput = `$hvdisp -T userApplication`;
my @cfgline;
my @application;
my $cfg;
my $cfgfile;
my $begin = 0;
my @machine;
my $critical = 0;
my @current;
my $text = "";

foreach my $line (@hvinput) {
	if ($line =~ /^Configuration/) {
		@cfgline = split(/:/, $line);
		$cfg = substr(basename($cfgline[1]), 0, -4);
	}

	if ($line =~ /^-/) {
		$begin = 1;
		next;
	}

	if ($line =~ /^$/) {
		$begin = 0;
		next;
	}

	if ($begin == 1) {
		@application = split(' ', $line);

		next if (!$application[2]); # Application was never active or is not part of a cluster node

		if ($application[2] =~ /Online|Offline|Faulted|Standby|Initial|Inconsistent|Preserved|Failed|Killed|Shutdown|Joined/) {
			push @application, $hostname;
			@current = ($application[0], $application[3], $application[2]);
		}
		else {
			@current = ($application[0], $application[2], $application[3]);
		}

		$cfgfile = $reliantpath.$cfg."/".$current[0].".m";

		open(FILE, '<', $cfgfile) or die "$!\n";
		while (<FILE>) {
			if ($_ =~ /HvpMachine000/) {
				@machine = split(/=/, $_);

				# Verbose output 
				if (defined($opt_v)) {
					printf "%s on %s is %s and runs primary on %s", $current[0], $current[1], $current[2], $machine[1];
				}

				if ($current[2] =~ /Inconsistent|Preserved|Failed|Killed|Shutdown|Joined|Faulted|Standby/) {
			   		$critical++;
					$text = $text.$current[0]." is ".$current[2]." on ".$machine[1]." ";
				}

				if ( ($current[1] eq $machine[1]) && ($current[2] ne "Online") ) {
					$critical++;
					$text = $text.$current[0]." is ".$current[2]." on ".$machine[1]." ";
				}
			}
		}
		close(FILE);
	}
}

if ($critical >= 1) {
    print "CRITICAL: $text\n";
    exit (2);
}
else {
    print "OK: All applications are running like expected\n";
    exit (0);
}
