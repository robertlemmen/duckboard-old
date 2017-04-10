#!/usr/bin/env perl6

use v6;

use Test;

use Duckboard::Tags;

plan 41;

# test cases around parsing tags
ok(parse-tags('') == {}, "empty string is valid tags case");
ok(parse-tags('test1') == {test1 => Nil}, "simple tag parses");
ok(parse-tags('com.plex~A_1-2') == {'com.plex~A_1-2' => Nil}, "complex tag parses");
dies-ok({ parse-tags('test&burn') }, "parsing tag with ampersand dies");
dies-ok({ parse-tags('test?not') }, "parsing tag with question mark dies");
ok(parse-tags('test2:woo') == {test2 => 'woo'}, "key/value tag parses");
ok(parse-tags('test1;test2:woo') == {test1 => Nil, test2 => 'woo'}, "list of tags parses");
dies-ok({ parse-tags('test=234') }, "parsing key/value tag using equals dies");
ok(parse-tags('test:A;test:B') == {test => 'B'}, "later value overrides earlier");

# parsing filters, positive cases are superficial and tested properly as part
# of the matching below
ok(parse-filter(''), "parses an empty string");
ok(parse-filter('test1'), "parses a single, simple tag as filter");
ok(parse-filter('!test1'), "parses a single, simple but negated tag as a filter");
dies-ok({ parse-filter('!!test1') }, "double-negation is not allows");
ok(parse-filter('(A)'), "parses a primitive group filter");
ok(parse-filter('((A))'), "parses nested brackets");
dies-ok({ parse-filter('((A)') }, "detects imbalanced brackets and throws, '(()' case");
dies-ok({ parse-filter('(A))') }, "detects imbalanced brackets and throws, '())' case");
ok(parse-filter('A+B'), "parses an AND filter");
ok(parse-filter('A/B'), "parses an OR filter");
dies-ok({ parse-filter('A+/B') }, "throws on repeated operators");
dies-ok({ parse-filter('+A') }, "throws on leading operator");
dies-ok({ parse-filter('A/') }, "throws on trailing");
ok(parse-filter('A+B/C+D'), "parses multipe operators");
ok(parse-filter('(A+B)/(C+D)'), "parses grouped terms");
ok(parse-filter('A/!(C+!D)'), "parses a complex term");

# now check that the filters actually match tags as expected
ok(filter-matches(
    parse-filter(''), 
    parse-tags('')), 
    "empty filter returns true even on empty tags");
ok(filter-matches(
    parse-filter(''), 
    parse-tags('test1;test2:abcd')), 
    "empty filter returns true on any tags");
ok(filter-matches(
    parse-filter('test1'), 
    parse-tags('test1')), 
    "filter matches identical simple tag");
ok(filter-matches(
    parse-filter('test:abc'), 
    parse-tags('test:abc')), 
    "filter matches identical key/value tag");
nok(filter-matches(
    parse-filter('test1'), 
    parse-tags('test2')), 
    "filter rejects mismatched tag");
nok(filter-matches(
    parse-filter('test:abc'), 
    parse-tags('test:def')), 
    "filter rejects identical tag with different value");
ok(filter-matches(
    parse-filter('test2'), 
    parse-tags('test1;test2;test3')), 
    "filter matches tag from larger set");
ok(filter-matches(
    parse-filter('test1+test2'), 
    parse-tags('test1;test2;test3')), 
    "AND filter matches");
nok(filter-matches(
    parse-filter('test1+test4'), 
    parse-tags('test1;test2;test3')), 
    "AND filter rejects partial match");
ok(filter-matches(
    parse-filter('test1/test2'), 
    parse-tags('test1;test2;test3')), 
    "OR filter, both matches");
ok(filter-matches(
    parse-filter('test4/test2'), 
    parse-tags('test1;test2;test3')), 
    "OR filter, partial match");
nok(filter-matches(
    parse-filter('test4/test5'), 
    parse-tags('test1;test2;test3')), 
    "OR filter, no match");
ok(filter-matches(
    parse-filter('!test1'), 
    parse-tags('test2;test3')), 
    "NOT filter matches");
nok(filter-matches(
    parse-filter('!test1'), 
    parse-tags('test1;test2;test3')), 
    "NOT filter rejects");
ok(filter-matches(
    parse-filter('test2+!test1'), 
    parse-tags('test2;test3')), 
    "AND plus NOT filter matches");
ok(filter-matches(
    parse-filter('!(test2+test1)'), 
    parse-tags('test2;test3')), 
    "AND plus NOT plus group filter matches");

done-testing;
