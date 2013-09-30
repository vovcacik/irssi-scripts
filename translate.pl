use strict;
use warnings;

use Irssi;
use Irssi::TextUI;
use Data::Dumper;
use List::Util qw( min );
use LWP::UserAgent;
use JSON;

our $VERSION = '1.0';
our %IRSSI = (
	authors		=> 'Vlastimil Ovčáčík',
	name		=> 'translate.pl',
	description	=> 'Translates incoming and outgoing messages on a per client basis.',
	license		=> 'The MIT License',
	url			=> 'https://github.com/vovcacik/irssi-scripts'
);

# Serialized %translate_list in JSON. It contains translation rules.
Irssi::settings_add_str('translate', 'translate_list', '{}');
# The language you prefer to use.
Irssi::settings_add_str('translate', 'translate_default_target_lang', 'en');
# Your Google Translate API key.
Irssi::settings_add_str('translate', 'translate_api_key', '');
# Number of lines in scrollback to translate upon adding translation rule.
Irssi::settings_add_int('translate', 'translate_scrollback_lines', 3);

my %translate_list = %{ decode_json Irssi::settings_get_str('translate_list') };
my ($tld2lang, $lang2printable, $printable2lang);

# Defines "/translate" command and couple shortcuts.
sub on_translate {
	my ($data, $server, $item) = @_;
	my ($arg1) = split(' ', $data);

	# Make 'add' the default subcommand if some arguments are given. Otherwise
	# run 'list'.
	if ($arg1) {
		if ($arg1 =~ m/(add|remove|list|save|reload|reset)/) {
			&Irssi::command_runsub('translate', @_);
		} else {
			&Irssi::command_runsub('translate', 'add ' . $data, @_[1..2]);
		}
	} else {
		&Irssi::command_runsub('translate', 'list', @_[1..2]);
	}
}

# Defines "/translate add" command. Adds/Updates translation rules.
sub on_translate_add {
	my ($data, $server, $item) = @_;
	my $chatnet = $server->{chatnet};

	# Parse arguments. Handle "*" wildcard. Use defaults if some args are missing.
	my ($source, $source_lang, $target_lang) = split(' ', $data);
	$source_lang = undef if ($source_lang && $source_lang eq "*");
	$target_lang = undef if ($target_lang && $target_lang eq "*");
	$source_lang = lc ($source_lang || "");
	$target_lang = lc ($target_lang || Irssi::settings_get_str('translate_default_target_lang') || "en");

	# Add/Update the translation rule.
	if ($source) {
		$translate_list{$chatnet} = {} unless $translate_list{$chatnet};
		my $langs = {
			'source_lang' => $tld2lang->{$source_lang} || $printable2lang->{$source_lang} || $source_lang,
			'target_lang' => $tld2lang->{$target_lang} || $printable2lang->{$target_lang} || $target_lang
		};
		$translate_list{$chatnet}->{$source} = $langs;

		# $item is undef when command was issued from "(status)" window.
		my $window = $item ? Irssi::Server::window_find_item($server, $item->{name}) : undef;
		translate_scrollback($server, $source, $window);
	}
}

# Defines "/translate remove" command. Removes space/comma separated list
# of translation rules.
sub on_translate_remove {
	my ($data, $server, $item) = @_;
	my $chatnet = $server->{chatnet};

	for (split(/[\s,]+/, $data)) {
		delete $translate_list{$chatnet}->{$_};
	}
}

# Defines "/translate list" command. Prints table of translation rules.
sub on_translate_list {
	my $width = 25; # Column width.
	printf("%s%-${width}s%-${width}s%-${width}s", "%W", "Name", "Source lang", "Target lang", "%n");

	while (my ($chatnet, $sources) = each %translate_list) {
		while (my ($source, $lang) = each $sources) {
			my $source_lang = $lang->{source_lang};
			my $target_lang = $lang->{target_lang};
			printf("%-${width}s%-${width}s%-${width}s",
				$chatnet . '/' . $source,
				$source_lang ? $lang2printable->{$source_lang} . " ($source_lang)" : "n/a",
				$target_lang ? $lang2printable->{$target_lang} . " ($target_lang)" : "n/a"
			)
		}
	}
}



