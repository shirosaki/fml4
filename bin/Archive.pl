#!/usr/local/bin/perl
#
# Copyright (C) 1993-1997 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1997 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $id = q$Id$;

chop ($PWD = `pwd`);

require 'getopts.pl';
&Getopts("dhu:A:U");

$opt_h && die(&Usage);

$debug       = $opt_d;
undef $debug if $opt_U;
# $Unit        = $opt_u || 100;
$ARCHIVE_DIR = "var/archive";
$DIR         = $PWD;

# FIX
$SPOOL_DIR   = "spool";

# eval config.ph (do the force of eval by "do")
if (-f "./config.ph")  { do "./config.ph";}
if (-f $SEQUENCE_FILE) { chop ($MaxSeq = `cat $SEQUENCE_FILE`);}

# CLO
unshift(@ARCHIVE_DIR, $opt_A) if $opt_A;

# Preliminary
$i = 1;

# Adjust following config.ph; moved here;
# fml-support: 02590 <fujita@soum.co.jp>
$Unit  = $opt_u   || $DEFAULT_ARCHIVE_UNIT || 100;
$limit = $ARGV[0] || ($Unit * int ($MaxSeq / $Unit )) || 1000;

# useless when seq(103) < unit(1000)
if ($MaxSeq < $Unit) { 
    print STDERR "Do nothing when Seq=$MaxSeq < Unit=$Unit\n";
    exit 0;
}

# MESSAGE
&Mesg( "Try archive 1 .. $limit by the unit 100");
&Mesg( "DEBUG MODE, DO NOTHING ACTUALLY\nHere is $PWD") if $debug;

# ARCHIVE DIR CHECK
&Mesg( "\$ARCHIVE_DIR\t$ARCHIVE_DIR") if $debug;
&Mesg( "\@ARCHIVE_DIR\t@ARCHIVE_DIR") if $debug;

$ARCHIVE_DIR = @ARCHIVE_DIR ? (shift @ARCHIVE_DIR) : $ARCHIVE_DIR;

&Mesg( "\$ARCHIVE_DIR\t$ARCHIVE_DIR") if $debug;


local($dir) = ".";
foreach (split(/\//, $ARCHIVE_DIR)) {
    next if /^\s*$/;
    $dir .= "/$_";
    -d $dir || do { mkdir($dir, 0700);}
}


while ($i * $Unit <= $limit) {
    $counter = 0;
    undef $files;
    $lower = $Unit * ($i - 1) + 1;
    $upper = $Unit * ($i);
    $tar  =  $Unit * ($i);
    $i++;
    
    foreach ($lower .. $upper) {
	if( -f "$SPOOL_DIR/$_") {
	    $files .= "$SPOOL_DIR/$_ "; 
	    $counter++;
	}
    }

    &Mesg("Cheking\t$lower -> $upper ($counter hits)");

    if ($counter > 0) {
	if (-f "$ARCHIVE_DIR/$tar.tar.gz") {
	    &Mesg( "Exists $ARCHIVE_DIR/$tar.tar.gz, SO SKIPPED");
	    next;
	}
	else {
	    &Mesg("tar cvf - $files |gzip > $ARCHIVE_DIR/$tar.tar.gz");
	    system "tar cvf - $files |gzip > $ARCHIVE_DIR/$tar.tar.gz"; 
	}
    }

}

exit 0;

sub Usage
{
    $0 =~ s#.*/##;
    $_ = qq#;
    $0 [-d] [-h] [unit];

    $0 archives \$SPOOL_DIR in this directory;
    in evaluating ./config.ph.;
    If exists, evaluate and use \$ARCHIVE_DIR, \@ARCHIVE_DIR and \$SEQUENCE_FILE;

    unit (default 100);

  option:;
    -d debug mode(do nothing actually);
    -h this help;
#;

    s/;//g;
    $_;
}

sub Mesg { print STDERR "@_\n";}

1;
