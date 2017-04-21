unit class Duckboard::Logic;

use Duckboard::Logging;
use X::Duckboard::BadRequest;

my $log = Duckboard::Logging.new('logic');

has $.store;

method new($store) {
    $log.info("Setting up business logic");
    return self.bless(store => $store);
}

method start {
    # XXX nothing to do
}

method stop {
    # XXX nothing to do
}

method list-domains {
    $log.trace("list-domains");
    return $!store.list-domains;
}

method create-domain($domain) {
    $log.trace("create-domain domain=$domain");
    return $!store.create-domain($domain);
}

method list-items($domain, $at = Nil, $filter = Nil) {
    # XXX should probably apply filter here rather than in store
    $log.trace("list-items domain=$domain");
    # XXX at, filter
#    die X::Duckboard::BadRequest.new("timestamp in 'at' argument malformed");
    return $!store.list-items($domain);
}

method create-item($domain, $item) {
    $log.trace("create-item domain=$domain item=" ~ $item.perl);
    if (!defined $item{'title'}) {
        die X::Duckboard::BadRequest.new("new item needs 'title' property");
    }
    if (!defined $item{'tags'}) {
        die X::Duckboard::BadRequest.new("new item needs 'tags' property (but can be empty)");
    }
    if (defined $item{'id'}) {
        die X::Duckboard::BadRequest.new("new item must not have 'id' property");
    }
    # XXX check title is string and tags is array
    my $ret = $!store.create-item($domain, $item);
    # XXX better logging, also store should not modify input argument but deep copy
    $log.trace("  -> " ~ $ret{'id'});
    return $ret;
}

method put-item($domain, $id, $item, $old-timestamp = Nil) {
    $log.trace("put-item domain=$domain id=$id");
    # XXX old-timestamp
    # XXX validations
    # XXX do we even want to return anything? if so, server needs updating
    return $!store.put-item($domain, $id, $item);
}

method get-item($domain, $id, $at = Nil) {
    $log.trace("get-item domain=$domain id=$id");
    # XXX handle at
    return $!store.get-item($domain, $id);
}
