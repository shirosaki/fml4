# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996-1997 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.

# $Id$;

sub ConfirmationModeInit
{
    # save the request and given identifier;
    # The concept of KEYWORD and ADDRESS suggeted (irc:-) by ando@iij-mc.co.jp
    $CONFIRMATION_KEYWORD = $CONFIRMATION_KEYWORD || "confirm";
    $CONFIRMATION_FILE    = $CONFIRMATION_FILE || "$DIR/confirm";
    $CONFIRMATION_LIST    = $CONFIRMATION_LIST || "$FP_VARLOG_DIR/confirm";
    $CONFIRMATION_ADDRESS = $CONFIRMATION_ADDRESS || $e{'CtlAddr:'};
    $CONFIRMATION_EXPIRE  = $CONFIRMATION_EXPIRE || 7*24; # unit is "hour"
    $CONFIRMATION_SUBSCRIBE = 
	$REQUIRE_SUBSCRIBE || $DEFAULT_SUBSCRIBE || 'subscribe';

    # touch
    -f $CONFIRMATION_LIST || &Touch($CONFIRMATION_LIST);

    # transfer main to Confirm NameSpace;
    for (CONFIRMATION_KEYWORD,
	 CONFIRMATION_LIST,   
	 CONFIRMATION_ADDRESS,
	 CONFIRMATION_SUBSCRIBE, 
	 CONFIRMATION_EXPIRE) {
	eval("\$Confirm'$_ = \$main'$_;");
    }
}


# return 1 if we can regist $addr (replied and confirmed);
# return 0 if first-time, expired, confirmation yntax error;
sub Confirm
{
    local(*e, $addr, $buffer) = @_;
    local($id, $r, @r, %r, $time, $m);

    $e{"GH:Subject:"} = "Subscribe confirmation result $ML_FN";

    # current time
    $time = time;

    # result code; @r is the identifier;
    $r = &Confirm'FirstTimeP(*r, $addr, $time);#';

    &Log("Confirm::FirstTimeP r=$r");

    if ($r eq 'first-time' || $r eq 'expired') {
	if ($r eq 'expired') {
	 $m .= "Your confirmation for \"subscribe request to $MAIL_LIST\"\n";
	 $m .= "is TOO LATE (ALREADY EXPIRED).\n";
	 $m .= "So we treat you request is the first time request.\n";
	 $m .= "Please try it from the first time as follows\n\n";
	}

	# $name == "Elena Lolabrigita";
	($name = &Confirm'BufferSyntax(*e, $buffer)) || return 0; #';

	 # required info format 
	 # [addr id time(for expire) signature]
	 $id   = &Confirm'GenKey($from);#';

	 # var/log/confirm;
	 &Append2("$time\t$addr\t$id\t$name", $CONFIRMATION_LIST);

	 # Header
	 $e{"GH:Subject:"} = "Subscribe confirmation request $ML_FN";
	 $m .= "To confirm your subscribe request to $MAIL_LIST,\n";
	 $m .= "please send the following phrase to $CONFIRMATION_ADDRESS\n\n";
	 $m .= "$CONFIRMATION_KEYWORD $id $name\n";
	 &Mesg(*e, $m);
	 $e{'message:append:files'} = $CONFIRMATION_FILE;
	 return 0;
    }
    elsif ($r eq 'confirmed') { # @r == identifier;
	$r = &Confirm'IdCheck(*e, *r, $buffer);#';
	return $r;
    }
    else {
	&Log("Confirm: Error exception");
	return 0;
    }
}


package Confirm;


sub AddressMatch { &main'AddressMatch(@_);} #';
sub Log          { &main'Log(@_);} #';
sub Mesg          { &main'Mesg(@_);} #';
sub Open         { &main'Open(@_);} #';


sub IdCheck
{
    local(*e, *r, $buffer) = @_;
    local($time, $a, $id, $name, $m);
    ($time, $a, $id, $name) = @r;

    if ($buffer =~ /$CONFIRMATION_KEYWORD $id $name/) {
	return 1;
    }
    else {
	$m .= "Confirmation Syntax Error:\n";
	$m .= "The Syntax is following style, check again\n\n";
	$m .= "$CONFIRMATION_KEYWORD password $name\n";
	$m .= "\nwhere this \"password\" can be seen\n";
	$m .= "in the confirmation request mail from $main'MAIL_LIST.\n";
	&Mesg(*e, $m);
	$e{'message:append:files'} = $CONFIRMATION_FILE;
	return 0;
    }
}

sub BufferSyntax
{
    local(*e, $buffer) = @_;
    local($name);

    if ($buffer =~ /$CONFIRMATION_SUBSCRIBE\s+(\S+.*)/) { # require anything;
	$name = $1;
    }
    else {
	&Mesg(*e, "Syntax Error! Please use the following syntax");
	&Mesg(*e, "   $CONFIRMATION_SUBSCRIBE Your-Name");
	&Mesg(*e, "Please use not only E-Mail Address but Your Name");
	&Mesg(*e, "for clearer identification in subscription.");
	&Mesg(*e, "\n Example:");
	&Mesg(*e, "   $CONFIRMATION_SUBSCRIBE Elena Lolabrigita");
	&Mesg(*e, "\n PLEASE DO NOT USE E-Mail Address like a");
	&Mesg(*e, "   $CONFIRMATION_SUBSCRIBE Elena\@baycity.pacific");
	return 0;
    }

    if ($buffer =~ /\@/) {
	&Mesg(*e, "Please use your name NOT E-Mail Address!");
	&Mesg(*e, "For Example:");
	&Mesg(*e, "\t\"$CONFIRMATION_SUBSCRIBE Elena Lolabrigita\"");
	return 0;
    }
    else {
	return $name;
    }
}

sub FirstTimeP
{
    local(*r, $addr, $cur_time) = @_;
    local($time, $key_addr, $a, $id, $match, $addr_found);
    
    # init variables;
    $cur_time   = time;
    ($key_addr) = split(/\@/, $addr);

    open(FILE, $CONFIRMATION_LIST) || 
	(&Log("cannot open $CONFIRMATION_LIST"), return $NULL);
    while (<FILE>) {
	chop;
	($time, $a, $id, $name) = split(/\s+/, $_, 4);

	# pre-match for faster code;
	next if $a !~ /^$key_addr/i;

	# address match
	&AddressMatch($addr, $a) || next;

	# already address is OK;
	if ($time + ($CONFIRMATION_EXPIRE*3600) < $cur_time) {
	    &Log("Confirmation [id=$id] is already Expired");
	    return 'expired';
	}
	else {
	    @r = ($time, $a, $id, $name);
	    return 'confirmed';
	}
    }
    close(FILE);

    @r = ($time, $a, $id, $name);
    return 'first-time';
}


sub Save
{
    local($addr, $id, $time, $file) = @_;
}
 

sub GenKey
{
    local($seed) = @_;
    local($key)  = time|$$;

    srand($key);
    int(rand($seed + $key));
}

1;
