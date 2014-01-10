package Velicio::Command::register;
use Mojo::Base 'Mojolicious::Command';

use Mojo::Util qw/slurp spurt/;

use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);

has description => "Register agent.\n";
has usage       => <<EOF;
usage: $0 register [OPTIONS] CODE

These options are available:
  -v, --verbose   Print return value to STDOUT.
  -V              Print returned data structure to STDOUT.
EOF

sub run {
  my ($self, @args) = @_;

  if ( -e $self->app->home.'/state/registration' ) {
    say "Already registered.";
  } else {
    mkdir $self->app->home.'/state';
    chmod 0700, $self->app->home.'/state';
    spurt $self->uuid, $self->app->home.'/state/registration';
    say "Welcome.";
  }
}

sub uuid { join "-", map { unpack "H*", $_ } map { substr pack("I", (((int(rand(65536)) % 65536) << 16) | (int(rand(65536)) % 65536))), 0, $_, "" } ( 4, 2, 2, 2, 6 ) }

1;
