#!/usr/bin/env perl
use Mojolicious::Lite;
use Mojo::Util qw( url_escape );
use Try::Tiny;
use Data::Dumper;


# Get the configuration
my $config = plugin 'JSONConfig';
app->secrets( [ $config->{'app_secret'} ] );

# Get a UserAgent
my $ua = Mojo::UserAgent->new;

# WhatCounts setup
my $API        = $config->{'wc_api_url'};
my $wc_list_id = $config->{'wc_listid'};
my $wc_realm   = $config->{'wc_realm'};
my $wc_pw      = $config->{'wc_password'};
my $secret     = $config->{'tw_secret'};

post '/' => sub {
    my $c = shift;
    # Don't do anything, unless we know this post if from Twitter
    unless ( $c->param( 'secret' ) && $c->param( 'secret' ) eq $secret ) {
        $c->render( text => "Forbidden", status => 403 );
        return;
    }

    # Grab the post data from Twitter
    my $email       = $c->param( 'email' );
    my $screen_name = url_escape $c->param( 'screen_name' );
    my $name        = url_escape $c->param( 'name' );
    my $campaign    = url_escape $c->param( 'campaign' );
    my $card        = url_escape $c->param( 'card' );
    my $frequency   = $c->param( 'frequency' );
    app->log->info( $email, $screen_name, $name, $campaign, $card );

    # Post it to WhatCounts
    my $args = {
        r                     => $wc_realm,
        p                     => $wc_pw,
        list_id               => $wc_list_id,
        cmd                   => 'sub',
        override_confirmation => '1',
        force_sub             => '1',
        format                => '2',
        data =>
            "email,custom_name_full,custom_twitter,custom_twitter_card,custom_twitter_campaign,custom_is_twitter_lead,pref_enews_$frequency^$email,$name,$screen_name,$card,$campaign,1,1"
    };
    app->log->info( Dumper( $args ) );
    my $result;
    my $tx = $ua->post( $API => form => $args );
    if ( my $res = $tx->success ) {
        $result = $res->body;
        app->log->info( Dumper( $result ) );
        $c->render( text => "$result", status => 200 );
    }
    else {
        my ( $err, $code ) = $tx->error;
        $result = $code ? "$code response: $err" : "Connection error: $err";
        app->log->info( Dumper( $result ) );
        $c->render( text => "$result", status => 500 );
    }
};

app->start;
