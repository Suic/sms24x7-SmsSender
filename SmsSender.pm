#!/usr/bin/perl

#by Minin Valeriy

package SmsSender;

use strict;
use warnings;
use LWP;
use XML::Simple;
use Text::Iconv;
use YAML::Tiny;
use JSON::XS qw(encode_json);
use Lingua::DetectCharset;

our $VERSION = 0.1;

my $converter  = Text::Iconv->new("windows-1251", "utf-8");
my $converter2 = Text::Iconv->new("utf-8", "windows-1251");
my @errors;
my $credits = 0;
my $xml = new XML::Simple;

sub new {
	my $class = shift;
	my $params = shift;
	my $opts;
	if ($params->{cfg} && -e $params->{cfg}) {
		my $yaml = YAML::Tiny->read( '/usr/local/nodeny/web/sms.yml' );
		$opts = $yaml->[0]->{opts};
	}
	my $email = $opts->{login} || $params->{email};
	$email = conv($email);
	my $password = $opts->{password} || $params->{password};
	$password = conv($password);
	my $url = $opts->{url} || $params->{url} || 'http://api.sms24x7.ru:80/';
	$url = conv($url);
	our $browser ||= LWP::UserAgent->new;
	$browser->cookie_jar({});
	my $response = $browser->post( $url, {method => 'login', email => $email, password => $password} );
	if ($response->is_success) {
		my $resphash = $xml->XMLin( $response->content );
		if( $resphash->{msg}{err_code} > 0 ) {
			push(@errors, "Error code: $resphash->{msg}{err_code}. Login failed");
			return 0;
		}
	}
	else {
		push(@errors, "Can't post request: ".$response->status_line);
	}

	my $self = { url => $url, test => $opts->{test} };
	bless $self, $class;
	return $self;
}

sub get_errors {
	my $self = shift;
	if ( @errors ) {
		return @errors;
	}
	else {
		return undef;
	}
}

sub get_credits {
	my $self = shift;
	return $credits;
}

sub get_profile {
	my $self = shift;
	my $params = shift;
	my $response = $SmsSender::browser->post( $self->{url}, {method => 'get_profile'} );
	my $result = $xml->XMLin( $response->decoded_content( charset => 'none' ) );
	if ( $result->{msg}->{err_code} > 0 ) {
		push( @errors, "Get profile info failed. Error code: $result->{msg}->{err_code}");
	}
	return $result;
}

sub get_msg_report {
	my $self = shift;
	my $params = shift;
	my $response = $SmsSender::browser->post( $self->{url}, {method => 'get_msg_report', id => $params->{id}} );
	my $result = $xml->XMLin( $response->decoded_content( charset => 'none' ) );
	if ( $result->{msg}->{err_code} > 0 ) {
		push( @errors, "Get message report failed. Error code: $result->{msg}->{err_code}");
	}
	return $result;
}

sub push_msg {
	my $self = shift;
	my $params = shift;
	my $post_data = { method => 'push_msg', test => $self->{test}, api_v => '1.1' };
	
	if ( !( $params->{phone} ) && scalar( @{$params->{phones}} ) > 1024 ) {
		#TODO: разбивать phones на массивы по 1024 номера и отправлять частями
		push( @errors, "Number of phones > 1024. Maximum 1024 numbers in phones argument." );
	}
	
	if ( $params->{message} ) {
		$post_data->{text} = conv( $params->{message} );
	}
	if ( $params->{phone} ) {
		$post_data->{phone} = conv( $params->{phone} );
	}
	elsif ( $params->{phones} ) {
		#TODO: добавить разбивку массива phones по 1024 элемента
		$post_data->{phones} = encode_json $params->{phones};
	}
	if ( $params->{sender} ) {
		$post_data->{sender_name} = conv( $params->{sender} );
	}
	else {
		$post_data->{sender_name} = conv( 'Arriva' );
	}
	my $response = $SmsSender::browser->post( $self->{url}, $post_data );
	my $result = $xml->XMLin( $response->decoded_content( charset => 'none' ) );
	if ( $result->{msg}->{err_code} > 0 ) {
		push( @errors, "Message: $post_data->{text}. Error code: $result->{msg}->{err_code}." );
	}
	elsif ( $post_data->{phone} ) {
		$credits += $result->{data}->{credits};
	}
	else {
		for my $key ( keys $result->{data}->{row} ) {
			if ( $result->{data}->{row}->{$key}->{msg}->{err_code} ) {
				push( @errors, "Phone: $result->{data}->{row}->{$key}->{phone}. Message: $post_data->{text}. Error code: $result->{data}->{row}->{$key}->{msg}->{err_code}." );
			}
			else {
				$credits += $result->{data}->{row}->{$key}->{credits};
			}
		}
	}
	return $result;
}

sub change_profile { #not tested yet
	my $self = shift;
	my $params = shift;
	$params->{method} = 'change_profile';
	for my $key (keys $params) {
		$params->{$key} = conv($params->{$key});
	}
	my $response = $SmsSender::browser->post( $self->{url}, $params);
	my $result = $xml->XMLin( $response->decoded_content( charset => 'none' ) );
	if ( $result->{msg}->{err_code} > 0 ) {
		push( @errors, "Error code: $result->{msg}->{err_code}." );
	}
	return $result;
}

#конвертирует в utf8
sub conv {
	return Lingua::DetectCharset::Detect( $_[0] ) eq 'WIN' ? $converter->convert($_[0]) : $_[0];
}

#конвертирует из utf8
sub conv2 {
	return $converter2->convert($_[0]);
}

sub DESTROY {
	my $self = shift;
	my $response = $SmsSender::browser->post( $self->{url}, {method => 'logout'} );
}

1;