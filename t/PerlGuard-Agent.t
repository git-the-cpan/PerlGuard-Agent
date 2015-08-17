# I have stripped out most of the tests for the initial CPAN release as they are only suitable for development
# Full test suite to follow once we establish which monitoring method to use (Hook::LexWrap may be unsuitable after initial customer testing)

# Before 'make install' is performed this script should be runnable with
# 'make test'. After 'make install' it should work as 'perl PerlGuard-Agent.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;
use FindBin;
# use Mojo::JSON;

use Test::More tests => 3;
BEGIN { use_ok('PerlGuard::Agent') };
BEGIN { use_ok('PerlGuard::Agent::Profile') };
BEGIN { use_ok('PerlGuard::Agent::Output::StandardError') };
# BEGIN { use_ok('PerlGuard::Agent::Frameworks::Mojolicious') };
# BEGIN { use_ok('PerlGuard::Agent::Monitors::DBI') };
#########################

open my $fh, '<', "$FindBin::Bin/assets/mojo_pg.txt";
my $pg_data = do { local $/; <$fh> };

my $agent = PerlGuard::Agent->new();
# my $dbi = PerlGuard::Agent::Monitors::DBI->new(agent => $agent);
# my $events = Mojo::JSON::decode_json($pg_data);
# my $event = $dbi->translate_raw_dbi_trace_to_database_transaction($events->[0]);

# is_deeply( $event  ,{ start_time => [1437663722,135410], finish_time => [1437663722,136976], rows_returned => 1, query => 'select * from users where id = ? and enabled = true and deleted = false limit 1' } , "First event");

