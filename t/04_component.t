#!/usr/bin/env perl6

use v6;

use PathTools;
use Test;
use HTTP::Client;
use JSON::Tiny;

use Duckboard::Server;
use Duckboard::Store;
use Duckboard::Logic;

my $port = 6002;

my $tmpdir = mktemp();
say "working in $tmpdir...";

my $store = Duckboard::Store.new("$tmpdir/store");
my $logic = Duckboard::Logic.new($store);
my $srv = Duckboard::Server.new($port, $logic);

$store.start;
$logic.start;
$srv.start;

my $client = HTTP::Client.new;

# XXX why does this not work with localhost?
my $response = $client.get("http://0.0.0.0:$port/api/v1/items");
ok($response.success, "getting initial domain list suceeds");
cmp-ok(from-json($response.content), 'eq', [], "initial domain list is empty");

my $rq = $client.post;
$rq.url("http://0.0.0.0:$port/api/v1/items/test");
$response = $rq.run;
cmp-ok($response.status, '==', 405, "POSTing to create new domain fails");

$rq = $client.put;
$rq.url("http://0.0.0.0:$port/api/v1/items/test2");
$response = $rq.run;
cmp-ok($response.status, '==', 200, "PUTing to create new domain suceeds");

$response = $client.get("http://0.0.0.0:$port/api/v1/items");
ok($response.success, "getting updated domain list suceeds");
cmp-ok(from-json($response.content), 'eq', ['test2'], "domain list contains new domain");

$srv.stop;
$logic.stop;
$store.stop;

done-testing;
