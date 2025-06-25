#!/usr/bin/perl
use strict;
use warnings;
use JSON;
use POSIX qw(strftime);

# Check for correct number of arguments
if (@ARGV != 3) {
    die "Usage: $0 <xml_file> <comma_separated_tbcit_ids> <tagname>\n";
}

my ($xml_file, $tbcit_ids_str, $tagname) = @ARGV;

# Split the comma-separated TBCIT IDs
my @tbcit_ids = split(/,/, $tbcit_ids_str);

# Read the entire XML file into memory
open(my $fh, '<:encoding(UTF-8)', $xml_file) or die "Could not open file '$xml_file': $!\n";
my $xml_content = do { local $/; <$fh> };
close $fh;

# Find the maximum apt_id in the document
my $max_apt_id = find_max_id($xml_content, 'apt_id="(\d+)"');

# Process each TBCIT ID
my @found_results;
my @missing_ids;

foreach my $tbcit_id (@tbcit_ids) {
    $tbcit_id =~ s/^\s+|\s+$//g;  # Trim whitespace
    next unless $tbcit_id;  # Skip empty IDs
    
    # Step 1: Find the tableg with matching apt_id
    if ($xml_content =~ /(<tableg[^>]*?apt_id="\Q$tbcit_id\E"[^>]*>\s*<ti[^<>]*?>)/ms) {
        my $tableg_tag = $1;
        
        # Step 2: Extract prefix, sno, and suffix from the matched tableg tag
        my ($prefix, $sno, $suffix) = ("", "", "");
        
        $prefix = $1 if $tableg_tag =~ /prefix="([^"]*?)"/;
        $sno = $1 if $tableg_tag =~ /sno="([^"]*?)"/;
        $suffix = $1 if $tableg_tag =~ /suffix="([^"]*?)"/;
        
        # Step 3: Generate the output
        $max_apt_id++;
        my $tbcit_content = "$prefix $sno$suffix";
        $tbcit_content =~ s/\s+/ /g;
        my $tbcit_tag = "<tbcit class=\"noneditable\" href=\"#$tbcit_id\" rid=\"$tbcit_id\" " .
                      "type=\"arabic\" apt_id=\"$max_apt_id\" id=\"tbcit_$max_apt_id\" " .
                      "contenteditable=\"false\" data-tor-href=\"#\">$tbcit_content</tbcit>";
        
        push @found_results, $tbcit_tag;
    } else {
        push @missing_ids, $tbcit_id;
    }
}

# Prepare the final response
my $message = "";
$message = "Warning: The following reference IDs were not found: " . join(', ', @missing_ids) if @missing_ids;

my %response = (
    result  => join(", ", @found_results),
    status  => "success",
    timestamp => strftime("%a %b %d %H:%M:%S %Y", localtime),
    message => $message
);

# Add missing_ids to the response if there are any
$response{missing_ids} = \@missing_ids if @missing_ids;

# Print the single JSON response
print to_json(\%response, { pretty => 1, utf8 => 1 });
print "\n\nProcessed " . scalar(@tbcit_ids) . " TBCIT IDs.\n";

# Helper function to find maximum ID in the document
sub find_max_id {
    my ($content, $pattern) = @_;
    my $max_id = 0;
    while ($content =~ /$pattern/g) {
        $max_id = $1 if $1 > $max_id;
    }
    return $max_id + 1;
}