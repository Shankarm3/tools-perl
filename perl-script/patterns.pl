#!/usr/bin/perl
use strict;
use warnings;
use XML::LibXML;
use JSON;
use Getopt::Long;
use File::Basename;

# Command-line arguments
my ($input_file, $help);

GetOptions(
    'input|i=s'  => \$input_file,
    'help|h'     => \$help
) or usage();

# Show help if requested or no arguments provided
usage() if $help || !$input_file;

# Validate input file
unless (-e $input_file) {
    print_error("Input file '$input_file' does not exist");
    exit 1;
}

# Initialize XML parser
my $parser = XML::LibXML->new();
my $doc;

eval {
    $doc = $parser->parse_file($input_file);
} or do {
    print_error("Error parsing XML file: $@");
    exit 1;
};

# Extract content as string for regex matching
my $content = $doc->toString();

my %citations;

# Define patterns for different citation formats
my %patterns = (
    pat1 => qr/(\([^<]+?<bibcit\s+[^>]*>(\d{4})<\/bibcit>[^)]*\))/,
    pat2 => qr/([A-Z][a-z]+(?:,\s+[A-Z][a-z.]+)*)\s*\(\s*(<bibcit[^>]*ref-type="bibr"\s+[^>]*>(\d{4})<\/bibcit>)\s*\)/,
    pat3 => qr/(\([^<]+?et al\.\s*,\s*(<bibcit[^>]*ref-type="bibr"\s+[^>]*>(\d{4})<\/bibcit>)[^)]*\))/,
    pat4 => qr/(\([^<]+?et al\.\s*,\s*(<bibcit[^>]*ref-type="bibr"\s+[^>]*>(\d{4})<\/bibcit>)[^)]*\))/,
    pat5 => qr/(\(\s*([A-Z][a-z]+(?:,\s+[A-Z][a-z.]+)*\s+<bibcit[^>]*ref-type="bibr"\s+[^>]*>(\d{4})<\/bibcit>\s*)\))/
);

# Process each pattern
while (my ($pattern_id, $pattern) = each %patterns) {
    while ($content =~ /$pattern/g) {
        my $full_match = $1;
        my $year = $2 || $4;
        if ($year) {
            $citations{$full_match} = {
                year => $year,
                pattern => $pattern_id
            };
        }
    }
}

# Prepare output data
my @output;
my $count = 1;

foreach my $citation (sort { 
    ($citations{$a}{year} || 0) <=> ($citations{$b}{year} || 0) || 
    $a cmp $b 
} keys %citations) {
    my $clean_citation = clean_citation($citation);
    
    push @output, {
        id => $count++,
        citationId => $citation,
        citation => $clean_citation
    };
    
    # Debug output to STDERR so it doesn't interfere with JSON output
    print STDERR "$citation ======> $citations{$citation}{year} (Pattern: $citations{$citation}{pattern})\n";
}

# Output JSON to STDOUT
my $json = JSON->new->pretty->canonical(1);
print $json->encode(\@output);

exit 0;

# Helper function to clean up citations
sub clean_citation {
    my ($citation) = @_;
    my $clean = $citation;
    $clean =~ s/<[^>]+>//g;
    $clean =~ s/\s+/ /g;
    $clean =~ s/\s+\)/)/g;
    $clean =~ s/\(\s+/(/g;
    return $clean;
}

# Print error message as JSON
sub print_error {
    my ($message) = @_;
    my $json = JSON->new->pretty->canonical(1);
    print $json->encode({
        error => 1,
        message => $message
    });
}

# Display usage information
sub usage {
    my $script_name = basename($0);
    print STDERR <<"USAGE";
Usage: $script_name -i <input_file>

Options:
  -i, --input FILE    Input XML file (required)
  -h, --help         Show this help message

Example:
  $script_name -i input.xml

USAGE
    exit 1;
}