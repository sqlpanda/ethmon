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
	my $cmd = 'nvidia-smi pmon -c 1';
	open (RUN,"$cmd|");
	my @results = <RUN>;
	@results = grep(!/^#/, @results);   
	### @results
	close(RUN);
	my @ethminer = grep(/ethminer/, @results);
	my @gpu = grep(/X/, @results);
	my %miner;
	my %gpu;
	foreach ( @ethminer ) {
		my @temps = split(/\s+/,$_);
		### @temps
		$miner{$temps[1]}->{PID}=$temps[2]; 
		$miner{$temps[1]}->{UTIL}=$temps[4]; 
	}
	### %miner
	foreach ( @gpu ) {
		my @temps = split(/\s+/,$_);
		### @temps
		$gpu{$temps[1]}=$temps[2];
	}

	### %gpu 
	# gpu     pid  type    sm   mem   enc   dec   command
	#  0   26086     C    99   100     0     0   ethminer
	foreach my $gpu(keys %gpu) {
		if ( ! $miner{$gpu}) {
			_print("GPU $gpu is missing");
			$return{$gpu}='-1';
		}
		else {
			if ( $miner{$gpu}->{UTIL} < 90 ) {
				_print("GPU $_: PID $miner{$gpu}->{PID} stopped or hang.");
				$return{$gpu}= $miner{$gpu}->{PID};
			}
			else {
				print "GPU $gpu: PID $miner{$gpu}->{PID} util $miner{$gpu}->{UTIL}% \n";
			}
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

