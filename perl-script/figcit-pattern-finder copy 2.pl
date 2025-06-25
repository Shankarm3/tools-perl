#!/usr/bin/perl
use strict;
use warnings;
use JSON;
use POSIX qw(strftime);
use Data::Dumper;

die "Usage: $0 <xml_file> <comma_separated_figcit_ids>\n" unless @ARGV == 2;

my ($xml_file, $figcit_ids_str) = @ARGV;
my @figcit_ids = split(/,/, $figcit_ids_str);

my $content = do {
    local $/ = undef;
    open(my $fh, '<:encoding(UTF-8)', $xml_file) or die "Could not open file '$xml_file': $!\n";
    my $text = <$fh>;
    close $fh;
    $text;
};

my @found_patterns;

foreach my $figcit_id (@figcit_ids) {
    my @patterns = (
        qr/(\(Fig(?:s|ure)?\.?\s*<figcit\b[^>]*?rid="\Q$figcit_id\E"[^>]*>.*?<\/figcit>.*?\))/i,
        qr/(\[Fig(?:s|ure)?\.?\s*<figcit\b[^>]*?rid="\Q$figcit_id\E"[^>]*>.*?<\/figcit>.*?\])/i,
        qr/(Fig(?:s|ure)?\.?\s*<figcit\b[^>]*?rid="\Q$figcit_id\E"[^>]*>.*?<\/figcit>)/i
    );

    my %pattern_counts;
    my $search_content = $content;

    foreach my $pattern (@patterns) {
        while ($search_content =~ /$pattern/isg) {
            my $match = $1;
            $match =~ s/<\/figcit>.*?(\)|\])/<\/figcit>$1/s;
            $pattern_counts{$match}++;
            $search_content =~ s/$match//;
        }
    }
    print(Dumper(%pattern_counts));

    my $max_pattern = '';
    my $max_count = 0;
    while (my ($pattern, $count) = each %pattern_counts) {
        if ($count > $max_count) {
            $max_count = $count;
            $max_pattern = $pattern;
        }
    }

    push @found_patterns, $max_pattern if $max_count > 0;
}

my $result = join(', ', @found_patterns);

my $output = {
    message => '',
    result => $result,
    status => 'success',
    timestamp => strftime("%a %b %d %H:%M:%S %Y", localtime)
};

binmode STDOUT, ':encoding(UTF-8)';
# print to_json($output, {utf8 => 1, pretty => 1, canonical => 1});