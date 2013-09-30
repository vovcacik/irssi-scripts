use strict;
use warnings;

use Irssi;
use Irssi::TextUI;
use Time::HiRes;

our $VERSION = '1.0';
our %IRSSI = (
	authors		=>	'Vlastimil Ovčáčík',
	name		=>	'continuous_scrollback.pl',
	description	=>	'Switch to window with the highest activity level upon ' .
					'bottoming out scrollback.',
	license		=>	'The MIT License',
	url			=>	'https://github.com/vovcacik/irssi-scripts'
);

# Last time the scrolling occured in seconds (with some decimal places).
my $time_last = -1;

sub on_scrolling {
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

	# If there are no lines in scrollforward switch active window to the one
	# with the highest activity level (the "data_level" property):
	#	no activity = 0		crap = 1
	#	public msgs = 2		highlighted = 3
	if ($scrollforward_length == 0) {
		my $time_diff = Time::HiRes::time() - $time_last;

		# Require double tap, ignore holding of scrolling key.
		if ($time_diff > 0.15 && $time_diff < 0.3) {
			my ($window_next) = sort by_activity Irssi::windows();
			Irssi::UI::Window::set_active($window_next);
			$time_last = -1;
		} else {
			$time_last = Time::HiRes::time();
		}
	}
}

# Sorts Irssi windows by activity level (data_level) in descending order and
# by window position (refnum) in ascending order if first criterium is equal.
sub by_activity {
	$b->{data_level} <=> $a->{data_level} ||
	$a->{refnum} <=> $b->{refnum}
}

# This signal is not triggered by autoscrolling.
Irssi::signal_add('gui page scrolled', \&on_scrolling);
