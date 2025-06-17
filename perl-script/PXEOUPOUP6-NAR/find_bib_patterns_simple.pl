#!/usr/bin/perl
use strict;
use warnings;

# Input XML file
my $xml_file = 'ugaf011_28115_7_819_W1.xml';

# Check if file exists
unless (-e $xml_file) {
    die "Error: File '$xml_file' not found.\n";
}

# Read the entire file into a scalar
my $content = '';
{
    local $/;  # Enable slurp mode
    open(my $fh, '<', $xml_file) or die "Could not open file '$xml_file': $!\n";
    $content = <$fh>;
    close $fh;
}

# Remove newlines and extra spaces for easier pattern matching
$content =~ s/\s+/ /g;

# Find all bibcit patterns
print "Searching for citation patterns in $xml_file...\n\n";

# Counter for citations
my $citation_count = 0;

# Find all citation patterns
while ($content =~ /(<bibcit\b[^>]*>.*?<\/bibcit>)/g) {
    my $full_match = $1;
    $citation_count++;
    
    # Extract attributes
    my %attrs = ();
    $full_match =~ /<bibcit\s+([^>]*)>/;
    my $attr_str = $1 || '';
    
    # Parse attributes
    while ($attr_str =~ /(\w+)=(["'])(.*?)\2/g) {
        $attrs{$1} = $3;
    }
    
    # Get content
    my $content = '';
    if ($full_match =~ /<bibcit[^>]*>(.*?)<\/bibcit>/) {
        $content = $1;
    }
    
    # Get context (square brackets or parentheses)
    my $context = 'unknown';
    my $surrounding = '';
    
    if ($full_match =~ /\[(<bibcit[^>]*>.*?<\/bibcit>)\]/) {
        $context = 'square_brackets';
        $surrounding = '[...]';
    } 
    elsif ($full_match =~ /\((<bibcit[^>]*>.*?<\/bibcit>)\)/) {
        $context = 'parentheses';
        $surrounding = '(...)';
    }
    
    # Print citation info
    print "\n--- Citation #$citation_count ($context) $surrounding ---\n";
    print "Full match: $full_match\n";
    print "Content: $content\n";
    
    # Print attributes
    if (keys %attrs) {
        print "Attributes:\n";
        foreach my $key (sort keys %attrs) {
            print "  $key = $attrs{$key}\n";
        }
    }
    
    # Handle ranges in content (e.g., 19-21)
    if ($content =~ /(\d+)\s*[–-]\s*(\d+)/) {
        my ($start, $end) = ($1, $2);
        print "Range detected: $start to $end\n";
    }
}

# Now look for multiple citations in brackets or parentheses
print "\n" . "=" x 80 . "\n";
print "CITATION PATTERNS FOUND\n";
print "=" x 80 . "\n\n";

# Find patterns like [1, 2, 3] or (1, 2, 3)
my $pattern_count = 0;

# Look for patterns with square brackets first
while ($content =~ /(\[((?:<bibcit[^>]*>.*?<\/bibcit>(?:\s*,\s*)?)+)\])/g) {
    my ($full_match, $citations) = ($1, $2);
    $pattern_count++;
    
    print "\n--- Pattern #$pattern_count (square brackets) ---\n";
    print "Full match: $full_match\n";
    
    # Extract individual citations
    my $citation_num = 0;
    while ($citations =~ /<bibcit[^>]*>(.*?)<\/bibcit>/g) {
        my $citation = $1;
        $citation_num++;
        print "  $citation_num. $citation\n";
    }
}

# Look for patterns with parentheses
while ($content =~ /(\(((?:<bibcit[^>]*>.*?<\/bibcit>(?:\s*,\s*)?)+)\))/g) {
    my ($full_match, $citations) = ($1, $2);
    $pattern_count++;
    
    print "\n--- Pattern #$pattern_count (parentheses) ---\n";
    print "Full match: $full_match\n";
    
    # Extract individual citations
    my $citation_num = 0;
    while ($citations =~ /<bibcit[^>]*>(.*?)<\/bibcit>/g) {
        my $citation = $1;
        $citation_num++;
        print "  $citation_num. $citation\n";
    }
}

print "\nFound $citation_count total citations and $pattern_count citation patterns.\n";
