# Copyright (C) 1993-1999 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1999 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$


# ContentHandler() by <t-nakano@imasy.or.jp>
# see fml-support ML articles for more details. For example, 
# 6229 6230 6233 6234 6235 6242 6243 6244 6245 6246 6247 6248 6253 6257
# 6263 6265 6270 6276 6313 6314 6331 6332 6333 6346 6348 6349 6350 6374
# 6379 6381 6393 6396 6397 6408 ...
sub ContentHandler
{
    local(*e) = @_;
    local($boundary) = $e{'MIME:boundary'};
    local($type, $subtype, $paramaters);
    local($xtype, $xsubtype);
    local($ptr, $header, $body, $prevp);
    local($reject, $multipart, $cutoff);
    local(@actions) = ();
    local($nonMime) = 0;
    
    # Split Bodie's Content-Type($paramaters is dummy) '
    ($type, $subtype, $paramaters) = split(/[\/;]/, $e{'h:content-type:'}, 3);
    $type =~ s/\s//g;
    $subtype =~ s/\s//g;
    $nonMime = 1 if ($type eq '');
    
    $ptr = 0;
    $multipart = 1;
    while ($multipart) {
	local($bodiesp, $action);
	
	# Check Content-Type Header
	if ($nonMime) {
	    # Non MIME mail
	    $type = '!MIME';
	    $subtype = '';
	    $xtype = '';
	    $xsubtype = '';
	    $multipart = 0;
	    $header = $type;
	    $bodiesp = -1;
	}
	else {
	    if ($type ne 'multipart') {
		$xtype = '';
		$xsubtype = '';
		$multipart = 0;
		$header = $type;
		$bodiesp = -1;
	    }
	    else {
		local(@xheader, $str);
		
		# MIME mail
		$prevp = $ptr;
		($header, $body, $ptr) = &GetNextMultipartBlock(*e, $ptr);
		if ($header eq '' && $body eq '' && $ptr == 0) {
		    # No more part/break do-while
		    last;
		}
		$bodiesp = $prevp;
		# Get Content-Type
		@xheader = split(/\n/, $header);
		foreach (@xheader) {
		    if (/^Content-Type:/io) {
			$str = $_;
			$str =~ s/^Content-Type:\s*//i;
			($xtype, $xsubtype, $paramaters) =
			    split(/[\/;]/, $str, 3);
			$xtype =~ s/\s//g;
			$xsubtype =~ s/\s//g;
			last;
		    }
		}
	    }
	}
	# Decide action to this part
	$action = 'allow';
	foreach (@MailContentHandler) {
	    local($t, $st, $xt, $xst, $act) = split(/\t/);
	    
	    if ($type =~ /^$t$/i && $subtype =~ /^$st$/i &&
		$xtype =~ /^$xt$/i && $xsubtype =~ /^$xst$/i) {
		$action = $act;
		last;
	    }
	}
	push (@actions, join("\t", $bodiesp, $action));
    }
    
    # Check REJECT, MULTIPART, CUTOFF
    $reject = grep(/^.*\treject$/, @actions);
    $multipart = grep(/^.*\tallow+multipart$/, @actions);
    $cutoff = grep(/^.*\tstrip$/, @actions);
    
    # Rebuild message body
    if ($reject) {
	&Mesg(*e, "We deny non plaintext mails", 'filter.reject_non_text_mail');
	&MesgMailBodyCopyOn;
	&Log("Reject multipart mail");
	return "reject";
    } 
    else {
	local($outputbody) = '';
	local($deletebody) = '';
	
	if ($multipart) {
	    if ($boundary eq '') {
		$boundary = 'simplebounrady==';
	    }
	    foreach (@actions) {
		local($bodiesp, $action) = split(/\t/);
		
		if ($bodiesp == -1) {
		    $body = $e{'Body'};
		    $header = '!MIME';
		} 
		else {
		    ($header, $body, $ptr) =
			&GetNextMultipartBlock(*e, $bodiesp);
		}
		if ($action eq 'allow' ||
		    $action eq 'allow+multipart' ||
		    $action eq '') {
		    if ($header eq '!MIME') {
			$outputbody .= '--' . $boundary . "\n" .
			    "Content-Type:" . $e{'h:content-type:'} . "\n\n" .
				$body;
		    } 
		    else {
			$outputbody .= $header . $body;
		    }
		} 
		elsif ($action eq 'strip+notice') {
		    if ($header eq '!MIME') {
			$deletebody .= $body . "\n";
		    }
		    else {
			$deletebody .= $header . $body . "\n";
		    }
		}
		# strip is do-nothing
	    }
	    $outputbody .= '--' . $boundary . "--\n";
	    # Fix mail header
	    if ($nonMime) {
		$e{'h:Content-Type:'} =
		    "multipart/mixed; boundary=\"$boundary\"";
		$e{'h:Mime-Version:'} = '1.0';
		$e{'h:Content-Transfer-Encoding:'} = '7bit';
	    }
	} 
	else {
	    local($singlepart) = 0;
	    
	    foreach (@actions) {
		local($bodiesp, $action) = split(/\t/);
		
		if ($bodiesp == -1) {
		    $body = $e{'Body'};
		    $header = '!MIME';
		    $singlepart = 1;
		} 
		else {
		    ($header, $body, $ptr) =
			&GetNextMultipartBlock(*e, $bodiesp);
		}
		if ($action eq 'allow' || $action eq '') {
		    $outputbody .= $body;
		} elsif ($action eq 'strip+notice') {
		    if ($header eq '!MIME') {
			$deletebody .= $body . "\n";
		    } 
		    else {
			$deletebody .= $header . $body . "\n";
		    }
		}
		# strip is do-nothing
	    }
	    # Fix mail header, if original is multipart.
	    if (!$singlepart) {
		$e{'h:Content-Type:'} = 'text/plain';
		$e{'h:Mime-Version:'} = '1.0';
		$e{'h:Content-Transfer-Encoding:'} = '7bit';
	    }
	}
	$e{'Body'} = $outputbody;
	if ($deletebody ne '') {
	    # Notice
	    &Mesg(*e, "strip attachments", 
		  'filter.strip_notice_non_text_mail');
	    &Mesg(*e, $deletebody);
	    &Log("Strip multipart mail and return notice");
	    return ('strip+notice');
	}
	if ($cutoff) {
	    &Log("Strip multipart mail");
	    return ('strip');
	}
	return ($NULL);
    }
    $NULL;
}


