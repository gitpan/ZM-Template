# Zet Maximum template parser
#
#		1999-2000
#		Version 0.0.3	production
#		Author	Maxim Kashliak	(maxico@softhome.net)
#				Aleksey Ivanov	(avi@zmaximum.ru)
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

$ZM::Template::VERSION = '0.0.3';

my %tokens;

sub new()
{
    my $class = shift;
    my %baseHtml = ();
    bless \%baseHtml, $class;
    return \%baseHtml
}

sub src()
{
    if ($#_ != 1)
    {
        die_msg("Error! template function requires a single parameter\n");
    }

    my $self = shift;
    my $src = shift;

    my $suxx=$/;
    undef $/;
    open(HTML, "<$src") || die_msg("Cannot open html template file!<br>$src");
    my $tmplString = <HTML>;
    close HTML;
    $/=$suxx;
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
#    print $htmlString;
    my ($padding, $token, $remainder);

    while ($htmlString =~ /.*?((__x_.+?__\n)|(__.+?__))/sg)
    {
        $token = $1;
        $token =~ s/\n$//g;         # chomp $token (chomp bust as $/ undef'd)
	$token =~ s/(^__|__$)//g;

#print " find token $token\n";
	$tokens{$token}=1;
    }

}

sub AUTOLOAD
{
        my $token = $AUTOLOAD;
        my ($self, $value, $block) = @_;
#	print $self->{html};
        $token =~ s/.*:://;
	if (defined $tokens{$token})
	{
#	    print "->$token used\n";
#	    if (substr($block,0,2) eq "x_")
	    if ($block ne "")
	    {
		my $bl_new=$block."_new";
		$bl_new=~s/^x_//; #надо обойтись без регекспа
		if ($self->{loops}{$bl_new} ne "") 
		{
#		    print $self->{loops}{$bl_new}."\n---------------\n";
		    $self->_post_loop($block) unless(strstr($self->{loops}{$bl_new},"__".$token."__"));
#		    $self->_post_loop($block);
		}
#		print "Loop used\n";
		$self->_set_loop($token,$value,$block);
	    }
	    else
	    {
#		print "Var sets\n";
    		$self->{html}=$self->set_to_str($token,$value,$self->{html});
	    }
	}
	else
	{
#	    print "$token NOT found\n";
	}
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
#	print "ВИЖУ!\n";
        $loop=$self->{loops}{$block."_new"};
    }
    else
    {
        $loop_name="__x_".$block."__";
        $loop_begin=strstr($self->{html},$loop_name);
        $loop_begin=substr($loop_begin,length($loop_name));
        $loop=str_before($loop_begin,$loop_name);
    }
    if(strstr($loop,"__z_".$block."__"))
    {
        $num=$self->{strnum}{$block};
        $loop2=$loop3=$loop;
        while(($num)&&($loop2=str_before($loop3,"__z_".$block."__")))
        {
            $num--;
            $loop3=str_after($loop3,"__z_".$block."__");
        }
        if($num==0)
        {
            $loop=$loop2;
            $self->{strnum}{$block}++;
        }
	elsif($num>=1)
	{
            $loop=str_before($loop,"__z_".$block."__");
            $self->{strnum}{$block}=2;
        }
#        print "#LOOP:$loop NUM:$num\n\n";
    }
    $self->{loops}{$block."_new"}=$self->set_to_str($token,$value,$loop);
#    print "-----------LOOP: ".$block."_new".":\n".$self->{loops}{$block."_new"}."\n-----------\n";
}


