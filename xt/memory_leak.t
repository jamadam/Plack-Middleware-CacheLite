use strict;
use warnings;
use Test::Memory::Cycle;
use Test::More;
use Plack::Builder;

    use Test::More tests => 1;
    
    my $app = sub {
        my $env = shift;
        [ 200, [], [ $env->{REQUEST_URI} ] ];
    };
    
    $a = builder {
        enable 'CacheLite';
        $app;
    };
    
    memory_cycle_ok( $a );

__END__
