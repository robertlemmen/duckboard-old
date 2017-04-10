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

# list-items should throw because the domain does not exist
dies-ok({ $store.list-items('default') }, "stores must throw on list-items for non-existing domain");
dies-ok({ $store.get-item('default', '0000') }, "stores must throw on get-item for non-existing domain");
dies-ok({ $store.list-versions('default', '0000') }, "stores must throw on list-versions for non-existing domain");
# XXX create/put

# once the domain is created, we should return an empty list
$store.create-domain('default');
cmp-ok($store.list-items('default').elems, '==', 0, "initial list of items for domain must be empty");
is($store.get-item('default', '0000'), Nil, "get-item for non-existing item must return Nil");
my $short-item = $store.create-item('default', {title => 'first item', tags => [], description => 'test234'});
# XXX check it
# XXX check item exists on disk
# XXX read back and compare
# XXX this is too simple, but as a start...
my $id = $short-item<id>;
isnt($store.get-item('default', $id), Nil, "get-item for created item $id must not return Nil");

done-testing;
