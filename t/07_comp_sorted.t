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
my $srv = Duckboard::Server.new($port, $logic, Nil);

$store.start;
$logic.start;
$srv.start;

my $client = HTTP::Client.new;

plan 29;

my $rq = $client.put;
$rq.url("http://0.0.0.0:$port/api/v1/items/dom1");
my $response = $rq.run;
cmp-ok($response.status, '==', 200, "PUTing to create new domain succeeds");

$response = $client.get("http://0.0.0.0:$port/api/v1/items/dom1");
ok($response.success, "getting list of items from domain succeeds");
cmp-ok(from-json($response.content), 'eq', [], "item list initially empty");

sub create-item($title, $tags) {
    $rq = $client.post;
    $rq.url("http://0.0.0.0:$port/api/v1/items/dom1");
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

$response = $client.get("http://0.0.0.0:$port/api/v1/items/dom1");
ok($response.success, "getting list of items without filter succeeds");
my $item-list = from-json($response.content).map(-> $id {
    $id{'title'} 
});
is($item-list, <A B C D E F>, "All items are returned in basic items query");

$rq = $client.put;
$rq.url("http://0.0.0.0:$port/api/v1/sortings/dom1/123");
$rq.set-content(to-json({nid => 'root', filter => ''}));
$response = $rq.run;
cmp-ok($response.status, '==', 200, "Creating new sorting suceeds");

$response = $client.get("http://0.0.0.0:$port/api/v1/sorted/dom1/12300");
cmp-ok($response.status, '==', 404, "Getting non-existing sorted list of items fails");

$response = $client.get("http://0.0.0.0:$port/api/v1/sorted/dom1/123");
cmp-ok($response.status, '==', 200, "Getting sorted list of items succeeds");
my $sorted = from-json($response.content);
my $root-item-list = $sorted{'items'}.map(-> $id {
    $id{'title'} 
});
is($root-item-list, <A B C D E F>, "All items are returned in simple sorted query");

$rq = $client.put;
$rq.url("http://0.0.0.0:$port/api/v1/sortings/dom1/123");
$rq.set-content(to-json({nid => 'root', filter => 'tag1/tag3'}));
$response = $rq.run;
cmp-ok($response.status, '==', 200, "Updating sorting suceeds");

$response = $client.get("http://0.0.0.0:$port/api/v1/sorted/dom1/123");
cmp-ok($response.status, '==', 200, "Getting sorted list of items succeeds");
$sorted = from-json($response.content);
$root-item-list = $sorted{'items'}.map(-> $id {
    $id{'title'} 
});
is($root-item-list, <B D E F>, "Correct items are returned in sorted query with root filter");

$rq = $client.put;
$rq.url("http://0.0.0.0:$port/api/v1/sortings/dom1/123");
$rq.set-content(to-json({nid => 'root', filter => '!tag4', children => [
                            {nid => 'c1', filter => 'tag1'},
                            {nid => 'c2', filter => ''},
                            ]}));
$response = $rq.run;
cmp-ok($response.status, '==', 200, "Updating sorting suceeds");

sub flatten-item-list($node) {
    my $result = {};
    $result{$node{'nid'}} = ($node{'items'} // []).map(-> $id {
        $id{'title'} 
    });
    if (defined $node{'children'}) {
        for @($node{'children'}) -> $child {
            my $child-result = flatten-item-list($child);
            $result = %(|$result, |$child-result);
        }
    }
    return $result;
}

$response = $client.get("http://0.0.0.0:$port/api/v1/sorted/dom1/123");
cmp-ok($response.status, '==', 200, "Getting sorted list of items succeeds");
$sorted = from-json($response.content);
$item-list = flatten-item-list($sorted);
is($item-list.keys.sort, <c1 c2 root >, "No unexpected children returned");
is($item-list{'root'}, < >, "No root items are returned in query against sorting with children");
is($item-list{'c1'}, <B D>, "Correct items are returned on node c1");
is($item-list{'c2'}, <A C E>, "Correct items are returned on node c2");

$response = $client.get("http://0.0.0.0:$port/api/v1/sorted/dom1/123?filter=!tag3");
cmp-ok($response.status, '==', 200, "Getting sorted list of items with extra filter succeeds");
$sorted = from-json($response.content);
$item-list = flatten-item-list($sorted);
is($item-list.keys.sort, <c1 c2 root >, "No unexpected children returned");
is($item-list{'root'}, < >, "No root items are returned in query against sorting with children");
is($item-list{'c1'}, <B D>, "Correct items are returned on node c1");
is($item-list{'c2'}, <A C>, "Correct items are returned on node c2 when using cmdline filter");

$srv.stop;
$logic.stop;
$store.stop;

done-testing;
