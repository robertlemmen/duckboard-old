unit class Duckboard::Server;

use HTTP::Server::Async;

use Duckboard::Logging;

my $log = Duckboard::Logging.new('server');

has $.httpd;

method new($port) {
    $log.info("Setting up HTTP server on port $port");
    return self.bless(httpd => HTTP::Server::Async.new(port => $port));
}

method start {
    $log.info("Starting HTTP server");
    # XXX this returns a promise, but has no clean way of shutting down yet...
    $!httpd.listen;
}

method stop {
    # XXX nothing to do yet
}
