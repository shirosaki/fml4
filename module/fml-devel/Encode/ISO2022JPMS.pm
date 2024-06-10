package Encode::ISO2022JPMS;
use strict;

our $VERSION = "0.1";

use Encode qw(:fallbacks);

use base qw(Encode::Encoding);
__PACKAGE__->Define('iso-2022-jp-ms');
Encode::define_alias(qr/\biso-?2022-?jp-?ms$/i =>  '"iso-2022-jp-ms"');

# we override this to 1 so PerlIO works
sub needs_lines { 1 }

my %_0208 = (
	       1978 => '\e\$\@',
	       1983 => '\e\$B',
		);

my %ESC =  (
	 JIS_0208 => "\e\$B",
	 ASC      => "\e\(B",
	 KANA     => "\e\(I",
	 UDC      => "\e\$(?",
	 );

my %RE =
    (
     ASCII     => '[\x00-\x7f]',
     JIS_0208  =>  "$_0208{1978}|$_0208{1983}",
     JIS_KANA  => "\e" . '\(I',
     ISO_ASC   => "\e" . '\([BJ]',     
     ISO_UDC   => "\e" . '\$\(\?',
     SJIS_C    => '[\x81-\x9f\xe0-\xfc][\x40-\x7e\x80-\xfc]',
     SJIS_KANA => '[\xa1-\xdf]',
     );

#
# decode
#

sub decode($$;$)
{
    my ($obj, $str, $chk) = @_;
    my $residue = '';
    if ($chk){
	$str =~ s/([^\x00-\x7f].*)$//so and $residue = $1;
    }
    $residue .= jis_sjis(\$str);
    $_[1] = $residue if $chk;
    return Encode::decode('cp932', $str, FB_PERLQQ);
}

#
# encode
#

sub encode($$;$)
{
    my ($obj, $utf8, $chk) = @_;
    # empty the input string in the stack so perlio is ok
    $_[1] = '' if $chk;
    my $octet = ibm2nec(Encode::encode('cp932', $utf8, FB_PERLQQ));
    sjis_jis(\$octet);
    return $octet;
}

#
# cat_decode
#
my $re_scan_jis_g = qr{
   \G ( ($RE{ISO_0208}) | ($RE{ISO_ASC}) |
        ($RE{JIS_KANA}) | ($RE{ISO_UDC}) | )
      ([^\e]*)
}x;
sub cat_decode { # ($obj, $dst, $src, $pos, $trm, $chk)
    my ($obj, undef, undef, $pos, $trm) = @_; # currently ignores $chk
    my ($rdst, $rsrc, $rpos) = \@_[1,2,3];
    local ${^ENCODING};
    use bytes;
    my $opos = pos($$rsrc);
    pos($$rsrc) = $pos;
    while ($$rsrc =~ /$re_scan_jis_g/gc) {
	my ($esc, $esc_0208, $esc_asc, $esc_kana, $esc_udc, $chunk) =
	  ($1, $2, $3, $4, $5, $6);

	unless ($chunk) { $esc or last;  next; }

	if ($esc && !$esc_asc) {
	    if ($esc_0208) {
		$chunk = _jis_sjis($chunk);
	    }
	    elsif ($esc_kana) {
		$chunk =~ tr/\x21-\x5f/\xa1-\xdf/;
	    }
	    elsif ($esc_udc) {
		$chunk =~ s{([\x21-\x34][\x21-\x7e])}
		{
		    my ($c1, $c2) = unpack('CC', $1);
		    pack('CC', $c1 + 0x5e, $c2);
		}geox;
		$chunk = _jis_sjis($chunk);
	    }
	    $chunk = Encode::decode('cp932', $chunk, 0);
	}
	elsif ((my $npos = index($chunk, $trm)) >= 0) {
	    $$rdst .= substr($chunk, 0, $npos + length($trm));
	    $$rpos += length($esc) + $npos + length($trm);
	    pos($$rsrc) = $opos;
	    return 1;
	}
	$$rdst .= $chunk;
	$$rpos = pos($$rsrc);
    }
    $$rpos = pos($$rsrc);
    pos($$rsrc) = $opos;
    return '';
}

# JIS<->SJIS
my $re_scan_jis = qr{
   (?:($RE{JIS_0208})|($RE{ISO_ASC})|($RE{JIS_KANA})|($RE{ISO_UDC}))([^\e]*)
}x;

