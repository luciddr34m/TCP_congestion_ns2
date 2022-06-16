#create a simulator
set ns [new Simulator]

$ns color 1 Blue

#Open the nam trace file
set nf [open tcp.nam w]
$ns namtrace-all $nf

#Open the trace file
set nt [open tcp.tr w]
$ns trace-all $nt

#create node4
set s1 [$ns node]
set n1 [$ns node]
set n2 [$ns node]
set d1 [$ns node]

$ns duplex-link $s1 $n1 10Mb 10ms DropTail
#n1 n1 set as bottleneck
$ns duplex-link $n1 $n2 1Mb 10ms DropTail
$ns duplex-link $n2 $d1 10Mb 10ms DropTail
$ns queue-limit $n1 $n2 15
$ns queue-limit $n2 $n1 15

$ns duplex-link-op $s1 $n1 orient right
$ns duplex-link-op $n1 $n2 orient right
$ns duplex-link-op $n2 $d1 orient right
$ns duplex-link-op $n1 $n2 queuePos 0.5

#set TCP agent
set tcp [new Agent/TCP/Vegas]
$ns attach-agent $s1 $tcp
$tcp set class_ 1
$tcp set window_ 30

#set FTP agent
set pktSize 1000
set ftp [new Application/FTP]
$ftp set type_ FTP
$ftp set packet_size_ $pktSize
$ftp set rate_ 1mb
$ftp attach-agent $tcp

#set sink agent
set sink [new Agent/TCPSink]
$ns attach-agent $d1 $sink
$ns connect $tcp $sink


#print cwnd procedure
set print_cwnd [open tcp_cwnd.xg w]
proc record_cwnd {tcpsource file1} {
	global ns
	set conges [$tcpsource set cwnd_]
	set now [$ns now]
	puts $file1 "$now $conges"
	$ns at [expr $now+0.1] "record_cwnd $tcpsource $file1"
}

#print throughput procedure
set tmpLastAck -1
set print_thp [open tcp_thp.xg w]
proc CalSendRate {tcpsource file2} {
	global ns tmpLastAck pktSize
	set time 0.1
	set tAck [$tcpsource set ack_]
	set now [$ns now]
	puts $file2 "$now\t[expr (($tAck-$tmpLastAck)*$pktSize / $time) * 8/1000000.0]"
	set tmpLastAck $tAck
	$ns at [expr $now+$time] "CalSendRate $tcpsource $file2"
}

#Tracing a queue
set qmonitor [$ns monitor-queue $n1 $n2 [open qm.out w]]
set print_qulength [open tcp_queuelength.xg w]
proc print_queueSize {qmonitorSource file3} {
	global ns
	set now [$ns now]
	set len [$qmonitorSource set pkts_]
	puts $file3 "$now $len"
	$ns at [expr $now+0.1] "print_queueSize $qmonitorSource $file3"
}


#'finish' procedure
proc finish {} {
	global ns nf nt print_cwnd print_thp print_qulength
	$ns flush-trace
	close $nf
	close $nt
	close $print_cwnd
	close $print_thp
	close $print_qulength
	#exec nam tcp.nam &
	exit 0
}

$ns at 0.0 "$ftp start"
$ns at 0.0 "print_queueSize $qmonitor $print_qulength"
$ns at 0.0 "record_cwnd $tcp $print_cwnd"
$ns at 0.0 "CalSendRate $tcp $print_thp"
$ns at 10.5 "finish"

#Rnu the simulation
$ns run
