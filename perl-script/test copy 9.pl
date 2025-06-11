#!/usr/bin/perl

use strict;
use warnings;
use JSON;
use XML::LibXML;
use Time::HiRes qw(time);
use File::Basename qw(basename);
use constant {
    MAX_FILE_SIZE => 100 * 1024 * 1024,
    PARSE_TIMEOUT => 30,
};

# Global variables
our $VERSION = '1.0';
our $DEBUG = $ENV{DEBUG} || 0;

# Main execution
sub main {
    my $start_time = time;
    log_info("Starting citation extractor v$VERSION");
    
    my $input_file = validate_command_line();
    validate_xml($input_file);
    my $content = read_file_content($input_file);
    my $citations = extract_citations($content);
    my $output = prepare_output($citations, $input_file);
    print_output($output);
    
    log_info(sprintf("Completed in %.2f seconds", time - $start_time));
}

# Validate command line arguments
sub validate_command_line {
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

# Validate XML file with timeout
sub validate_xml {
    my ($file) = @_;
    my $xml_parser = XML::LibXML->new();
    
    eval {
        local $SIG{ALRM} = sub { die "XML parsing timed out after " . PARSE_TIMEOUT . " seconds\n" };
        alarm PARSE_TIMEOUT;
        
        log_debug("Validating XML: $file");
        my $xml_doc = $xml_parser->parse_file($file);
        
        alarm 0;
    };
    
    if ($@) {
        die "Error: Failed to parse XML file '$file': $@";
    }
    
    log_debug("XML validation successful");
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
            (?:[\(])
            <bibcit\b[^>]*>  
            (?:.*?)
            <bibcit\b[^>]*>  
            (?:.*?)       
            (?:[\)])
            \)
        }x,

        qr{
            \(              
            [^\(]+
            <bibcit\b[^>]*>  
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
            (<bibcit\b[^>]*rid="(bib\d+)"[^>]*>[^<]+<\/bibcit>)
            \s*\)
        }xi,
        
        qr{
            ([A-Z][a-z]+(?:,\s+[A-Z][a-z]+)*
            (?:,\s+[A-Z][a-z]+)*
            (?:\s*[&,;]\s*[A-Z][a-z]+)*)
            \s*\(\s*                         
            <bibcit\b[^>]*rid="(bib\d+)"[^>]*>[^<]+<\/bibcit>
            (?:                               
            \s*,\s*                       
            <bibcit\b[^>]*rid="(bib\d+)"[^>]*>[^<]+<\/bibcit>
            )*
            \s*\)                             
        }xi,
        
        qr{
            ([A-Z][a-z]+)                      
            \s+<[^>]+>et\s*al\.<\/[^>]+>              
            \s*\(\s*                                  
            <bibcit\b[^>]*rid="(bib\d+)"[^>]*>[^<]+<\/bibcit>          
            \s*\)                                      
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
        
        while ($content =~ /$pattern/g) {
            my $full_match = $&;
            $matches++;
            
            if ($seen{$full_match}++) {
                $total_duplicates++;
                next;
            }
            
            push @citations, $full_match;
            $content =~ s/\Q$full_match\E//;
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
        push @citations_json, {
            id => $count++,
            citationId => $citation,
            citationText => sort_citations(clean_citation_text($citation)),
        };
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
    my ($citation_text) = @_;
    return '' unless defined $citation_text && $citation_text =~ /\S/;
    my $is_bracketed = $citation_text =~ /^\(.*\)$/s ? 1 : 0;
    $citation_text =~ s/^\((.*?)\)$/$1/g if $is_bracketed;  
    $citation_text =~ s/&amp;/&/gi;
    my @citations = map {
        s/^\s+|\s+$//g;
        s/\s+/ /g;
        s/á/a/g;
        $_;
    } grep { /\S/ } split(/;/, $citation_text);
    if (@citations > 1) {
        $citation_text =~ s/e\.g\.?\s*//gi;  
        @citations = sort {
            my ($a_author, $a_year) = ('', 0);
            my ($b_author, $b_year) = ('', 0);
            
            if ($a =~ /(.*?)\s+(\d{4}(?:[a-z]?))\s*$/) {
                ($a_author, $a_year) = ($1, $2);
            } else {
                $a_author = $a;
            }
            
            if ($b =~ /(.*?)\s+(\d{4}(?:[a-z]?))\s*$/) {
                ($b_author, $b_year) = ($1, $2);
            } else {
                $b_author = $b;
            }
            
            for ($a_author, $b_author) {
                next unless defined;
                s/&[^;]+;/ /g;
                s/^\s+|\s+$//g;
                s/\s+/ /g;
            }
            
            my $author_cmp = $a_author cmp $b_author;
            return $author_cmp if $author_cmp;
            
            $a_year =~ s/[^0-9]//g;  
            $b_year =~ s/[^0-9]//g;
            $a_year ||= 0;  
            $b_year ||= 0;
            
            $a_year <=> $b_year;
        } @citations;
    }
    
    my $result = join('; ', @citations);
    $result = "($result)" if $is_bracketed;
    $result =~ s/&/&amp;/g;
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
