package Velicio;

use Mojo::Base 'Mojolicious';

use Mojo::Util qw/slurp/;

use constant DEFAULT_MONIKER => 'agent';

our $VERSION = '0.01';

use Velicio::Agent;
use Velicio::Manager;

has 'uuid';
has agent => sub { Velicio::Agent->new({app=>shift}) };
has manager => sub { Velicio::Manager->new({app=>shift}) };
sub probe { $_[0]->agent && $_[0]->manager }
has detect_moniker => sub { $_[0]->moniker($ENV{MOJO_CONFIG} ? ((split /\./, $ENV{MOJO_CONFIG}))[0] : DEFAULT_MONIKER) };

sub startup {
  my $self = shift;

  $self->secrets(['new_passw0rd', 'old_passw0rd', 'very_old_passw0rd']);
  $self->uuid(slurp $self->home.'/state/registration');
  $self->detect_moniker;
  my $config = $self->plugin('Config' => {default => {
    manager => 'localhost',
    manager_port => '3500',
  }});

  if ( $self->moniker eq 'agent' ) { $self->manager(undef) }
  elsif ( $self->moniker eq 'manager' ) { $self->agent(undef) }
  if ( $self->probe ) {
    $self->app->log->debug("I am a Probe");
  } elsif ( $self->agent ) {
    $self->app->log->debug("I am an Agent");
  } elsif ( $self->manager ) {
    $self->app->log->debug("I am a Manager");
  } else {
    $self->app->log->fatal("I don't know what I am!");
  }

  #$self->plugin('Velicio::Plugin::Helpers');
  $self->helper(version => sub { $VERSION });
  $self->helper(protocol => sub { int $_[1] || $VERSION });

  my $r = $self->routes;
  $r->add_condition(port => sub { $_[1]->req->url->port == $_[3] });
  $r->get('/')->to('HelloWorld#hello_world');
  $r->get('/snmpwalk')->to('HelloWorld#snmpwalk');
  $r->get('/interval/:interval', {interval => 5})->to('HelloWorld#set_interval');
  $r->get('/quit')->to('HelloWorld#quit');
  $r->websocket('/manager')->to('Manager#websocket') if $self->manager;

  $self->agent->connect if $self->agent;
  $self->manager->probe if $self->probe;
}

1;