sub jis_sjis {
    local ${^ENCODING};
    my $r_str = shift;
    $$r_str =~ s($re_scan_jis)
    {
	my ($esc_0208, $esc_asc, $esc_kana, $esc_udc, $chunk) =
	   ($1, $2, $3, $4, $5);
	if (!$esc_asc) {
	    if ($esc_0208) {
		$chunk = _jis_sjis($chunk);
	    }
	    elsif ($esc_kana) {
		$chunk =~ tr/\x21-\x5f/\xa1-\xdf/;
	    }
	    elsif ($esc_udc) {
		$chunk =~ s{([\x21-\x34][\x21-\x7e])}
		{
		    my ($c1, $c2) = unpack('CC', $1);
		    pack('CC', $c1 + 0x5e, $c2);
		}geox;
		$chunk = _jis_sjis($chunk);
	    }
	}
	$chunk;
    }geox;
    my ($residue) = ($$r_str =~ s/(\e.*)$//so);
    return $residue;
}

sub sjis_jis {
    my $r_str = shift;
    $$r_str =~ s{
	((?:$RE{SJIS_C})+)
	}{
	    my $chunk = $1;
	    $chunk = _sjis_jis($chunk);
	    my $esc = ($chunk =~ tr/\x7f-\x92/\x21-\x34/) ? $ESC{UDC} :
		                                            $ESC{JIS_0208};
	    $esc . $chunk . $ESC{ASC};
	}geox;
    $$r_str =~ s{
	((?:$RE{SJIS_KANA})+)
	}{
	    my $chunk = $1;
	    $chunk =~ tr/\xa1-\xdf/\x21-\x5f/;
	    $ESC{KANA} . $chunk . $ESC{ASC};
	}geox;
    $$r_str =~
	s/\Q$ESC{ASC}\E
	    (\Q$ESC{JIS_0208}\E|\Q$ESC{KANA}\E|\Q$ESC{UDC}\E)/$1/gox;
    $$r_str;
}

my %_S2J = ();
my %_J2S = ();

sub _sjis_jis {
    my $thingy = shift;
    my $r_str = ref $thingy ? $thingy : \$thingy;
    $$r_str =~ s(
		 ($RE{SJIS_C})
	     )
    {
	my $str = $1;
	unless ($_S2J{$1}){
	    my ($c1, $c2) = unpack('CC', $str);
	    if (0x9f <= $c2) {
		$c1 = $c1 * 2 - ($c1 >= 0xe0 ? 0x160 : 0xe0);
		$c2 -= 0x7e;
	    } else {
		$c1 = $c1 * 2 - ($c1 >= 0xe0 ? 0x161 : 0xe1);
		$c2 -= 0x20 - ($c2 < 0x7f);
	    }
	    $_S2J{$str} = pack('CC', $c1, $c2);
	}
	$_S2J{$str};
    }geox;
    $$r_str;
}

sub _jis_sjis {
    my $thingy = shift;
    my $r_str = ref $thingy ? $thingy : \$thingy;
    $$r_str =~ s(
		 ([\x21-\x98][\x21-\x7e])
		 )
    {
	my $str = $1;
	unless ($_J2S{$str}){
	    my ($c1, $c2) = unpack('CC', $str);
	    if ($c1 % 2) {
		$c1 = ($c1>>1) + ($c1 < 0x5f ? 0x71 : 0xb1);
		$c2 += 0x20 - ($c2 < 0x60);
	    } else {
		$c1 = ($c1>>1) + ($c1 < 0x5f ? 0x70 : 0xb0);
		$c2 += 0x7e;
	    }
	    $_J2S{$str} = pack('CC', $c1, $c2);
	}
	$_J2S{$str};
    }geox;
    $$r_str;
}

#

my $re_sjis = "$RE{ASCII}|$RE{SJIS_C}|$RE{SJIS_KANA}";
my $re_cp932ibm = '[\xfa-\xfc][\x40-\x7e\x80-\xfc]';

sub ibm2nec {
    my $octet = shift;
    $octet =~ s/\G((?:$re_sjis)*?)($re_cp932ibm)/$1 . _ibm2nec($2)/geo;
    return $octet;
}

sub _ibm2nec {
    my ($c1, $c2) = unpack('CC', shift);
    my $linear = $c1 * 188 + (($c2 < 0x7f) ? ($c2 - 0x40) : ($c2 - 0x41));
    if (0xb7b4 <= $linear) {
	$linear -= 0x09a8;
    }
    elsif (0xb7ad <= $linear) {
	$linear -= 0x82c;
    }
    else {
	$linear -= 0x822;
    }
    $c1 = int($linear / 188);
    $c2 = $linear % 188 + 0x40;
    $c2++ if ($c2 > 0x7e);
    return pack('CC', ($c1, $c2));
}

1;
__END__
