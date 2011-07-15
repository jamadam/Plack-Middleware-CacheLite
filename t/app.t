use Test::More;
use Plack::Builder;
#use Plack::Middleware::CacheLite;

my $counter = 1;
my $app = sub {
    my $env = shift;
    $env->{counter} = $counter;
    [ 200, [], [ $env->{REQUEST_URI}.($counter++) ] ];
};

run_test( builder {
    enable 'CacheLite';
    $app;
} );

sub run_test {
    my $app = shift;

    my $res = $app->( { REQUEST_METHOD => 'GET', REQUEST_URI => 'foo' } );
    is_deeply( $res, [200,[],['foo1']], 'first call: foo' );

    $res = $app->( { REQUEST_METHOD => 'GET', REQUEST_URI => 'bar' } );
    is_deeply( $res, [200,[],['bar2']], 'second call: bar' );

    $res = $app->( { REQUEST_METHOD => 'GET', REQUEST_URI => 'foo' } );
    is_deeply( $res, [200,[],['foo1']], 'third call: foo (cached)' );
}

$capp = builder {
    enable 'CacheLite', keygen => sub {$_[0]->{REQUEST_URI}. '\t'. $_[0]->{HTTP_COOKIE}};
    $app
};

$counter = 1;
run_test( $capp );

$res = $capp->( { REQUEST_METHOD => 'GET', REQUEST_URI => 'foo', HTTP_COOKIE => 'doz=baz' } );
is_deeply( $res, [200,[],['foo3']], 'call with cookies: foo (new)' );
$res = $capp->( { REQUEST_METHOD => 'GET', REQUEST_URI => 'foo', HTTP_COOKIE => 'doz=baz' } );
is_deeply( $res, [200,[],['foo3']], 'call with cookies: foo (cached)' );

$counter = 1;
$capp = builder {
    enable 'CacheLite', threshold => 0.8;
    $app
};

# pass additional options from set to the cache
$res = $capp->( { REQUEST_METHOD => 'GET', REQUEST_URI => 'foo' } );
is_deeply( $res, [200,[],['foo1']], 'first' );
$res = $capp->( { REQUEST_METHOD => 'GET', REQUEST_URI => 'foo' } );
is_deeply( $res, [200,[],['foo2']], 'second' );

$counter = 1;
$capp = builder {
    enable 'CacheLite', threshold => 0.8;
    sub {
        my $env = shift;
        $env->{counter} = $counter;
        sleep(1);
        [ 200, [], [ $env->{REQUEST_URI}.($counter++) ] ];
    }
};

$res = $capp->( { REQUEST_METHOD => 'GET', REQUEST_URI => 'foo' } );
is_deeply( $res, [200,[],['foo1']], 'first' );
$res = $capp->( { REQUEST_METHOD => 'GET', REQUEST_URI => 'foo' } );
is_deeply( $res, [200,[],['foo1']], 'second' );

# do not cache if keygen returns undef
$counter = 1;
$capp = builder {
    enable 'CacheLite', keygen => sub {};
    sub {
        my $env = shift;
        $env->{counter} = $counter;
        [ 200, [], [ $env->{REQUEST_URI}.($counter++) ] ];
    }
};

$res = $capp->( { REQUEST_METHOD => 'GET', REQUEST_URI => 'foo' } );
is_deeply( $res, [200,[],['foo1']], 'first' );
$res = $capp->( { REQUEST_METHOD => 'GET', REQUEST_URI => 'foo' } );
is_deeply( $res, [200,[],['foo2']], 'second' );

done_testing;