sub _post_loop
{
    my $self=shift;
    my $block=shift;

    $block=~s/^x_//;

    my ($text,$pos, $before_loop, $loop, $loop_name, $after_loop);
    #Find inner loops
    $text=$self->{loops}{$block."_new"};
    while($pos=strstr($text,"__x_"))
    {
        $before_loop=substr($text,0,length($text)-length($pos));
        $loop_name=substr($pos,4);
        $loop_name=substr($loop_name,0,length($loop_name)-length(strstr($loop_name,"__")));
        $loop=strstr($text,"__x_".$loop_name."__");
        $after_loop=str_after(str_after($loop,"__x_".$loop_name."__"),"__x_".$loop_name."__");
        $loop=substr($loop,0,length($loop)-length($after_loop));
        $self->_post_loop($loop_name);
        $text=$before_loop.$self->{loops}{$loop_name}.$after_loop;
        $self->{loops}{$loop_name}="";
        $self->{strnum}{$loop_name}="";
    }
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
    while(($sub_str=str_before($str,"__x_")) ne $str)
    {
	    # получаем имя цикла
		$loop_name=str_before(substr($str,length($sub_str)+4),"__");
		# заменяем переменную перед циклом, если она там есть
        $ret.=str_replace("__".$token."__",$value,$sub_str);
        $ret.="__x_".$loop_name."__".str_before(substr($str,length($sub_str)+length($loop_name)+6),"__x_".$loop_name."__")."__x_".$loop_name."__";
        $str=str_after(substr($str,length($sub_str)+length($loop_name)+6),"__x_".$loop_name."__");
    }
    $ret.=str_replace("__".$token."__",$value,$str);
    return($ret);
}

sub fill_loops
{	
    my $self=shift;
    my $text=shift;

    my ($pos, $before_loop, $loop_name, $loop, $after_loop);

    # постим те лупы, что запонились, ноне заполнились
    foreach(keys %{$self->{loops}})
    {
		if (($loop_name=str_before($_,"_new")) ne $_)
		{
	    	$self->_post_loop($loop_name) if($self->{loops}{$_} ne "");
		}
    }
    # удаляем незаполненные лупы
    while($pos=strstr($text,"__x_"))
    {
        $before_loop=substr($text,0,length($text)-length($pos));
        $loop_name=substr($pos,4);
        $loop_name=substr($loop_name,0,length($loop_name)-length(strstr($loop_name,"__")));
        $loop=strstr($text,"__x_".$loop_name."__");
        $after_loop=str_after(str_after($loop,"__x_".$loop_name."__"),"__x_".$loop_name."__");
        $loop=substr($loop,0,length($loop)-length($after_loop));
        $text=$before_loop.$self->{loops}{$loop_name}.$after_loop;
    }
    $text=~s/__[\d\w_\-]+__//g;
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
#    my $strbef=str_before($str2,$str);
#    if ($strbef ne $str2)
#    {
#	return ($strbef.$str1.str_after($str2,$str));
#    }
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

    $self->{html}=$self->fill_loops($self->{html});
    print $self->{html};
}

sub htmlString()
{
    my $self = shift;
    $self->{html}=$self->fill_loops($self->{html});
    return $self->{html};
}

sub DESTROY()
{
}

sub die_msg
{
    my $msg = shift;
    print "$msg\n";
    die;
}

1;

__END__

=head1 NAME

ZM::Template - Merges runtime data with static HTML or Plain Text template file.

=head1 VERSION

 Template.pm v 0.0.3

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

 use HTMLTMPL;

 # Create a template object and load the template source.
 $templ = new HTMLTMPL;
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

=head1 METHODS

src($)

The single parameter specifies the name of the template file to use.

srcString($)

If the template is within a string rather than a file, use this method to
populate the template object.

output(@)

Merges the data already passed to the HTMLTMPL instance with the template file
specified in src().
The optional parameter is output first, followed by a blank line. These form
the HTTP headers.

htmlString()

Returns a string of html produced by merging the data passed to the HTMLTMPL
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

 use HTMLTMPL;

 # Create a template object and load the template source.
 $templ = new HTMLTMPL;
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

 use HTMLTMPL;

 # Create the template object and load it.
 $templ = new HTMLTMPL;
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

=head2 Example 5.

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

 use HTMLTMPL;

 # Create a template object and load the template source.
 my($templ) = new HTMLTMPL;
 $templ->src('example5.html');


 # Set values for tokens within the page
 $templ->surname('Smyth');
 $templ->firstname('Arthur');
 $templ->nickname('Art!');

 my $subTmpl = new HTMLTMPL;
 $subTmpl->src('example5a.html');
 $subTmpl->widget('this is widget');
 $subTmpl->wodget('this is wodget');

 $templ->guts($subTmpl->htmlString);

 # Send the merged page and data to the web server as a standard text/html mime
 #       type document
 $templ->output('Content-Type: text/html');


=head1 HISTORY

 Oct 2003	Version 0.0.3	First release

=head1 AUTHOR

 Zet Maximum ltd.
 Maxim Kashliak
 Aleksey Ivanov
 http://www.zmaximum.ru/
 http://perl.zmaximum.ru
 
