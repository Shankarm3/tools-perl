#!/usr/bin/perl
use strict;
use warnings;

# Input file containing the patterns
my $input_file = 'numbered-bib-patterns.txt';

# Open the input file
open(my $fh, '<', $input_file) or die "Could not open file '$input_file' $!\n";

# Read the file line by line
while (my $line = <$fh>) {
    chomp $line;
    
    # Skip empty lines
    next if $line =~ /^\s*$/;
    
    print "\nProcessing line: $line\n";
    
    # Match single citation pattern
    if ($line =~ /\[<bibcit[^>]+>(\d+)<\/bibcit>\]/) {
        print "Found single citation in square brackets: $1\n";
    }
    # Match multiple citations in square brackets
    elsif ($line =~ /\[((?:<bibcit[^>]+>\d+<\/bibcit>(?:, )?)+)\]/) {
        my $citations = $1;
        print "Found multiple citations in square brackets: $citations\n";
        
        # Extract individual citation numbers
        while ($citations =~ /<bibcit[^>]+>(\d+)<\/bibcit>/g) {
            print "  - Citation number: $1\n";
        }
    }
    # Match single citation in parentheses
    elsif ($line =~ /\(<bibcit[^>]+>(\d+)<\/bibcit>\)/) {
        print "Found single citation in parentheses: $1\n";
    }
    # Match multiple citations in parentheses
    elsif ($line =~ /\(((?:<bibcit[^>]+>\d+(?:–\d+)?<\/bibcit>(?:, )?)+\))/) {
        my $citations = $1;
        print "Found multiple citations in parentheses: $citations\n";
        
        # Extract individual citation numbers and ranges
        while ($citations =~ /<bibcit[^>]+>(\d+(?:–\d+)?)<\/bibcit>/g) {
            if ($1 =~ /(\d+)–(\d+)/) {
                print "  - Citation range: $1 to $2\n";
            } else {
                print "  - Citation number: $1\n";
            }
        }
    }
    
    # Extract all attributes from bibcit tags
    while ($line =~ /<bibcit\s+([^>]+)>/g) {
        my $attrs = $1;
        print "Attributes: $attrs\n";
        
        # Parse individual attributes
        while ($attrs =~ /(\w+)="([^"]*)"/g) {
            print "  - $1 = $2\n";
        }
    }
}

close $fh;

print "\nPattern matching completed.\n";
