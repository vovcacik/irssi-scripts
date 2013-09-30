use strict;
use warnings;

use Irssi;

our $VERSION = '1.0';
our %IRSSI = (
	authors		=>	'Vlastimil Ovčáčík',
	name		=>	'highlight_opening_message.pl',
	description	=>	'Highlights messages sent after period of silence ' .
					'on a per client basis.',
	license		=>	'The MIT License',
	url			=>	'https://github.com/vovcacik/irssi-scripts'
);

Irssi::settings_add_str('highlight_opening_message', 'highlight_opening_message_forget_interval', '300');
Irssi::settings_add_str('highlight_opening_message', 'highlight_opening_message_format', '%W');

my %clients = ();

sub on_join {
	my ($channel) = @_;
	my $channel_name = $channel->{name};
	my %nicks = ();
	foreach my $nick (Irssi::Channel::nicks($channel)) {
		$nicks{$nick->{nick}} = time();
	}
	$clients{$channel_name} = \%nicks;
};

sub on_part {
	my ($channel) = @_;
	my $channel_name = $channel->{name};
	delete $clients{$channel_name};
};

sub on_rename {
	my ($server, $new_nick, $old_nick, $host) = @_;
	while (my ($channel_name, $nicks) = each %clients) {
		if ($nicks->{$old_nick}) {
			$nicks->{$new_nick} = $nicks->{$old_nick};
		}
	}
};

sub on_public {
	my ($server, $message, $nick, $host, $channel_name) = @_;
	my $forget_interval = Irssi::settings_get_str('highlight_opening_message_forget_interval');
	my $color = Irssi::settings_get_str('highlight_opening_message_format');

	on_join(Irssi::channel_find($channel_name)) unless $clients{$channel_name};
	my $nicks = $clients{$channel_name};

	if (!$nicks->{$nick} || (time() - $nicks->{$nick} > $forget_interval)) {
		my $window = Irssi::Server::window_find_item($server, $channel_name);
		my $theme = $window->{theme} || Irssi::current_theme();
		my $format_old = my $format_new = Irssi::UI::Theme::get_format($theme, 'fe-common/core', 'pubmsg');

		# Match last argument and surround it with color codes. Last argument is probably the text.
		# Arguments examples: $0, $1, $[7]0, $[-7]1, $[!30.0]9 etc.
		$format_new =~ s/(.*)(\$(?:\[[-!]?[.\d]+\])?\d)/$1$color$2%n/;

		# Apply the new format_old (temporarily) on the message.
		Irssi::UI::Window::command($window, "/^format pubmsg $format_new");
		Irssi::signal_continue($server, $message, $nick, $host, $channel_name);
		Irssi::UI::Window::command($window, "/^format pubmsg $format_old");
	}
	$nicks->{$nick} = time();
};

Irssi::signal_add_first('channel joined', \&on_join);
Irssi::signal_add_first('channel destroyed', \&on_part);
Irssi::signal_add_first('message nick', \&on_rename);
Irssi::signal_add_first('message public', \&on_public);
