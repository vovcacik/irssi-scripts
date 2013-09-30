use strict;
use warnings;

use Irssi;
use Data::Dumper;
use LWP::UserAgent;

our $VERSION = '1.0';
our %IRSSI = (
	authors		=> 'Vlastimil Ovčáčík',
	name		=> 'pastebin_inline.pl',
	description	=> 'Pastes anything between start and end tag on pastebin.com - inline.',
	license		=> 'The MIT License',
	url			=> 'https://github.com/vovcacik/irssi-scripts'
);

Irssi::settings_add_str('pastebin_inline', 'pastebin_inline_api_dev_key', 'ba4e185a675b792c2288ba65cd84a96c');
# If you want the pastes to be associated with your Pastebin account go grab your
# user API key at http://pastebin.com/api/api_user_key.html
Irssi::settings_add_str('pastebin_inline', 'pastebin_inline_api_user_key', '');
# Privacy settings: public = 0, unlisted = 1, private = 2.
Irssi::settings_add_str('pastebin_inline', 'pastebin_inline_api_paste_private', '1');
# Paste expiration: 10M, 1H, 1D, 1W, 2W, 1M, N.
Irssi::settings_add_str('pastebin_inline', 'pastebin_inline_api_paste_expire_date', '1D');
Irssi::settings_add_str('pastebin_inline', 'pastebin_inline_start_tag', 'pastebin:');
Irssi::settings_add_str('pastebin_inline', 'pastebin_inline_end_tag', ':pastebin');

# The array used to build the paste.
my @log = ();

# Bother the user until he disables the "paste_join_multiline" feature which
# should have never be ON by default, argh.
if (Irssi::settings_get_bool('paste_join_multiline')) {
	print CRAP "%y$IRSSI{name}%n: Irssi is configured to join multiple lines with same ".
	"indentation. This feature is destructive for code pastes. It's ON by default, but can be ".
	"safely switched OFF: `/set paste_join_multiline OFF`.";
}



# Scan input for start tag, build the paste if you find one.
sub on_send {
	my ($message, $server, $item) = @_;
	my $start_tag = Irssi::settings_get_str('pastebin_inline_start_tag');
	my $end_tag = Irssi::settings_get_str('pastebin_inline_end_tag');

	# Gather lines.
	if (scalar @log or $message =~ m/$start_tag/) {
		push(@log, $message);
		Irssi::signal_stop();
	}

	# Upload the lines and let the signal continue.
	if (scalar @log and $message =~ m/$end_tag/) {
		join("\n", @log) =~ m/(.*?)$start_tag(.*)$end_tag(.*)/s;
		my $head = $1;
		my $url = pastebin_post($2);
		my $tail = $3;

		@log = ();
		Irssi::signal_continue($head . $url . $tail, $server, $item);
	}
};

# Post the text. Returns paste URL on success, otherwise empty string.
sub pastebin_post {
	my ($message) = @_;

	my $ua = new LWP::UserAgent;
	my $payload = {
		'api_dev_key'		=>	Irssi::settings_get_str('pastebin_inline_api_dev_key'),
		'api_option'		=>	'paste',
		'api_paste_code'	=>	$message,
		'api_user_key'		=>	Irssi::settings_get_str('pastebin_inline_api_user_key'),
		'api_paste_private'	=>	Irssi::settings_get_str('pastebin_inline_api_paste_private'),
		'api_paste_expire_date'	=>	Irssi::settings_get_str('pastebin_inline_api_paste_expire_date')
	};

	my $response = $ua->post("http://pastebin.com/api/api_post.php", $payload);
	if ($response->is_success and $response->decoded_content =~ m/^http/) {
		return $response->decoded_content;
	} else {
		print CRAP "%r$IRSSI{name}%n: Pastebin responded with error: " . $response->status_line;
		print CRAP "Response content:";
		print Dumper($response->decoded_content);

		return "";
	}
}

# The "send command" signal passes pretty much anything you type in input,
# which means this script works everywhere.
Irssi::signal_add('send command', \&on_send);
