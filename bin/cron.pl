#!/usr/local/bin/perl
#
# Copyright (C) 1993-1995 fukachan@phys.titech.ac.jp
# Please obey GNU Public Licence(see ./COPYING)

$rcsid   = q$Id$;
($rcsid) = ($rcsid =~ /Id:(.*).pl,v(.*) *\d\d\d\d\/\d+\/\d+.*/ && $1.$2);
$rcsid  .= "current";
# For the insecure command actions
$ENV{'PATH'}  = '/bin:/usr/ucb:/usr/bin';	# or whatever you need
$ENV{'SHELL'} = '/bin/sh' if $ENV{'SHELL'} ne '';
$ENV{'IFS'}   = '' if $ENV{'IFS'} ne '';

# Directory of Mailing List Server Libraries
# format: fml.pl DIR(for config.ph) PERLLIB's
$DIR		= $ARGV[0] ? $ARGV[0] : '/home/axion/fukachan/work/spool/EXP';
$LIBDIR		= $ARGV[1] ? $ARGV[1] : $DIR;	# LIBDIR is the second arg. 
foreach(@ARGV) { /^\-/ && &Opt($_) || push(@INC, $_);}# adding to include path;

#################### MAIN ####################
require 'config.ph';

$debug || ($debug = $_cf{'opt', 'd'});
 
chdir $DIR || die "Can't chdir to $DIR\n";

$pid = &GetPID;
if($pid > 0 && 1 == kill(0, $pid)) {
    print STDERR "Already Running, exit 0\n";
}else {
    &OutPID;
    &Cron;
}

exit 0;				# the main ends.
#################### MAIN ENDS ####################

##### SubRoutines #####

sub GetTime
{
    @WDay = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
    @Month = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
	      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
    
    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $Now = sprintf("%2d/%02d/%02d %02d:%02d:%02d", $year, $mon + 1, $mday, $hour, $min, $sec);
    $MailDate = sprintf("%s, %d %s %d %02d:%02d:%02d %s", $WDay[$wday],
			$mday, $Month[$mon], $year, $hour, $min, $sec, $TZone);
}

sub GetPID
{
    open(F, $CRON_PIDFILE) || return 0;
    local($pid) = <F>;
    chop $pid;
    close(F);

    return $pid;
}

sub OutPID
{
    open(F, "> $CRON_PIDFILE")|| return 0;
    select(F); $| = 1; select(stdout);	
    print F "$$\n";
    close(F);
}

sub Cron
{
    # FOR PROCESS TABLE
    $FML .= "[".substr($MAIL_LIST, 0, 8)."]"; # Trick for tracing

  CRON: while($_cf{'opt', 'a'} || $max_wait--> 0) {
      $0 = "--Cron <$FML $LOCKFILE>";
      $0 = "--Cron [$max_wait] times <$FML $LOCKFILE>" unless $_cf{'opt', 'a'}; 
      
      &GetTime;
      $init_t = time();
      if($EXEC = &ReadCrontab) {
	  print STDERR "\nDate $hour:$min:$sec:\n" if $debug;
	  print STDERR "$EXEC\n" if $debug;

	  &system($EXEC);
	  &Log($@) if $@;

      }
      
      # next 60sec.
      $0 = "--Cron Sleeping <$FML $LOCKFILE>";
      $0 = "--Cron Sleeping [$max_wait] times <$FML $LOCKFILE>" unless $_cf{'opt', 'a'}; 

      if($time = (time() - $init_t) <= 60) {
	  $time = 60 - $time;
	  print STDERR "Sleeping $time\n" if $debug;
	  sleep $time;
      }else {
	  print STDERR "Hmm exec costs over 60sec... go the next step now!\n" if $debug;
	  next CRON;
      }
  }#END OF WHILE;
}

sub CronChk
{
    local($m, $h, $d, $M, $w, $exec, $org) = @_;

    print STDERR "Try ($m, $h, $d, $M, $w, $exec)\n" if $debug;

    if(&Match($m, $h, $d, $M, $w)) {
	return $exec;
    }else {
	return "";
    }
}

sub Match
{
    local($m, $h, $d, $M, $w) = @_;
    local($nomatch);

    # WEEK
    print STDERR "($w eq '*') || ($w eq $wday) || (7==$w && 0==$wday)\n" if $debug;
    if(($w eq '*') || ($w eq $wday) || (7==$w && 0==$wday)) { 
	;
    }else { 
	$nomatch++; 
    }

    # MONTH
    print STDERR "($M eq '*') || ($M eq ($mon + 1))\n" if $debug;
    if(($M eq '*') || ($M eq ($mon + 1))) { 
	;
    }else { 
	$nomatch++; 
    }

    # DAY
    print STDERR "($d eq '*') || ($d eq $mday)\n" if $debug;
    if(($d eq '*') || ($d eq $mday)) { 
	;
    }else { 
	$nomatch++; 
    }

    # HOUR
    print STDERR "($h eq '*') || ($h eq $hour)\n" if $debug;
    if(($h eq '*') || ($h eq $hour)) { 
	;
    }else { 
	$nomatch++; 
    }

    # MINUTE
    print STDERR "($m eq '*') || ($m eq $min)\n" if $debug;
    if(($m eq '*') || ($m eq $min)) { 
	;
    }else { 
	$nomatch++; 
    }

    # O.K.
    return $nomatch ? 0 : 1;
}

