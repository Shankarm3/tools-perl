#!/usr/bin/perl
use strict;
use warnings;
use JSON;

# Check command line arguments
die "Usage: $0 <xml_file> <comma_separated_figcit_ids>\n" unless @ARGV == 2;

my ($xml_file, $figcit_ids_str) = @ARGV;
my @figcit_ids = split(/,/, $figcit_ids_str);

# Read the entire file content
my $content = do {
    local $/ = undef;
    open(my $fh, '<:encoding(UTF-8)', $xml_file) or die "Could not open file '$xml_file': $!\n";
    my $text = <$fh>;
    close $fh;
    $text;
};

# Hash to store patterns and their counts
my %pattern_counts;

foreach my $figcit_id (@figcit_ids) {
    # Define patterns to search for (keeping the original patterns)
    my @patterns = (
        qr/(\(Fig(?:s|ure)?\.?\s*<figcit\b[^>]*?\brid="\Q$figcit_id\E"[^>]*>.*?<\/figcit>.*?\))/i,
        qr/(\[Fig(?:s|ure)?\.?\s*<figcit\b[^>]*?\brid="\Q$figcit_id\E"[^>]*>.*?<\/figcit>.*?\])/i,
        qr/(Fig(?:s|ure)?\.?\s*<figcit\b[^>]*?\brid="\Q$figcit_id\E"[^>]*>.*?<\/figcit>)/i
    );

    foreach my $pattern (@patterns) {
        while ($content =~ /$pattern/isg) {
            my $match = $1;
            $match =~ s/<\/figcit>.*?(\)|\])/<\/figcit>$1/g;
            $pattern_counts{$match}++;
        }
    }
}

# Convert the hash to an array of patterns with their counts
my @result;
while (my ($pattern, $count) = each %pattern_counts) {
    push @result, {
        pattern => $pattern,
        count => $count
    };
}

# Output the results as JSON
binmode STDOUT, ':encoding(UTF-8)';
print to_json(\@result, {utf8 => 1, pretty => 1, canonical => 1});