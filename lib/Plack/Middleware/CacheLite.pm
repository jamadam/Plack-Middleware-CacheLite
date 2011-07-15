package Plack::Middleware::CacheLite;
use strict;
use warnings;
use parent qw(Plack::Middleware);
use Plack::Util::Accessor qw(max_keys keygen threshold cache);
use Time::HiRes qw(time);
our $VERSION = '0.01';

    our $_EXPIRE_CODE_ARRAY = [];
    
    sub prepare_app {
        my $self = shift;
        
        $self->cache(Plack::Middleware::CacheLite::_Cache->new);
        
        $self->cache->max_keys($self->max_keys || 100);
        
        if (! $self->keygen) {
            $self->keygen(sub {$_[0]->{REQUEST_URI} || $_[0]->{PATH_INFO}});
        }
    }
    
    sub set_expire {
        my ($class, $code) = @_;
        push @$_EXPIRE_CODE_ARRAY, $code;
    }

    sub call {
        my ($self, $env) = @_;
        
        my $cache = $self->cache;
        
        if ($env->{REQUEST_METHOD} eq 'GET' && (my $key = $self->keygen->($env))) {
            if (my $res = $cache->get($key)) {
                return $res;
            }
            
            local $_EXPIRE_CODE_ARRAY;
            
            my $ts_s = time;
            
            my $res = $self->app->($env);
            
            if (time - $ts_s > ($self->threshold || 0)) {
                if ($res->[0] && $res->[0] == 200) {
                    $cache->set($key, $res, \@$_EXPIRE_CODE_ARRAY);
                }
            }
            return $res;
        } else {
            return $self->app->($env);
        }
    }

package Plack::Middleware::CacheLite::_Cache;
use strict;
use warnings;
use Plack::Util::Accessor qw(max_keys);
    
    my $ATTR_CACHE      = 1;
    my $ATTR_STACK      = 2;
    
    sub new {bless {}, $_[0]}
    
    sub get {
        if (my $cache = $_[0]->{$ATTR_CACHE}->{$_[1]}) {
            if ($cache->[2]) {
                for my $code (@{$cache->[2]}) {
                    if ($code->($cache->[1])) {
                        return;
                    }
                }
            }
            $cache->[0];
        }
    }
    
    sub set {
        my ($self, $key, $value, $cbs) = @_;
        
        my $keys  = $self->max_keys;
        my $cache = $self->{$ATTR_CACHE} ||= {};
        my $stack = $self->{$ATTR_STACK} ||= [];
        
        while (@$stack >= $keys) {
            my $key = shift @$stack;
            delete $cache->{$key};
        }
        
        push @$stack, $key;
        
        $cache->{$key} = [
            $value,
            time,
            (ref $cbs eq 'CODE') ? [$cbs] : $cbs
        ];
    }

1;

__END__

=head1 NAME

Plack::Middleware::CacheLite - Stand alone implementation of cache

=head1 SYNOPSIS

    use Mojolicious::Plugin::CacheLite;
    
    builder {
        enable "CacheLite", {
            max_keys  => 100,    
            threshold => 0.08,   # second
            keygen => sub {
                my $env = shift;
                
                # generate key here maybe with $env
                # return undef causes cache disable
                
                return $key;
            },
        }
        $app;
    };

=head1 DESCRIPTION

Plack::Middleware::CacheLite is a stand alone cache middleware for plack

This plugin caches whole response into key-value object and returns it for next
request instead of invoking app. You can specify the cache key by
giving code reference which gets env for argument.

You can also specify one or more expiration conditions for each cache key from
anywhere in your app by giving code references. In many case, a single page
output involves not only one data model and each of the models may should have
own cache expiration conditions. To expire a cache exactly right timing,
the cache itself must know when to expire. The feature of this class provides
the mechanism.

=head1 OPTIONS

=head2 keygen => code reference [optional]

Key generator for cache entries. This must be given in code reference.
The following is the default.

    $self->plugin(cache_lite => {
        keygen => sub {
            $env = shift;
            return $env->{REQUEST_URI} || $env->{PATH_INFO}
        }
    });

returning undef causes both cache generation and reference disabled.

=head2 max_keys => number [optional]

Maximum number of cache keys, defaults to 100.

    $self->plugin(cache_lite => {max_keys => 100});

=head2 threshold => number [optional]

Threshold time interval for page generation to activate cache generation.
You can give it a floating number of second. This plugin measures how long
the page generation spent and compares to the threshold. 

    $self->plugin(cache_lite => {threshold => 0.8});

=head1 METHODS

=head2 Plack::Middleware::CacheLite->set_expire($code_ref)

This appends a code reference for cache expiration control. 
    
    package Model::NewsRelease;
    
    my $sqlite_file = 'news_release.sqlite';
    
    sub list {
        ...
        
        Plack::Middleware::CacheLite->set_expire(sub {
            my $cache_timestamp = shift;
            return $cache_timestamp - (stat($sqlite_file))[9] > 0;
        });
        ...
    }

=head2 call

Internal use.

=head2 prepare_app

Internal use.

=head1 AUTHOR

Sugama, E<lt>sugama@jamadam.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by jamadam.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
