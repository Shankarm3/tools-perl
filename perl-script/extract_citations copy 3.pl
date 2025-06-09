#!/usr/bin/perl
###############################################################################
# Script Name : extract_citations.pl
# Description : Extracts and sorts citations from an XML file with <bibcit> tags.
# Author      : Shankar Dutt Mishra
# Created     : 2024-05-30
# Version     : 1.1
#
# Usage       : perl extract_citations.pl <xml_file>
#               perl extract_citations.pl --help
#
# Notes       : Requires Perl modules: JSON, File::Basename, Text::Unidecode
#               The script reads an XML file, extracts citations, sorts them,
#               and outputs them in JSON format.
#               It handles large files, duplicates, and normalizes text.
###############################################################################

use strict;
use warnings;
use JSON;
use Text::Unidecode;
use File::Basename qw(basename);

use constant {
    MAX_FILE_SIZE => 100 * 1024 * 1024,
};

our $VERSION = '1.1';
our $DEBUG = $ENV{DEBUG} || 0;

# Main execution
sub main {
    log_info("Starting citation extractor v$VERSION");

    my $input_file = validate_command_line();
    my $content = read_file_content($input_file);
    my $citations = extract_citations($content);
    my $output = prepare_output($citations, $input_file);
    print_output($output);

    log_info("Completed citation extraction");
}

# Validate command line arguments
sub validate_command_line {
    if (@ARGV && ($ARGV[0] =~ /^-?-?h(elp)?$/i)) {
        print <<"USAGE";
Usage: perl $0 <xml_file>

The script reads an XML file with <bibcit> tags, extracts citations, sorts them, and outputs them in JSON format.
It handles large files 100mb, duplicates, and normalizes text.

Options:
<xml_file>   Path to the input XML file.
-h, --help   Show this help message.

Example:
perl $0 staf323.xml

USAGE
        exit 0;
    }

    die "Usage: $0 <xml_file>\n" unless @ARGV >= 1;
    my $input_file = $ARGV[0];

    unless (-e $input_file) {
        die "Error: File '$input_file' does not exist\n";
    }

    if (-z $input_file) {
        die "Error: File '$input_file' is empty\n";
    }

    my $file_size = -s $input_file;
    if ($file_size > MAX_FILE_SIZE) {
        die sprintf("Error: File '%s' is too large (%.2fMB > %.2fMB)\n",
            $input_file, $file_size/(1024*1024), MAX_FILE_SIZE/(1024*1024));
    }

    log_debug("Input file validated: $input_file (" . sprintf("%.2f", $file_size/1024) . " KB)");
    return $input_file;
}

# Read file content with error handling
sub read_file_content {
    my ($file) = @_;

    open(my $in_fh, '<:encoding(UTF-8)', $file)
        or die "Error: Could not open input file '$file': $!\n";

    log_debug("Reading file content");
    local $/;
    my $content = <$in_fh>;
    $content =~ s/\&amp;/\&/gi;
    $content =~ s/\&nbsp;/ /gi;
    $content =~ s/\xA0/ /gi;
    $content = unidecode($content);
    close $in_fh;

    return $content;
}

# Define citation patterns with comments
sub get_citation_patterns {
    return (

        qr{
            \(              
            (?:[\(])
            <bibcit\b[^>]*rid="([a-z]+?\d+)"[^>]*>  
            (?:.*?)
            <bibcit\b[^>]*rid="([a-z]+?\d+)"[^>]*>  
            (?:.*?)       
            (?:[\)])
            \)
        }x,

        qr{
            \(              
            [^\(]+
            <bibcit\b[^>]*rid="([a-z]+?\d+)"[^>]*>  
            [^<]+            
            <\/bibcit>        
            [^)]*           
            \)
        }x,
        
        qr{
            ([A-Z][a-z]+(?:,\s+[A-Z][a-z]+)*
            (?:,\s+[A-Z][a-z]+)*
            (?:\s*[&,;]\s*[A-Z][a-z]+)*)
            \s*\(\s*
            (<bibcit\b[^>]*rid="([a-z]+?\d+)"[^>]*>[^<]+<\/bibcit>)
            \s*\)
        }xi,
        
        qr{
            ([A-Z][a-z]+(?:,\s+[A-Z][a-z]+)*
            (?:,\s+[A-Z][a-z]+)*
            (?:\s*[&,;]\s*[A-Z][a-z]+)*)
            \s*\(\s*                         
            <bibcit\b[^>]*rid="([a-z]+?\d+)"[^>]*>[^<]+<\/bibcit>
            (?:                               
            \s*,\s*                       
            <bibcit\b[^>]*rid="([a-z]+?\d+)"[^>]*>[^<]+<\/bibcit>
            )*
            \s*\)                             
        }xi,
        
        qr{
            ([A-Z][a-z]+)                      
            \s+<[^>]+>et\s*al\.<\/[^>]+>              
            \s*\(\s*                                  
            <bibcit\b[^>]*rid="([a-z]+?\d+)"[^>]*>[^<]+<\/bibcit>          
            \s*\)                                      
        }xi,

        qr{
            \(
                (?:
                    [^()]*?
                    <bibcit\b[^>]*>[^<>]*<\/bibcit>
                    \s*;\s*
                ){3,}
                [^()]*?
                <bibcit\b[^>]*>[^<>]*<\/bibcit>
                [^()]*?
            \)
        }xi
    );
}

