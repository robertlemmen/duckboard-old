unit class Duckboard::Server;

use HTTP::Server::Async;
use JSON::Tiny;
use URI;
use URI::Escape;

use Duckboard::Logging;
use X::Duckboard::BadRequest;

my $log = Duckboard::Logging.new('server');

has $.httpd;
has $.logic;

method new($port, $logic) {
    $log.info("Setting up HTTP server on port $port");
    return self.bless(httpd => HTTP::Server::Async.new(port => $port),
                      logic => $logic);
}

method start {
    $log.info("Starting HTTP server");

    $!httpd.handler(sub ($request, $response) {
        self!rq-handler($request, $response);

        CATCH {
            when X::Duckboard::BadRequest {
                self!mk-error-response($response, 400, 
                    "Request to " ~ $request.uri ~ " failed: " ~ .message);
            }
            default {
                self!mk-error-response($response, 500, 
                    "Request to " ~ $request.uri ~ " failed: " ~ .Str);
            }
        }
    });   

    # XXX this returns a promise, but has no clean way of shutting down yet...
    $!httpd.listen;
}

method stop {
    # XXX nothing to do yet
}

method !mk-error-response($response, $code, $message) {
    $log.warn($message);
    $response.status = $code;
    $response.write($message);
    $response.close;
}

method !mk-json-response($response, $data) {
    $response.status = 200;
    $response.headers{'Content-Type'} = 'application/json';
    $response.write(to-json($data));
    $response.close;
}

method !rq-handler($request, $response) {
    my $method = $request.method;
    my $headers = $request.headers;
    my $body = $request.data.decode('UTF-8');
    my $uri = URI.new($request.uri);
    my $path = uri-unescape($uri.path);
    my $query = uri-unescape($uri.query);
    my $query-args = %($query.split('&').comb(/(\w+) '=' (\w+)/, :match)>>.Slip>>.Str);

    # deal with binary zeroes in method and body, our httpd has bugs!
    if ($method.starts-with('0'.chr)) {
        $method = $method.substr(1);
    }
    if ($body.ends-with('0'.chr)) {
        $body = $body.substr(0, *-1);
    }

    $log.trace("$method $path $query");

    if ($path ~~ /^ \/api\/v1\/items \/?$/) {
        if ($method eq 'GET') {
            my $domains = $!logic.list-domains;
            self!mk-json-response($response, $domains);
            return;
        }
        else {
            self!mk-error-response($response, 405, "Method $method not allowed on $path");
            return;
        }
    }
    elsif ($path ~~ /^ \/api\/v1\/items\/ (<[\w]-[^\/]>+) \/?$/) {
        my $domain = $0;
        if ($method eq 'GET') {
            # XXX validate query parts at and filter
            my $items = $!logic.list-items($domain);
            self!mk-json-response($response, $items);
            return;
        }
        else {
            self!mk-error-response($response, 405, "Method $method not allowed on $path");
            return;
        }
    }

    self!mk-error-response($response, 404, "URI path $path does not match any endpoint");
}

