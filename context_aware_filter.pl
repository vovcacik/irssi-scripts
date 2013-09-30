use strict;
use warnings;

use Irssi;

our $VERSION = '1.0';
our %IRSSI = (
	authors		=> 'Vlastimil Ovčáčík',
	name		=> 'context_aware_filter.pl',
	description	=> 'Filters status messages of those you did not talk to.',
	license		=> 'The MIT License',
	url			=> 'https://github.com/vovcacik/irssi-scripts'
);

Irssi::settings_add_str('context_aware_filter', 'context_aware_filter_forget_interval', '900');

my %nicks = ();

# Looks at your public messages in case you address them with
# the "<nick>: <message body>" syntax.
sub on_own_public {
	my ($server, $message, $channel_name) = @_;
	if ($message =~ m/^(\w+?):/) {
		$nicks{"$1"} = time();
	}
};

# The trivial case of private messages/queries.
sub on_own_private {
	my ($server, $message, $nick, $orig_target) = @_;
	$nicks{$nick} = time();
};

# Decides what status messages to filter out or pass on.
sub on_status_message {
	my ($nick) = @_;
	my $forget_interval = Irssi::settings_get_str('context_aware_filter_forget_interval');

	if (!$nicks{$nick} || (time() - $nicks{$nick} > $forget_interval)) {
		delete $nicks{$nick};
		Irssi::signal_stop();
	}
};

sub on_join {
	my ($server, $channel_name, $nick, $host) = @_;
	on_status_message($nick);
};

sub on_part {
	my ($server, $channel_name, $nick, $host, $reason) = @_;
	on_status_message($nick);
};

sub on_quit {
	my ($server, $nick, $host, $reason) = @_;
	on_status_message($nick);
};

sub on_rename {
	my ($server, $new_nick, $old_nick, $host) = @_;
	on_status_message($old_nick);

	if ($nicks{$old_nick}) {
		$nicks{$new_nick} = $nicks{$old_nick};
		delete $nicks{$old_nick};
	}
};

Irssi::signal_add('message own_public', \&on_own_public);
Irssi::signal_add('message own_private', \&on_own_private);
Irssi::signal_add('message join', \&on_join);
Irssi::signal_add('message part', \&on_part);
Irssi::signal_add('message quit', \&on_quit);
Irssi::signal_add('message nick', \&on_rename);
