unit class Duckboard::UI;

use Template6;

use Duckboard::Logging;
use Duckboard::Logic;
use X::Duckboard::BadRequest;

my $log = Duckboard::Logging.new('ui');

has $!logic;
has $!tt;

method new($logic) {
    $log.info("Setting up UI");
    return self.bless(logic => $logic);
}

submethod BUILD(:$logic) {
    $!logic = $logic;
    $!tt = Template6.new;
    # XXX relative to program?
    $!tt.add-path('templates');
}

method start {
    # XXX nothing to do
}

method stop {
    # XXX nothing to do
}

method !html-response($response, $content) {
    $response.status = 200;
    $response.write($content);
    $response.close;
}

method list-domains($response) {
    $log.trace("list-domains");
    my $domains = $!logic.list-domains;
    self!html-response($response, $!tt.process('list-domains', domains => $domains));
}

method list-boards($response, $domain) {
    $log.trace("list-boards domain=$domain");
    my $boards = $!logic.list-boards($domain);
    self!html-response($response, $!tt.process('list-boards', dom => $domain, boards => $boards));
}

method render-board($response, $domain, $board) {
    $log.trace("render-board domain=$domain board=$board");
    self!html-response($response, $!tt.process('render-board', dom => $domain, board => $board));
}
