use Test::More;
use Plack::Builder;
#use Plack::Middleware::CacheLite;

my $counter = 1;
my $app = sub {
    my $env = shift;
    $env->{counter} = $counter;
    [ 200, [], BodyHandler->new ];
};

{
    package BodyHandler;
    sub new {
        return bless ['a','b','c','d'], shift;
    }
    sub close {}
    sub getline {
        my $self = shift;
        return shift @$self;
    }
}

run_test( builder {
    enable 'CacheLite';
    $app;
} );

sub run_test {
    my $app = shift;

    my $res = $app->( { REQUEST_METHOD => 'GET', REQUEST_URI => 'foo' } );
    is_deeply( $res, [200,[],['a','b','c','d']], 'first call: foo' );

    $res = $app->( { REQUEST_METHOD => 'GET', REQUEST_URI => 'bar' } );
    is_deeply( $res, [200,[],['a','b','c','d']], 'second call: bar' );

    $res = $app->( { REQUEST_METHOD => 'GET', REQUEST_URI => 'foo' } );
    is_deeply( $res, [200,[],['a','b','c','d']], 'third call: foo (cached)' );
}

done_testing;
