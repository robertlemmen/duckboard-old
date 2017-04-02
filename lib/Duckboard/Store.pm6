unit class Duckboard::Store;

use Duckboard::Logging;

my $log = Duckboard::Logging.new('store');

has $.store-dir;

method new($store-dir) {
    $log.info("Setting up store");
    my $ret = self.bless(store-dir => $store-dir);
    $ret!init;
    return $ret;
}

method !init {
    # XXX mkdir etc
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
