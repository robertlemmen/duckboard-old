#!/usr/bin/env perl6

use v6;

use PathTools;
use Test;

use Duckboard::Store;

my $tmpdir = mktemp();
say "working in $tmpdir...";

plan 10;

# given an empty working directory, after creating and starting a duckboard 
# store it will set up the store directory
my $store = Duckboard::Store.new("$tmpdir/store");
$store.start;
ok("$tmpdir/store".IO.d, "directory must be created by store setup");

# the initial list of domains is empty
cmp-ok($store.list-domains.elems, '==', 0, "initial list of domains must be empty");

# when creating domains, they can be retrieved through the API and seen on disk
$store.create-domain('default');
cmp-ok($store.list-domains, 'eq', ('default'), "added domain must be visible through API");
ok("$tmpdir/store/default".IO.d, "directory for domain must get created");

# creating the same domain again is idempotent
$store.create-domain('default');
cmp-ok($store.list-domains, 'eq', ('default'), "adding existing domain must be idempotent");

# create another domain
$store.create-domain('atest');
cmp-ok($store.list-domains.sort, 'eq', ('atest', 'default'), "two domains can be created");

# when I stop and restart the store, I should have the same state
$store.stop;
$store = Duckboard::Store.new("$tmpdir/store");
$store.start;
cmp-ok($store.list-domains.sort, 'eq', ('atest', 'default'), "restarting the store recreates state");

# changes from one store are visible in other stores using the same directory
my $store2 = Duckboard::Store.new("$tmpdir/store");
cmp-ok($store2.list-domains.sort, 'eq', ('atest', 'default'), "state is visible in second store");
$store2.create-domain('btest');
cmp-ok($store2.list-domains.sort, 'eq', ('atest', 'btest', 'default'), "second store can be modified");
sleep(.01); # filesystem timestamps have some granularity
cmp-ok($store.list-domains.sort, 'eq', ('atest', 'btest', 'default'), "modifications in second store are visible in first");


done-testing;
