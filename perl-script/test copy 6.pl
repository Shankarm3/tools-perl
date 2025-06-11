#!/usr/bin/perl
use strict;
use warnings;
use JSON;
use XML::LibXML;

# Main execution
sub main {
    my $input_file = validate_command_line();
    validate_xml($input_file);
    my $content = read_file_content($input_file);
    my $citations = extract_citations($content);
    my $output = prepare_output($citations, $input_file);
    print_output($output);
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
    
    return $input_file;
}

# Validate XML file
sub validate_xml {
    my ($file) = @_;
    my $xml_parser = XML::LibXML->new();
    eval {
        my $xml_doc = $xml_parser->parse_file($file);
    };
    if ($@) {
        die "Error: Invalid XML in file '$file': $@\n";
    }
}

# Read file content
sub read_file_content {
    my ($file) = @_;
    open(my $in_fh, '<:encoding(UTF-8)', $file) 
        or die "Could not open input file '$file': $!\n";
    local $/;
    my $content = <$in_fh>;
    close $in_fh;
    return $content;
}

# Define citation patterns
sub get_citation_patterns {
    return (
        qr{
            \(              
            [^<]+
            <bibcit\b[^>]*>  
            \d{4}            
            </bibcit>        
            [^)]*           
            \)
        }x,
        
        qr{
            ([A-Z][a-z]+,\s+[A-Z][a-z]+)             
            \s*\(\s*                                  
            <bibcit\b[^>]*>(\d{4})<\/bibcit>          
            \s*\)                                     
        }xi,
        
        qr{
            ([A-Z][a-z]+)\s*
            <bibcit\b[^>]*>(\d{4})<\/bibcit>
        }xi,
        
        qr{
            ([A-Z][a-z]+,\s+[A-Z][a-z]+\s*&\s*[A-Z][a-z]+) 
            \s*\(\s*                                          
            <bibcit\b[^>]*>(\d{4})<\/bibcit>                  
            \s*\)+                                            
        }xi,
        
        qr{
            ([A-Z][a-z]+,\s+[A-Z][a-z]+)             
            \s*\(\s*                                  
            <bibcit\b[^>]*>(\d{4})<\/bibcit>          
            \s*;\s*                                   
            \s*<bibcit\b[^>]*>\d+<\/bibcit>           
            \s*\)                                     
        }xi,
        
        qr{
            ([A-Z][a-z]+)                              
            \s+<[^>]+>et\s*al\.<\/[^>]+>              
            \s*\(\s*                                  
            <bibcit\b[^>]*>(\d{4})<\/bibcit>          
            \s*\)                                      
        }xi
    );
}

# Extract citations using patterns
sub extract_citations {
    my ($content) = @_;
    my %citations;
    my %seen;
    my $total_duplicates = 0;
    
    my @patterns = get_citation_patterns();
    
    foreach my $pattern (@patterns) {
        while ($content =~ /$pattern/g) {
            my $full_match = $&;
            
            if ($seen{$full_match}++) {
                $total_duplicates++;
                next;
            }         
            
            my $year;
            if ($pattern == $patterns[0]) {  # Special handling for first pattern
                $year = ($full_match =~ /<bibcit[^>]*>(\d{4})/)[0];
            } else {
                $year = $+;
            }
            
            $citations{$full_match} = $year;
            $content =~ s/\Q$full_match\E//;
        }
    }
    
    return {
        citations => \%citations,
        duplicates => $total_duplicates
    };
}

# Clean citation text
sub clean_citation_text {
    my ($text) = @_;
    $text =~ s/<[^>]+>//g;
    $text =~ s/\s+/ /g; 
    $text =~ s/\s+\)/)/g; 
    $text =~ s/\(\s+/(/g; 
    $text =~ s/^\s+|\s+$//g; 
    return $text;
}

# Prepare output data structure
sub prepare_output {
    my ($data, $input_file) = @_;
    my @citations_json;
    my $count = 1;
    
    foreach my $citation (sort { 
        ($data->{citations}{$a} || 0) <=> ($data->{citations}{$b} || 0) || 
        $a cmp $b 
    } keys %{$data->{citations}}) {
        push @citations_json, {
            id => $count++,
            citationId => $citation,
            citationText => clean_citation_text($citation),
        };
    }
    
    return {
        metadata => {
            sourceFile => $input_file,
            extractionDate => scalar localtime,
            totalCitations => scalar @citations_json,
            totalDuplicates => $data->{duplicates}
        },
        citations => \@citations_json
    };
}

# Print JSON output
sub print_output {
    my ($output) = @_;
    my $json = JSON->new->pretty->encode($output);
    print $json;
}

# Run main
main();

# Logs
sub log_debug {
    my ($message) = @_;
    print STDERR "[DEBUG] $message\n" if $ENV{DEBUG};
}
