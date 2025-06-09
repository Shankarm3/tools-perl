use strict;
use warnings;
use utf8;
use open qw(:std :utf8);

my $xml = do {
    local $/;
    open my $fh, '<', 'input.xml' or die "Can't open file: $!";
    <$fh>;
};

$xml =~ s/\r\n/\n/g;

my $hyphen_count = () = $xml =~ /(\w+)-\s*\n\s*(\w+)/g;

my $plain_count = () = $xml =~ /(\w+)\s*\n\s*(\w+)/g;

my $only_plain_count = $plain_count - $hyphen_count;

print "Soft line break with hyphen: $hyphen_count\n";
print "Soft line break without hyphen: $only_plain_count\n";
print "Total soft line breaks: ", $hyphen_count + $only_plain_count, "\n";
