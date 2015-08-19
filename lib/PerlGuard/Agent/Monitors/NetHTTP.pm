package PerlGuard::Agent::Monitors::NetHTTP;
use Moo;
use Data::Dumper;
use PerlGuard::Agent::LexWrap;
use Time::HiRes;
extends 'PerlGuard::Agent::Monitors';

has requests_in_progress => ( is => 'rw', default => sub { {} });

sub die_unless_suitable {
  eval 'use Net::HTTP::Methods; use LWP::UserAgent; 1' or die "Could not load modules required for NetHTTP monitoring";
}


sub start_monitoring {
  my $self = shift;

  my $simple_request_wrapper = wrap 'LWP::UserAgent::simple_request', pre => $self->simple_request_wrapper_sub();
  my $simple_response_wrapper = wrap 'LWP::UserAgent::simple_request', post => $self->simple_response_wrapper_sub();

  push(@{$self->overrides}, $simple_request_wrapper);
  push(@{$self->overrides}, $simple_response_wrapper);

}

sub stop_monitoring {
  my $self = shift;

  foreach my $override(@{$self->overrides}) {
    undef $override;
  }

}

sub inform_agent_of_event {
  my $self = shift;
  my $trace = shift;

  $self->agent->add_webservice_transaction($trace);

}

sub simple_response_wrapper_sub {
  my $self = shift;

  return sub {
    my $request = $_[1];
    my $response = $_[4];

    my $request_id = $request->header('X-PerlGuard-Auto-Track');
    my $trace = $self->requests_in_progress->{$request_id};
    unless($trace) {
      warn "Could not find a transaction trace matching the request\n";
      return;
    }

    $trace->{finish_time} = [Time::HiRes::gettimeofday()];
    $trace->{status_code} = $response->code();
    $trace->{status_message} = $response->message();

    $self->inform_agent_of_event($trace);

    delete $self->requests_in_progress->{$request_id};

  }


}

# What we want to do is stash a unique value in a header so that we can 
# A) Link this up with its response later
# B) Use it as the unique ID for cross application tracing
sub simple_request_wrapper_sub {
  my $self = shift;

  return sub {
    my $profile = $self->agent->current_profile();
    unless($profile) {
      warn "Could not associate HTTP request with a profile";
      return;
    }

    my $request = $_[0]->[1];
    my $request_id = $profile->generate_new_cross_application_tracing_id();

    $request->header( 'X-PerlGuard-Auto-Track' => $request_id );    

    $self->requests_in_progress->{$request_id} = {
      cross_application_tracing_id => $request_id,
      start_time => [Time::HiRes::gettimeofday()],
      uri => $request->uri,
      method => $request->method,
    };

  }
}

1;

