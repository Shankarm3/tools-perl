#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);

my %seen_patterns;

# Check if file name is provided as command line argument
unless (@ARGV == 1) {
    die "Usage: $0 <xml_file>\n";
}

binmode STDOUT, ':utf8';

# Get XML file from command line
my $xml_file = $ARGV[0];

# Check if file exists and is readable
unless (-e $xml_file && -r $xml_file) {
    die "Error: Cannot read file '$xml_file' or file does not exist.\n";
}

print "Processing file: $xml_file\n";

# Read the entire file into a scalar with UTF-8 encoding
my $content = '';
{
    local $/;
    open(my $fh, '<:encoding(UTF-8)', $xml_file) 
        or die "Could not open file '$xml_file': $!\n";
    $content = <$fh>;
    $content =~ s/\x{2013}/-/g;
    close $fh;
}

$content =~ s/\s+/ /g;

print "Searching for citation patterns in $xml_file...\n\n";

my $pattern_count = 0;

my @patterns = (
    {
        name => 'square brackets',
        regex => qr/(\[([^]]*<bibcit[^>]*>.*?<\/bibcit>[^]]*)\])/,
        group => 1
    },
    {
        name => 'parentheses',
        regex => qr/(\(([^)]*<bibcit[^>]*>.*?<\/bibcit>[^)]*)\))/,
        group => 1
    },
    {
        name => 'single citation',
        regex => qr/(<bibcit\b[^>]*>.*?<\/bibcit>)/,
        group => 1
    }
);

# Process patterns within square brackets first
while ($content =~ /(\[([^]]*<bibcit[^>]*>.*?<\/bibcit>[^]]*)\])/g) {
    my ($full_match, $pattern) = ($1, $2);
    next if $seen_patterns{$full_match}++;
    
    $pattern_count++;
    print "\n--- Pattern #$pattern_count (square brackets) ---\n";
    print "Full pattern: $full_match\n";
 
    $content =~ s/\Q$full_match\E//;
}

foreach my $pattern (@patterns) {
    my $name = $pattern->{name};
    my $regex = $pattern->{regex};
    my $group = $pattern->{group};
    
    while ($content =~ /$regex/g) {
        my $full_match = $1;
        next if $seen_patterns{$full_match}++;
        
        $pattern_count++;
        print "\n--- Pattern #$pattern_count ($name) ---\n";
        print "Full pattern: $full_match\n";
        
        $content =~ s/\Q$full_match\E//;
        
        if ($name eq 'single citation' && $full_match =~ /<bibcit\s+([^>]*)>/) {
            my $attrs = $1;
            print "  Attributes: $attrs\n";
        }
    }
}

print "\n" . "=" x 80 . "\n";
print "PROCESSING COMPLETE\n";
print "=" x 80 . "\n\n";
print "Found $pattern_count unique citation patterns.\n";