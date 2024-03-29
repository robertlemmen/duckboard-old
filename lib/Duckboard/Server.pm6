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
has $.ui;

method new($port, $logic, $ui) {
    $log.info("Setting up HTTP server on port $port");
    return self.bless(httpd => HTTP::Server::Async.new(port => $port),
                      logic => $logic, ui => $ui);
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
                $log.error("Unexpected exception: " ~ .Str);
                for .backtrace -> $bt {
                    $log.warn(chomp($bt.Str));
                }
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

method !mk-ok-response($response) {
    $response.status = 200;
    $response.close;
}

method !mk-json-response($response, $data) {
    $response.status = 200;
    $response.headers{'Content-Type'} = 'application/json';
    $response.write(to-json($data));
    $response.close;
}

sub is-under($path, $base) {
    # XXX this could be done better with .child or IO::Path::ChildSecure
    return $path.absolute.starts-with($base.absolute);
}

sub content-type-from-file($filename) {
    given $filename {
        when /\.css$/ { return "text/css"; }
    }
    return "text/html";
}

method !rq-handler($request, $response) {
    state $static-dir = $*PROGRAM.dirname.IO.child("static").resolve;
    my $method = $request.method;
    my $headers = $request.headers;
    my $body = $request.data.decode('UTF-8');
    my $uri = URI.new($request.uri);
    my $path = uri-unescape($uri.path);
    # XXX we also need to work out exactly what the character classes should be
    my $query-args = %(%($uri.query.split('&').comb(/(<[\w\%+]>+) '=' (<[!\w\%+\/\(\)\+]>+)/, :match)>>.Slip>>.Str)
                        .kv.map(-> $arg { uri-unescape($arg) }));

    # deal with binary zeroes in method and body, our httpd has bugs!
    if ($method.starts-with('0'.chr)) {
        $method = $method.substr(1);
    }
    if ($body.ends-with('0'.chr)) {
        $body = $body.substr(0, *-1);
    }

    $log.trace("$method $path " ~ $uri.query);

    if ($path ~~ /^ \/(static\/.+) /) {
        my $filename = $0;
        if ($method eq 'GET') {
            my $file = IO::Path.new($filename).resolve;
            if (!is-under($file, $static-dir)) {
                self!mk-error-response($response, 403, "Access to $filename not allowed");
            }
            elsif ($file.e) {
                $response.status = 200;
                $response.write($file.slurp(:bin));
                $response.headers{'Content-Type'} = content-type-from-file($filename);
                $response.close;
            }
            else {
                self!mk-error-response($response, 404, "File $filename not found");
            }
            return;
        }
        else {
            self!mk-error-response($response, 405, "Method $method not allowed on $path");
            return;
        }
    }
    elsif ($path ~~ /^ \/api\/v1\/items \/?$/) {
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
    elsif ($path ~~ /^ \/api\/v1\/items\/ (<[\w-]-[^\/]>+) \/?$/) {
        my $domain ~= $0;
        if ($method eq 'GET') {
            # XXX validate query parts at and filter

            # uri-unescape turns '+' into space, which is arguably correct, but we don't need
            # that here...
            if ($query-args{'filter'}) {
                $query-args{'filter'}.subst-mutate(' ', '+');
            }
            my $items = $!logic.list-items($domain, $query-args{'at'}, $query-args{'filter'});
            self!mk-json-response($response, $items);
            return;
        }
        elsif ($method eq 'PUT') {
            # XXX validate that there is no body
            $!logic.create-domain($domain);
            self!mk-ok-response($response);
            return;
        }
        elsif ($method eq 'POST') {
            # XXX validate content-type 
            my $item = from-json($body);
            my $new-item = $!logic.create-item($domain, $item);
            self!mk-json-response($response, $new-item);
            return;
        }
        else {
            self!mk-error-response($response, 405, "Method $method not allowed on $path");
            return;
        }
    }
    elsif ($path ~~ /^ \/api\/v1\/items\/ (<[\w-]-[^\/]>+) \/ (<[\w-]-[^\/]>+) \/?$/) {
        my $domain ~= $0;
        my $id ~= $1;
        if ($method eq 'GET') {
            my $item = $!logic.get-item($domain, $id);
            if (defined $item) {
                self!mk-json-response($response, $item);
            }
            else {
                self!mk-error-response($response, 404, "Item '$id' in domain '$domain' not found");
            }
            return;
        }
        elsif ($method eq 'PUT') {
            # XXX validate content-type 
            # XXX old-timestamp
            my $item = from-json($body);
            $!logic.put-item($domain, $id, $item);
            self!mk-ok-response($response);
            return;
        }
        else {
            self!mk-error-response($response, 405, "Method $method not allowed on $path");
            return;
        }
    }
    elsif ($path ~~ /^ \/api\/v1\/sortings\/ (<[\w-]-[^\/]>+) \/?$/) {
        my $domain ~= $0;
        if ($method eq 'GET') {
            my $sortings = $!logic.list-sortings($domain);
            self!mk-json-response($response, $sortings);
            return;
        }
        else {
            self!mk-error-response($response, 405, "Method $method not allowed on $path");
            return;
        }
    }
    elsif ($path ~~ /^ \/api\/v1\/sortings\/ (<[\w-]-[^\/]>+) \/ (<[\w-]-[^\/]>+) \/?$/) {
        my $domain ~= $0;
        my $id ~= $1;
        if ($method eq 'GET') {
            my $sorting = $!logic.get-sorting($domain, $id);
            if (defined $sorting) {
                self!mk-json-response($response, $sorting);
            }
            else {
                self!mk-error-response($response, 404, "Sorting '$id' in domain '$domain' not found");
            }
            return;
        }
        elsif ($method eq 'PUT') {
            my $sorting = from-json($body);
            $!logic.put-sorting($domain, $id, $sorting);
            self!mk-ok-response($response);
            return;
        }
        else {
            self!mk-error-response($response, 405, "Method $method not allowed on $path");
            return;
        }
    }
    elsif ($path ~~ /^ \/api\/v1\/sorted\/ (<[\w-]-[^\/]>+) \/ (<[\w-]-[^\/]>+) \/?$/) {
        my $domain ~= $0;
        my $id ~= $1;
        # XXX at

        # uri-unescape turns '+' into space, which is arguably correct, but we don't need
        # that here...
        if ($query-args{'filter'}) {
            $query-args{'filter'}.subst-mutate(' ', '+');
        }

        if ($method eq 'GET') {
            my $sorted = $!logic.get-sorted($domain, $id, $query-args{'at'}, $query-args{'filter'});
            if (defined $sorted) {
                self!mk-json-response($response, $sorted);
            }
            else {
                self!mk-error-response($response, 404, "Sorting '$id' in domain '$domain' not found");
            }
            return;
        }
        else {
            self!mk-error-response($response, 405, "Method $method not allowed on $path");
            return;
        }
    }
    elsif ($path ~~ /^ \/api\/v1\/boards\/ (<[\w-]-[^\/]>+) \/?$/) {
        my $domain ~= $0;
        if ($method eq 'GET') {
            my $boards = $!logic.list-boards($domain);
            self!mk-json-response($response, $boards);
            return;
        }
        else {
            self!mk-error-response($response, 405, "Method $method not allowed on $path");
            return;
        }
    }
    elsif ($path ~~ /^ \/api\/v1\/boards\/ (<[\w-]-[^\/]>+) \/ (<[\w-]-[^\/]>+) \/?$/) {
        my $domain ~= $0;
        my $id ~= $1;
        # XXX at??

        if ($method eq 'GET') {
            my $board = $!logic.get-board($domain, $id);
            if (defined $board) {
                self!mk-json-response($response, $board);
            }
            else {
                self!mk-error-response($response, 404, "Board '$id' in domain '$domain' not found");
            }
            return;
        }
        elsif ($method eq 'PUT') {
            my $board = from-json($body);
            $!logic.put-board($domain, $id, $board);
            self!mk-ok-response($response);
            return;
        }
        else {
            self!mk-error-response($response, 405, "Method $method not allowed on $path");
            return;
        }
    }
    elsif ($path ~~ /^ \/ui \/?$/) {
        $!ui.list-domains($response);
        return;
    }
    elsif ($path ~~ /^ \/ui\/ (<[\w-]-[^\/]>+) \/?$/) {
        my $domain ~= $0;
        $!ui.list-boards($response, $domain);
        return;
    }
    elsif ($path ~~ /^ \/ui\/ (<[\w-]-[^\/]>+) \/ (<[\w-]-[^\/]>+) \/?$/) {
        my $domain ~= $0;
        my $board ~= $1;
        $!ui.render-board($response, $domain, $board);
        return;
    }
    elsif ($path ~~ /^ \/ $/) {
        $response.status = 301;
        $response.headers{'Location'} = '/ui';
        $response.close;
        return;
    }

    self!mk-error-response($response, 404, "URI path $path does not match any endpoint");
}

