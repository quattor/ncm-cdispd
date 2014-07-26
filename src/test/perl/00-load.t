# -*- mode: cperl -*-
# ${license-info}
# ${author-info}
# ${build-info}

=pod

=head1 Smoke test

Basic test that ensures that our modules will load correctly.

B<Do not disable this test>.

=cut

use strict;
use warnings;
use Test::More tests => 2;

use_ok("CDISPD::Application");
use_ok("CDISPD::Utils");
