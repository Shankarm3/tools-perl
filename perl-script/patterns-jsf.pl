#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use XML::LibXML;
use File::Basename;
use JSON;

# Command-line arguments
my ($input_file, $output_file, $help);

GetOptions(
    'input|i=s'  => \$input_file,
    'output|o=s' => \$output_file,
    'help|h'     => \$help
) or usage();

# Show help if requested or no arguments provided
usage() if $help || !$input_file;

# Set default output filename if not provided
$output_file ||= 'extracted_citations.json';

# Validate input file
unless (-e $input_file) {
    die "Error: Input file '$input_file' does not exist.\n";
}

# Initialize XML parser
my $parser = XML::LibXML->new();
my $doc;

eval {
    $doc = $parser->parse_file($input_file);
} or do {
    die "Error parsing XML file: $@\n";
};

# Extract content as string for regex matching
my $content = $doc->toString();

# Define patterns for different citation formats
my %patterns = (
    pat1 => qr/(\([^<]+?<bibcit\s+[^>]*>(\d{4})<\/bibcit>[^)]*\))/,
    pat2 => qr/([A-Z][a-z]+(?:,\s+[A-Z][a-z.]+)*)\s*\(\s*(<bibcit[^>]*ref-type="bibr"\s+[^>]*>(\d{4})<\/bibcit>)\s*\)/,
    pat3 => qr/(\([^<]+?et al\.\s*,\s*(<bibcit[^>]*ref-type="bibr"\s+[^>]*>(\d{4})<\/bibcit>)[^)]*\))/,
    pat4 => qr/(\([^<]+?et al\.\s*,\s*(<bibcit[^>]*ref-type="bibr"\s+[^>]*>(\d{4})<\/bibcit>)[^)]*\))/,
    pat5 => qr/(\(\s*([A-Z][a-z]+(?:,\s+[A-Z][a-z.]+)*\s+<bibcit[^>]*ref-type="bibr"\s+[^>]*>(\d{4})<\/bibcit>\s*)\))/
);

# Process each pattern
my %citations;
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
    
    # Also print to console for debugging
    print "$citation ======> $citations{$citation}{year} (Pattern: $citations{$citation}{pattern})\n";
}

# Write JSON output
open(my $out_fh, '>', $output_file) or die "Could not open output file '$output_file': $!\n";
my $json = JSON->new->pretty->canonical(1);
print $out_fh $json->encode(\@output);
close $out_fh;

print "\nExtraction complete. Found " . scalar(@output) . " unique citations.\n";
print "Results saved to: $output_file\n";

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

# Display usage information
sub usage {
    my $script_name = basename($0);
    print <<"USAGE";
Usage: $script_name -i <input_file> [-o <output_file>]

Options:
  -i, --input FILE    Input XML file (required)
  -o, --output FILE   Output JSON file (default: extracted_citations.json)
  -h, --help         Show this help message

Example:
  $script_name -i input.xml -o citations.json

USAGE
    exit(1);
}