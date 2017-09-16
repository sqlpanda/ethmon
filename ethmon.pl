#!/usr/bin/perl
#use Smart::Comments '###', '####';
use Sys::Hostname;
use strict;
use warnings;

my $log_file = '/tmp/ethmon.log';
_print("ethmon starting ...");

my $ref_bad_gpu= _get_gpu_state();
my %bad_gpu = %{$ref_bad_gpu};
if ( scalar keys %bad_gpu  > 0 ) {
	my $worker = _get_worker();
	foreach my $gpu( keys %bad_gpu ) {
		my $pid = $bad_gpu{$gpu};
#		my $return = _kill_ethminer($pid);
#		if ( $return ) {
#			_start_ethminer ($gpu,$worker);
#		}
	}

}
else {
	_print("All GPU are health.");
}
	_print('--------END---------');


sub _get_gpu_state {
	my %return;
	my $cmd = 'nvidia-smi pmon -c 1 |grep ethminer';
	open (RUN,"$cmd|");
	my @results = <RUN>;
	### @results
	close(RUN);
	# gpu     pid  type    sm   mem   enc   dec   command
	#  0   26086     C    99   100     0     0   ethminer
	foreach (@results) {
		my @temps = split(/\s+/,$_);
		#print "$_\n";
		if ( $temps[4] < 90 ) {
			_print("GPU $temps[1]: PID $temps[2] stopped.");
			$return{$temps[0]}=$temps[1];
		}
		else {
			print "GPU $temps[1]: PID $temps[2] $temps[4] \n";
		}
		
	}
	return \%return;
}

sub _kill_ethminer {
	my $input = shift;
	_print("Killing $input ...");	
	unless (kill 0, $input) {
  		_print("$input has gone away!");
	}
}


sub _start_ethminer  {
	my $input = shift;
	my $worker = shift;
	my $cmd = "/opt/miners/ethminer/ethminer -F http://127.0.0.1:8080/$worker -U --dag-load-mode sequential --cl-global-work 8192 --farm-recheck 200 --cuda-parallel-hash 4 --cuda-devices $input 2>/var/run/miner.$input.output";	

	my $pid ;
	if (  defined $pid ) {
		_print("start ethminer for $input ...");
		system "$cmd";
	}	
	elsif ( $pid = fork ) {
		_print("ethminer($input) on pid $pid ...");
		sleep 60;
	}

}

sub _get_worker {
	my $c_host = hostname;
	my $cmd = `grep loc local.conf |grep -v '#' |grep $c_host`;
	my @temps = split(/\s+/,$cmd);
	return $temps[1];
}

sub getLoggingTime {

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
    my $nice_timestamp = sprintf ( "%04d%02d%02d %02d:%02d:%02d",
                                   $year+1900,$mon+1,$mday,$hour,$min,$sec);
    return $nice_timestamp;
}

sub _print {
	my $timestamp = getLoggingTime();
	my $input =  shift;
	print "$timestamp: $input\n";
	open (OUT, '>>', $log_file);
	print OUT "$timestamp: $input\n";
	close(OUT);
}
