#!/usr/bin/perl
use strict;
use warnings;
use JSON;
use XML::LibXML;

# Error handling for command line arguments
die "Usage: $0 <xml_file>\n" unless @ARGV == 1;

my $input_file = $ARGV[0];

# Basic input validation
unless (-e $input_file) {
    die "Error: File '$input_file' does not exist\n";
}

if (-z $input_file) {
    die "Error: File '$input_file' is empty\n";
}

# Validate XML
my $xml_parser = XML::LibXML->new();
my $xml_doc;
eval {
    $xml_doc = $xml_parser->parse_file($input_file);
};
if ($@) {
    die "Error: Invalid XML in file '$input_file': $@\n";
}

# Read file content for processing
my $content;
{
    open(my $in_fh, '<:encoding(UTF-8)', $input_file) 
        or die "Could not open input file '$input_file': $!\n";
    local $/;
    $content = <$in_fh>;
    close $in_fh;
}

my %citations;
my %seen;
my $total_duplicates = 0;

# Citations patterns
my $pattern1 = qr{
    \(              
    [^<]+
    <bibcit\b[^>]*>  
    \d{4}            
    </bibcit>        
    [^)]*           
    \)
}x;

my $pattern2 = qr{
    ([A-Z][a-z]+,\s+[A-Z][a-z]+)             
    \s*\(\s*                                  
    <bibcit\b[^>]*>(\d{4})<\/bibcit>          
    \s*\)                                     
}xi;

my $pattern3 = qr{
    ([A-Z][a-z]+)\s*
    <bibcit\b[^>]*>(\d{4})<\/bibcit>
}xi;

my $pattern4 = qr{
    ([A-Z][a-z]+,\s+[A-Z][a-z]+)             
    \s*\(\s*                                  
    <bibcit\b[^>]*>(\d{4})<\/bibcit>          
    \s*\)                                     
}xi;
my $pattern5 = qr{
    ([A-Z][a-z]+,\s+[A-Z][a-z]+\s*&\s*[A-Z][a-z]+) 
    \s*\(\s*                                          
    <bibcit\b[^>]*>(\d{4})<\/bibcit>                  
    \s*\)+                                            
}xi;
my $pattern6 = qr{
    ([A-Z][a-z]+,\s+[A-Z][a-z]+)             
    \s*\(\s*                                  
    <bibcit\b[^>]*>(\d{4})<\/bibcit>          
    \s*;\s*                                   
    \s*<bibcit\b[^>]*>\d+<\/bibcit>           
    \s*\)                                     
}xi;
my $pattern7 = qr{
    ([A-Z][a-z]+)                              
    \s+<[^>]+>et\s*al\.<\/[^>]+>              
    \s*\(\s*                                  
    <bibcit\b[^>]*>(\d{4})<\/bibcit>          
    \s*\)                                      
}xi;

# Array of patterns
my @all_patterns = (
    $pattern1,
    $pattern2,
    $pattern3,
    $pattern4,
    $pattern5,
    $pattern6,
    $pattern7
);

# Process all patterns 
foreach my $pattern (@all_patterns) {
    while ($content =~ /$pattern/g) {
        my $full_match = $&;
        if ($seen{$full_match}++) {
            $total_duplicates++;
            next;
        }         
        my $year;
        if ($pattern == $pattern1) {
            $year = ($full_match =~ /<bibcit[^>]*>(\d{4})/)[0];
        } else {
            $year = $+;
        }
        
        $citations{$full_match} = $year;
        $content =~ s/$pattern//;
    }
}

# Prepare data for JSON output
my @citations_json;
my $count = 1;

foreach my $citation (sort { 
    ($citations{$a} || 0) <=> ($citations{$b} || 0) || 
    $a cmp $b 
} keys %citations) {
    my $clean_citation = $citation;
    $clean_citation =~ s/<[^>]+>//g; 
    $clean_citation =~ s/\s+/ /g; 
    $clean_citation =~ s/\s+\)/)/g;   
    $clean_citation =~ s/\(\s+/(/g;   
    $clean_citation =~ s/^\s+|\s+$//g;
    
    push @citations_json, {
        id => $count++,
        citationId => $citation,
        citationText => $clean_citation,
    };
}

# Create final output hash
my $output = {
    metadata => {
        sourceFile => $input_file,
        extractionDate => scalar localtime,
        totalCitations => scalar @citations_json,
    },
    citations => \@citations_json
};

# Print JSON output
my $json = JSON->new->pretty->encode($output);
print $json;

# Simple logging function for debugging
sub log_debug {
    my ($message) = @_;
    print STDERR "[DEBUG] $message\n" if $ENV{DEBUG};
}
