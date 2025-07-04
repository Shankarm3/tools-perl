#!/usr/bin/perl

###############################################################################
# Script Name : extract_citations.pl
# Description : Extracts and sorts citations from an XML file with <bibcit> tags.
# Author      : Shankar Dutt Mishra
# Created     : 2024-05-29
# Version     : 1.0
#
# Usage       : perl extract_citations.pl <xml_file>
#               perl extract_citations.pl --help
#
# Notes       : Requires Perl modules: JSON
###############################################################################

use strict;
use warnings;
use JSON;
use File::Basename qw(basename);
use constant {
    MAX_FILE_SIZE => 100 * 1024 * 1024,
};

# Global variables
our $VERSION = '1.0';
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
        Extracts and sorts citations from an XML file with <bibcit> tags.

        Options:
        <xml_file>   Path to the input XML file.
        -h, --help   Show this help message.

        Example:
        perl $0 staf323.xml

USAGE
        exit 0;
    }

    die "Usage: $0 <xml_file>\n" unless @ARGV == 1;
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
    close $in_fh;

    return $content;
}

# Define citation patterns with comments
sub get_citation_patterns {
    return (
        qr{
            \(
            (?:
                [^\(\)]*?
                <bibcit\b[^>]*rid="(?:bib\d+)"[^>]*>
                [^<]*?
                <\/bibcit>
            ){2,}
            [^\(\)]*?
            \)
        }xi,

        qr{
            ([A-Z][a-z]+(?:,\s+[A-Z][a-z]+)*(?:,\s+[A-Z][a-z]+)*(?:\s*[&,;]\s*[A-Z][a-z]+)*)
            \s*\(\s*
            <bibcit\b[^>]*rid="(?:bib\d+)"[^>]*>[^<]+<\/bibcit>
            (?:
                \s*,\s*
                <bibcit\b[^>]*rid="(?:bib\d+)"[^>]*>[^<]+<\/bibcit>
            )*
            \s*\)
        }xi,

        qr{
            ([A-Z][a-z]+)
            \s+<[^>]+>et\s*al\.<\/[^>]+>
            \s*\(\s*
            <bibcit\b[^>]*rid="(?:bib\d+)"[^>]*>[^<]+<\/bibcit>
            \s*\)
        }xi,

        qr{
            ([A-Z][a-z]+(?:,\s+[A-Z][a-z]+)*(?:,\s+[A-Z][a-z]+)*(?:\s*[&,;]\s*[A-Z][a-z]+)*)
            \s*\(\s*
            <bibcit\b[^>]*rid="(?:bib\d+)"[^>]*>[^<]+<\/bibcit>
            \s*\)
        }xi,

        qr{
            ([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)
            \s*\(\s*
            <bibcit\b[^>]*rid="(?:bib\d+)"[^>]*>
            [^<]+
            <\/bibcit>
            \s*\)
        }xi,

        qr{
            ([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)
            \s*
            <bibcit\b[^>]*rid="(?:bib\d+)"[^>]*>
            [^<]+
            <\/bibcit>
        }xi,

        qr{
            \(([^()<>]+?)\s*<bibcit[^>]*?>\d{4}</bibcit>\)
        }xi,

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

sub clean_citation_text {
    my ($text) = @_;
    return '' unless defined $text;

    $text =~ s/<[^>]+>//g;
    $text =~ s/\s+/ /g;
    $text =~ s/\s+\)/)/g;
    $text =~ s/\(\s+/(/g;
    $text =~ s/^\s+|\s+$//g;

    return $text;
}

# Prepare output data structure with metadata
sub prepare_output {
    my ($citations, $input_file) = @_;
    my @citations_json;
    my $count = 1;

    log_debug("Preparing output data");
    foreach my $citation (@$citations) {
        my $actual_replacement = 0;
        my $citation_text = sort_citations(clean_citation_text($citation), \$actual_replacement);
        if($actual_replacement > 0){
            push @citations_json, {
                id => $count++,
                citationId => $citation,
                citationText => $citation_text,
            };
        }
    }

    return {
        metadata => {
            sourceFile => basename($input_file),
            sourcePath => $input_file,
            extractionDate => scalar localtime,
        },
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

sub sort_citations {
    my ($citation_text, $counter_ref) = @_;
    return '' unless defined $citation_text && $citation_text =~ /\S/;
    my $is_bracketed = $citation_text =~ /^\(.*\)$/s ? 1 : 0;
    $citation_text =~ s/\(out to.*?e\.g./\(/ig;
    $citation_text =~ s/^\((.*?)\)$/$1/g if $is_bracketed;  
    $citation_text =~ s/\s+e\.g\.|e\.g\.\s+//gi;
    $citation_text =~ s/\s+i\.e\.;?|i\.e\.\s*;?//gi;
    $citation_text =~ s/see,\s*//gi;
    $citation_text =~ s/\band\b//gi;
    $citation_text =~ s/&[^;]+;//gi;
    $citation_text =~ s/\s+/ /g;
    $citation_text =~ s/^\s+|\s+$//g;

    my $original_citation_text = $citation_text;
    my @citations = map {
        s/^\s+|\s+$//g;
        s/\s+/ /g;
        s/á/a/g;
        $_;
    } grep { /\S/ } split(/;/, $citation_text);
    if (@citations > 1) {
        @citations = sort {
            my ($a_base, $a_year) = $a =~ /^(.+?)(?:\s+et al\.)?\s*(\d{4}[a-z]?)/i;
            my ($b_base, $b_year) = $b =~ /^(.+?)(?:\s+et al\.)?\s*(\d{4}[a-z]?)/i;

            $a_base //= $a; $a_year //= 0;
            $b_base //= $b; $b_year //= 0;

            $a_base =~ s/\s+et al\.//i;
            $b_base =~ s/\s+et al\.//i;
            $a_base = lc $a_base;
            $b_base = lc $b_base;

            my $a_is_et_al = ($a =~ /et al\./i) ? 0 : 1;
            my $b_is_et_al = ($b =~ /et al\./i) ? 0 : 1;

            my $cmp = $a_base cmp $b_base;
            return $cmp if $cmp;
            $cmp = $a_is_et_al <=> $b_is_et_al;
            return $cmp if $cmp;
            $a_year =~ s/[^0-9]//g;
            $b_year =~ s/[^0-9]//g;
            $a_year ||= 0;
            $b_year ||= 0;
            return $a_year <=> $b_year;
        } @citations;
        if($original_citation_text ne join('; ', @citations)){
            ${$counter_ref}++;
        }
    }

    my $result = join('; ', @citations);
    $result = "($result)" if $is_bracketed;
    return $result;
}

# Logging functions
sub log_debug {
    my ($message) = @_;
    return unless $DEBUG;
    print STDERR "[DEBUG] " . localtime() . " - $message\n";
}

# Logging info
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