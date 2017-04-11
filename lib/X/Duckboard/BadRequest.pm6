unit class X::Duckboard::BadRequest is Exception;

has $.message;

method new($message) {
    return self.bless(message => $message);
}
