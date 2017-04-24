#!/usr/bin/env perl6

use v6;

use PathTools;
use Test;

use Duckboard::Store;

my $tmpdir = mktemp();
say "working in $tmpdir...";

# given an empty store
my $store = Duckboard::Store.new("$tmpdir/store");
$store.start;

dies-ok({ $store.list-objects('default', 'items') }, "stores must throw on list-objects for non-existing domain");
dies-ok({ $store.get-object('default', 'items', '0000') }, "stores must throw on get-object for non-existing domain");
dies-ok({ $store.list-versions('default', '0000') }, "stores must throw on list-versions for non-existing domain");
# XXX create/put

# once the domain is created, we should return an empty list
$store.create-domain('default');
cmp-ok($store.list-objects('default', 'items').elems, '==', 0, "initial list of objects for domain must be empty");
is($store.get-object('default', 'items', '0000'), Nil, "get-object for non-existing id must return Nil");
my $short-item = $store.create-object('default', 'items', {title => 'first item', tags => [], description => 'test234'});
my $id = $short-item{'id'};
my $new-item = $store.put-object('default', 'items', $id, {title => 'first item v2', tags => [], description => 'test234'});
cmp-ok($new-item{'title'}, 'eq', 'first item v2', "Title on item can be updated");
cmp-ok($short-item{'timestamp'}, '<', $new-item{'timestamp'}, "After updating an item, the timstamp is increased");

# XXX check it
# XXX check item exists on disk
# XXX read back and compare
# XXX this is too simple, but as a start...
$id = $short-item<id>;
isnt($store.get-object('default', 'items', $id), Nil, "get-object for created item $id must not return Nil");

done-testing;
