unit module Duckboard::Tags;

my grammar Tags {
    token unreserved {
          <[A..Za..z0..9_.~-]>
    }
    token identifier {
        <unreserved>+
    }
    token value-tag {
          <key=identifier> ':' <val=identifier>
    }
    token single-tag {
          <key=identifier>
    }
    rule tag {
          <single-tag>
        | <value-tag>
    }
    rule tags {
          ^
              <tag>* % \;
            | ''
          $
    }
    rule group-term {
          '(' <filter-expression> ')'
    }
    rule predicate {
        <tag>
    }
    rule filter-term {
          <predicate>
        | <group-term>
    }
    rule and-expression {
          <left=filter-term> '+' <right=filter-expression>
    }
    rule or-expression {
          <left=filter-term> '/' <right=filter-expression>
    }
    rule not-expression {
          '!' <filter-term>
    }
    rule filter-expression {
          <not-expression>
        | <and-expression>
        | <or-expression>
        | <filter-term>
    }
    rule filter {
        ^ [
              <filter-expression>
            | ''
        ] $
    }
}

my class TagsActions {
    method identifier($/) {
        make ~$/;
    }
    method single-tag($/) {
        make { $<key>.made => Nil };
    }
    method value-tag($/) {
        make { $<key>.made => $<val>.made };
    }
    method tag($/) {
        if ($<single-tag>) {
            make $<single-tag>.made;
        }
        if ($<value-tag>) {
            make $<value-tag>.made;
        }
    }
    method tags($/) {
        # combine the hashes from each tag
        if ($<tag>) {
            make $<tag>>>.made.reduce({%(|$^a, |$^b)});
        }
        else {
            make {};
        }
    }
    method predicate($/) {
        my $expected = $<tag>.made;
        if (defined $expected.values[0]) {
            make sub ($at) { return $at{$expected.keys[0]} eqv $expected.values[0]; }
        }
        else {
            make sub ($at) { return $at{$expected.keys[0]}:exists; }
        } 
    }
    method group-term($/) {
        make $<filter-expression>.made;
    }
    method and-expression($/) {
        my $left = $<left>.made;
        my $right = $<right>.made;
        make sub ($at) { return $left($at) && $right($at) };
    }
    method or-expression($/) {
        my $left = $<left>.made;
        my $right = $<right>.made;
        make sub ($at) { return $left($at) || $right($at) };
    }
    method not-expression($/) {
        my $term = $<filter-term>.made;
        make sub ($at) { return ! $term($at) };
    }
    method filter-term($/) {
        if ($<predicate>) {
            make $<predicate>.made;
        }
        if ($<group-term>) {
            make $<group-term>.made;
        }
    }
    method filter-expression($/) {
        if ($<filter-term>) {
            make $<filter-term>.made;
        }
        if ($<and-expression>) {
            make $<and-expression>.made;
        }
        if ($<or-expression>) {
            make $<or-expression>.made;
        }
        if ($<not-expression>) {
            make $<not-expression>.made;
        }
    }
    method filter($/) {
        if ($<filter-expression>) {
            make $<filter-expression>.made;
        }
        else {
            make sub ($at) { return True };
        }
    }
}

sub parse-tags($text) is export {
    my $ret = Tags.parse($text, rule => 'tags', actions => TagsActions.new);
    if ($ret) {
        return $ret.made;
    }
    die "Could not parse tags string '$text'";
}

sub parse-filter($text) is export {
    my $ret = Tags.parse($text, rule => 'filter', actions => TagsActions.new);
    if ($ret) {
        return $ret.made;
    }
    die "Could not parse filter string '$text'";
}

sub filter-matches($filter, $tags) is export {
    return $filter($tags);
}
