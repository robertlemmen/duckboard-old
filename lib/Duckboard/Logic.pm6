unit class Duckboard::Logic;

use Duckboard::Logging;
use Duckboard::Tags;
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

method list-items($domain, $at = Nil, $filter-spec = Nil) {
    $log.trace("list-items domain=$domain filter=" ~ ($filter-spec//''));
    # XXX at
    my $filter = Nil;
    if ($filter-spec) {
        $filter = parse-filter($filter-spec);
        CATCH {
            default {
                die X::Duckboard::BadRequest.new(.Str);
            }
        }
    }
    my $items = $!store.list-items($domain);
    if ($filter) {
        $items = $items.grep({ filter-matches($filter, parse-tags($_{'tags'})) });
    }
    return $items;
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
    # XXX check title is string and tags is also a string
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

method list-sortings($domain) {
    $log.trace("list-sortings domain=$domain");
    return $!store.list-sortings($domain);
}
