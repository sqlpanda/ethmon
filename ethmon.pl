#!/usr/bin/perl
#use Smart::Comments '###', '####';
use Sys::Hostname;
use Cwd;
use strict;
use warnings;

my $dir = getcwd;
my $xmr= '45pwYiBt5vvWm6KgsAkGkrZztC7NthMbEMMvgUGD6SitK7YDbPgFvJS2mNiW4Fx4Pb2oncinP92A1j7uVxHdjCmKHQpPjHH';
my $xmr_pool = 'stratum+tcp://pool.supportxmr.com:7777';


# `pwd`/ccminer -a cryptonight -o stratum+tcp://pool.supportxmr.com:7777 -u 45pwYiBt5vvWm6KgsAkGkrZztC7NthMbEMMvgUGD6SitK7YDbPgFvJS2mNiW4Fx4Pb2oncinP92A1j7uVxHdjCmKHQpPjHH -p pandaE1 -d 0
my $log_file = '/tmp/ethmon.log';
_print('--------------------');
_print("ethmon starting ...");
my $worker = _get_worker();
my $cpu_worker = "$worker-CPU";
# Setting up the mem/core
_print('Checking default core/mem');
my $cmd1= 'ethos-readdata core > /var/run/ethos/defaultcore.file';
my $cmd2= 'ethos-readdata mem > /var/run/ethos/defaultmem.file';
system($cmd1);
system($cmd2);
# start cpuminer 
my $has_cpu_miner = _check_cpu_miner( $cpu_worker );
if ( $has_cpu_miner ) {
	_print("CPU miner is health ...");
}
else {
	_print("CPU miner is not health ...");
	_start_cpu_miner()
}
# start xmr miner  if ethmon die 


my $ref_bad_gpu= _get_gpu_state();
my %bad_gpu = %{$ref_bad_gpu};
my @new_miners;
if ( scalar keys %bad_gpu  > 0 ) {
	foreach my $gpu( keys %bad_gpu ) {
		my $pid = $bad_gpu{$gpu};
		my $return = _kill_ethminer($pid);
		if ( $return ) {
			push @new_miners, $gpu;
			#_start_gpuXMR($gpu,$worker);
			#_start_ethminer ($gpu,$worker);
		}
	}

	_start_miner(\@new_miners);

}
else {
	_print("All GPU are health.");
}

	_print('--------END---------');

sub _find_miner_need_eth {
	my $c_host = hostname;
	my @temps = qw//;
        my $cmd = `grep sel /home/ethos/local.conf |grep -v '#' |grep $c_host`;
        if ( $cmd) {
		@temps = split(/\s+/,$cmd);
		shift @temps;
		shift @temps;
	}
	
	
	return \@temps;
	
}

sub _start_miner{
	my $ref_input = shift;
	my @bad_gpus = @$ref_input;
	my @eth_gpus = @{_find_miner_need_eth()};
	my %eth=map{$_ =>1} @eth_gpus;
	my %bad=map{$_=>1} @bad_gpus;
	
	# the intersection of @females and @simpsons:
	my @eth_bad = grep( $bad{$_}, @eth_gpus );
	### @eth_bad		
	if ( scalar @eth_bad > 0) {
		foreach my $eth ( @eth_bad ) {
			_start_ethminer($eth);	
		}
	}
	my %eth_bad = map{$_=>1} @eth_bad;
	my @xmr_gpu=grep(  ! defined $eth_bad{$_}, @bad_gpus);
	### @xmr_gpu
	if ( scalar @xmr_gpu > 0) {
		_start_gpuXMR(\@xmr_gpu);
        }

}


