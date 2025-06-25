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

my %figcit_patterns;

foreach my $figcit_id (@figcit_ids) {
    my %pattern_types;
    my %example_patterns;
    my @patterns = (
        qr/(\(Fig(?:s|ure)?\.?\s*<figcit\b[^>]*?\brid="\Q$figcit_id\E"[^>]*>.*?<\/figcit>.*?\))/i,
        qr/(\[Fig(?:s|ure)?\.?\s*<figcit\b[^>]*?\brid="\Q$figcit_id\E"[^>]*>.*?<\/figcit>.*?\])/i,
        qr/(Fig(?:s|ure)?\.?\s*<figcit\b[^>]*?\brid="\Q$figcit_id\E"[^>]*>.*?<\/figcit>)/i
    );

    foreach my $pattern (@patterns) {
        while ($content =~ /$pattern/isg) {
            my $match = $1;
            $match =~ s/<\/figcit>.*?(\)|\])/<\/figcit>$1/s;
            
            my ($fig_num) = $match =~ /<figcit[^>]*>(\d+)<\/figcit>/;
            next unless defined $fig_num;
            
            my $type = $match =~ /^\(/ ? 'parentheses' : 'plain';
            
            my $normalized = $type eq 'parentheses' 
                ? "(Fig. <figcit>$fig_num</figcit>)"
                : "Fig. <figcit>$fig_num</figcit>";
            
            $pattern_types{$normalized}++;
            $example_patterns{$normalized} //= $match;
        }
    }
    
    my ($max_pattern, $max_count) = ('', 0);
    while (my ($pattern, $count) = each %pattern_types) {
        if ($count > $max_count) {
            $max_count = $count;
            $max_pattern = $pattern;
        }
    }
    
    if ($max_count > 0) {
        $figcit_patterns{$figcit_id} = {
            count => $max_count,
            max_found_pattern => $example_patterns{$max_pattern}
        };
    }
}

binmode STDOUT, ':encoding(UTF-8)';
print to_json(\%figcit_patterns, {utf8 => 1, pretty => 1, canonical => 1});