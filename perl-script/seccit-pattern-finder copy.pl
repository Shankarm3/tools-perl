#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use open ':std', ':encoding(UTF-8)';
use JSON;
use POSIX 'strftime';

# Check command line arguments
die "Usage: $0 <xml_file> <comma_separated_ids> <tag_name>\n" unless @ARGV == 3;
my ($xml_file, $ids_str, $tag_name) = @ARGV;

# Initialize result variables
my @found_citations;
my @missing_ids;

# Read the entire file with UTF-8 encoding
open(my $fh, '<:encoding(UTF-8)', $xml_file) or die "Could not open file '$xml_file': $!\n";
my $content = do { local $/; <$fh> };
$content =~ s/\xA0/ /g;
close $fh;

# Find the maximum apt_id in the document
my $max_apt_id = 0;
$content =~ /apt_id="(\d+)"/g;
while ($content =~ /apt_id="(\d+)"/g) {
    $max_apt_id = $1 if $1 > $max_apt_id;
}

# Process each section ID
my @ids = split(/,/, $ids_str);
foreach my $sect_id (@ids) {
    $sect_id =~ s/^\s+|\s+$//g;  # Trim whitespace
    my $found = 0;
    
    # 1. First check for existing seccit tag
    if ($content =~ /(Sec\.|Section)\s*(<seccit[^>]*rid="\Q$sect_id\E"[^>]*>.*?<\/seccit>)/i) {
        push @found_citations, "Section $2";
        $found = 1;
        next;
    }
    
    # 2. Look for the section with the given apt_id
    if ($content =~ /<sect\d+\s+[^>]*?\bapt_id="\Q$sect_id\E"[^>]*>\s*<ti[^>]*?\bsno="([^"]*)"[^>]*>/s) {
        my $sno = $1;
        my $sect_match = $&;
        
        # Get the apt_id of the sect
        my $sect_apt_id = $sect_id;
        if ($sect_match =~ /apt_id="([^"]*)"/) {
            $sect_apt_id = $1;
        }
        
        # Create new seccit element
        $max_apt_id++;
        my $new_seccit = qq{<seccit rid="$sect_apt_id" title="seccit" href="#" contenteditable="false" id="seccit_$max_apt_id" apt_id="$max_apt_id">$sno</seccit>};
        
        push @found_citations, "Section $new_seccit";
        $found = 1;
    }
    
    push @missing_ids, $sect_id unless $found;
}

# Prepare the result
my $result = {
    message => @missing_ids ? "Some section IDs not found: " . join(', ', @missing_ids) : "",
    result => join(', ', @found_citations),
    status => @missing_ids ? "partial" : "success",
    timestamp => strftime("%a %b %d %H:%M:%S %Y", localtime)
};

# Output as pretty-printed JSON
my $json = JSON->new->pretty(1)->encode($result);
print $json;