# Crontab is 4.4BSD syntax 
#
#minute	hour	mday	month	wday	command
#
sub ReadCrontab
{
    undef $EXEC;

    open(CRON, "< $CRONTAB");
    while(<CRON>) {
	chop;
	next if /^\#/o;
	next if /^\s*$/o;

	local($m, $h, $d, $M, $w, @com) = split(/\s+/, $_, 99);
	local($org)  = $_;
	local($exec) = join(" ", @com);
	local(@s, $i, $start, $end, $unit);

	if($m =~ /(.*)\/(\d+)$/) {
	    print STDERR "MATCHED CRON MIN:($m =~ /(.*)\/(\d+)\$/);\n" if $debug;
	    print STDERR "\$m = $1; \$unit = $2;\n" if $debug;
	    $m = $1; 
	    $unit = $2;
	}

	foreach $m (split(/,/, $m, 9999)) {
	    if($m =~ /^(\d+)$/) {
		push(@s, $1);
	    }elsif($m =~ /^(\d+)\-(\d+)$/) {
		$start = $1;
		$end   = $2;
		for($i = $start; $i <= $end ; $i++) { push(@s, $i);}
	    }
	}

	# Check
	$unit > 0 || ($unit = 1);
	foreach $m (@s) {
	    next unless 0 == ($m % $unit);
	    print STDERR "$m," if $debug;
	}
	print STDERR "\n\n" if $debug;

	foreach $m (@s) {
	    next unless 0 == ($m % $unit);
	    if(&CronChk($m, $h, $d, $M, $w, $exec, $org)) {
		$EXEC .= "$exec;\n";   
	    }
	}
    }
    close(CRON);

    return $EXEC;
}

sub abs
{
    local($x) = @_;

    return $x > 0 ? $x : -$x;
}

# Alias but delete \015 and \012 for seedmail return values
sub Log { 
    local($str, $s) = @_;
    $str =~ s/\015\012$//;
    &Logging($str);
    &Logging("   ERROR: $s", 1) if $s;
}

# Logging(String as message)
# $errf(FLAG) for ERROR
sub Logging
{
    local($str, $e) = @_;

    &GetTime;

    open(LOGFILE, ">> $LOGFILE");
    select(LOGFILE); $| = 1; select(stdout);
    print LOGFILE "$Now $str ". ((!$e)? "($From_address)\n": "\n");
    close(LOGFILE);
}

# Lastly exec to be exceptional process
sub ExExec { &RunHooks(@_);}
sub RunHooks
{
    local($s);
    $0 = "--Run Hooks ".$_cf{'hook', 'prog'}." $FML $LOCKFILE>";
	
    if($s = $_cf{'hook', 'prog'}) {
	print STDERR "\nexec sh -c $s\n\n" if $debug;
	exec "sh", '-c', "$s";
    }elsif($s = $_cf{'hook', 'str'}) {
	print STDERR "\neval >$s<\n\n" if $debug;
	&eval($s, 'Run Hooks:');
    }
}

# Warning to Maintainer
sub Warn
{
    local($s, $b) = @_;
    &Sendmail($MAINTAINER, $s, $b);
}

# eval and print error if error occurs.
sub eval
{
    local($exp, $s) = @_;
    eval $exp; 
    &Log("$s:$@") if $@;
}

# Getopt
sub Opt
{
    local($opt) = @_;
    ($opt =~ /^\-(\S)/) && ($_cf{'opt', $1} = 1);
}

sub system
{
    local($s, $out, $in) = @_;

    if(($pid = fork) < 0) {
	&Log("Cannot fork");
    }elsif(0 == $pid) {
	if($in){
	    open(STDIN, $in) || die "in";
	}else {
	    close(STDIN);
	}

	if($out){
	    open(STDOUT, '>'. $out)|| die "out";
	}else {
	    close(STDOUT);
	}

	exec '/bin/sh', '-c', $s;
	&Log("Cannot exec $s:$@");
    }

    # Wait for the child to terminate.
    while(($dying = wait()) != -1 && ($dying != $pid) ){
	;
    }
}

1;
