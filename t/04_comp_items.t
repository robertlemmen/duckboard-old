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

plan 24;

# XXX why does this not work with localhost?
my $response = $client.get("http://0.0.0.0:$port/api/v1/items");
ok($response.success, "getting initial domain list succeeds");
cmp-ok(from-json($response.content), 'eq', [], "initial domain list is empty");

my $rq = $client.post;
$rq.url("http://0.0.0.0:$port/api/v1/items/test");
$response = $rq.run;
cmp-ok($response.status, '==', 500, "POSTing to create new domain fails, this is actually a rq to create a new item");

$rq = $client.put;
$rq.url("http://0.0.0.0:$port/api/v1/items/test2");
$response = $rq.run;
cmp-ok($response.status, '==', 200, "PUTing to create new domain succeeds");

$response = $client.get("http://0.0.0.0:$port/api/v1/items");
ok($response.success, "getting updated domain list succeeds");
cmp-ok(from-json($response.content), 'eq', ['test2'], "domain list contains new domain");

$response = $client.get("http://0.0.0.0:$port/api/v1/items/test");
# XXX should be 404?
cmp-ok($response.status, '==', 400, "getting list of items from non-existing domain fails");

$response = $client.get("http://0.0.0.0:$port/api/v1/items/test2");
ok($response.success, "getting list of items from non-existing domain succeeds");
cmp-ok(from-json($response.content), 'eq', [], "item list initially empty");

$rq = $client.post;
$rq.url("http://0.0.0.0:$port/api/v1/items/test2");
$rq.set-content(to-json({id => 123, title => 'test', tags => ''}));
$response = $rq.run;
cmp-ok($response.status, '==', 400, "posting item with id fails");

$rq = $client.post;
$rq.url("http://0.0.0.0:$port/api/v1/items/test2");
$rq.set-content(to-json({tags => []}));
$response = $rq.run;
cmp-ok($response.status, '==', 400, "posting item without title fails");

$rq = $client.post;
$rq.url("http://0.0.0.0:$port/api/v1/items/test2");
$rq.set-content(to-json({title => 'test', tags => ''}));
$response = $rq.run;
cmp-ok($response.status, '==', 200, "posting basic item succeeds");
my $item = from-json($response.content);
ok({defined $item{'id'}}, "newly created item has 'id'");
my $id = $item{'id'};
ok({defined $item{'timestamp'}}, "newly created item has 'timestamp'");
my $old-timestamp = $item{'timestamp'};
cmp-ok($item{'title'}, 'eq' , 'test', "newly created item has correct title");
cmp-ok($item{'tags'}, 'eq' , '', "newly created item has correct tags");

$rq = $client.put;
my $test-id = $id+1;
$rq.url("http://0.0.0.0:$port/api/v1/items/test2/$test-id");
$rq.set-content(to-json({title => 'test2', tags => ''}));
$response = $rq.run;
# XXX should be 404?
cmp-ok($response.status, '==', 400, "PUTting to non-existing item fails");

$rq = $client.put;
$test-id = $id;
$rq.url("http://0.0.0.0:$port/api/v1/items/test2/$test-id");
$rq.set-content(to-json({title => 'test3', tags => 'key:value'}));
$response = $rq.run;
ok($response.success, "PUT new version of existing item succeeds");

$test-id = $id+1;
$response = $client.get("http://0.0.0.0:$port/api/v1/items/test2/$test-id");
cmp-ok($response.status, '==', 404, "getting non-existing item fails");

$test-id = $id;
$response = $client.get("http://0.0.0.0:$port/api/v1/items/test2/$test-id");
ok($response.success, "getting existing item succeeds");
$item = from-json($response.content);
cmp-ok($item{'id'}, '==', $test-id, "id of updated item is correct");
cmp-ok($item{'title'}, 'eq', 'test3', "title of updated item is correct");
cmp-ok($item{'timestamp'}, '>', $old-timestamp, "timestamp of updated item has increased");
cmp-ok($item{'tags'}, 'eq', 'key:value', "tags property has been updated correctly");

# XXX more stuff!

$srv.stop;
$logic.stop;
$store.stop;

done-testing;
