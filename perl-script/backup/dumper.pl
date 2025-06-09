use strict;
use warnings;
use Data::Dumper;

my %data = (
    fruits  => ['apple', 'banana', 'cherry'],
    numbers => [1, 2, 3],
    user    => {
        name => "Alice",
        age  => 30,
    },
);

print Dumper(\%data);
