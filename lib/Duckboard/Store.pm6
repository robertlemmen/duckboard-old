unit class Duckboard::Store;

use Duckboard::Logging;

my $log = Duckboard::Logging.new('store');

method new() {
    $log.info("Setting up store");
    return self.bless();
}