# Translates incoming public and private messages if they match a translation rule.
sub on_message {
	my ($server, $message, $nick, $host, $channel_name) = @_;
	# Only public messages have $channel_name. Channel name of query is however
	# equal to the $nick argument.
	$channel_name = $channel_name || "";
	my $chatnet = $server->{chatnet};

	# Try to find translation rule for nickname or channel name.
	my $langs = $translate_list{$chatnet}->{$nick} || $translate_list{$chatnet}->{$channel_name};
	if ($langs) {
		# Get the translated text and update the rule to whatever Google
		# Translator detected as language, so it does not have to guess next time.
		(my $translation, $langs->{source_lang}, $langs->{target_lang}) =
		translate($message, $langs->{source_lang}, $langs->{target_lang});
		if ($translation) {
			Irssi::signal_continue($server, $translation, $nick, $host, $channel_name);
		}
	}
}

# Translates your outgoing public/private messages.
sub on_send_text {
	my ($message, $server, $item) = @_;
	my $chatnet = $server->{chatnet};
	# Channel name or query name.
	my $item_name = $item->{name} or return;
	# Get the addressee of $message from the $message (if any). Assumes
	# the "<nickname>: <message>" syntax.
	(my $nick, $message) = ($message =~ m/^(?:(\w+?):)?(.*)/);
	$nick = $nick || "";

	my $langs = $translate_list{$chatnet}->{$nick} || $translate_list{$chatnet}->{$item_name};
	if ($langs) {
		(my $translation, $langs->{target_lang}, $langs->{source_lang}) =
		translate($message, $langs->{target_lang}, $langs->{source_lang});
		if ($translation) {
			Irssi::signal_continue(
				($nick ? $nick . ':' : '') . $translation,
				$server,
				$item
			);
		}
	}
}



# Returns translated $message, (detected) source language and target language.
# @param $source_lang Language of the $message. Optional.
# @param $target_lang Language to which translate the $message. Required.
sub translate {
	my ($message, $source_lang, $target_lang) = @_;

	my $ua = new LWP::UserAgent;
	$ua->default_header('X-HTTP-Method-Override' => 'GET');
	my $payload = {
			'key'		=>	Irssi::settings_get_str('translate_api_key'),
			'q'			=>	$message,
			'target'	=>	$target_lang,
			'format'	=>	'text'
	};
	$payload->{source} = $source_lang if $source_lang;

	my $response = $ua->post("https://www.googleapis.com/language/translate/v2", $payload);
	if ($response->is_success) {
		my $json = $response->decoded_content;
		my $decoded = decode_json $json;
		my $translation = $decoded->{'data'}->{'translations'}->[0]->{'translatedText'};
		my $source_lang = $decoded->{'data'}->{'translations'}->[0]->{'detectedSourceLanguage'} || $source_lang;

		return $translation, $source_lang, $target_lang;
	} else {
		print CRAP "%r$IRSSI{name}%n: Google responded with error: " . $response->status_line;
		print CRAP "Request details:";
		print Dumper($payload);
		print CRAP "Response content:";
		print Dumper($response->decoded_content);

		return "", $source_lang, $target_lang;
	}
}

