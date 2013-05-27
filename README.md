sms24x7-SmsSender
=================

Perl module to send sms through sms24x7 service. API manual can be found at https://outbox.sms24x7.ru/api_manual/index.html

## Usage

use or require this module to your project

```
use SmsSender;
#or
require '/path/to/module/SmsSender.pm';
```
Now you need to initialize module.

```
my $sender = SmsSender->new( {cfg => '/path/to/yaml/config/cfg.yml'} );
#or without config
my $sender = SmsSender->new( {option => value, ...} );
```
List of options:
email - yours account email. password - password. url - url to api

Now you can send sms:
```
$sender->push_msg( { phone => '', message => 'Hello, world!' } );
#or
my $arraylink = ['phone1', 'phone2', ...]; #max 1024 numbers
$sender->push_msg( { phones => $arraylink, message => 'Hello, world!' } );
```
Any time you can check, how many credits you spend, by method get_credits:
```
$sender->get_credits;
```

Or you can get profile info with method get_profile:
```
my $profile = $sender->get_profile;
```

For check message status:
```
my $response = $sender->get_msg_report( { id => $message_id } );
```

You can check for errors by calling get_errors method:
```
$sender->push_msg( { phone => '79999999999', message => 'Hello, world!' } );
if ($sender->get_errors) {
  #... get_errors method returns array of errors
}
```

##Dependencies

LWP

XML::Simple

Text::Iconv

YAML::Tiny

JSON::XS

Lingua::DetectCharset