# Extract citations
sub extract_citations {
    my ($content) = @_;
    my @citations;
    my %seen;
    my $total_duplicates = 0;
    my $total_matches = 0;

    log_debug("Starting citation extraction");
    my @patterns = get_citation_patterns();

    for (my $i = 0; $i < @patterns; $i++) {
        my $pattern = $patterns[$i];
        my $matches = 0;
        my @matches;

        while ($content =~ /$pattern/g) {
            my $full_match = $&;
            $matches++;
            if ($seen{$full_match}++) {
                $total_duplicates++;
                next;
            }
            push @citations, $full_match;
            push @matches, $full_match;
        }

        for my $m (@matches) {
            $content =~ s/\Q$m\E//g;
        }

        $total_matches += $matches;
        log_debug(sprintf("Pattern %d: Found %d matches", $i + 1, $matches));
        %seen = () if $i % 3 == 0 && $i > 0;
    }

    log_debug(sprintf("Extraction complete: %d unique citations, %d duplicates",
        scalar @citations, $total_duplicates));

    return \@citations;
}

# Remove tags and normalize for plain text
sub citation_to_plain_text {
    my ($text) = @_;
    return '' unless defined $text;
    $text =~ s/<[^>]+>//g;
    $text =~ s/\s+/ /g;
    $text =~ s/\s+\)/)/g;
    $text =~ s/\(\s+/(/g;
    $text =~ s/^\s+|\s+$//g;
    return $text;
}

# Sort <bibcit> chunks within a citation source string
sub sort_citation_source {
    my ($citation_source) = @_;

    my @chunks;
    my $prefix = '';
    my $suffix = '';
    my $inside = $citation_source;

    if ($inside =~ /^\((.*)\)$/s) {
        $inside = $1;
        $prefix = '(';
        $suffix = ')';
    }

    @chunks = split(/(?<=<\/bibcit>);/, $inside);

    my @sortable = map {
        my $chunk = $_;
        my $plain = citation_to_plain_text($chunk);
        my ($author, $year) = $plain =~ /(.+?)\s*(\d{4}[a-z]?)/i;
        $author //= $plain;
        $year //= 0;
        $author =~ s/\s+et al\.//ig;
        $author =~ s/\s*e\.g\.\s*//ig;
        $author = lc $author;
        { orig => $chunk, author => $author, year => $year, plain => $plain }
    } @chunks;


    @sortable = sort {
        my ($year_num_a, $year_suf_a) = $a->{year} =~ /^(\d{4})([a-z]?)$/i;
        my ($year_num_b, $year_suf_b) = $b->{year} =~ /^(\d{4})([a-z]?)$/i;
        ($a->{author} cmp $b->{author})
        ||
        ($year_num_a <=> $year_num_b)
        ||
        ($year_suf_a cmp $year_suf_b)
    } @sortable;

    my $sorted = join(';', map { $_->{orig} } @sortable);
    return $prefix . $sorted . $suffix;
}

# Prepare output data structure
sub prepare_output {
    my ($citations, $input_file) = @_;
    my @citations_json;
    my $count = 1;

    log_debug("Preparing output data");
    foreach my $citation (@$citations) {
        my $sourceCitationXml = $citation;
        my $sortedCitationXml = sort_citation_source($sourceCitationXml);

        my $sourceCitationText = citation_to_plain_text($sourceCitationXml);
        my $sortedCitationText = citation_to_plain_text($sortedCitationXml);

        next if $sourceCitationXml eq $sortedCitationXml;

        push @citations_json, {
            id => $count++,
            sourceCitationXml => $sourceCitationXml,
            sourceCitationText => $sourceCitationText,
            sortedCitationXml => $sortedCitationXml,
            sortedCitationText => $sortedCitationText,
        };
    }

    $input_file =~ s/\\/\\\\/g;
    return {
        citations => \@citations_json
    };
}

# Print JSON output with error checking
sub print_output {
    my ($output) = @_;

    eval {
        my $json = JSON->new->pretty->canonical->encode($output);
        print $json;
        1;
    } or do {
        my $error = $@ || 'Unknown error';
        die "Error generating JSON output: $error\n";
    };

    log_debug("Output generated successfully");
}

# Logging functions
sub log_debug {
    my ($message) = @_;
    return unless $DEBUG;
    print STDERR "[DEBUG] " . localtime() . " - $message\n";
}

sub log_info {
    my ($message) = @_;
    print STDERR "[INFO]  " . localtime() . " - $message\n";
}

# Run main with error handling
eval {
    main();
    1;
} or do {
    my $error = $@ || 'Unknown error';
    print STDERR "\nERROR: $error\n";
    exit 1;
};

__END__