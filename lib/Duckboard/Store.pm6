unit class Duckboard::Store;

use JSON::Tiny;

use Duckboard::Logging;
use X::Duckboard::BadRequest;

my $log = Duckboard::Logging.new('store');

# XXX across the boad, this needs lockfiles to protect certain operations

has $.store-dir; #XXX should this be private? same across other classes

our enum Supported-Types is export <items sortings>;

# we only store whether a domain exists or not, one level
has $!domains-cache = {};
has $!domains-cache-time = 0;

# this is keyed by domain at the first level
# and the cache contains a hash with keys per 
has $!objects-cache = {};
has $!objects-cache-time = {};

# sequence to allocate new ids
has $!max-item-id = {};

# last timestamp allocated to avoid collisions
has $!last-timestamp = 0;

method new($store-dir) {
    $log.info("Setting up store in '$store-dir'");
    my $ret = self.bless(store-dir => $store-dir);
    return $ret;
}

method start {
    if (!$!store-dir.IO.d) {
        $log.info("Store directory '$!store-dir' does not exist, creating");
        mkdir $!store-dir;
        # XXX create lockfile
    }
    self!refresh-domains-cache;
}

method stop {
    # XXX not sure what to do...
}

method !refresh-domains-cache($domain = Nil) {
    if ($domain && $!domains-cache{$domain}) {
        # domains can only be added, so if it is in our cache then
        # the cache is ok for that item
        return;
    }
    # we are interested in all domains, so update cache
    my $disk-timestamp = $!store-dir.IO.modified;
    if ($disk-timestamp > $!domains-cache-time) {
        # reload domains cache as it has changed on disk
        $!domains-cache = {};
        for $!store-dir.IO.dir -> $entry {
            if ($entry.d) {
                $!domains-cache{$entry.basename} = 1;
            }
        }
        $!domains-cache-time = $disk-timestamp;
    }
}

# XXX alternatively this could update the cache
method !invalidate-domains-cache {
    $!domains-cache-time = 0;
}

method !refresh-objects-cache($domain, $type, $item = Nil) {
    if ($item && $!objects-cache-time{$domain}{$type}{$item}) {
        # items can only be added, so if we have something in out cache
        # then the cache is correct
        return;
    }
    my $disk-timestamp = "$!store-dir/$domain/$type".IO.modified;
    if (   (defined $!objects-cache-time{$domain}{$type}) 
        && ($disk-timestamp > $!objects-cache-time{$domain}{$type})) {
        # reload objects cache for this domain and type as it has changed on disk
        $!objects-cache{$domain}{$type} = {};
        for "$!store-dir/$domain/$type".IO.dir -> $entry {
            if ($entry.d) {
                my $item-id = $entry.basename;
                $!objects-cache{$domain}{$type}{$item-id} = 1;
                if ($item-id > $!max-item-id{$domain}{$type}) {
                    $!max-item-id{$domain}{$type} = $item-id;
                }
            }
        }
        $!objects-cache-time{$domain}{$type} = $disk-timestamp;
    }
}

# XXX alternatively this could update the cache
method !invalidate-objects-cache($domain, $type) {
    $!objects-cache-time{$domain}{$type} = 0;
}

method !load-object($domain, $type, $id, $at = Nil) {
    # XXX at
    # XXX LRU-caching
    return from-json("$!store-dir/$domain/$type/$id/latest".IO.slurp);
}

method !store-object($domain, $type, $id, $timestamp, $object) {
    my $store-object = $object; # XXX make deep copy
    $store-object{'id'} = $id;
    $store-object{'timestamp'} = $timestamp;
    my $fh = open("$!store-dir/$domain/$type/$id/$timestamp", :w);
    $fh.print(to-json($store-object));
    close $fh;
#    # XXX sad that we can't be atomic, this needs handling... do we have a rename()??
    unlink("$!store-dir/$domain/$type/$id/latest");
    symlink("$!store-dir/$domain/$type/$id/$timestamp", "$!store-dir/$domain/$type/$id/latest");
    return $store-object;
}

method !allocate-id($domain, $type) {
    return ++$!max-item-id{$domain}{$type};
}

method !make-timestamp {
    my $ret;
    repeat {
        my $now = DateTime.new(now).Instant;
        $ret = truncate($now.to-posix.first * 1000.0);
        if ($!last-timestamp == $ret) {
            sleep(0.001);
        }
    } while ($!last-timestamp == $ret);
    return $ret;
}

method list-domains {
    self!refresh-domains-cache;
    return $!domains-cache.keys.sort;
}

method create-domain($domain) {
    self!refresh-domains-cache;
    if (!"$!store-dir/$domain".IO.d) {
        # XXX looks like a bit of a race...
        for Supported-Types.enums.keys -> $type {
            mkdir "$!store-dir/$domain/$type";
        }
        # XXX create lockfile
        self!invalidate-domains-cache;
    }
}

# XXX these should probably all be positional arguments
method list-objects($domain, $type, $at = Nil) {
    self!refresh-domains-cache($domain);
    if (!$!domains-cache{$domain}) {
        die X::Duckboard::BadRequest.new("requested domain '$domain' does not exist");
    }
    self!refresh-objects-cache($domain, $type);
    # XXX at

    my $item-ids = $!objects-cache{$domain}{$type}.keys.sort;
    my $items = $item-ids.map(-> $id { 
        self!load-object($domain, $type, $id, $at)
    });
    return $items;
}

method get-object($domain, $type, $id, $at = Nil) {
    self!refresh-domains-cache($domain);
    if (!$!domains-cache{$domain}) {
        die X::Duckboard::BadRequest.new("requested domain '$domain' does not exist");
    }
    self!refresh-objects-cache($domain, $type, $id);
    if (!$!objects-cache{$domain}{$type}{$id}) {
        return Nil;
    }
    return self!load-object($domain, $type, $id, $at);
}

method put-object($domain, $type, $id, $item, $old-timestamp = Nil) {
    # XXX support for old-timestamp
    self!refresh-domains-cache($domain);
    if (!$!domains-cache{$domain}) {
        die X::Duckboard::BadRequest.new("requested domain '$domain' does not exist");
    }
    self!refresh-objects-cache($domain, $type, $id);
    if (!$!objects-cache{$domain}{$type}{$id}) {
        die X::Duckboard::BadRequest.new("requested item '$id' in domain '$domain' does not exist");
    }
    my $timestamp = self!make-timestamp;
    my $stored-item = self!store-object($domain, $type, $id, $timestamp, $item);
    self!invalidate-objects-cache($domain, $type);
    return $stored-item;
}

method create-object($domain, $type, $item) {
    self!refresh-domains-cache($domain);
    if (!$!domains-cache{$domain}) {
        die X::Duckboard::BadRequest.new("requested domain '$domain' does not exist");
    }
    self!refresh-objects-cache($domain, $type);
    # XXX validate item constraints
    my $new-id = self!allocate-id($domain, $type);
    my $timestamp = self!make-timestamp;
    mkdir("$!store-dir/$domain/items/$new-id");
    my $stored-item = self!store-object($domain, $type, $new-id, $timestamp, $item);
    self!invalidate-objects-cache($domain, $type);
    return $stored-item;
}

method list-versions($domain, $id) {
    self!refresh-domains-cache($domain);
    if (!$!domains-cache{$domain}) {
        die X::Duckboard::BadRequest.new("requested domain '$domain' does not exist");
    }
    # XXX return list of short-items
    ...
}