sub AgainstReplyWithNoRef
{
    local(*e, $pat) = @_;
    local($buf, @buf);

    # no $SUBJECT_FREE_FORM_REGEXP defined
    if ($SUBJECT_FREE_FORM_REGEXP eq '') {
	&Log("ERROR: \$AGAINST_MAIL_WITHOUT_REFERENCE not work "
	     ."without \$SUBJECT_FREE_FORM_REGEXP");
	return $NULL;
    }

    # add "forced Messasge-ID:";
    &ADD_FIELD('X-Original-Message-Id');
    $e{'h:X-Original-Message-Id:'} = $e{'h:message-id:'};
    $e{'h:Message-Id:'} = "<mid-". $ID . "-". $MAIL_LIST.">";

    # fml-support: 6219; add by kokubo776@okisoft.co.jp 05/15/1999
    # check subject tag in mis-encoded ASCII char
    if ($e{'h:subject:'} =~ /=\?ISO\-2022\-JP\?/io
	&& ($e{'h:subject:'} !~ /($SUBJECT_FREE_FORM_REGEXP)/)) {
	&use('MIME');
        $e{'h:subject:'} = &DecodeMimeStrings($e{'h:subject:'});
        $e{'h:subject:'} = &mimeencode($e{'h:subject:'});
        $e{'h:subject:'} =~ s/\n$//;
    }

    # extract/speculate referenced Message-ID:
    # IF BOTH Message-ID: and In-Reply-To: DO NOT EXIST!
    # e.g. [Elena 00100] => 00100 => 100
    if ($e{'h:subject:'} =~ /($SUBJECT_FREE_FORM_REGEXP)/) {
	$buf = $1;
	if ($BRACKET_SEPARATOR ne '') {
	    @buf = split($BRACKET_SEPARATOR, $buf);
	}

	# we need to extrace the ID part only to generate virtual Message-ID.
	# e.g. [Elena 00100] => 00100 => 100
	$buf = $buf[1] || $buf[0] || $buf;
	$buf =~ s/\D//g;
	$buf =~ s/^0+//;

	local($xref) = "<mid-${buf}-$MAIL_LIST>";

	# append it to References:.
	# If we can emulate Message-ID: and the references: does not
	# contain it, we add it. fml-support: 05852
	if ($buf &&
	    ($e{'h:references:'} !~ /$xref/i) &&
	    ($e{'h:in-reply-to:'} !~ /$xref/i)) {
	    $e{'h:References:'} .= " ". $xref;
	}
    }
    else {
	&Log("AgainstEudora: subject has no tag") if $debug;
    }
}


1;
