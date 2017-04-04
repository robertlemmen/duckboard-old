unit class Duckboard::Store;

use Duckboard::Logging;

my $log = Duckboard::Logging.new('store');

has $.store-dir; #XXX should this be private? same across other classes
has $!domains-cache = [];
has $!domains-cache-time = 0;

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
    # XXX read initial state from disk? perhaps not required with caching?
}

method stop {
    # XXX not sure what to do...
}

method !refresh-domains-cache {
    my $disk-timestamp = $!store-dir.IO.modified;
    if ($disk-timestamp > $!domains-cache-time) {
        # reload domains cache as it has changed on disk
        $!domains-cache = [];
        for $!store-dir.IO.dir -> $entry {
            if ($entry.d) {
                $!domains-cache.append($entry.basename);
            }
        }
        $!domains-cache-time = $disk-timestamp;
    }
}

method !invalidate-domains-cache {
    $!domains-cache-time = 0;
}

method list-domains {
    self!refresh-domains-cache;
    return $!domains-cache;
}

method create-domain($domain) {
    self!refresh-domains-cache;
    if (!"$!store-dir/$domain".IO.d) {
        mkdir "$!store-dir/$domain";
        # XXX create lockfile
        self!invalidate-domains-cache;
    }
}

# XXX these should probably all be positional arguments
method list-items($domain, $at = Nil, $filter = Nil) {
    # XXX return list of short items
    ...
}

method get-item($domain, $id, $at = Nil) {
    # XXX return item in question or Nil
    ...
}

method put-item($domain, $id, $item, $old-timestamp = Nil) {
    # XXX may fail apart from exception, return new short-item with timestamp
    ...
}

method create-item($domain, $item) {
    # XXX return short-item with new id
    ...
}

method list-versions($domain, $id) {
    # XXX return list of short-items
    ...
}
