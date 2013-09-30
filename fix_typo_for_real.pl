use strict;
use warnings;

use Irssi;
use Irssi::TextUI;

our $VERSION = '1.0';
our %IRSSI = (
	authors		=> 'Vlastimil Ovčáčík',
	name		=> 'fix_typo_for_real.pl',
	description	=> 'Applies vim-like substitution for real.',
	license		=> 'The MIT License',
	url			=> 'https://github.com/vovcacik/irssi-scripts'
);

Irssi::settings_add_str('fix_typo_for_real', 'fix_typo_for_real_format', '%k%7');

sub on_message {
	my ($server, $message, $nick, $channel_name) = @_;

	# Proceed only if the message matches vim substitution syntax.
	if ($message =~ m|^s/([^/]+)/([^/]*)/?$|) {
		my ($a, $b) = (quotemeta($1), $2);
		my $window = Irssi::Server::window_find_item($server, $channel_name);
		my $view = Irssi::UI::Window::view($window);

		my @lines = get_lines_for_nick($view, $nick) or return;
		my $last = $lines[$#lines];
		my $prev = Irssi::TextUI::Line::prev($last) or return;
		my $color = Irssi::settings_get_str('fix_typo_for_real_format');
		# Keep head colorful,
		# but filter out the colors in body - regex engine would not like them.
		my ($head, undef) = (Irssi::TextUI::Line::get_text($last, 1) =~ m/(.*?>.*? )(.*)/);
		my (undef, $body) = (Irssi::TextUI::Line::get_text($last, 0) =~ m/(.*?>.*? )(.*)/);
		# Apply the substitution and highlight the substituted text.
		$body =~ s/$a/$color$b%n/ or return;
		# We have to parse $body before we concatenate it with $head,
		# because $head is colorful.
		$body = Irssi::parse_special($body, "", 0);

		my $ypos = $view->{ypos};
		my $level = Irssi::MSGLEVEL_MSGS() + Irssi::MSGLEVEL_PUBLIC() + 
			Irssi::MSGLEVEL_NO_ACT() + Irssi::MSGLEVEL_NEVER();
		# Replace the old line with the new one. The replacement will mess with
		# scrollback, so make sure to scroll to the same position as it was.
		Irssi::TextUI::TextBufferView::remove_line($view, $last);
		Irssi::UI::Window::print_after($window, $prev, $level, $head . $body);
		scroll_to_ypos($view, $ypos);

		# Dont display the substitution message because its already applied.
		Irssi::signal_stop();
	}
}

# Parses scrollback line by line and returns the ones that match the nick
# parameter. Note that this depends on default Irssi theme.
sub get_lines_for_nick {
	my ($view, $nick) = @_;
	my $line = Irssi::TextUI::TextBufferView::get_lines($view); # Returns first line.
	my @lines = ();
	while ($line) {
		my $text = Irssi::TextUI::Line::get_text($line, 0);
		push @lines, $line if $text =~ m/^.*?<.?$nick>/;
		$line = Irssi::TextUI::Line::next($line);
	}
	return @lines;
}

# Scrolls the view to supplied ypos.
sub scroll_to_ypos {
	my ($view, $ypos) = @_;	
	Irssi::TextUI::TextBufferView::clear($view);
	Irssi::TextUI::TextBufferView::scroll($view, -($ypos + 1));
}

Irssi::signal_add('message public',		sub { on_message($_[0], $_[1], $_[2], $_[4]); });
Irssi::signal_add('message private',	sub { on_message($_[0], $_[1], $_[2], $_[2]); });
Irssi::signal_add('message own_public',	sub { on_message($_[0], $_[1], $_[0]->{nick}, $_[2]); });
Irssi::signal_add('message own_private',sub { on_message($_[0], $_[1], $_[0]->{nick}, $_[2]); });