# Translates messages that have been received (i.e. msgs already in scrollback).
sub translate_scrollback {
	my ($server, $source, $window) = @_;
	my $chatnet = $server->{chatnet};
	my $source_is_channel = ($source =~ m/^#/);

	my $langs = $translate_list{$chatnet}->{$source};
	if ($langs) {
		# Get $source window if $source is channel, otherwise use the one from
		# args. We have to make sure that we are using correct $window (or $view
		# if you want) because we translate some lines from scrollback and we 
		# dont want to update the language details (especially source_lang) with
		# language detected for different channel.
		# This relevancy is guaranteed for query and nick sources, because 
		# the lines are filter by the query or nick name.
		$window = ($source_is_channel ? 
			Irssi::Server::window_find_item($server, $source) : 
			$window
		) or return;
		my $view = Irssi::UI::Window::view($window);
		my $ypos = $view->{ypos};

		# Get lines for any nick if $source is channel (i.e. not a nick or
		# query). We can dare to match any nick because we made sure $view is
		# the $source's view.
		my $nick_pattern = $source_is_channel ? ".*" : $source;
		my @lines = get_lines_for_nick($view, $nick_pattern) or return;

		# Translate last n lines.
		my $n = min( scalar @lines, Irssi::settings_get_int('translate_scrollback_lines') );
		foreach my $line (@lines[-$n..-1]) {
			my $prev = Irssi::TextUI::Line::prev($line) or next;
			# Keep head colorful, but Google would not like color codes in 
			# the text to be translated ($body).
			my ($head, undef) = (Irssi::TextUI::Line::get_text($line, 1) =~ m/(.*?>.*? )(.*)/);
			my (undef, $body) = (Irssi::TextUI::Line::get_text($line, 0) =~ m/(.*?>.*? )(.*)/);

			(my $translation, $langs->{source_lang}, $langs->{target_lang}) = 
			translate($body, $langs->{source_lang}, $langs->{target_lang});
			if ($translation) {
				# The translated text comes from PRIVATE (i.e. query) or PUBLIC
				# level, so use both. Dont trigger window activity and NEVER
				# ignore or log the new lines.
				my $level = Irssi::MSGLEVEL_MSGS() + Irssi::MSGLEVEL_PUBLIC() +
					Irssi::MSGLEVEL_NO_ACT() + Irssi::MSGLEVEL_NEVER();
				# There is nothing to escape in $translation, but do it anyway.
				# Otherwise printing `$head . $translation` will result in
				# double parsing the $head and thus incorrectly displayed line.
				$translation = Irssi::parse_special($translation, "", 0);

				Irssi::TextUI::TextBufferView::remove_line($view, $line);
				Irssi::UI::Window::print_after($window, $prev, $level, $head . $translation);
				scroll_to_ypos($view, $ypos);
			}
		}
	}
}

# Parses scrollback and returns array of lines that matches the nick pattern.
sub get_lines_for_nick {
	my ($view, $nick_pattern) = @_;
	my @lines = ();
	my $line = Irssi::TextUI::TextBufferView::get_lines($view); # First line only.

	while ($line) {
		my $text = Irssi::TextUI::Line::get_text($line, 0);
		push @lines, $line if $text =~ m/^.*?<.?$nick_pattern>/;
		$line = Irssi::TextUI::Line::next($line);
	}
	return @lines;
}

# Scrolls the view to ypos.
sub scroll_to_ypos {
	my ($view, $ypos) = @_;	
	Irssi::TextUI::TextBufferView::clear($view);
	Irssi::TextUI::TextBufferView::scroll($view, -($ypos + 1));
}



$tld2lang = {
	'za' => 'af',	'ae' => 'ar',	'bh' => 'ar',	'dz' => 'ar',	'eg' => 'ar',	'iq' => 'ar',
	'jo' => 'ar',	'km' => 'ar',	'kw' => 'ar',	'lb' => 'ar',	'ly' => 'ar',	'ma' => 'ar',
	'mr' => 'ar',	'om' => 'ar',	'ps' => 'ar',	'qa' => 'ar',	'sa' => 'ar',	'sd' => 'ar',
	'so' => 'ar',	'sy' => 'ar',	'tn' => 'ar',	'ye' => 'ar',	'by' => 'be',	'bd' => 'bn',
	'ad' => 'ca',	'cz' => 'cs',	'dk' => 'da',	'fo' => 'da',	'at' => 'de',	'ch' => 'de',
	'li' => 'de',	'gr' => 'el',	'bo' => 'es',	'cl' => 'es',	'co' => 'es',	'cr' => 'es',
	'cu' => 'es',	'do' => 'es',	'ec' => 'es',	'gq' => 'es',	'gt' => 'es',	'hn' => 'es',
	'mx' => 'es',	'ni' => 'es',	'pa' => 'es',	'pe' => 'es',	'py' => 'es',	'uy' => 'es',
	've' => 'es',	'ee' => 'et',	'ir' => 'fa',	'tj' => 'fa',	'ax' => 'fi',	'bf' => 'fr',
	'bi' => 'fr',	'bj' => 'fr',	'cd' => 'fr',	'cf' => 'fr',	'cg' => 'fr',	'ci' => 'fr',
	'cm' => 'fr',	'dj' => 'fr',	'lu' => 'fr',	'mc' => 'fr',	'mg' => 'fr',	'ml' => 'fr',
	'ne' => 'fr',	'rw' => 'fr',	'sc' => 'fr',	'sn' => 'fr',	'td' => 'fr',	'tg' => 'fr',
	'vu' => 'fr',	'ie' => 'ga',	'in' => 'hi',	'ba' => 'hr',	'sm' => 'it',	'va' => 'it',
	'il' => 'iw',	'jp' => 'ja',	'ge' => 'ka',	'kp' => 'ko',	'kr' => 'ko',	'cc' => 'ms',
	'my' => 'ms',	'sg' => 'ms',	'an' => 'nl',	'aw' => 'nl',	'bq' => 'nl',	'cw' => 'nl',
	'sx' => 'nl',	'ao' => 'pt',	'br' => 'pt',	'cv' => 'pt',	'gw' => 'pt',	'mz' => 'pt',
	'st' => 'pt',	'md' => 'ro',	'kg' => 'ru',	'kz' => 'ru',	'su' => 'ru',	'si' => 'sl',
	'al' => 'sq',	'rs' => 'sr',	'se' => 'sv',	'ke' => 'sw',	'tz' => 'sw',	'ug' => 'sw',
	'lk' => 'ta',	'ph' => 'tl',	'ua' => 'uk',	'pk' => 'ur',	'vn' => 'vi',	'cn' => 'zh-CN',
	'hk' => 'zh-CN','mo' => 'zh-CN','tw' => 'zh-CN'
};

$lang2printable = {
	'af' => 'Afrikaans',	'ar' => 'Arabic',		'az' => 'Azerbaijani',	'be' => 'Belarusian',
	'bg' => 'Bulgarian',	'bn' => 'Bengali',		'ca' => 'Catalan',		'cs' => 'Czech',
	'cy' => 'Welsh',		'da' => 'Danish',		'de' => 'German',		'el' => 'Greek',
	'en' => 'English',		'eo' => 'Esperanto',	'es' => 'Spanish',		'et' => 'Estonian',
	'eu' => 'Basque',		'fa' => 'Persian',		'fi' => 'Finnish',		'fr' => 'French',
	'ga' => 'Irish',		'gl' => 'Galician',		'gu' => 'Gujarati',		'hi' => 'Hindi',
	'hr' => 'Croatian',		'ht' => 'Haitian Creole','hu' => 'Hungarian',	'id' => 'Indonesian',
	'is' => 'Icelandic',	'it' => 'Italian',		'iw' => 'Hebrew',		'ja' => 'Japanese',
	'ka' => 'Georgian',		'kn' => 'Kannada',		'ko' => 'Korean',		'la' => 'Latin',
	'lt' => 'Lithuanian',	'lv' => 'Latvian',		'mk' => 'Macedonian',	'ms' => 'Malay',
	'mt' => 'Maltese',		'nl' => 'Dutch',		'no' => 'Norwegian',	'pl' => 'Polish',
	'pt' => 'Portuguese',	'ro' => 'Romanian',		'ru' => 'Russian',		'sk' => 'Slovak',
	'sl' => 'Slovenian',	'sq' => 'Albanian',		'sr' => 'Serbian',		'sv' => 'Swedish',
	'sw' => 'Swahili',		'ta' => 'Tamil',		'te' => 'Telugu',		'th' => 'Thai',
	'tl' => 'Filipino',		'tr' => 'Turkish',		'uk' => 'Ukrainian',	'ur' => 'Urdu',
	'vi' => 'Vietnamese',	'yi' => 'Yiddish',		'zh-CN' => 'Chinese Simplified', 'zh-TW' => 'Chinese Traditional'
};

$printable2lang = {
	'afrikaans'	=> 'af',		'arabic'	=> 'ar',		'azerbaijani'	=> 'az',			'belarusian'=> 'be',
	'bulgarian'	=> 'bg',		'bengali'	=> 'bn',		'catalan'		=> 'ca',			'czech'		=> 'cs',
	'welsh'		=> 'cy',		'danish'	=> 'da',		'german'		=> 'de',			'greek'		=> 'el',
	'english'	=> 'en',		'esperanto'	=> 'eo',		'spanish'		=> 'es',			'estonian'	=> 'et',
	'basque'	=> 'eu',		'persian'	=> 'fa',		'finnish'		=> 'fi',			'french'	=> 'fr',
	'irish'		=> 'ga',		'galician'	=> 'gl',		'gujarati'		=> 'gu',			'hindi'		=> 'hi',
	'croatian'	=> 'hr',	'haitian-creole'=> 'ht',		'hungarian'		=> 'hu',			'indonesian'=> 'id',
	'icelandic'	=> 'is',		'italian'	=> 'it',		'hebrew'		=> 'iw',			'japanese'	=> 'ja',
	'georgian'	=> 'ka',		'kannada'	=> 'kn',		'korean'		=> 'ko',			'latin'		=> 'la',
	'lithuanian'=> 'lt',		'latvian'	=> 'lv',		'macedonian'	=> 'mk',			'malay'		=> 'ms',
	'maltese'	=> 'mt',		'dutch'		=> 'nl',		'norwegian'		=> 'no',			'polish'	=> 'pl',
	'portuguese'=> 'pt',		'romanian'	=> 'ro',		'russian'		=> 'ru',			'slovak'	=> 'sk',
	'slovenian'	=> 'sl',		'albanian'	=> 'sq',		'serbian'		=> 'sr',			'swedish'	=> 'sv',
	'swahili'	=> 'sw',		'tamil'		=> 'ta',		'telugu'		=> 'te',			'thai'		=> 'th',
	'filipino'	=> 'tl',		'turkish'	=> 'tr',		'ukrainian'		=> 'uk',			'urdu'		=> 'ur',
	'vietnamese'=> 'vi',		'yiddish'	=> 'yi',	'chinese-simplified'=>'zh-CN',	'chinese-traditional'=> 'zh-TW'
};



Irssi::command_bind('translate',		\&on_translate);
Irssi::command_bind('translate add',	\&on_translate_add);
Irssi::command_bind('translate remove',	\&on_translate_remove);
Irssi::command_bind('translate list',	\&on_translate_list);
Irssi::command_bind('translate save',	sub { Irssi::settings_set_str('translate_list', encode_json \%translate_list) });
Irssi::command_bind('translate reload',	sub { %translate_list = %{decode_json Irssi::settings_get_str('translate_list')} });
Irssi::command_bind('translate reset',	sub { %translate_list = (); });

Irssi::signal_add('message public',		\&on_message);
Irssi::signal_add('message private',	\&on_message);
Irssi::signal_add('send text', 			\&on_send_text);
