#!/usr/bin/env perl
use Test::Stream '-V1', 'Subtest';

use AWS::DynamoDB::ItemTransformer;

# Each test is an array ref with three pieces:
# 1. What the data looks like when thawed.
# 2. What the data looks like when frozen.
# 3. Some message stating what kind of data is involved.
my @tests = (
    [
        'a',
        {S=>'a'},
        'string = S',
    ],
    [
        2,
        {N => '2'},
        'number = N',
    ],
    [
        '3',
        { S => '3' },
        'numeric string = S',
    ],
    [
        undef,
        {NULL => 1 },
        'null = NULL',
    ],
    [
        { a=>1, b=>'2' },
        { M => { a=>{N=>'1'}, b=>{S=>'2'} } },
        'hash = M',
    ],
    [
        [1, 'b', '3'],
        { L => [ {N=>'1'}, {S=>'b'}, {S=>'3'} ] },
        'array = L',
    ],
    [
        {
            a => ['b',{c=>'d'}],
            e => {f=>['g','h']},
        },
        { M => {
            a => { L=> [
                {S=>'b'},
                { M=>{ c=>{S=>'d'} } },
            ]},
            e => { M=> {
                f => { L=> [
                    {S=>'g'},
                    {S=>'h'},
                ]},
            }},
        }},
        'nested',
    ],
);


subtest encode => sub{
    foreach my $test (@tests) {
        my ($decoded, $encoded, $title) = @$test;

        is(
            encode_ddb_value( $decoded ),
            $encoded,
            $title,
        );
    }
};

my @decode_tests = (
    @tests,
    [
        'A',
        {B=>'A'},
        'string = B',
    ],
    [
        ['a','b','c'],
        {BS=>['a','b','c']},
        'array = BS',
    ],
    [
        ['a','b','c'],
        {SS=>['a','b','c']},
        'array = SS',
    ],
    [
        1,
        {BOOL=>1},
        'number = BOOL',
    ],
    [
        [1, 2, 3],
        {NS=>[1, 2, 3]},
        'array = NS',
    ],
);

subtest decode => sub{
    foreach my $test (@decode_tests) {
        my ($decoded, $encoded, $title) = @$test;

        is(
            decode_ddb_value( $encoded ),
            $decoded,
            $title,
        );
    }
};

done_testing;
