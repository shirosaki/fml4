#-*- perl -*-
#
#  Copyright (C) 2002,2003 Ken'ichi Fukamachi
#   All rights reserved. This program is free software; you can
#   redistribute it and/or modify it under the same terms as Perl itself.
#
# $FML: log.pm,v 1.21 2003/10/18 06:50:29 fukachan Exp $
#

package FML::Command::Admin::log;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $AUTOLOAD);
use Carp;


=head1 NAME

FML::Command::Admin::log - log file operations

=head1 SYNOPSIS

See C<FML::Command> for more details.

=head1 DESCRIPTION

show log file(s).

=head1 METHODS

=head2 process($curproc, $command_args)

=cut


# Descriptions: constructor.
#    Arguments: OBJ($self)
# Side Effects: none
# Return Value: OBJ
sub new
{
    my ($self) = @_;
    my ($type) = ref($self) || $self;
    my $me     = {};
    return bless $me, $type;
}


# Descriptions: need lock or not
#    Arguments: none
# Side Effects: none
# Return Value: NUM( 1 or 0)
sub need_lock { 0;}


# Descriptions: show log file.
#    Arguments: OBJ($self) OBJ($curproc) HASH_REF($command_args)
# Side Effects: update $member_map $recipient_map
# Return Value: none
sub process
{
    my ($self, $curproc, $command_args) = @_;
    my $config   = $curproc->config();
    my $log_file = $config->{ log_file };
    my $options  = $command_args->{ options };
    my $address  = $command_args->{ command_data } || $options->[ 0 ];

    # XXX-TODO: we should provide $curproc->util->get_print_style() ?
    my $style    = $curproc->get_print_style();

    if (-f $log_file) {
	$self->{ _curproc } = $curproc;
	$self->_show_log($log_file, { printing_style => $style });
    }
}


# Descriptions: show cgi menu
#    Arguments: OBJ($self)
#               OBJ($curproc) HASH_REF($args) HASH_REF($command_args)
# Side Effects: update $member_map $recipient_map
# Return Value: none
sub cgi_menu
{
    my ($self, $curproc, $args, $command_args) = @_;
    my $config   = $curproc->config();
    my $log_file = $config->{ log_file };
    my $style    = $curproc->get_print_style();

    if (-f $log_file) {
	$self->{ _curproc } = $curproc;
	$self->_show_log($log_file, { printing_style => $style });
    }
}


# Descriptions: show log file.
#    Arguments: OBJ($self) STR($log_file) HASH_REF($args)
# Side Effects: none
# Return Value: none
sub _show_log
{
    my ($self, $log_file, $args) = @_;
    my $is_cgi       = 1 if $args->{ printing_style } eq 'html';
    my $last_n_lines = 30;
    my $linecount    = 0;
    my $maxline      = 0;
    my $curproc      = $self->{ _curproc };
    my $charset      = $curproc->get_charset($is_cgi ? "cgi" : "log_file");

    use Mail::Message::Encode;
    my $obj = new Mail::Message::Encode;

    use FileHandle;
    my $fh = new FileHandle $log_file;
    my $wh = \*STDOUT;

    if (defined $fh) {
	while (<$fh>) { $maxline++;}
	$fh->close();

	$fh = new FileHandle $log_file;
	my $s = '';
	$maxline -= $last_n_lines;

	if ($is_cgi) { print $wh "<pre>\n";}

	# show the last $last_n_lines lines by default.
	my $buf;
      LINE:
	while ($buf = <$fh>) {
	    next LINE if $linecount++ < $maxline;

	    $s = $obj->convert( $buf, $charset );

	    if ($is_cgi) {
		print $wh (_html_to_text($s));
		print $wh "\n";
	    }
	    else {
		print $wh $s;
	    }
	}
	$fh->close;

	if ($is_cgi) { print $wh "</pre>\n";}
    }
}


# Descriptions: convert text to html
#    Arguments: STR($str)
# Side Effects: none
# Return Value: STR
sub _html_to_text
{
    my ($str) = @_;

    eval q{
	use HTML::FromText;
    };
    unless ($@) {
	return text2html($str, urls => 1, pre => 0);
    }
    else {
	croak($@);
    }
}


=head1 CODING STYLE

See C<http://www.fml.org/software/FNF/> on fml coding style guide.

=head1 AUTHOR

Ken'ichi Fukamachi

=head1 COPYRIGHT

Copyright (C) 2002,2003 Ken'ichi Fukamachi

All rights reserved. This program is free software; you can
redistribute it and/or modify it under the same terms as Perl itself.

=head1 HISTORY

FML::Command::Admin::log first appeared in fml8 mailing list driver package.
See C<http://www.fml.org/> for more details.

=cut


1;