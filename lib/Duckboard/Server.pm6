unit class Duckboard::Server;

use HTTP::Server::Async;

use Duckboard::Logging;

my $log = Duckboard::Logging.new('server');

has $!httpd = HTTP::Server::Async.new;

method new() {
    $log.info("Setting up HTTP server");
    return self.bless();
}

method start {
    $log.info("Starting HTTP server");
    # XXX different port, do not block?
    $!httpd.listen(True);
}