sub _get_gpu_state {
	my %return;
	# FIX ME, time out the command 
	my $cmd = 'nvidia-smi pmon -c 1';
	open (RUN,"$cmd|");
	my @results = <RUN>;
	@results = grep(!/^#/, @results);   
	### @results
	close(RUN);
	my @ethminer = grep(/ethminer|ccminer/, @results);
	my @gpu = grep(/X/, @results);
	my %miner;
	my %gpu;
	foreach ( @ethminer ) {
		my @temps = split(/\s+/,$_);
		### @temps
		$miner{$temps[1]}->{PID}=$temps[2]; 
		$miner{$temps[1]}->{UTIL}=$temps[4]; 
		$miner{$temps[1]}->{MEM}=$temps[5]; 
		$miner{$temps[1]}->{NAME}=$temps[-1]; 
	}
	### %miner
	foreach ( @gpu ) {
		my @temps = split(/\s+/,$_);
		### @temps
		$gpu{$temps[1]}=$temps[2];
	}
	my %threshold = (
		'ccminer'=> {
			'UTIL' => 50,
			'MEM' => 10,
		},
		'ethminer'=> {
			'UTIL' => 90,
			'MEM' => 70,
		},
		
	);

	### %gpu 
	# gpu     pid  type    sm   mem   enc   dec   command
	#  0   26086     C    99   100     0     0   ethminer
	foreach my $gpu(sort keys %gpu) {
		if ( ! $miner{$gpu}) {
			_print("GPU $gpu is missing ethminer process");
			$return{$gpu}='-1';
		}
		else {
			my $gpu_threshold = $threshold{$miner{$gpu}->{NAME}}->{UTIL};
			my $mem_threshold = $threshold{$miner{$gpu}->{NAME}}->{MEM};

					if ( $miner{$gpu}->{UTIL} < $gpu_threshold ) {
						_print("GPU $gpu: $miner{$gpu}->{NAME} -> PID $miner{$gpu}->{PID} stopped or hang($miner{$gpu}->{UTIL})");
						$return{$gpu}= $miner{$gpu}->{PID};
					}
					elsif ( $miner{$gpu}->{MEM} < $mem_threshold) {
						_print("GPU $gpu: $miner{$gpu}->{NAME} -> PID $miner{$gpu}->{PID} stopped or han{($miner{$gpu}->{MEM}) . Memory STOP");
						$return{$gpu}= $miner{$gpu}->{PID};
					}
					else {
						print "GPU $gpu: $miner{$gpu}->{NAME} -> PID $miner{$gpu}->{PID} util $miner{$gpu}->{UTIL}% ,MEM $miner{$gpu}->{MEM} \n";
					}
			}
			
		}
		return \%return;
}



sub _kill_ethminer {
	my $input = shift;
	if ( $input > 0 ) {
		_print("Killing $input ...");	
		unless (kill 'KILL', $input) {
  			_print("$input has gone away!");
			return 1; 
		}
	}
	else {
		print "SKIP $input ..\n";
	}
}


sub _start_ethminer  {
	my $input = shift;
	my $cmd = "/opt/miners/ethminer/ethminer -F http://127.0.0.1:8080/$worker -U --dag-load-mode sequential --cl-global-work 8192 --farm-recheck 200 --cuda-parallel-hash 4 --cuda-devices $input >/var/run/miner.$input.output 2>&1 &";	
	_print("start ethminer for $input ...");
	print "$cmd\n";
	exec($cmd ) or _print("fail to exec $!");
	#sleep 10;
}
sub _start_gpuXMR  {
# `pwd`/ccminer -a cryptonight -o stratum+tcp://pool.supportxmr.com:7777 -u 45pwYiBt5vvWm6KgsAkGkrZztC7NthMbEMMvgUGD6SitK7YDbPgFvJS2mNiW4Fx4Pb2oncinP92A1j7uVxHdjCmKHQpPjHH -p pandaE1 -d 0
	my $ref_input = shift;
	
	my @gpus = @$ref_input;
	my $gpu = join(',',@gpus);
	my $cmd = "/opt/miners/ccminer/ccminer -a cryptonight -o $xmr_pool -u $xmr -p $worker -d $gpu 2>/tmp/miner.xmr.output 2>&1";	
	_print("start GPU Miner XMR for $gpu ...");
	print "$cmd\n";
	system("$cmd &") or _print("fail to exec $!");
	#sleep 10;
}




sub _get_worker {
	my $c_host = hostname;
	my $cmd = `grep loc /home/ethos/local.conf |grep -v '#' |grep $c_host`;
	my @temps = split(/\s+/,$cmd);
	return $temps[-1];
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

sub _check_cpu_miner {
	my $worker =shift;
        my $cmd = 'ps -ef |grep  minerd';
	_print("Checking CPU miner  ...");	
        open (RUN,"$cmd|");
        my @results = <RUN>;
        @results = grep(/$worker/, @results);
	close(RUN);
	### @results
	if ( scalar @results > 0 ) {
		return 1;
	}
	else {
		return 0;
	}
}

sub _start_cpu_miner {
        #my $cmd = "$dir/cpuminer/minerd -a cryptonight -o $xmr_pool -u $xmr.$cpu_worker -p x &";
        my $cmd = "$dir/minerd -a cryptonight -o $xmr_pool -u $xmr.$cpu_worker -p x &";
        _print("start CPU miner for XMR ...");
        print "$cmd\n";
        exec($cmd ) or _print("fail to exec $!");
}
