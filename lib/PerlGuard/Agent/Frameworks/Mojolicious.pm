package PerlGuard::Agent::Frameworks::Mojolicious;
#use Moo;
use PerlGuard::Agent;
use Mojo::Base 'Mojolicious::Plugin';

BEGIN {
  $PerlGuard::Agent::Frameworks::Mojolicious::VERSION = '1.00';
}

sub register {
    my ($self, $app, $args) = @_;
    $args ||= {};

    my $agent = PerlGuard::Agent->new($args);

    $app->helper(perlguard_agent => sub {
        return $agent;
    });

    # $app->hook(after_render => sub {
    #   my ($c, $output, $format) = @_;
    # });

    $app->hook(after_build_tx => sub {
      my $tx = shift;
      
        unless($tx->{'PerlGuard::Profile'}) {
          my $profile = $agent->create_new_profile();

          $tx->{'PerlGuard::Profile'} //= $profile;

          $profile->start_recording;
        }      
    });


    $app->hook(after_dispatch => sub {
      my $c = shift;

      return if ($c->stash->{'mojo.static'});
      $c->tx->{'PerlGuard::Profile'}->finish_recording;
    });


    $app->hook(before_routes => sub {
      my $c = shift;

      my $stash = $c->stash;
      unless ($stash->{'mojo.static'}) {

        unless($c->tx->{'PerlGuard::Profile'}) {

          my $profile = $agent->create_new_profile();

          $c->tx->{'PerlGuard::Profile'} //= $profile;

          $profile->start_recording;
        }
      }

    });


    $app->hook(around_action => sub {
      my ($next, $c, $action, $last) = @_;
      

      unless($c->stash->{'mojo.static'}) {
        my $profile = $c->tx->{'PerlGuard::Profile'};

        $profile->url( $c->req->url );
        $profile->http_method( $c->req->method );
        $profile->controller( ref($c) );
        $profile->controller_action( $c->stash->{action} );

        if( my $cross_application_tracing_id = $c->req->headers->header("X-PerlGuard-Auto-Track") ) {
          $profile->cross_application_tracing_id($cross_application_tracing_id);
        }

      }

      $next->();

    });

    $app->helper(perlguard_profile => sub {
      my $c = shift;
      return $c->tx->{'PerlGuard::Profile'};
    });

    $agent->detect_monitors();
    $agent->start_monitors();

}


1;