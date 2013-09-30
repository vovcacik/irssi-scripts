use strict;
use warnings;

use Irssi;
use Irssi::TextUI;
use POSIX;
use Number::Fraction;

our $VERSION = '1.0';
our %IRSSI = (
	authors		=> 'Vlastimil Ovčáčík',
	name		=> 'blank_page.pl',
	description	=> 'Maintains blank page at the end of each scrollback.',
	license		=> 'The MIT License',
	url			=> 'https://github.com/vovcacik/irssi-scripts'
);

sub on_signal {
	my $window = Irssi::active_win();
	my $view = Irssi::UI::Window::view($window);

	# Height of the visible part of scrollback (counted in lines).
	my $height = $view->{height};
	# Number of blank lines at the end of scrollback.
	my $empty_lines = $view->{empty_linecount};
	# Number of non-blank lines from the bottom to the top edge of view.
	my $ypos = $view->{ypos} + 1;
	# Scrollforward = lines below bottom edge of the view.
	my $scrollforward_length = $ypos + $empty_lines - $height;

	# Get scrolling size and deal with different syntax for this Irssi settings.
	my $scrolling_step = Irssi::settings_get_str('scroll_page_count') || $height;
	if ($scrolling_step =~ m|^/|) {
		# "scroll_page_count" is fraction of page height in fraction syntax.
		$scrolling_step =~ s|^/|1/|;
		$scrolling_step = Number::Fraction->new($scrolling_step);
		$scrolling_step = ceil($scrolling_step * $height) || 1;
	} elsif ($scrolling_step =~ m|^\.|) {
		# "scroll_page_count" is fraction of page height in decimal point syntax.
		$scrolling_step =~ s|^\.|0\.|;
		$scrolling_step = ceil($scrolling_step * $height) || 1;
	} elsif ($scrolling_step < 0) {
		# "scroll_page_count" is negative number of lines (see Irssi bug #254).
		$scrolling_step = $height + $scrolling_step;
	} # $scrolling_step is number of lines to scroll at this point.

	# If there is not enough lines in scrollforward to do full scrolling step &&
	# we can gain some empty lines by clearing the view then do it.
	if ($scrollforward_length < $scrolling_step && $empty_lines != $height) {
		Irssi::TextUI::TextBufferView::clear($view);
		Irssi::TextUI::TextBufferView::scroll($view, -$ypos);
	}
}

# Irssi::signal_add('gui page scrolled', \&on_signal);
# Irssi::signal_add('window changed', \&on_signal);
Irssi::signal_add('gui key pressed', \&on_signal);
