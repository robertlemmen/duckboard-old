unit class Duckboard::Logic;

use Duckboard::Logging;
use Duckboard::Tags;
use Duckboard::Store;
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

method !shorten-item($item) {
    my $ret = {};
    $ret<id> = $item<id>;
    $ret<title> = $item<title>;
    $ret<timestamp> = $item<timestamp>;
    $ret<tags> = $item<tags>;
    # XXX should add HATEOS link to full item
    return $ret;
}

method !validate-item($item) {
    if (!defined $item{'title'}) {
        die X::Duckboard::BadRequest.new("new item needs 'title' property");
    }
    if (!defined $item{'tags'}) {
        die X::Duckboard::BadRequest.new("new item needs 'tags' property (but can be empty)");
    }
    if (defined $item{'id'}) {
        die X::Duckboard::BadRequest.new("new item must not have 'id' property");
    }
}

method !validate-sorting($sorting, :$nid-set = {}) {
    if (!defined $sorting{'nid'}) {
        die X::Duckboard::BadRequest.new("sorting needs 'nid' property");
    }
    my $nid = $sorting{'nid'};

    if (defined $nid-set{$nid}) {
        die X::Duckboard::BadRequest.new("sorting node has non-unique nid $nid");
    }
    $nid-set{$nid} = 1;

    if (!defined $sorting{'filter'}) {
        die X::Duckboard::BadRequest.new("sorting node $nid needs 'filter' property");
    }
    {
        my $filter = parse-filter($sorting{'filter'});
        CATCH {
            default {
                die X::Duckboard::BadRequest.new("error on sorting node $nid: " ~ .Str);
            }
        }
    }

    if (defined $sorting{'children'}) {
        if (!$sorting{'children'} ~~ Array) {
            die X::Duckboard::BadRequest.new("sorting node $nid has non-array 'children' property");
        }
        for @($sorting{'children'}) -> $child {
            self!validate-sorting($child, nid-set => $nid-set);
        }
    }
}

method !validate-board($item) {
    # XXX
}

method !split-match($input, $matcher) {
    my $matched = [];
    my $remainder = [];
    for @($input) -> $item {
        if ($matcher($item)) {
            push @($matched), $item;
        }
        else {
            push @($remainder), $item;
        }
    }
    return ($matched, $remainder);
}

method !sort-items($sorting, $items) {
    my $filter = parse-filter($sorting{'filter'});
    my ($matched, $remainder) = self!split-match($items,
        { filter-matches($filter, parse-tags($_{'tags'})) } );

    if (defined $sorting{'children'}) {
        my $items-todo = $matched;
        my $sorted-result = Nil;
        for @($sorting{'children'}) -> $child {
            ($sorted-result, $items-todo) = self!sort-items($child, $items-todo);
        }
    }
    else {
        $sorting{'items'} = $matched;
    }

    return ($sorting, $remainder);
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
    my $items = $!store.list-objects($domain, Supported-Types::items);
    if ($filter) {
        $items = $items.grep({ filter-matches($filter, parse-tags($_{'tags'})) });
    }
    $items = $items.map(-> $current-item {
        self!shorten-item($current-item);
    });
    return $items;
}

method create-item($domain, $item) {
    $log.trace("create-item domain=$domain item=" ~ $item.perl);
    self!validate-item($item);
    my $ret = $!store.create-object($domain, Supported-Types::items, $item);
    # XXX better logging, also store should not modify input argument but deep copy
    $log.trace("  -> " ~ $ret{'id'});
    return self!shorten-item($ret);
}

method put-item($domain, $id, $item, $old-timestamp = Nil) {
    $log.trace("put-item domain=$domain id=$id");
    # XXX old-timestamp
    self!validate-item($item);
    # XXX do we even want to return anything? if so, server needs updating
    my $ret = $!store.put-object($domain, Supported-Types::items, $id, $item);
    return self!shorten-item($ret);
}

method get-item($domain, $id, $at = Nil) {
    $log.trace("get-item domain=$domain id=$id");
    # XXX handle at
    return $!store.get-object($domain, Supported-Types::items, $id);
}

method list-sortings($domain) {
    $log.trace("list-sortings domain=$domain");
    return $!store.list-objects($domain, Supported-Types::sortings);
}

method put-sorting($domain, $id, $sorting, $old-timestamp = Nil) {
    $log.trace("put-sorting domain=$domain id=$id");
    # XXX old-timestamp
    self!validate-sorting($sorting);
    my $ret = $!store.put-object($domain, Supported-Types::sortings, $id, $sorting, create => True);
}

method get-sorting($domain, $id, $at = Nil) {
    $log.trace("get-sorting domain=$domain id=$id");
    # XXX handle at
    return $!store.get-object($domain, Supported-Types::sortings, $id);
}

method get-sorted($domain, $id, $at = Nil, $filter-spec = Nil) {
    $log.trace("get-sorted domain=$domain id=$id");
    # XXX handle at

    my $sorting = $!store.get-object($domain, Supported-Types::sortings, $id);
    if (defined $sorting) {
        my $items = self.list-items($domain, $at, $filter-spec);
        my ($sorted, $remaining) = self!sort-items($sorting, $items);
        my $timestamp = $sorting{'timestamp'};
        for @($items) -> $i {
            if $i{'timestamp'} > $timestamp {
                $timestamp = $i{'timestamp'};
            }
        }
        $sorted{'timestamp'} = $timestamp;
        return $sorted;
    }
    else {
        return Nil;
    }
}

method list-boards($domain) {
    $log.trace("list-boards domain=$domain");
    return $!store.list-objects($domain, Supported-Types::boards);
}

method put-board($domain, $id, $board, $old-timestamp = Nil) {
    $log.trace("put-board domain=$domain id=$id");
    # XXX old-timestamp
    self!validate-board($board);
    my $ret = $!store.put-object($domain, Supported-Types::boards, $id, $board, create => True);
}

method get-board($domain, $id, $at = Nil) {
    $log.trace("get-board domain=$domain id=$id");
    # XXX handle at
    return $!store.get-object($domain, Supported-Types::boards, $id);
}
