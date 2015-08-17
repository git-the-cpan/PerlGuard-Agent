# This class needs updating as relying on parsing trace output is not going to be reliable
# leave as is for initial release to development partners to gain feedback in other areas

package PerlGuard::Agent::Monitors::DBI;
use Moo;
use DBI;
use PerlGuard::Agent::Monitors::DBI::viaDBILogger;
extends 'PerlGuard::Agent::Monitors';

has layered_filehandle => ( is => 'rw' );
has dbi_logger => (is => 'rw', default => sub { PerlGuard::Agent::Monitors::DBI::DBILogger->new(monitor => shift) });

sub start_monitoring {
  my $self = shift;
  open my $fh, '>:via(PerlGuard::Agent::Monitors::DBI::viaDBILogger)', $self->dbi_logger;
  $self->layered_filehandle($fh);
  DBI->trace('SQL|CON|1', $self->layered_filehandle);

}

sub stop_monitoring {
  my $self = shift;

  close $self->layered_filehandle();
}

sub inform_agent_of_event {
  my $self = shift;
  my $event = shift;

  my $database_transaction = $self->translate_raw_dbi_trace_to_database_transaction($event);
  return unless $database_transaction;

  $self->agent->add_database_transaction($database_transaction);

}

sub translate_raw_dbi_trace_to_database_transaction {
  my $self = shift;
  my $raw_event = shift;

  my $database_transaction = {};

  foreach my $row(@$raw_event) {

    if($row->{log} =~ /^    <- bind_param/) {
      #print STDERR "Detected Start of Query\n";
      $database_transaction->{start_time} = $row->{time};
    }
    if($row->{log} =~ /^>parse_params statement (.*)/) {
      $database_transaction->{query} = $1; 
    }
    if($row->{log} =~ /prepare_cached/) {
      #print STDERR $row->{log};
      if($row->{log} =~ /\s?<-\s?prepare_cached\('([\s\S]*)'/) {

        $database_transaction->{query} = $1; 
        #print STDERR $database_transaction->{query};
        $database_transaction->{start_time} = $row->{time};
        
      }
    }  

    elsif($row->{log} =~ /(\s)+<-(\s)(execute)(.*)=\s\(\s?(\d+)/ ) {
      #print STDERR "Detected End of Query\n";
      $database_transaction->{finish_time} = $row->{time};
      $database_transaction->{rows_returned} = $5;
    }
    else {
      #$database_transaction->{raw} = $row->{log};
    }
  }
  return keys(%$database_transaction) ? $database_transaction : ();
}

1;



package PerlGuard::Agent::Monitors::DBI::DBILogger;

use Scalar::Util;

sub new
{
    my $self = {
      queries => [],
      monitor => pop
    };

    Scalar::Util::weaken($self->{monitor});

    return bless $self, shift;
}

sub log
{
    my $self = shift;
    my $string = shift;

    $self->{_buf} .= $string unless 0 || $string =~ /mysql.xs/;

    #
    # DBI feeds us pieces at a time, so accumulate a complete line
    # before outputing
    #

    if($self->{_buf}=~tr/\n//) {
      
      push(@{$self->{queries}},{ time => [Time::HiRes::gettimeofday()], log =>  $self->{_buf} });
      $self->inform_monitor() if $self->ready_to_inform_monitor();
      $self->{_buf} = '';
    }
}

sub inform_monitor {
  my $self = shift;

  $self->{monitor}->inform_agent_of_event($self->{queries});
  $self->{queries} = [];
  
}

sub ready_to_inform_monitor {
  my $self = shift;

  if($self->{queries}->[-1]->{log} =~ /(\s)+<-(\s)(execute)(.*)=\s\(\s?(\d+)/  ) {
    return 1;
  }
  return 0;
}

sub close {
    my $self = shift;
}