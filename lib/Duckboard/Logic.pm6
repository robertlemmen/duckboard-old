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

method list-items($domain, $at = Nil, $filter = Nil) {
    # XXX should probably apply filter here rather than in store
    $log.trace("list-items domain=$domain");
    # XXX at, filter
    die X::Duckboard::BadRequest.new("timestamp in 'at' argument malformed");
    return [];
#    return $!store.list-items($domain);
}

