# Library of fml.pl 
# Copyright (C) 1994-1995 fukachan@phys.titech.ac.jp
# Please obey GNU Public Licence(see ./COPYING)

local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: lib(.*).pl,v\s+(\S+)\s+/ && "$1[$2]");

&Ftpmail_00 if $LOAD_LIBRARY eq 'libftpmail.pl';

sub Ftpmail_00
{
    require 'libfop.pl';
    require 'libftp.pl';
    &Ftp(*Envelope);
}

1;
