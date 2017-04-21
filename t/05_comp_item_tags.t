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

my $rq = $client.put;
$rq.url("http://0.0.0.0:$port/api/v1/items/test-item-tags");
my $response = $rq.run;
cmp-ok($response.status, '==', 200, "PUTing to create new domain succeeds");

$response = $client.get("http://0.0.0.0:$port/api/v1/items/test-item-tags");
ok($response.success, "getting list of items from non-existing domain succeeds");
cmp-ok(from-json($response.content), 'eq', [], "item list initially empty");

sub create-item($title, $tags) {
    $rq = $client.post;
    $rq.url("http://0.0.0.0:$port/api/v1/items/test-item-tags");
    $rq.set-content(to-json({title => $title, tags => $tags}));
    $response = $rq.run;
    cmp-ok($response.status, '==', 200, "posting basic item succeeds");
    my $item = from-json($response.content);
}

create-item('A', '');
create-item('B', 'tag1');
create-item('C', 'tag2');
create-item('D', 'tag1;tag2');
create-item('E', 'tag3:12');
create-item('F', 'tag3:14;tag4');

$response = $client.get("http://0.0.0.0:$port/api/v1/items/test-item-tags");
ok($response.success, "getting list of items without filter succeeds");
my $item-list = from-json($response.content).map(-> $id {
    $id{'title'} 
});
is($item-list, <A B C D E F>, "All items are returned when not supplying a filter");

$response = $client.get("http://0.0.0.0:$port/api/v1/items/test-item-tags?filter=test%3Dval");
cmp-ok($response.status, '==', 400, "getting list of items with malformed filter fails with code");


$response = $client.get("http://0.0.0.0:$port/api/v1/items/test-item-tags?filter=tag0");
cmp-ok($response.status, '==', 200, "getting list of items with simple filter suceeds");
$item-list = from-json($response.content).map(-> $id {
    $id{'title'} 
});
is($item-list, < >, "No items are returned when supplying a filter that does not match any");

$response = $client.get("http://0.0.0.0:$port/api/v1/items/test-item-tags?filter=tag4");
cmp-ok($response.status, '==', 200, "getting list of items with simple filter suceeds");
$item-list = from-json($response.content).map(-> $id {
    $id{'title'} 
});
is($item-list, <F >, "Single, matching item is returned for simple, matching filter");

$response = $client.get("http://0.0.0.0:$port/api/v1/items/test-item-tags?filter=tag1/tag2");
cmp-ok($response.status, '==', 200, "getting list of items with OR filter suceeds");
$item-list = from-json($response.content).map(-> $id {
    $id{'title'} 
});
is($item-list, <B C D>, "OR filter returns correct items");

$response = $client.get("http://0.0.0.0:$port/api/v1/items/test-item-tags?filter=(tag1/tag2)");
cmp-ok($response.status, '==', 200, "getting list of items with grouped OR filter suceeds");
$item-list = from-json($response.content).map(-> $id {
    $id{'title'} 
});
is($item-list, <B C D>, "Grouped OR filter returns correct items");

# XXX escaping "+" for now, but need better char for it...
$response = $client.get("http://0.0.0.0:$port/api/v1/items/test-item-tags?filter=tag1\%2Btag2");
cmp-ok($response.status, '==', 200, "getting list of items with AND filter suceeds");
$item-list = from-json($response.content).map(-> $id {
    $id{'title'} 
});
is($item-list, <D >, "AND filter returns correct items");

# XXX darn, ! as well!
$response = $client.get("http://0.0.0.0:$port/api/v1/items/test-item-tags?filter=\%21(tag1/tag3)");
cmp-ok($response.status, '==', 200, "getting list of items with NOT filter suceeds");
$item-list = from-json($response.content).map(-> $id {
    $id{'title'} 
});
is($item-list, <A C >, "NOT filter returns correct items");

$srv.stop;
$logic.stop;
$store.stop;

done-testing;
