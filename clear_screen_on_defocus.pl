use strict;
use warnings;

use Irssi;
use Irssi::TextUI;

our $VERSION = '1.0';
our %IRSSI = (
	authors		=> 'Vlastimil Ovčáčík',
	name		=> 'clear_screen_on_defocus.pl',
	description	=> 'Clears view upon switching to another window.',
	license		=> 'The MIT License',
	url			=> 'https://github.com/vovcacik/irssi-scripts'
);

sub on_defocus {
	my ($window, $old_window) = @_;
	if ($old_window) {
		my $old_window_view = Irssi::UI::Window::view($old_window);
		if ($old_window_view) {
			Irssi::TextUI::TextBufferView::clear($old_window_view);
		}
	}
};

Irssi::signal_add('window changed', \&on_defocus);
