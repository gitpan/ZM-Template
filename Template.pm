# Zet Maximum template parser
#
#		2002-2003
#		Version 0.5.2	production
#		Author	Maxim Kashliak	(maxico@softhome.net)
#				Aleksey V. Ivanov	(avimail@zmaximum.ru)
#
#		For latest releases, documentation, faqs, etc see the homepage at
#			http://perl.zmaximum.ru
#
#

package ZM::Template;

use strict;
use vars qw($AUTOLOAD);
use Carp;

no strict 'refs';

$ZM::Template::VERSION = '0.5.2';

my %tokens;

sub new()
{
    my $class = shift;
	my %baseHtml=@_;
	$baseHtml{tag}="__" if ($baseHtml{tag} eq "");
    bless \%baseHtml, $class;
    return \%baseHtml
}

sub src()
{
    if ($#_ !=1)
    {
        die_msg("Error! template function requires a single parameter\n");
    }

    my $self = shift;
    my $src = shift;

    my $suxx=$/;
    undef $/;
    open(HTML, "<$src") || die_msg("Cannot open html template file!<br>($src)");
    my $tmplString = <HTML>;
    close HTML;
    $/=$suxx;
	# обработка SSI деректив внутри темплейта
	eval('require ZM::SSI;');
	$tmplString = ZM::SSI::parse($tmplString) unless $@;
	$self->srcString($tmplString);
}

sub srcString
{
	my $self = shift;
	my $str = shift;
	$self->{html}=$str;
    _parse_tokens($self,$str);
}

sub listAllTokens
{
	my $self=shift;
	return(keys %tokens);
}

sub _parse_tokens
{
    my $self=shift;
    my $htmlString=shift;
    my ($padding, $token, $remainder);

    while ($htmlString =~ /.*?(($self->{tag}x_.+?$self->{tag}\n)|($self->{tag}([^_]).*?$self->{tag}))/sg)
    {
        $token = $1;
        $token =~ s/\n$//g;         # chomp $token (chomp bust as $/ undef'd)
		$token =~ s/(^$self->{tag}|$self->{tag}$)//g;
		$tokens{$token}=1;
    }
}

sub AUTOLOAD
{
	my $token = $AUTOLOAD;
	my ($self, $value, $block) = @_;
	$token =~ s/.*:://;
	if (defined $tokens{$token})
	{
	    if ($block ne "")
	    {
			my $bl_new=$block."_new";
			$bl_new=~s/^x_//; #надо обойтись без регекспа
			if ($self->{loops}{$bl_new} ne "") 
			{
			    $self->_post_loop($block) unless(strstr($self->{loops}{$bl_new},"$self->{tag}".$token."$self->{tag}"));
			}
			$self->_set_loop($token,$value,$block);
	    }
	    else
	    {
    		$self->{html}=$self->set_to_str($token,$value,$self->{html});
	    }
	}
}

sub setif
{
	my $self = shift;
	my $token = shift;
	my $loop = shift;
	
	if($loop eq "")
	{
		$self->{ifs}->{$token}=1;
	}
	else
	{
		$self->{ifs_loop}->{$loop}->{$token}=1;
	}
}

sub fromfile
{
	my $self = shift;
	my $token = shift;
	my $file = shift;
	my $block = shift;
	
	open (my $f,"<$file") or return;
	my $suxx=$/;
    undef $/;
	my $filecontent=<$f>;
	$/=$suxx;
	$self->$token($filecontent,$block);
}

sub _set_loop
{
    my $self=shift;
    my $token=shift;
    my $value=shift;
    my $block=shift;

    $block=~s/^x_//;

    my ($loop, $loop_name, $loop_begin, $num, $loop2, $loop3);

    if($self->{strnum}{$block} eq "")
    {
        $self->{strnum}{$block}=1;
    }
    if($self->{loops}{$block."_new"} ne "")
    {
		# если уже выставлялись токены в этом цикле
        $loop=$self->{loops}{$block."_new"};
    }
    else
    {
		# если еще не вставлялись токены в этом цикле,
		# то выдираем тело цикла из всего шаблона
        $loop_name="$self->{tag}x_".$block."$self->{tag}";
        $loop_begin=strstr($self->{html},$loop_name);
        $loop_begin=substr($loop_begin,length($loop_name));
        $loop=str_before($loop_begin,$loop_name);
    }
    if(strstr($loop,"$self->{tag}z_".$block."$self->{tag}"))
    {
        $num=$self->{strnum}{$block};
        $loop2=$loop3=$loop;
        while(($num)&&(($loop2=str_before($loop3,"$self->{tag}z_".$block."$self->{tag}")) ne $loop3))
        {
            $num--;
            $loop3=str_after($loop3,"$self->{tag}z_".$block."$self->{tag}");
        }
        if($num==0)
        {
            $loop=$loop2;
            $self->{strnum}{$block}++;
        }
		elsif($num>=1)
		{
            #$loop=str_before($loop,"$self->{tag}z_".$block."$self->{tag}");
			$loop=$loop3;
            $self->{strnum}{$block}=1;
        }
    }
    $self->{loops}{$block."_new"}=$self->set_to_str($token,$value,$loop);
}

sub _post_loop
{
    my $self=shift;
    my $block=shift;

    $block=~s/^x_//;

    my ($text,$pos, $before_loop, $loop, $loop_name, $after_loop);
    #Find and post inner loops
    $text=$self->{loops}{$block."_new"};
    while($pos=strstr($text,"$self->{tag}x_"))
    {
        $before_loop=substr($text,0,length($text)-length($pos));
        $loop_name=substr($pos,4);
        $loop_name=substr($loop_name,0,length($loop_name)-length(strstr($loop_name,"$self->{tag}")));
        $loop=strstr($text,"$self->{tag}x_".$loop_name."$self->{tag}");
        $after_loop=str_after(str_after($loop,"$self->{tag}x_".$loop_name."$self->{tag}"),"$self->{tag}x_".$loop_name."$self->{tag}");
        $loop=substr($loop,0,length($loop)-length($after_loop));
        $self->_post_loop($loop_name);
        $text=$before_loop.$self->{loops}{$loop_name}.$after_loop;
        $self->{loops}{$loop_name}="";
        $self->{strnum}{$loop_name}="";
    }
	$text=_fill_ifs($self,$text,"x_".$block);
    $self->{loops}{$block."_new"}=$text;
    #POST
    $self->{loops}{$block}.=$self->{loops}{$block."_new"};
    $self->{loops}{$block."_new"}="";
}

sub set_to_str
{
    my $self=shift;
    my $token=shift;
    my $value=shift;
    my $str=shift;

    my $ret="";
    my $sub_str;
    my $loop_name;
    while(($sub_str=str_before($str,"$self->{tag}x_")) ne $str)
    {
	    # получаем имя цикла
		$loop_name=str_before(substr($str,length($sub_str)+4),"$self->{tag}");
		# заменяем переменную перед циклом, если она там есть
        $ret.=str_replace("$self->{tag}".$token."$self->{tag}",$value,$sub_str);
        $ret.="$self->{tag}x_".$loop_name."$self->{tag}".str_before(substr($str,length($sub_str)+length($loop_name)+6),"$self->{tag}x_".$loop_name."$self->{tag}")."$self->{tag}x_".$loop_name."$self->{tag}";
        $str=str_after(substr($str,length($sub_str)+length($loop_name)+6),"$self->{tag}x_".$loop_name."$self->{tag}");
    }
    $ret.=str_replace("$self->{tag}".$token."$self->{tag}",$value,$str);
    return($ret);
}

sub _fill_ifs
{
	my $self=shift;
	my $text=shift;
	my $l_name=shift;
	my ($pos,$before_loop,$loop_name,$loop,$after_loop,$if_name,$h_ifs);
	if($l_name eq "")
	{
		$h_ifs=$self->{ifs};
	}
	else
	{
		$h_ifs=$self->{ifs_loop}->{$l_name};
	}
	
	# удаляем незаполненные IF и вставляем заполненные в окончательный текст
    while($pos=strstr($text,"$self->{tag}if_"))
    {
        $before_loop=substr($text,0,length($text)-length($pos));
        $loop_name=substr($pos,5);
        $loop_name=substr($loop_name,0,length($loop_name)-length(strstr($loop_name,"$self->{tag}")));
		$if_name="$self->{tag}if_".$loop_name."$self->{tag}";
		$loop=$pos;
		$after_loop=str_after(str_after($loop,$if_name),$if_name);
		$loop=substr($loop,length($if_name),length($loop)-length($after_loop)-length($if_name)*2);
		#$loop=substr($loop,length($if_name),length($loop)-length($after_loop));
		#print "##################################\n";
		#print "LOOP $if_name: $loop\n";
		#print "##################################\n";
		#print "AFTERLOOP: $after_loop\n";
		#print "##################################\n";
		unless(defined $h_ifs->{$loop_name})
		{
			#IF не выставлялся
			if($pos=strstr($loop,"$self->{tag}else_".$loop_name))
			{
				#else есть и его надо оставить
				$loop=substr($pos,9+length($loop_name));
			}
			else
			{
				#else нет
				$loop="";
			}
		}
		else
		{
			#убираем содержимое ELSE, если таковой есть
			if($pos=strstr($loop,"$self->{tag}else_".$loop_name))
			{
				#else есть и его надо оставить
				$loop=str_before($loop,$pos);
			}
			undef $h_ifs->{$loop_name};
		}
		$text=$before_loop.$loop.$after_loop;
    }
	return($text);
}

sub _fill_loops
{	
    my $self=shift;
    my $text=shift;

    my ($pos, $before_loop, $loop_name, $loop, $after_loop);

    # постим те лупы, что запонились, но не заполнились
    foreach(keys %{$self->{loops}})
    {
		if (($loop_name=str_before($_,"_new")) ne $_)
		{
	    	$self->_post_loop($loop_name) if($self->{loops}{$_} ne "");
		}
    }
    # удаляем незаполненные лупы и вставляем заполненные в окончательный текст
    while($pos=strstr($text,"$self->{tag}x_"))
    {
        $before_loop=substr($text,0,length($text)-length($pos));
        $loop_name=substr($pos,4);
        $loop_name=substr($loop_name,0,length($loop_name)-length(strstr($loop_name,"$self->{tag}")));
        #$loop=strstr($text,"$self->{tag}x_".$loop_name."$self->{tag}");
		$loop=$pos;
        $after_loop=str_after(str_after($loop,"$self->{tag}x_".$loop_name."$self->{tag}"),"$self->{tag}x_".$loop_name."$self->{tag}");
        $loop=substr($loop,0,length($loop)-length($after_loop));
        $text=$before_loop.$self->{loops}{$loop_name}.$after_loop;
    }
	my $tag=$self->{tag};
	my $if_name;
	$text=_fill_ifs($self,$text);
#	print "|$tag|";
    $text=~s/($tag)[\d\w_\-]+($tag)//g;
    return($text);
}


sub strstr
{
    my $str=shift;
    my $str2=shift;
    my $index=index($str,$str2);
    if ($index>-1)
    {
        $str=substr($str,$index,length($str)-$index);
        return($str);
    }
    else
    {
		return undef;
    }
}

sub str_before
{
    my $str=shift;
    my $str2=shift;
    my $indx=index($str,$str2);
    if($indx!=-1)
    {
	$str=substr($str,0,$indx);
    }
    return $str;
}
sub str_after
{
    my $str=shift;
    my $str2=shift;
    $str=substr($str,index($str,$str2)+length($str2),length($str)-index($str,$str2)-length($str2));
    return($str);
}
sub str_between
{
    my $str=shift;
    my $str1=shift;
    my $str2=shift;
    my $ret=str_after($str,$str1);
    return(str_before($ret,$str2));
}

sub str_replace
{
    my $str=shift;
    my $str1=shift;
    my $str2=shift;
    
    $str2=~s/$str/$str1/g;
    return($str2);
}

sub output()
{
    my $self = shift;
    my $hdr;

    foreach $hdr (@_)
    {
        print "$hdr\n";
    }

    print "\n";
#    $self->{html}=$self->_fill_loops($self->{html});
    print $self->htmlString();
}

sub htmlString()
{
    my $self = shift;

    $self->{html}=$self->_fill_loops($self->{html});
	
    return $self->{html};
}

sub DESTROY()
{
}

sub die_msg
{
    my $msg = shift;
	print "Content-type: text/html\n\n";
	print <<EOF;
	<HTML>
		<HEAD></HEAD>
	<BODY>
		<b>ZM::Template Error:</b> $msg
	</BODY>
	</HTML>
EOF
    exit;
}

1;

__END__

=head1 NAME

ZM::Template - Merges runtime data with static HTML or Plain Text template file.

=head1 VERSION

 Template.pm v 0.5.2

=head1 SYNOPSIS

How to merge data with a template.

The template :

 <html><head><title>parser Example 1</title></head>
 <body bgcolor=beige>
 My name is __firstname__ __surname__ but my friends call me __nickname__.
 <hr>
 </body>
 </html>

The code :

 use ZM::Template;

 # Create a template object and load the template source.
 $templ = new ZM::Template;
 $templ->src('example1.html');

 # Set values for tokens within the page
 $templ->surname('Smyth');
 $templ->firstname('Arthur');
 $templ->nickname('Art!');

 # Send the merged page and data to the web server as a standard text/html mime
 #   type document
 $templ->output('Content-Type: text/html');

Produces this output :

 <html><head><title>parser Example 1</title></head>
 <body bgcolor=beige>
 My name is Arthur Smyth but my friends call me Art!.
 <hr>
 </body>
 </html>

=head1 DESCRIPTION

In an ideal web system, the HTML used to build a web page would
be kept distinct from the application logic populating the web page.
This module tries to achieve this by taking over the chore of merging runtime
data with a static html template.
Template can contain SSI derectives like
<!--#include file="..." --> and
<!--#exec cgi="..." -->
It is used ZM::SSI for SSI parsing. If module ZM::SSI not installed SSI
derectives will be ignoring.

The ZM::Template module can address the following template scenarios :

=over 3

=item *

Single values assigned to tokens

=item *

Multiple values assigned to tokens (as in html table rows)

=item *

Single pages built from multiple templates (ie: header, footer, body)

=item *

html tables with runtime determined number of columns

=back

An template consists of 2 parts; the boilerplate and the tokens (place
holders) where the variable data will sit.

A token has the format __tokenName__ and can be placed anywhere within the
template file. If it occurs in more than one location, when the data is merged
with the template, all occurences of the token will be replaced.

 <p>
 My name is __userName__ and I am aged __age__.
 My friends often call me __nickName__ although my name is __userName__.

When an html table is being populated, it will be necessary to
output several values for each token. This will result in multiple rows in the 
table. However, this will only work if the tokens appear within a repeating
block.

To mark a section of the template as repeating, it needs to be enclosed within
a matching pair of repeating block tokens. These have the format __x_blockName__. They must always come in pairs.

 and I have the following friends
 <table>
 __x_friends__
 <tr>
     <td>__friendName__</td><td>__friendNickName__</td>
 </tr>
 __x_friends__
 </table>

For interleave data in loop used __z_ token

 and I have the following friends
 <table>
 __x_friends__
 <tr>
     <td bgcolor="#FEFEFE">__friendName__</td><td>__friendNickName__</td>
 </tr>
 __z_friends__
 <tr>
     <td bgcolor="#FFFFFF">__friendName__</td><td>__friendNickName__</td>
 </tr>
 __x_friends__
 </table>

Count of __z_ token is UNLIMITED.

Template engine understand inner loops like this

 List of companies:
 __x_companies__
 Company name: __name__
 Company address: __address__
 Company e-mails:
  __x_emails__
  __email__
  __x_emails__
 Company web: __web__
 __x_companies__
 
For condition __if_ token. They must always come in pairs.

 List of companies:
 __x_companies__
 Company name: __name__
 Company address: __address__
 Company e-mails:
  __x_emails__
  __email__
  __x_emails__
 __if_company_web__
 Company web: __web__
 __if_company_web__
 __x_companies__
 
Template engine understand __else_ token within __if_ token.

 List of companies:
 __x_companies__
 Company name: __name__
 Company address: __address__
 Company e-mails:
  __x_emails__
  __email__
  __x_emails__
 __if_company_web__
 Company web: __web__
 __else_company_web__
 Company have not web site
 __if_company_web__
 __x_companies__

=head1 METHODS

src($)

The single parameter specifies the name of the template file to use.

srcString($)

If the template is within a string rather than a file, use this method to
populate the template object.

output(@)

Merges the data already passed to the ZM::Template instance with the template file
specified in src().
The optional parameter is output first, followed by a blank line. These form
the HTTP headers.

htmlString()

Returns a string of html produced by merging the data passed to the ZM::Template
instance with the template specified in the src() method. No http headers are
sent to the output string.

listAllTokens()

Returns an array. The array contains the names of all tokens found within
the template specifed to src() method.

tokenName($)

Assigns to the 'tokenName' token the value specified as parameter.

tokenName($$)

Assigns to the 'tokenName' token, within the repeating block specified in 2nd
parameter, the value specified as the first parameter.

setif(tokenName)

Set true for __if_ token type.

fromfile($$)

Assigns to the token specified as parameter the content of file specified in 2nd
parameter.

fromfile($$$)

Assigns to the token specified as parameter, within the repeating block specified
in 3nd parameter, the value specified in 2nd parameter.

=head1 EXAMPLES

=head2 Example 1.

A simple template with single values assigned to each token.

The template :

 <html><head><title>parser Example 1</title></head>
 <body bgcolor=beige>
 My name is __firstname__ __surname__ but my friends call me __nickname__.
 <hr>
 </body>
 </html>

The code :

 use ZM::Template;

 # Create a template object and load the template source.
 $templ = new ZM::Template;
 $templ->src('example1.html');

 # Set values for tokens within the page
 $templ->surname('Smyth');
 $templ->firstname('Arthur');
 $templ->nickname('Art!');

 # Send the merged page and data to the web server as a standard text/html mime
 #   type document
 $templ->output('Content-Type: text/html');

Produces this output :

 <html><head><title>parser Example 1</title></head>
 <body bgcolor=beige>
 My name is Arthur Smyth but my friends call me Art!.
 <hr>
 </body>
 </html>

=head2 Example 2

Produces an html table with a variable number of rows.

The template :

 <html><head><title>Example 2 - blocks</title></head>
 <body bgcolor=beige>
 <table border=1>
 __x_details__
 <tr>
        <td>__id__</td>
        <td>__name__</td>
        <td>__desc__</td>
 </tr>
 __x_details__
 </table>
 <ul>
 __x_customer_det__
        <li>__customer__</li>
 __x_customer_det__
 </ul>
 <br>
 <hr>
 </body>
 </html>

The code :

 use ZM::Template;

 # Create the template object and load it.
 $templ = new ZM::Template;
 $templ->src('example2.html');

 # Simulate obtaining data from database, etc and populate 300 blocks.

 for ($i=0; $i<300; $i++)
 {
     # Ensure that the token is qualified by the name of the block and load
     #       values for the tokens.
     $templ->id($i, 'x_details');
     $templ->name("the name is $i", 'x_details');
     $templ->desc("the desc for $i", 'x_details');
 }

 for ($i=0; $i<4; $i++)
 {
     $templ->customer("And more $i", 'x_customer_det');
 }

 #    Send the completed html document to the web server.
 $templ->output('Content-Type: text/html');

=head2 Example 3.

Uses 2 seperate templates to produce a single web page :

The overall page template :

 <html>
 <head><title>Example 5 - sub templates</title></head>
 <body bgcolor=blue>

 Surname : __surname__
 First Name : __firstname__
 My friends (both of them) call me : __nickname__

 Now to include a sub template...
 __guts__

 And this is the end of the outer template.
 <hr>
 </body>
 </html>

The subtemplate which will be slotted into the 'guts' token position :

 <table border=1>
 <tr>
     <td>__widget__</td>
     <td>__wodget__</td>
 </tr>
 </table>

The code :

 use ZM::Template;

 # Create a template object and load the template source.
 my($templ) = new ZM::Template;
 $templ->src('example5.html');


 # Set values for tokens within the page
 $templ->surname('Smyth');
 $templ->firstname('Arthur');
 $templ->nickname('Art!');

 my $subTmpl = new ZM::Template;
 $subTmpl->src('example5a.html');
 $subTmpl->widget('this is widget');
 $subTmpl->wodget('this is wodget');

 $templ->guts($subTmpl->htmlString);

 # Send the merged page and data to the web server as a standard text/html mime
 #       type document
 $templ->output('Content-Type: text/html');


=head1 HISTORY

 Jun 2004	Version 0.5.2	Parse SSI before template parsing.
 Oct 2003	Version 0.5.0	Added __else_ token type.
 Oct 2003	Version 0.4.1	Fixed some errors with __z_ token type.
 Oct 2003	Version 0.4.0	Added __if_ token type.
 Oct 2003	Version 0.3.1	Fixed some errors.
 Oct 2003	Version 0.3.0	Added SSI parsing inside template.
 Oct 2003	Version 0.2.0	Added fromfile method.
 Oct 2003	Version 0.1.1	Some fixes in documentation, messages and code.
 Oct 2003	Version 0.1.0	Added __z_ token type.
 Oct 2003	Version 0.0.3	First release.

=head1 AUTHOR

 Zet Maximum ltd.
 Maxim Kashliak
 Aleksey V. Ivanov
 http://www.zmaximum.ru/
 http://perl.zmaximum.ru
 
