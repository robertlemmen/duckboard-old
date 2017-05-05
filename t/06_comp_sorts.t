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

my $rq = $client.put;
$rq.url("http://0.0.0.0:$port/api/v1/items/test");
my $response = $rq.run;
cmp-ok($response.status, '==', 200, "creating new domain succeeds");

$response = $client.get("http://0.0.0.0:$port/api/v1/sortings/test");
ok($response.success, "getting list of sortings succeeds");
cmp-ok(from-json($response.content), 'eq', [], "list of sortings initially empty");

$rq = $client.put;
$rq.url("http://0.0.0.0:$port/api/v1/sortings/test/1233");
$rq.set-content(to-json({title => 'testA'}));
$response = $rq.run;
cmp-ok($response.status, '==', 200, "PUTting to create new sorting succeeds");

$response = $client.get("http://0.0.0.0:$port/api/v1/sortings/test");
ok($response.success, "getting list of sortings succeeds");
my $data = from-json($response.content);
cmp-ok($data.elems, '==', 1, "list of sortings has one element");
$data = $data[0];
cmp-ok($data{'id'}, 'eq', 1233, "id of new sorting matches");

$response = $client.get("http://0.0.0.0:$port/api/v1/sortings/test/1233");
ok($response.success, "getting single sorting succeeds");
$data = from-json($response.content);
cmp-ok($data{'id'}, 'eq', 1233, "id of new sorting matches");

$srv.stop;
$logic.stop;
$store.stop;

done-testing;
