unit class Duckboard::Store;

use Duckboard::Logging;

my $log = Duckboard::Logging.new('store');

has $.store-dir;

method new($store-dir) {
    $log.info("Setting up store");
    return self.bless(store-dir => $store-dir);
}
