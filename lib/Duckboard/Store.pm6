unit class Duckboard::Store;

use JSON::Tiny;

use Duckboard::Logging;
use X::Duckboard::BadRequest;

my $log = Duckboard::Logging.new('store');

# XXX across the boad, this needs lockfiles to protect certain operations

has $.store-dir; #XXX should this be private? same across other classes

# we only store whether a domain exists or not, one level
has $!domains-cache = {};
has $!domains-cache-time = 0;

# this is keyed by domain at the first level
# and the cache contains a hash with keys per item
has $!items-cache = {};
has $!items-cache-time = {};
has $!max-item-id = {};

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

method !refresh-items-cache($domain, $item = Nil) {
    if ($item && $!items-cache-time{$domain}{$item}) {
        # items can only be added, so if we have something in out cache
        # then the cache is correct
        return;
    }
    my $disk-timestamp = "$!store-dir/$domain/items".IO.modified;
    if ((defined $!items-cache-time{$domain}) && ($disk-timestamp > $!items-cache-time{$domain})) {
        # reload items cache for this domain as it has changed on disk
        $!items-cache{$domain} = {};
        for "$!store-dir/$domain/items".IO.dir -> $entry {
            if ($entry.d) {
                my $item-id = $entry.basename;
                $!items-cache{$domain}{$item-id} = 1;
                if ($item-id > $!max-item-id{$domain}) {
                    $!max-item-id{$domain} = $item-id;
                }
            }
        }
        $!items-cache-time{$domain} = $disk-timestamp;
    }
}

# XXX alternatively this could update the cache
method !invalidate-items-cache($domain) {
    $!items-cache-time{$domain} = 0;
}

method !load-item($domain, $id, $at = Nil) {
    # XXX at
    # XXX LRU-caching
    return from-json("$!store-dir/$domain/items/$id/latest".IO.slurp);
}

method !store-item($domain, $id, $timestamp, $item) {
    my $store-item = $item; # XXX make deep copy
    $store-item<id> = $id;
    $store-item<timestamp> = $timestamp;
    my $fh = open("$!store-dir/$domain/items/$id/$timestamp", :w);
    $fh.print(to-json($store-item));
    close $fh;
#    # XXX sad that we can't be atomic, this needs handling... do we have a rename()??
    unlink("$!store-dir/$domain/items/$id/latest");
    symlink("$!store-dir/$domain/items/$id/$timestamp", "$!store-dir/$domain/items/$id/latest");
    return $store-item;
}

method !allocate-id($domain) {
    return ++$!max-item-id{$domain};
}

method !shorten-item($item) {
    my $ret = {};
    $ret<id> = $item<id>;
    $ret<title> = $item<title>;
    $ret<timestamp> = $item<timestamp>;
    $ret<tags> = $item<tags>;
    return $ret;
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
        mkdir "$!store-dir/$domain/items";
        # XXX create lockfile
        self!invalidate-domains-cache;
    }
}

# XXX these should probably all be positional arguments
method list-items($domain, $at = Nil, $filter = Nil) {
    self!refresh-domains-cache($domain);
    if (!$!domains-cache{$domain}) {
        die X::Duckboard::BadRequest.new("requested domain '$domain' does not exist");
    }
    self!refresh-items-cache($domain);
    # XXX at
    # XXX filter should be done in logic

    my $item-ids = $!items-cache{$domain}.keys.sort;
    my $items = $item-ids.map(-> $id { 
        self!load-item($domain, $id, $at)
    });
    $items = $items.map(-> $current-item {
        self!shorten-item($current-item);
    });
    return $items;
}

method get-item($domain, $id, $at = Nil) {
    self!refresh-domains-cache($domain);
    if (!$!domains-cache{$domain}) {
        die X::Duckboard::BadRequest.new("requested domain '$domain' does not exist");
    }
    self!refresh-items-cache($domain, $id);
    if (!$!items-cache{$domain}{$id}) {
        return Nil;
    }
    return self!load-item($domain, $id, $at);
}

method put-item($domain, $id, $item, $old-timestamp = Nil) {
    # XXX support for old-timestamp
    self!refresh-domains-cache($domain);
    if (!$!domains-cache{$domain}) {
        die X::Duckboard::BadRequest.new("requested domain '$domain' does not exist");
    }
    self!refresh-items-cache($domain, $id);
    if (!$!items-cache{$domain}{$id}) {
        die X::Duckboard::BadRequest.new("requested item '$id' in domain '$domain' does not exist");
    }
    my $timestamp = self!make-timestamp;
    my $stored-item = self!store-item($domain, $id, $timestamp, $item);
    self!invalidate-items-cache($domain);
    return self!shorten-item($stored-item);
}

method create-item($domain, $item) {
    self!refresh-domains-cache($domain);
    if (!$!domains-cache{$domain}) {
        die X::Duckboard::BadRequest.new("requested domain '$domain' does not exist");
    }
    self!refresh-items-cache($domain);
    # XXX validate item constraints
    my $new-id = self!allocate-id($domain);
    my $timestamp = self!make-timestamp;
    mkdir("$!store-dir/$domain/items/$new-id");
    my $stored-item = self!store-item($domain, $new-id, $timestamp, $item);
    self!invalidate-items-cache($domain);
    return self!shorten-item($stored-item);
}

method list-versions($domain, $id) {
    self!refresh-domains-cache($domain);
    if (!$!domains-cache{$domain}) {
        die X::Duckboard::BadRequest.new("requested domain '$domain' does not exist");
    }
    # XXX return list of short-items
    ...
}
