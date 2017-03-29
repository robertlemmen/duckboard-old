unit class Duckboard::Server;

use HTTP::Server::Async;

use Duckboard::Logging;

my $log = Duckboard::Logging.new('server');

has $.httpd;

method new($port) {
    $log.info("Setting up HTTP server");
    return self.bless(httpd => HTTP::Server::Async.new(port => $port));
}

method start {
    $log.info("Starting HTTP server");
    # XXX perhaps should not block?
    $!httpd.listen(True);
}
