package Velicio::Agent;
use Mojo::Base 'Mojo::EventEmitter';

use Mojo::JSON 'j';

use Time::HiRes 'time';
use Math::Prime::Util;

use constant {
  FATAL => 1000,
};

has retry => 0;
has 'tid';
has log => sub { Mojo::Log->new };
has app => sub { shift->{app} };
has 'ua';
has 'tx';
has counter => 0;
sub _wait_prime {
  my $self = shift;
  $self->log->info(sprintf "I am an Agent, attempting to connect to MANAGER (%s:%s) in %s seconds...", $self->app->config->{manager}, $self->app->config->{manager_port}, $self->retry) if $self->retry && !$self->counter;
  $self->counter($self->counter+1);
  $self->counter < $self->retry;
}
sub _advance_prime {
  my ($self, $next) = @_;
  $self->counter(0);
  $self->retry(60*5) if $self->retry > 60*15;
  $self->retry(Math::Prime::Util::next_prime($self->retry));
}

sub connect {
  my $self = shift;
  return unless $self->app->agent;
  $self->tid(Mojo::IOLoop->recurring(1 => sub {
    return Mojo::IOLoop->remove($self->tid) if $$ > getppid + 1; # Only the first prefork'd process should behave as a UserAgent; the same and the rest behave as Controllers
    $self->ping and return;
    return if $self->_wait_prime;
    $self->_advance_prime;
    $self->ua(Mojo::UserAgent->new);
    $self->ua->websocket('ws://'.$self->app->config->{manager}.':'.$self->app->config->{manager_port}.'/manager' => sub {
      my ($ua, $tx) = @_;
      $self->log->error(sprintf "I am an Agent, Websocket handshake failed: ", $tx->error) and return unless $tx->is_websocket;
      $self->retry(0);
      $self->tx($tx);
      $self->log->debug(sprintf 'I am an Agent, my New TX: %s', $self->tx);
      $self->tx->on(error => sub { $self->log->error(sprintf 'I am an Agent, TX error: %s', $_[1]) });
      $self->tx->on(finish => sub {
        my ($ws, $code, $reason) = @_;
        $self->log->debug(sprintf 'I am an Agent, TX (%s) finish: %s - %s', $self->tx, $code, $reason);
        $self->tx(undef); # This is critical
        $self->retry(10) if $code == FATAL;
      });
      $self->tx->on(frame => sub {
        my ($ws, $frame) = @_;
        $self->app->log->debug(sprintf 'I am an Agent (%s), my MANAGER responded: %s', $self->tx, $frame->[5]);
      });
      $self->tx->on(json => sub {
        my ($ws, $json) = @_;
        $ws->emit($json->{_} => $json);
      });
    }) unless $self->tx && $self->tx->is_websocket;
  })) unless $self->tid;
}

sub ping {
  my $self = shift;
  return undef unless $self->tx && $self->tx->is_websocket;
  $self->tx->send([1, 0, 0, 0, 9, join ':', $self->app->version, time, $self->app->uuid, $self->app->secrets->[0]]);
}

1;
